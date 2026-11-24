// functions/plataforma.js — Etapa 21: portal da plataforma (admin do SaaS)
//
// O portal (site separado, lib/main_admin.dart) NÃO lê o Firestore direto: tudo
// passa por esta Function, que confere o admin e registra a auditoria.
//
// Quem é admin da plataforma (dupla checagem, como no QuotaFlow):
//   1. o token de login tem a marca  plataforma: true  (só o script
//      functions/scripts/admin-plataforma.js põe essa marca — não há tela);
//   2. plataforma_admins/{uid} existe com ativo: true (o script "remover"
//      desliga na hora, sem esperar o token vencer);
//   e NÃO é usuário de corretora (não tem users/{uid}): a conta de admin é
//   separada das contas dos clientes.
// O contrário também vale: o token de um usuário de corretora nunca passa aqui
// (não tem a marca), e as Functions dos clientes exigem users/{uid} — o admin
// não tem.
//
// Coleções novas (raiz) — o app não grava nenhuma; só esta Function / o script:
//   plataforma_admins/{uid}         { email, ativo, desde }
//   plataforma_auditoria/{id}       { em, uid, email, acao, alvoTipo, alvoId, detalhes }
//   plataforma_contas/{empresaId}   assinatura da corretora (situação, plano…)
//   plataforma_contas/{e}/historico quem mudou o quê, de → para
// A conta NÃO fica em corretoras/{e}: lá o gestor da corretora pode gravar
// (e poderia ligar o próprio plano).

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

const cat = require('./catalogo'); // Etapa 22
const mod = require('./modulos'); // Etapa 23
const planos = require('./planos'); // Etapa 24

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();
const agora = () => admin.firestore.FieldValue.serverTimestamp();

// Situações da conta (Etapa 25 liga o teste grátis e o "só leitura").
const SITUACOES = ['teste', 'teste_encerrado', 'ativa', 'inadimplente', 'suspensa', 'cancelada'];

/** Admin da plataforma ou null. Nunca lança. */
async function adminDaPlataforma(req) {
  const m = String((req.get && req.get('Authorization')) || '').match(/^Bearer (.+)$/);
  if (!m) return null;
  try {
    const t = await admin.auth().verifyIdToken(m[1]);
    if (t.plataforma !== true) return null;
    const [reg, usuario] = await Promise.all([
      db().collection('plataforma_admins').doc(t.uid).get(),
      db().collection('users').doc(t.uid).get(),
    ]);
    if (!reg.exists || (reg.data() || {}).ativo !== true) return null;
    if (usuario.exists) {
      logger.warn('Conta com marca de admin também é usuária de corretora — recusada', t.uid);
      return null;
    }
    return { uid: t.uid, email: t.email || (reg.data() || {}).email || '' };
  } catch (e) {
    logger.warn('plataforma: token inválido', e.message);
    return null;
  }
}

async function auditar(quem, acao, { alvoTipo = '', alvoId = '', detalhes = {} } = {}) {
  await db().collection('plataforma_auditoria').doc().set({
    em: agora(),
    uid: quem.uid,
    email: quem.email,
    acao,
    alvoTipo,
    alvoId,
    detalhes,
  });
}

async function contar(col) {
  try {
    const s = await col.count().get();
    return s.data().count;
  } catch (e) {
    return null;
  }
}

const data = (v) => (v && typeof v.toDate === 'function' ? v.toDate().toISOString() : v || null);

function resumoConta(c) {
  if (!c) return null;
  return {
    situacao: c.situacao || '',
    plano: c.plano || null,
    cortesia: c.cortesia === true,
    cortesiaAte: data(c.cortesiaAte), // Etapa 24
    modulos: Array.isArray(c.modulos) ? c.modulos : null, // Etapa 23 (null = tudo ligado)
    observacao: c.observacao || '',
    testeAte: data(c.testeAte),
    criadaEm: data(c.criadaEm),
  };
}

/** Lista das corretoras com o essencial para o portal. */
async function listarCorretoras() {
  const refs = await db().collection('corretoras').listDocuments();
  const lista = [];
  for (const ref of refs) {
    const [cad, conta, usuarios, sinistros, assistencias, clientes] = await Promise.all([
      ref.get(),
      db().collection('plataforma_contas').doc(ref.id).get(),
      contar(db().collection('users').where('empresaId', '==', ref.id)),
      contar(ref.collection('sinistros')),
      contar(ref.collection('assistencias')),
      contar(ref.collection('clientes')),
    ]);
    const c = cad.exists ? cad.data() || {} : {};
    lista.push({
      id: ref.id,
      nome: c.nome || '(sem cadastro)',
      razaoSocial: c.razaoSocial || '',
      cnpj: c.cnpj || '',
      email: c.email || '',
      telefone: c.telefone || '',
      criadaEm: data(c.dataCriacao),
      usuarios,
      sinistros,
      assistencias,
      clientes,
      conta: conta.exists ? resumoConta(conta.data()) : null,
    });
  }
  lista.sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'));
  return lista;
}

/** Cria a conta das corretoras que ainda não têm (lição do QuotaFlow: conta sem
 *  assinatura some da receita). Entram como "ativa", "Tudo ligado", cortesia. */
async function criarContasQueFaltam(quem) {
  const refs = await db().collection('corretoras').listDocuments();
  const criadas = [];
  for (const ref of refs) {
    const contaRef = db().collection('plataforma_contas').doc(ref.id);
    if ((await contaRef.get()).exists) continue;
    const conta = {
      situacao: 'ativa',
      plano: { tipo: 'tudo_ligado', nome: 'Tudo ligado' },
      cortesia: true,
      observacao: 'Corretora anterior aos planos (fundadora).',
      criadaEm: agora(),
      atualizadaEm: agora(),
    };
    await contaRef.set(conta);
    await contaRef.collection('historico').doc().set({
      em: agora(),
      email: quem.email,
      acao: 'conta_criada',
      de: null,
      para: { situacao: conta.situacao, plano: conta.plano, cortesia: true },
      motivo: conta.observacao,
    });
    criadas.push(ref.id);
  }
  if (criadas.length) await auditar(quem, 'contas_criadas', { alvoTipo: 'corretora', detalhes: { ids: criadas } });
  return criadas;
}

async function ultimasAcoes(limite = 100) {
  const snap = await db().collection('plataforma_auditoria').orderBy('em', 'desc').limit(limite).get();
  return snap.docs.map((d) => {
    const a = d.data() || {};
    return { id: d.id, em: data(a.em), email: a.email || '', acao: a.acao || '', alvoTipo: a.alvoTipo || '', alvoId: a.alvoId || '', detalhes: a.detalhes || {} };
  });
}

// ── Etapa 23: módulos da corretora ───────────────────────────────────────────

/** Define os módulos de uma corretora: "tudo ligado" ou a lista escolhida.
 *  A conta precisa existir (portal → "Criar contas que faltam"). */
async function definirModulos(quem, { empresaId, tipo, modulos }) {
  const e = String(empresaId || '');
  if (!e) throw new ErroDeUso('Informe a corretora.');
  if (!['tudo_ligado', 'personalizado'].includes(tipo)) throw new ErroDeUso('Tipo de plano inválido.');
  const ref = db().collection('plataforma_contas').doc(e);
  const atual = await ref.get();
  if (!atual.exists) throw new ErroDeUso('Esta corretora ainda não tem conta. Use "Criar contas que faltam".', 409);
  const antes = atual.data() || {};
  const lista = tipo === 'tudo_ligado' ? null : [...mod.efetivos(Array.isArray(modulos) ? modulos : [])].sort();
  const plano = { ...(antes.plano || {}), tipo, nome: tipo === 'tudo_ligado' ? 'Tudo ligado' : 'Personalizado' };
  await ref.update({
    plano,
    modulos: lista === null ? admin.firestore.FieldValue.delete() : lista,
    atualizadaEm: agora(),
  });
  await ref.collection('historico').doc().set({
    em: agora(),
    email: quem.email,
    acao: 'modulos',
    de: { plano: antes.plano || null, modulos: Array.isArray(antes.modulos) ? antes.modulos : null },
    para: { plano, modulos: lista },
  });
  await auditar(quem, 'modulos_definidos', { alvoTipo: 'corretora', alvoId: e, detalhes: { tipo, modulos: lista } });
  return { ok: true, modulos: lista };
}

// ── Etapa 22: catálogo global de seguradoras ─────────────────────────────────

class ErroDeUso extends Error {
  constructor(msg, codigo = 400) { super(msg); this.codigo = codigo; }
}

const limparApelidos = (lista, nome) => {
  const vistos = new Set([cat.chave(nome) + '|' + String(nome).trim().toUpperCase()]);
  const r = [];
  for (const a of Array.isArray(lista) ? lista : []) {
    const t = String(a || '').trim();
    if (!t || t.toUpperCase() === String(nome).trim().toUpperCase()) continue;
    const k = t.toUpperCase();
    if (vistos.has(k)) continue;
    vistos.add(k);
    r.push(t);
  }
  return r;
};

async function catalogoParaPortal() {
  const lista = await cat.todasDoCatalogo();
  const nomesCorretora = {};
  for (const x of lista) {
    const e = (x.criadaPor || {}).empresaId;
    if (e && !(e in nomesCorretora)) {
      const c = await db().collection('corretoras').doc(e).get();
      nomesCorretora[e] = c.exists ? (c.data() || {}).nome || e : e;
    }
  }
  return lista
    .map((x) => ({
      id: x.id,
      nome: x.nome || '',
      cnpj: x.cnpj ? cat.formatarCnpj(x.cnpj) : '',
      razaoSocial: x.razaoSocial || '',
      susep: x.susep || '',
      apelidos: Array.isArray(x.apelidos) ? x.apelidos : [],
      situacao: x.situacao || '',
      origem: x.origem || '',
      situacaoReceita: x.situacaoReceita || '',
      dadosReceita: x.dadosReceita || '',
      criadaPor: x.criadaPor ? { ...x.criadaPor, corretora: nomesCorretora[x.criadaPor.empresaId] || '' } : null,
      criadaEm: data(x.criadaEm),
      juntadaCom: x.juntadaCom || '',
      motivo: x.motivo || '',
    }))
    .sort((a, b) => a.nome.localeCompare(b.nome, 'pt-BR'));
}

/** Monta o catálogo a partir do cadastro de seguradoras das corretoras (uma vez;
 *  rodar de novo só vincula o que faltar). Grafias parecidas viram uma entrada
 *  (a mais usada vira o nome; as outras, apelidos). */
async function importarDasCorretoras(quem) {
  const grupos = new Map(); // chave → { grafias: Map nome→qtd, docs: [{ref, nome}] }
  const corretoras = await db().collection('corretoras').listDocuments();
  for (const c of corretoras) {
    const s = await c.collection('seguradoras').get();
    for (const d of s.docs) {
      const nome = String((d.data() || {}).nome || '').trim();
      if (!nome) continue;
      const k = cat.chave(nome);
      if (!grupos.has(k)) grupos.set(k, { grafias: new Map(), docs: [] });
      const g = grupos.get(k);
      g.grafias.set(nome, (g.grafias.get(nome) || 0) + 1);
      g.docs.push({ ref: d.ref, nome, catalogoId: (d.data() || {}).catalogoId || '' });
    }
  }
  const catalogo = await cat.todasDoCatalogo();
  const r = { criadas: 0, vinculadas: 0, renomeadas: 0 };
  for (const g of grupos.values()) {
    const grafias = [...g.grafias.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
    let alvo = cat.mesmaChave(catalogo, grafias[0][0]);
    if (!alvo) {
      const nome = grafias[0][0];
      const ref = db().collection(cat.COL).doc();
      alvo = { id: ref.id, nome, situacao: 'aprovada', apelidos: limparApelidos(grafias.map((x) => x[0]), nome) };
      await ref.set({
        nome,
        chave: cat.chave(nome),
        cnpj: '',
        razaoSocial: '',
        susep: '',
        apelidos: alvo.apelidos,
        situacao: 'aprovada',
        origem: 'importada',
        criadaEm: agora(),
        aprovadaEm: agora(),
        atualizadaEm: agora(),
      });
      catalogo.push(alvo);
      r.criadas++;
    } else {
      const novos = limparApelidos([...(alvo.apelidos || []), ...grafias.map((x) => x[0])], alvo.nome);
      if (novos.length !== (alvo.apelidos || []).length) {
        await db().collection(cat.COL).doc(alvo.id).update({ apelidos: novos, atualizadaEm: agora() });
        alvo.apelidos = novos;
      }
    }
    for (const d of g.docs) {
      if (d.nome !== alvo.nome) {
        await cat.renomearNosRegistros(d.nome, alvo.nome, alvo.id);
        r.renomeadas++;
      } else if (d.catalogoId !== alvo.id) {
        await d.ref.update({ catalogoId: alvo.id });
      }
      r.vinculadas++;
    }
  }
  await auditar(quem, 'catalogo_importado', { alvoTipo: 'catalogo', detalhes: r });
  return r;
}

async function entrada(id) {
  if (!id) throw new ErroDeUso('Informe a seguradora.');
  const d = await db().collection(cat.COL).doc(String(id)).get();
  if (!d.exists) throw new ErroDeUso('Seguradora não encontrada no catálogo.', 404);
  return { id: d.id, ref: d.ref, ...(d.data() || {}) };
}

/** Troca o nome de uma entrada (confere duplicidade e atualiza os registros). */
async function trocarNome(e, novoNome) {
  const nome = String(novoNome || '').trim();
  if (!nome || nome === e.nome) return null;
  const outra = cat.mesmaChave(await cat.todasDoCatalogo(), nome, e.id);
  if (outra) throw new ErroDeUso(`Já existe "${outra.nome}" no catálogo — use "Juntar".`, 409);
  const total = await cat.renomearNosRegistros(e.nome, nome, e.id);
  await e.ref.update({ nome, chave: cat.chave(nome), apelidos: limparApelidos([...(e.apelidos || []), e.nome], nome), atualizadaEm: agora() });
  return total;
}

/** 22.1: o admin cria direto (aprovada), com o CNPJ consultado no portal. */
async function criar(quem, { cnpj, nome, razaoSocial, susep }) {
  const c = String(cnpj || '').replace(/\D/g, '');
  const n = String(nome || '').trim();
  if (!n) throw new ErroDeUso('Informe o nome.');
  if (c && !cat.cnpjValido(c)) throw new ErroDeUso('CNPJ inválido.');
  const lista = await cat.todasDoCatalogo();
  const vivas = ['aprovada', 'pendente', 'inativa'];
  const porCnpj = c && lista.find((x) => x.cnpj === c && vivas.includes(x.situacao));
  if (porCnpj) throw new ErroDeUso(`Esse CNPJ já é de "${porCnpj.nome}".`, 409);
  const parecida = cat.mesmaChave(lista, n);
  if (parecida) throw new ErroDeUso(`Já existe "${parecida.nome}" — edite essa (pode pôr o CNPJ nela).`, 409);
  const ref = db().collection(cat.COL).doc();
  await ref.set({
    nome: n,
    chave: cat.chave(n),
    cnpj: c,
    razaoSocial: String(razaoSocial || '').trim(),
    susep: String(susep || '').trim(),
    apelidos: [],
    situacao: 'aprovada',
    origem: 'portal',
    criadaEm: agora(),
    aprovadaEm: agora(),
    atualizadaEm: agora(),
  });
  await auditar(quem, 'seguradora_criada', { alvoTipo: 'seguradora', alvoId: ref.id, detalhes: { nome: n, cnpj: c } });
  return { ok: true, id: ref.id };
}

async function aprovar(quem, { id, nome }) {
  const e = await entrada(id);
  if (e.situacao !== 'pendente') throw new ErroDeUso('Só dá para aprovar uma seguradora pendente.');
  const renomeados = await trocarNome(e, nome);
  await e.ref.update({ situacao: 'aprovada', aprovadaEm: agora(), atualizadaEm: agora() });
  await auditar(quem, 'seguradora_aprovada', { alvoTipo: 'seguradora', alvoId: e.id, detalhes: { nome: nome || e.nome, de: e.nome, renomeados } });
  return { ok: true };
}

async function editar(quem, { id, nome, cnpj, susep, apelidos, ativa, razaoSocial }) {
  const e = await entrada(id);
  if (!['aprovada', 'inativa', 'pendente'].includes(e.situacao)) throw new ErroDeUso('Esta entrada não pode mais ser editada.');
  const mudancas = {};
  const c = cnpj === undefined ? undefined : String(cnpj).replace(/\D/g, '');
  if (c !== undefined && c !== (e.cnpj || '')) {
    if (c && !cat.cnpjValido(c)) throw new ErroDeUso('CNPJ inválido.');
    if (c) {
      const outra = (await cat.todasDoCatalogo()).find((x) => x.id !== e.id && x.cnpj === c && ['aprovada', 'pendente', 'inativa'].includes(x.situacao));
      if (outra) throw new ErroDeUso(`Esse CNPJ já é de "${outra.nome}".`, 409);
    }
    mudancas.cnpj = c;
  }
  if (susep !== undefined) mudancas.susep = String(susep || '').trim();
  if (razaoSocial !== undefined) mudancas.razaoSocial = String(razaoSocial || '').trim(); // 22.1
  const renomeados = await trocarNome(e, nome);
  const nomeFinal = String(nome || '').trim() || e.nome;
  if (apelidos !== undefined) mudancas.apelidos = limparApelidos([...apelidos, ...(renomeados ? [e.nome] : [])], nomeFinal);
  if (ativa === false && e.situacao === 'aprovada') mudancas.situacao = 'inativa';
  if (ativa === true && e.situacao === 'inativa') mudancas.situacao = 'aprovada';
  if (Object.keys(mudancas).length) await e.ref.update({ ...mudancas, atualizadaEm: agora() });
  await auditar(quem, 'seguradora_editada', { alvoTipo: 'seguradora', alvoId: e.id, detalhes: { de: e.nome, para: nomeFinal, campos: Object.keys(mudancas), renomeados } });
  return { ok: true, renomeados };
}

/** Junta [de] em [para]: os registros com o nome de [de] passam a usar o de [para]. */
async function juntar(quem, { de, para }) {
  if (de === para) throw new ErroDeUso('Escolha outra seguradora.');
  const a = await entrada(de);
  const b = await entrada(para);
  if (!['aprovada', 'pendente', 'inativa'].includes(a.situacao)) throw new ErroDeUso('Esta entrada já foi juntada ou recusada.');
  if (b.situacao !== 'aprovada') throw new ErroDeUso('Junte com uma seguradora aprovada.');
  const renomeados = await cat.renomearNosRegistros(a.nome, b.nome, b.id);
  const atualiza = { apelidos: limparApelidos([...(b.apelidos || []), a.nome, ...(a.apelidos || [])], b.nome), atualizadaEm: agora() };
  if (!b.cnpj && a.cnpj) atualiza.cnpj = a.cnpj;
  await b.ref.update(atualiza);
  await a.ref.update({ situacao: 'juntada', juntadaCom: b.id, atualizadaEm: agora() });
  await auditar(quem, 'seguradoras_juntadas', { alvoTipo: 'seguradora', alvoId: a.id, detalhes: { de: a.nome, para: b.nome, renomeados } });
  return { ok: true, renomeados };
}

async function recusar(quem, { id, motivo }) {
  const e = await entrada(id);
  if (e.situacao !== 'pendente') throw new ErroDeUso('Só dá para recusar uma seguradora pendente.');
  const uso = await cat.usoDoNome(e.nome);
  if (uso.total > 0) throw new ErroDeUso(`Já está em ${uso.total} registro(s). Use "Juntar" com a seguradora certa.`, 409);
  await e.ref.update({ situacao: 'recusada', motivo: String(motivo || '').trim(), atualizadaEm: agora() });
  await auditar(quem, 'seguradora_recusada', { alvoTipo: 'seguradora', alvoId: e.id, detalhes: { nome: e.nome, motivo: motivo || '' } });
  return { ok: true };
}

/**
 * POST { acao, ... } com "Authorization: Bearer <ID token>" do admin.
 *   eu          { entrada?: true }  → { email }   (entrada: registra o login na auditoria)
 *   corretoras                      → { corretoras: [...] }
 *   auditoria                       → { acoes: [...] }
 *   criarContasQueFaltam            → { criadas: [ids] }
 *   Etapa 22 — catálogo de seguradoras:
 *   catalogo                        → { seguradoras: [...] }
 *   catalogoImportar                → { criadas, vinculadas, renomeadas }
 *   catalogoUso      { id }         → { sinistros, assistencias, apolices, total }
 *   catalogoAprovar  { id, nome? }  · catalogoEditar { id, nome?, cnpj?, susep?, apelidos?, ativa? }
 *   catalogoJuntar   { de, para }   · catalogoRecusar { id, motivo }
 *   catalogoCriar    { cnpj, nome, razaoSocial?, susep? }   (22.1: o admin cria direto)
 *   Etapa 23 — módulos:
 *   contaDefinirModulos { empresaId, tipo: 'tudo_ligado' | 'personalizado', modulos: [ids] }
 *   Etapa 24 — planos (functions/planos.js):
 *   planos                           → { planos: [...] }  (com nº de corretoras em cada)
 *   planoSalvar  { id?, nome, descricao, ativo, modulos, precoCentavos, franquias }
 *   planoExcluir { id }              (só sem corretoras)
 *   contaDefinirPlano { empresaId, tipo: 'tudo_ligado'|'modelo'|'personalizado', planoId?, modulos?,
 *                       precoCentavos?, franquias?, cortesia?, cortesiaAte? }
 */
const plataforma = onRequest((req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const quem = await adminDaPlataforma(req);
      if (!quem) return res.status(403).json({ erro: 'Acesso restrito ao administrador da plataforma.' });
      const corpo = req.body || {};
      switch (corpo.acao) {
        case 'eu':
          if (corpo.entrada === true) await auditar(quem, 'entrada');
          return res.json({ email: quem.email });
        case 'corretoras':
          return res.json({ corretoras: await listarCorretoras() });
        case 'auditoria':
          return res.json({ acoes: await ultimasAcoes() });
        case 'criarContasQueFaltam':
          return res.json({ criadas: await criarContasQueFaltam(quem) });
        case 'catalogo':
          return res.json({ seguradoras: await catalogoParaPortal() });
        case 'catalogoImportar':
          return res.json(await importarDasCorretoras(quem));
        case 'catalogoUso':
          return res.json(await cat.usoDoNome((await entrada(corpo.id)).nome));
        case 'contaDefinirModulos':
          return res.json(await definirModulos(quem, corpo));
        case 'planos':
          return res.json({ planos: await planos.listar() });
        case 'planoSalvar':
          return res.json(await planos.salvar(quem, corpo, auditar));
        case 'planoExcluir':
          return res.json(await planos.excluir(quem, corpo, auditar));
        case 'contaDefinirPlano':
          return res.json(await planos.definirDaConta(quem, corpo, auditar));
        case 'catalogoCriar':
          return res.json(await criar(quem, corpo));
        case 'catalogoAprovar':
          return res.json(await aprovar(quem, corpo));
        case 'catalogoEditar':
          return res.json(await editar(quem, corpo));
        case 'catalogoJuntar':
          return res.json(await juntar(quem, corpo));
        case 'catalogoRecusar':
          return res.json(await recusar(quem, corpo));
        default:
          return res.status(400).json({ erro: 'Ação desconhecida' });
      }
    } catch (e) {
      if (e instanceof ErroDeUso || e instanceof planos.ErroDePlano) return res.status(e.codigo).json({ erro: e.message });
      logger.error(e);
      if (!res.headersSent) res.status(500).json({ erro: 'Erro interno' });
    }
  }),
);

module.exports = { plataforma, adminDaPlataforma, SITUACOES };
