// functions/catalogo.js — Etapa 22: catálogo global de seguradoras
//
// Uma lista só para todas as corretoras, em catalogo_seguradoras/{id}:
//   { nome, chave, cnpj (só dígitos ou ''), razaoSocial, susep, apelidos: [],
//     situacao: 'aprovada' | 'pendente' | 'juntada' | 'recusada' | 'inativa',
//     origem: 'importada' | 'sugerida' | 'portal',
//     criadaPor: { empresaId, uid, email } (sugeridas), criadaEm, atualizadaEm,
//     aprovadaEm, juntadaCom, motivo }
// Só o servidor grava. As corretoras leem as aprovadas + as pendentes que elas
// mesmas sugeriram (firestore.rules).
//
// O que cada corretora tem de próprio (telefone, e-mail, contato, "não trabalho
// com essa") continua em corretoras/{e}/seguradoras/{id}, com catalogoId.
//
// Os registros (sinistros, assistências, apólices dos clientes) guardam o NOME.
// O catálogo garante nome único; renomear ou juntar no portal troca o nome em
// todas as corretoras (renomearNosRegistros).
//
// Seguradora nova: a corretora informa o CNPJ; QUEM consulta a Receita é o
// servidor (BrasilAPI), então o nome é o oficial — não dá para digitar errado.
// Ela entra como "pendente", a corretora já pode usar, e o admin aprova / junta /
// recusa no portal.

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const { usuarioAtivo } = require('./seguranca');

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();
const agora = () => admin.firestore.FieldValue.serverTimestamp();
const COL = 'catalogo_seguradoras';

// ── nomes (mesmas regras de lib/utils/relatorio_modelo.dart → chaveSeguradora) ──

function semAcento(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '');
}

/** CHUBB = Chubb = "Chubb Seguros" = "CHUBB S.A." */
function chave(nome) {
  const t = semAcento(nome).toUpperCase().replace(/[./-]/g, '').replace(/[^A-Z0-9 ]/g, ' ');
  const p = t.split(/\s+/).filter(Boolean);
  const sufixos = new Set(['SEGUROS', 'SEGURADORA', 'SA', 'CIA']);
  while (p.length > 1 && sufixos.has(p[p.length - 1])) p.pop();
  return p.join(' ');
}

const simples = (s) => semAcento(s).toUpperCase().replace(/\s+/g, ' ').trim();
const digitos = (s) => String(s || '').replace(/\D/g, '');

function cnpjValido(c) {
  const d = digitos(c);
  if (d.length !== 14 || /^(\d)\1{13}$/.test(d)) return false;
  const dv = (base, pesos) => {
    const soma = pesos.reduce((s, p, i) => s + Number(base[i]) * p, 0);
    const r = soma % 11;
    return r < 2 ? 0 : 11 - r;
  };
  return dv(d, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) === Number(d[12])
    && dv(d, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]) === Number(d[13]);
}

const formatarCnpj = (c) => {
  const d = digitos(c);
  return d.length === 14 ? `${d.slice(0, 2)}.${d.slice(2, 5)}.${d.slice(5, 8)}/${d.slice(8, 12)}-${d.slice(12)}` : c;
};

/** Consulta a Receita (BrasilAPI). { ok, razaoSocial, nomeFantasia, situacao } ou { erro, codigo }. */
async function consultarReceita(cnpj) {
  try {
    const r = await fetch(`https://brasilapi.com.br/api/cnpj/v1/${digitos(cnpj)}`, { signal: AbortSignal.timeout(15000) });
    if (r.status === 404) return { erro: 'CNPJ não encontrado na Receita Federal.', codigo: 404 };
    if (r.status !== 200) return { erro: `A consulta à Receita não respondeu agora (${r.status}). Tente de novo.`, codigo: 502 };
    const j = await r.json();
    const t = (v) => String(v || '').trim();
    return {
      ok: true,
      razaoSocial: t(j.razao_social),
      nomeFantasia: t(j.nome_fantasia) || t(j.nome_Fantasia),
      situacao: t(j.descricao_situacao_cadastral),
    };
  } catch (e) {
    logger.warn('consultarReceita', e.message);
    return { erro: 'A consulta à Receita não respondeu agora. Tente de novo.', codigo: 502 };
  }
}

// ── leitura do catálogo ──────────────────────────────────────────────────────

async function todasDoCatalogo() {
  const s = await db().collection(COL).get();
  return s.docs.map((d) => ({ id: d.id, ...(d.data() || {}) }));
}

/** Entrada viva (aprovada ou pendente) com a mesma chave de nome — ou null. */
function mesmaChave(lista, nome, exceto = '') {
  const k = chave(nome);
  return lista.find((x) => x.id !== exceto && ['aprovada', 'pendente'].includes(x.situacao) && chave(x.nome) === k) || null;
}

// ── troca de nome em todas as corretoras ─────────────────────────────────────

async function gravarEmLotes(ops) {
  for (let i = 0; i < ops.length; i += 400) {
    const lote = db().batch();
    for (const [ref, dados] of ops.slice(i, i + 400)) lote.update(ref, dados);
    await lote.commit();
  }
}

/**
 * Troca o nome da seguradora [antigo] por [novo] em sinistros, assistências,
 * apólices dos clientes e no cadastro de seguradoras de TODAS as corretoras.
 * [catalogoId]: grava também o vínculo no cadastro da corretora.
 */
async function renomearNosRegistros(antigo, novo, catalogoId = null) {
  const total = { sinistros: 0, assistencias: 0, clientes: 0, cadastros: 0 };
  if (!antigo || antigo === novo) return total;
  const corretoras = await db().collection('corretoras').listDocuments();
  for (const c of corretoras) {
    const ops = [];
    for (const col of ['sinistros', 'assistencias']) {
      const s = await c.collection(col).where('seguradora', '==', antigo).get();
      for (const d of s.docs) ops.push([d.ref, { seguradora: novo }]);
      total[col] += s.size;
    }
    const clientes = await c.collection('clientes').get();
    for (const d of clientes.docs) {
      const ap = (d.data() || {}).apolices;
      if (!Array.isArray(ap)) continue;
      let mudou = false;
      const nova = ap.map((a) => {
        if (a && typeof a === 'object' && a.seguradora === antigo) {
          mudou = true;
          return { ...a, seguradora: novo };
        }
        return a;
      });
      if (mudou) {
        ops.push([d.ref, { apolices: nova }]);
        total.clientes++;
      }
    }
    const cad = await c.collection('seguradoras').where('nome', '==', antigo).get();
    for (const d of cad.docs) ops.push([d.ref, catalogoId ? { nome: novo, catalogoId } : { nome: novo }]);
    total.cadastros += cad.size;
    await gravarEmLotes(ops);
  }
  return total;
}

/** Quantos registros usam o nome, somando todas as corretoras. */
async function usoDoNome(nome) {
  const r = { sinistros: 0, assistencias: 0, apolices: 0 };
  const corretoras = await db().collection('corretoras').listDocuments();
  for (const c of corretoras) {
    for (const col of ['sinistros', 'assistencias']) {
      const s = await c.collection(col).where('seguradora', '==', nome).count().get();
      r[col] += s.data().count;
    }
    const clientes = await c.collection('clientes').get();
    for (const d of clientes.docs) {
      const ap = (d.data() || {}).apolices;
      if (Array.isArray(ap)) r.apolices += ap.filter((a) => a && a.seguradora === nome).length;
    }
  }
  return { ...r, total: r.sinistros + r.assistencias + r.apolices };
}

// ── Function das corretoras ──────────────────────────────────────────────────

/**
 * POST com "Authorization: Bearer <ID token>" de usuário ativo de corretora.
 *   { acao: 'consultarCnpj', cnpj }        → { existente: {id,nome,situacao} } ou
 *                                            { receita: {cnpj, razaoSocial, nomeFantasia, situacao} }
 *   { acao: 'sugerir', cnpj, nome }        → { seguradora: {id, nome, situacao}, existente: bool }
 *     [nome] tem de ser o nome fantasia ou a razão social que a Receita devolveu.
 */
const catalogoSeguradoras = onRequest((req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const u = await usuarioAtivo(req);
      const empresaId = u && String((u.dados || {}).empresaId || '');
      if (!u || !empresaId) return res.status(403).json({ erro: 'Entre com um usuário ativo de corretora.' });

      const corpo = req.body || {};
      const cnpj = digitos(corpo.cnpj);
      if (!cnpjValido(cnpj)) return res.status(400).json({ erro: 'CNPJ inválido — confira os 14 dígitos.' });

      const catalogo = await todasDoCatalogo();
      if (!catalogo.some((x) => x.situacao === 'aprovada')) {
        return res.status(409).json({ erro: 'O catálogo de seguradoras ainda não foi montado pela plataforma. Use a lista atual por enquanto.' });
      }
      const porCnpj = catalogo.find((x) => x.cnpj === cnpj && ['aprovada', 'pendente'].includes(x.situacao));
      const visivel = (x) => x.situacao === 'aprovada' || ((x.criadaPor || {}).empresaId === empresaId);
      const resumo = (x) => ({ id: x.id, nome: x.nome, situacao: x.situacao });

      if (corpo.acao === 'consultarCnpj') {
        if (porCnpj && visivel(porCnpj)) return res.json({ existente: resumo(porCnpj) });
        const rec = await consultarReceita(cnpj);
        if (!rec.ok) return res.status(rec.codigo === 404 ? 404 : 502).json({ erro: rec.erro });
        return res.json({ receita: { cnpj: formatarCnpj(cnpj), razaoSocial: rec.razaoSocial, nomeFantasia: rec.nomeFantasia, situacao: rec.situacao } });
      }

      if (corpo.acao === 'sugerir') {
        if (porCnpj && visivel(porCnpj)) return res.json({ seguradora: resumo(porCnpj), existente: true });
        if (porCnpj) {
          // pendente de OUTRA corretora com o mesmo CNPJ: não duplica, deixa ela visível para esta também
          return res.status(409).json({ erro: 'Essa seguradora já foi enviada para aprovação por outra corretora. Assim que for aprovada, aparece na lista.' });
        }
        const rec = await consultarReceita(cnpj);
        if (!rec.ok) return res.status(rec.codigo === 404 ? 404 : 502).json({ erro: rec.erro });
        const opcoes = [rec.nomeFantasia, rec.razaoSocial].filter(Boolean);
        const nome = opcoes.find((o) => simples(o) === simples(corpo.nome)) || rec.nomeFantasia || rec.razaoSocial;
        const parecida = mesmaChave(catalogo, nome);
        if (parecida && visivel(parecida)) return res.json({ seguradora: resumo(parecida), existente: true });
        if (parecida) {
          return res.status(409).json({ erro: `Já existe "${parecida.nome}" aguardando aprovação. Assim que for aprovada, aparece na lista.` });
        }
        const ref = db().collection(COL).doc();
        await ref.set({
          nome,
          chave: chave(nome),
          cnpj,
          razaoSocial: rec.razaoSocial,
          susep: '',
          apelidos: [],
          situacao: 'pendente',
          origem: 'sugerida',
          situacaoReceita: rec.situacao,
          criadaPor: { empresaId, uid: u.uid, email: u.email || '' },
          criadaEm: agora(),
          atualizadaEm: agora(),
        });
        return res.json({ seguradora: { id: ref.id, nome, situacao: 'pendente' }, existente: false });
      }

      return res.status(400).json({ erro: 'Ação desconhecida' });
    } catch (e) {
      logger.error(e);
      if (!res.headersSent) res.status(500).json({ erro: 'Erro interno' });
    }
  }),
);

module.exports = {
  catalogoSeguradoras,
  chave,
  cnpjValido,
  formatarCnpj,
  consultarReceita,
  todasDoCatalogo,
  mesmaChave,
  renomearNosRegistros,
  usoDoNome,
  COL,
};
