// functions/planos.js — Etapa 24: planos-modelo e plano de cada corretora
//
// plataforma_planos/{id}  (só o servidor grava; o app não lê — a corretora vê
// uma CÓPIA do plano dentro da própria conta)
//   { nome, chave, descricao, ativo, modulos: [ids], precoCentavos,
//     franquias: { usuarios: { incluido, extraCentavos }, gb: {…}, gb_video: {…} },
//     criadoEm, atualizadoEm }
//
// plataforma_contas/{e}.plano
//   { tipo: 'tudo_ligado' }                                   todos os módulos (fundadoras)
//   { tipo: 'modelo', planoId, nome, descricao, precoCentavos, franquias } cópia do plano-modelo
//   { tipo: 'personalizado', nome, precoCentavos, franquias }   feito só para a corretora
// plataforma_contas/{e}.modulos  lista efetiva (modelo/personalizado). As regras do
// Firestore/Storage só olham plano.tipo e modulos — por isso a cópia: editar um
// plano-modelo regrava as contas que o usam.
//
// Franquia: incluido = null → sem limite. A medição do uso (GB, vídeos) entra na
// Etapa 27; aqui só fica o que o plano promete e o preço do excedente.

const admin = require('firebase-admin');
const mod = require('./modulos');

const db = () => admin.firestore();
const agora = () => admin.firestore.FieldValue.serverTimestamp();
const COL = 'plataforma_planos';

/** Métricas das franquias (espelho de lib/utils/planos.dart). */
const METRICAS = ['usuarios', 'gb', 'gb_video'];

class ErroDePlano extends Error {
  constructor(msg, codigo = 400) { super(msg); this.codigo = codigo; }
}

const chave = (s) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^A-Z0-9]+/g, ' ').trim();

function centavos(v, rotulo) {
  if (v === undefined || v === null || v === '') return 0;
  const n = Number(v);
  if (!Number.isFinite(n) || n < 0 || n > 100000000 || !Number.isInteger(n)) throw new ErroDePlano(`${rotulo}: valor inválido.`);
  return n;
}

function franquias(f) {
  const r = {};
  for (const m of METRICAS) {
    const x = (f && typeof f === 'object' && f[m]) || {};
    const inc = x.incluido;
    let incluido = null;
    if (inc !== undefined && inc !== null && inc !== '') {
      const n = Number(inc);
      if (!Number.isInteger(n) || n < 0 || n > 1000000) throw new ErroDePlano(`Franquia (${m}): quantidade inválida.`);
      incluido = n;
    }
    r[m] = { incluido, extraCentavos: centavos(x.extraCentavos, `Franquia (${m}) — excedente`) };
  }
  return r;
}

/** Preço, franquias e módulos (comuns ao plano-modelo e ao personalizado). */
function comercial(corpo) {
  return {
    modulos: [...mod.efetivos(Array.isArray(corpo.modulos) ? corpo.modulos : [])].sort(),
    precoCentavos: centavos(corpo.precoCentavos, 'Preço mensal'),
    franquias: franquias(corpo.franquias),
  };
}

const data = (v) => (v && typeof v.toDate === 'function' ? v.toDate().toISOString() : v || null);

async function todasAsContas() {
  const s = await db().collection('plataforma_contas').get();
  return s.docs.map((d) => ({ id: d.id, ref: d.ref, ...(d.data() || {}) }));
}

async function listar() {
  const [planos, contas] = await Promise.all([db().collection(COL).get(), todasAsContas()]);
  const uso = {};
  for (const c of contas) {
    const p = c.plano || {};
    if (p.tipo === 'modelo' && p.planoId) uso[p.planoId] = (uso[p.planoId] || 0) + 1;
  }
  return planos.docs
    .map((d) => {
      const p = d.data() || {};
      return {
        id: d.id,
        nome: p.nome || '',
        descricao: p.descricao || '',
        ativo: p.ativo !== false,
        modulos: Array.isArray(p.modulos) ? p.modulos : [],
        precoCentavos: p.precoCentavos || 0,
        franquias: p.franquias || franquias({}),
        corretoras: uso[d.id] || 0,
        atualizadoEm: data(p.atualizadoEm),
      };
    })
    .sort((a, b) => a.precoCentavos - b.precoCentavos || a.nome.localeCompare(b.nome, 'pt-BR'));
}

const copiaDoModelo = (id, p) => ({
  tipo: 'modelo', planoId: id, nome: p.nome, descricao: p.descricao || '', precoCentavos: p.precoCentavos, franquias: p.franquias,
});

/** Cria ou edita um plano-modelo. Editar regrava as contas que usam o plano. */
async function salvar(quem, corpo, auditar) {
  const nome = String(corpo.nome || '').trim();
  if (!nome) throw new ErroDePlano('Informe o nome do plano.');
  if (chave(nome) === chave('Tudo ligado') || chave(nome) === chave('Personalizado')) throw new ErroDePlano('Esse nome é reservado.');
  const dados = {
    nome,
    chave: chave(nome),
    descricao: String(corpo.descricao || '').trim(),
    ativo: corpo.ativo !== false,
    ...comercial(corpo),
  };
  const existentes = (await db().collection(COL).get()).docs;
  const id = corpo.id ? String(corpo.id) : '';
  if (existentes.some((d) => d.id !== id && (d.data() || {}).chave === dados.chave)) throw new ErroDePlano(`Já existe um plano "${nome}".`, 409);

  let ref;
  if (id) {
    ref = db().collection(COL).doc(id);
    if (!(await ref.get()).exists) throw new ErroDePlano('Plano não encontrado.', 404);
    await ref.update({ ...dados, atualizadoEm: agora() });
  } else {
    ref = db().collection(COL).doc();
    await ref.set({ ...dados, criadoEm: agora(), atualizadoEm: agora() });
  }

  let contas = 0;
  if (id) {
    for (const c of await todasAsContas()) {
      if ((c.plano || {}).tipo !== 'modelo' || c.plano.planoId !== id) continue;
      const plano = copiaDoModelo(id, dados);
      await c.ref.update({ plano, modulos: dados.modulos, atualizadaEm: agora() });
      await c.ref.collection('historico').doc().set({
        em: agora(),
        email: quem.email,
        acao: 'plano_atualizado',
        de: { plano: c.plano, modulos: Array.isArray(c.modulos) ? c.modulos : null },
        para: { plano, modulos: dados.modulos },
        motivo: 'Plano-modelo editado no portal.',
      });
      contas++;
    }
  }
  await auditar(quem, id ? 'plano_editado' : 'plano_criado', { alvoTipo: 'plano', alvoId: ref.id, detalhes: { nome, precoCentavos: dados.precoCentavos, contas } });
  return { ok: true, id: ref.id, contas };
}

async function excluir(quem, { id }, auditar) {
  const ref = db().collection(COL).doc(String(id || ''));
  const d = await ref.get();
  if (!d.exists) throw new ErroDePlano('Plano não encontrado.', 404);
  const usando = (await todasAsContas()).filter((c) => (c.plano || {}).tipo === 'modelo' && c.plano.planoId === d.id).length;
  if (usando) throw new ErroDePlano(`${usando} corretora(s) usam este plano. Troque o plano delas ou desative-o.`, 409);
  await ref.delete();
  await auditar(quem, 'plano_excluido', { alvoTipo: 'plano', alvoId: d.id, detalhes: { nome: (d.data() || {}).nome || '' } });
  return { ok: true };
}

/**
 * Define o plano de uma corretora.
 *   { empresaId, tipo: 'tudo_ligado' | 'modelo' | 'personalizado',
 *     planoId (modelo), modulos/precoCentavos/franquias (personalizado),
 *     cortesia: bool, cortesiaAte: 'AAAA-MM-DD' | null }
 */
async function definirDaConta(quem, corpo, auditar) {
  const e = String(corpo.empresaId || '');
  if (!e) throw new ErroDePlano('Informe a corretora.');
  const ref = db().collection('plataforma_contas').doc(e);
  const atual = await ref.get();
  if (!atual.exists) throw new ErroDePlano('Esta corretora ainda não tem conta. Use "Criar contas que faltam".', 409);
  const antes = atual.data() || {};

  let plano;
  let modulos;
  if (corpo.tipo === 'tudo_ligado') {
    plano = { tipo: 'tudo_ligado', nome: 'Tudo ligado' };
    modulos = null;
  } else if (corpo.tipo === 'modelo') {
    const p = await db().collection(COL).doc(String(corpo.planoId || '')).get();
    if (!p.exists) throw new ErroDePlano('Escolha um plano.');
    const pd = p.data() || {};
    const mesmo = (antes.plano || {}).tipo === 'modelo' && antes.plano.planoId === p.id;
    if (pd.ativo === false && !mesmo) throw new ErroDePlano('Este plano está desativado.');
    plano = copiaDoModelo(p.id, { nome: pd.nome, descricao: pd.descricao, precoCentavos: pd.precoCentavos || 0, franquias: pd.franquias || franquias({}) });
    modulos = Array.isArray(pd.modulos) ? [...mod.efetivos(pd.modulos)].sort() : [];
  } else if (corpo.tipo === 'personalizado') {
    const c = comercial(corpo);
    plano = { tipo: 'personalizado', nome: 'Personalizado', precoCentavos: c.precoCentavos, franquias: c.franquias };
    modulos = c.modulos;
  } else {
    throw new ErroDePlano('Tipo de plano inválido.');
  }

  const mudancas = { plano, modulos: modulos === null ? admin.firestore.FieldValue.delete() : modulos, atualizadaEm: agora() };
  if (corpo.cortesia !== undefined) {
    mudancas.cortesia = corpo.cortesia === true;
    const ate = corpo.cortesia === true && corpo.cortesiaAte ? new Date(`${corpo.cortesiaAte}T23:59:59-03:00`) : null;
    if (ate && Number.isNaN(ate.getTime())) throw new ErroDePlano('Data da cortesia inválida.');
    mudancas.cortesiaAte = ate ? admin.firestore.Timestamp.fromDate(ate) : admin.firestore.FieldValue.delete();
  }
  await ref.update(mudancas);
  await ref.collection('historico').doc().set({
    em: agora(),
    email: quem.email,
    acao: 'plano',
    de: { plano: antes.plano || null, modulos: Array.isArray(antes.modulos) ? antes.modulos : null, cortesia: antes.cortesia === true },
    para: { plano, modulos, cortesia: corpo.cortesia === undefined ? antes.cortesia === true : corpo.cortesia === true },
    motivo: String(corpo.motivo || '').trim(),
  });
  await auditar(quem, 'plano_da_corretora', { alvoTipo: 'corretora', alvoId: e, detalhes: { tipo: plano.tipo, nome: plano.nome, modulos } });
  return { ok: true, plano, modulos };
}

module.exports = { METRICAS, ErroDePlano, listar, salvar, excluir, definirDaConta, chave };
