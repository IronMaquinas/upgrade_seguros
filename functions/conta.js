// functions/conta.js — Etapa 25: autocadastro, teste grátis, situação da conta e pedidos
//
//   autocadastro (público)   a corretora pede para usar o app: CNPJ conferido na
//                            Receita (no navegador — a BrasilAPI barra o servidor),
//                            responsável, e-mail. Vira um PEDIDO; nada é criado
//                            até o admin da plataforma aprovar no portal.
//   minhaConta (logado)      planos disponíveis e "Quero este plano" (pedido de
//                            contratação) — Meu plano no app.
//   portal (via plataforma)  listar pedidos, aprovar (cria corretora + gestor +
//                            conta em teste), recusar, marcar atendido, mudar a
//                            situação da conta.
//
// Coleção nova (raiz, só o servidor): plataforma_pedidos/{id}
//   { tipo: 'cadastro' | 'contratacao', situacao: 'pendente' | 'aprovado' | 'recusado' | 'atendido', … }
//
// Só leitura: as regras (firestore.rules / storage.rules → contaGrava) barram
// gravações quando a situação é teste_encerrado, suspensa ou cancelada — ou
// "teste" com testeAte vencido (não depende de rotina agendada).
// situacaoEfetiva() abaixo é a mesma conta, para o portal e o app mostrarem.

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const cors = require('cors')({ origin: true });

const cat = require('./catalogo');
const mod = require('./modulos');
const planos = require('./planos');

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();
const agora = () => admin.firestore.FieldValue.serverTimestamp();
const COL = 'plataforma_pedidos';

const SITUACOES = ['teste', 'teste_encerrado', 'ativa', 'inadimplente', 'suspensa', 'cancelada'];
/** Situações em que a corretora só lê (espelho de contaGrava nas regras). */
const SO_LEITURA = ['teste_encerrado', 'suspensa', 'cancelada'];
const DIAS_TESTE = 14;
const MAX_PENDENTES = 100; // trava simples contra enxurrada de pedidos

class ErroDeConta extends Error {
  constructor(msg, codigo = 400) { super(msg); this.codigo = codigo; }
}

const paraData = (v) => (v && typeof v.toDate === 'function' ? v.toDate() : v instanceof Date ? v : v ? new Date(v) : null);
const iso = (v) => { const d = paraData(v); return d && !Number.isNaN(d.getTime()) ? d.toISOString() : null; };

/** 'teste' vencido conta como 'teste_encerrado'. */
function situacaoEfetiva(conta, quando = new Date()) {
  if (!conta) return 'ativa';
  const s = conta.situacao || 'ativa';
  if (s === 'teste') {
    const ate = paraData(conta.testeAte);
    if (ate && ate.getTime() < quando.getTime()) return 'teste_encerrado';
  }
  return s;
}

const contaGrava = (conta, quando) => !SO_LEITURA.includes(situacaoEfetiva(conta, quando));

const emailValido = (e) => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(e);
const texto = (v, max = 200) => String(v || '').trim().slice(0, max);

/** Fim do dia (horário de Brasília) daqui a [dias] dias. */
function fimDoDia(dias, base = new Date()) {
  const d = new Date(base.getTime() + dias * 86400000);
  const brt = new Date(d.getTime() - 3 * 3600000);
  return new Date(Date.UTC(brt.getUTCFullYear(), brt.getUTCMonth(), brt.getUTCDate(), 23 + 3, 59, 59));
}

async function corretoraComCnpj(digitos) {
  const refs = await db().collection('corretoras').listDocuments();
  for (const r of refs) {
    const d = await r.get();
    if (d.exists && String((d.data() || {}).cnpj || '').replace(/\D/g, '') === digitos) return { id: r.id, nome: (d.data() || {}).nome || '' };
  }
  return null;
}

async function emailJaTemConta(email) {
  try {
    await admin.auth().getUserByEmail(email);
    return true;
  } catch (e) {
    if (e.code === 'auth/user-not-found') return false;
    throw e;
  }
}

// ── autocadastro (público) ───────────────────────────────────────────────────

/**
 * POST sem login: { cnpj, nomeCorretora, responsavel, email, telefone, susep?,
 *   receita: { razaoSocial, nomeFantasia, situacao }, aceite: true, site: '' (isca) }
 */
async function pedirCadastro(corpo, ip = '') {
  if (texto(corpo.site)) return { ok: true }; // isca para robôs: finge que deu certo
  const cnpj = String(corpo.cnpj || '').replace(/\D/g, '');
  if (!cat.cnpjValido(cnpj)) throw new ErroDeConta('CNPJ inválido.');
  const nome = texto(corpo.nomeCorretora, 120);
  const responsavel = texto(corpo.responsavel, 120);
  const email = texto(corpo.email, 160).toLowerCase();
  const telefone = texto(corpo.telefone, 40);
  if (!nome || !responsavel) throw new ErroDeConta('Informe o nome da corretora e o seu nome.');
  if (!emailValido(email)) throw new ErroDeConta('E-mail inválido.');
  if (corpo.aceite !== true) throw new ErroDeConta('É preciso aceitar os termos para continuar.');
  const r = corpo.receita && typeof corpo.receita === 'object' ? corpo.receita : {};
  const receita = { razaoSocial: texto(r.razaoSocial), nomeFantasia: texto(r.nomeFantasia), situacao: texto(r.situacao, 40) };
  if (receita.situacao && receita.situacao.toUpperCase() !== 'ATIVA') throw new ErroDeConta(`Na Receita, este CNPJ está "${receita.situacao}".`);

  const ja = await corretoraComCnpj(cnpj);
  if (ja) throw new ErroDeConta('Esta corretora já usa o app. Fale com o gestor dela para receber um acesso.', 409);
  if (await emailJaTemConta(email)) throw new ErroDeConta('Este e-mail já tem uma conta. Use "Esqueci minha senha" na tela de entrada.', 409);

  const pendentes = (await db().collection(COL).where('situacao', '==', 'pendente').get()).docs.map((d) => d.data() || {});
  if (pendentes.some((p) => p.tipo === 'cadastro' && (p.cnpj === cnpj || p.email === email))) {
    throw new ErroDeConta('Já recebemos um pedido para este CNPJ ou e-mail. Assim que for aprovado, você recebe um e-mail.', 409);
  }
  if (pendentes.length >= MAX_PENDENTES) throw new ErroDeConta('Muitos pedidos em análise agora. Tente de novo mais tarde.', 429);

  const ref = db().collection(COL).doc();
  await ref.set({
    tipo: 'cadastro',
    situacao: 'pendente',
    cnpj,
    nomeCorretora: nome,
    responsavel,
    email,
    telefone,
    susep: texto(corpo.susep, 40),
    receita,
    dadosReceita: 'navegador',
    ip: texto(ip, 60),
    criadoEm: agora(),
  });
  logger.info(`Pedido de cadastro ${ref.id} (${cat.formatarCnpj(cnpj)})`);
  return { ok: true };
}

function postPublico(handler) {
  return onRequest((req, res) =>
    cors(req, res, async () => {
      if (req.method !== 'POST') return res.status(405).send('Método não permitido');
      try {
        return res.json(await handler(req));
      } catch (e) {
        if (e instanceof ErroDeConta || e instanceof planos.ErroDePlano) return res.status(e.codigo).json({ erro: e.message });
        logger.error(e);
        if (!res.headersSent) res.status(500).json({ erro: 'Erro interno' });
      }
    }),
  );
}

const autocadastro = postPublico((req) => pedirCadastro(req.body || {}, req.ip || ''));

// ── minhaConta (usuário logado de uma corretora) ─────────────────────────────

/**
 * POST com login:
 *   planos                         → { planos: [ativos, sem nº de corretoras] }
 *   pedirPlano { planoId?, mensagem } → pedido de contratação (um pendente por corretora)
 */
const minhaConta = postPublico(async (req) => {
  const { usuarioAtivo } = require('./seguranca');
  const quem = await usuarioAtivo(req);
  if (!quem) throw new ErroDeConta('Faça login novamente.', 401);
  const empresaId = String(quem.dados.empresaId || '');
  if (!empresaId) throw new ErroDeConta('Seu usuário não tem corretora.', 400);
  const corpo = req.body || {};
  if (corpo.acao === 'planos') {
    const lista = (await planos.listar()).filter((p) => p.ativo);
    return { planos: lista.map(({ corretoras, ...p }) => p) };
  }
  if (corpo.acao === 'pedirPlano') {
    let planoNome = '';
    const planoId = texto(corpo.planoId, 60);
    if (planoId) {
      const p = await db().collection(planos.COL).doc(planoId).get();
      if (!p.exists || (p.data() || {}).ativo === false) throw new ErroDeConta('Plano não encontrado.');
      planoNome = (p.data() || {}).nome || '';
    }
    const corretora = await db().collection('corretoras').doc(empresaId).get();
    const dados = {
      tipo: 'contratacao',
      situacao: 'pendente',
      empresaId,
      corretora: (corretora.data() || {}).nome || '',
      uid: quem.uid,
      email: quem.email,
      nome: texto(quem.dados.nome, 120),
      planoId,
      planoNome,
      mensagem: texto(corpo.mensagem, 1000),
      criadoEm: agora(),
    };
    const ja = (await db().collection(COL).where('situacao', '==', 'pendente').get()).docs
      .find((d) => (d.data() || {}).tipo === 'contratacao' && (d.data() || {}).empresaId === empresaId);
    if (ja) await ja.ref.update({ ...dados, atualizadoEm: agora() });
    else await db().collection(COL).doc().set(dados);
    return { ok: true };
  }
  throw new ErroDeConta('Ação desconhecida');
});

// ── portal (chamado por functions/plataforma.js, que confere o admin) ────────

async function listarPedidos() {
  const s = await db().collection(COL).get();
  return s.docs
    .map((d) => {
      const p = d.data() || {};
      return {
        id: d.id,
        tipo: p.tipo || '',
        situacao: p.situacao || '',
        cnpj: p.cnpj ? cat.formatarCnpj(p.cnpj) : '',
        nomeCorretora: p.nomeCorretora || p.corretora || '',
        responsavel: p.responsavel || p.nome || '',
        email: p.email || '',
        telefone: p.telefone || '',
        susep: p.susep || '',
        receita: p.receita || null,
        empresaId: p.empresaId || '',
        planoId: p.planoId || '',
        planoNome: p.planoNome || '',
        mensagem: p.mensagem || '',
        motivo: p.motivo || '',
        criadoEm: iso(p.criadoEm),
        resolvidoEm: iso(p.resolvidoEm),
        resolvidoPor: p.resolvidoPor || '',
      };
    })
    .sort((a, b) => (a.situacao === 'pendente') !== (b.situacao === 'pendente')
      ? (a.situacao === 'pendente' ? -1 : 1)
      : String(b.criadoEm || '').localeCompare(String(a.criadoEm || '')))
    .slice(0, 200);
}

async function pedido(id, tipo) {
  const ref = db().collection(COL).doc(String(id || ''));
  const d = await ref.get();
  if (!d.exists) throw new ErroDeConta('Pedido não encontrado.', 404);
  const p = d.data() || {};
  if (tipo && p.tipo !== tipo) throw new ErroDeConta('Tipo de pedido errado.');
  if (p.situacao !== 'pendente') throw new ErroDeConta('Este pedido já foi resolvido.', 409);
  return { ref, ...p };
}

/**
 * Aprova um pedido de cadastro: cria a conta de login do responsável (gestor),
 * a corretora, users/{uid} e a conta da plataforma em teste.
 *   { id, planoId?: (vazio = Tudo ligado no teste), diasTeste?: 14 }
 * O portal manda o e-mail de "criar senha" (sendPasswordResetEmail) depois.
 */
async function aprovarCadastro(quem, { id, planoId, diasTeste }, auditar) {
  const p = await pedido(id, 'cadastro');
  const dias = diasTeste === undefined || diasTeste === null || diasTeste === '' ? DIAS_TESTE : Number(diasTeste);
  if (!Number.isInteger(dias) || dias < 1 || dias > 90) throw new ErroDeConta('Dias de teste: de 1 a 90.');
  if (await corretoraComCnpj(p.cnpj)) throw new ErroDeConta('Já existe uma corretora com este CNPJ.', 409);

  let plano = { tipo: 'tudo_ligado', nome: 'Tudo ligado' };
  let modulos = null;
  if (planoId) {
    const pd = await db().collection(planos.COL).doc(String(planoId)).get();
    if (!pd.exists || (pd.data() || {}).ativo === false) throw new ErroDeConta('Escolha um plano ativo.');
    const x = pd.data() || {};
    plano = { tipo: 'modelo', planoId: pd.id, nome: x.nome, descricao: x.descricao || '', precoCentavos: x.precoCentavos || 0, franquias: x.franquias || {} };
    modulos = [...mod.efetivos(x.modulos || [])].sort();
  }

  let login;
  try {
    login = await admin.auth().createUser({ email: p.email, password: crypto.randomBytes(24).toString('base64url'), displayName: p.responsavel });
  } catch (e) {
    if (e.code === 'auth/email-already-exists') throw new ErroDeConta('Este e-mail já tem uma conta de login.', 409);
    throw e;
  }

  const empresaRef = db().collection('corretoras').doc();
  const empresaId = empresaRef.id;
  const testeAte = fimDoDia(dias);
  await empresaRef.set({
    nome: p.nomeCorretora,
    razaoSocial: (p.receita || {}).razaoSocial || '',
    cnpj: cat.formatarCnpj(p.cnpj),
    email: p.email,
    telefone: p.telefone || '',
    susep: p.susep || '',
    ativa: true,
    dataCriacao: agora(),
    migradoEtapa16: true, // corretora nova já nasce na organização da Etapa 16
    origem: 'autocadastro',
  });
  await db().doc(`users/${login.uid}`).set({
    nome: p.responsavel,
    email: p.email,
    matricula: null,
    role: 'admin',
    telefone: p.telefone || null,
    ativo: true,
    empresaId,
    criadoPor: 'plataforma',
    createdAt: agora(),
  });
  const contaRef = db().collection('plataforma_contas').doc(empresaId);
  const conta = {
    situacao: 'teste',
    testeAte: admin.firestore.Timestamp.fromDate(testeAte),
    plano,
    cortesia: false,
    observacao: 'Autocadastro aprovado no portal.',
    origem: 'autocadastro',
    criadaEm: agora(),
    atualizadaEm: agora(),
  };
  if (modulos) conta.modulos = modulos;
  await contaRef.set(conta);
  await contaRef.collection('historico').doc().set({
    em: agora(),
    email: quem.email,
    acao: 'conta_criada',
    de: null,
    para: { situacao: 'teste', testeAte: testeAte.toISOString(), plano },
    motivo: `Autocadastro — ${dias} dias de teste.`,
  });
  await p.ref.update({ situacao: 'aprovado', empresaId, uid: login.uid, resolvidoEm: agora(), resolvidoPor: quem.email });
  await auditar(quem, 'cadastro_aprovado', { alvoTipo: 'corretora', alvoId: empresaId, detalhes: { nome: p.nomeCorretora, email: p.email, dias, plano: plano.nome } });
  return { ok: true, empresaId, email: p.email, testeAte: testeAte.toISOString() };
}

async function recusarPedido(quem, { id, motivo }, auditar) {
  const p = await pedido(id);
  await p.ref.update({ situacao: 'recusado', motivo: texto(motivo, 500), resolvidoEm: agora(), resolvidoPor: quem.email });
  await auditar(quem, 'pedido_recusado', { alvoTipo: 'pedido', alvoId: String(id), detalhes: { tipo: p.tipo, nome: p.nomeCorretora || p.corretora || '' } });
  return { ok: true };
}

async function pedidoAtendido(quem, { id, nota }, auditar) {
  const p = await pedido(id, 'contratacao');
  await p.ref.update({ situacao: 'atendido', motivo: texto(nota, 500), resolvidoEm: agora(), resolvidoPor: quem.email });
  await auditar(quem, 'pedido_atendido', { alvoTipo: 'pedido', alvoId: String(id), detalhes: { corretora: p.corretora || '', plano: p.planoNome || '' } });
  return { ok: true };
}

/**
 * Situação da conta: { empresaId, situacao, testeAte?: 'AAAA-MM-DD' (para "teste"), motivo? }
 */
async function definirSituacao(quem, { empresaId, situacao, testeAte, motivo }, auditar) {
  const e = String(empresaId || '');
  if (!e) throw new ErroDeConta('Informe a corretora.');
  if (!SITUACOES.includes(situacao)) throw new ErroDeConta('Situação inválida.');
  const ref = db().collection('plataforma_contas').doc(e);
  const atual = await ref.get();
  if (!atual.exists) throw new ErroDeConta('Esta corretora ainda não tem conta. Use "Criar contas que faltam".', 409);
  const antes = atual.data() || {};
  const mudancas = { situacao, atualizadaEm: agora() };
  let ate = null;
  if (situacao === 'teste') {
    ate = testeAte ? new Date(`${testeAte}T23:59:59-03:00`) : fimDoDia(DIAS_TESTE);
    if (Number.isNaN(ate.getTime())) throw new ErroDeConta('Data do teste inválida.');
    if (ate.getTime() < Date.now()) throw new ErroDeConta('A data do fim do teste já passou.');
    mudancas.testeAte = admin.firestore.Timestamp.fromDate(ate);
  } else {
    mudancas.testeAte = admin.firestore.FieldValue.delete();
  }
  await ref.update(mudancas);
  await ref.collection('historico').doc().set({
    em: agora(),
    email: quem.email,
    acao: 'situacao',
    de: { situacao: antes.situacao || '', testeAte: iso(antes.testeAte) },
    para: { situacao, testeAte: ate ? ate.toISOString() : null },
    motivo: texto(motivo, 500),
  });
  await auditar(quem, 'situacao_definida', { alvoTipo: 'corretora', alvoId: e, detalhes: { de: antes.situacao || '', para: situacao } });
  return { ok: true };
}

module.exports = {
  autocadastro,
  minhaConta,
  pedirCadastro,
  listarPedidos,
  aprovarCadastro,
  recusarPedido,
  pedidoAtendido,
  definirSituacao,
  situacaoEfetiva,
  contaGrava,
  fimDoDia,
  ErroDeConta,
  SO_LEITURA,
  SITUACOES,
};
