// functions/seguranca.js — Etapa 15
//
// Até a Etapa 14 o banco estava aberto ("allow read, write: if true") e o app
// fazia direto no Firestore três coisas que acontecem SEM LOGIN:
//   1. a pesquisa NPS respondida pelo cliente final (lia e gravava sinistro,
//      cliente, avaliação…);
//   2. "entrar com usuário ou matrícula" (procurava o e-mail em users/);
//   3. o administrador criando um usuário (o app entrava como o usuário novo
//      e gravava o próprio cadastro dele — e o administrador era deslogado).
// Com as regras novas (firestore.rules) isso passa a ser feito aqui, no
// servidor, com conferência: token da pesquisa, só o e-mail, só administrador.
//
// Também: usuarioAtivo(req) — usado por uploadFile/deleteFiles (index.js) para
// exigir login de usuário ativo.

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const crypto = require('crypto');
const cors = require('cors')({ origin: true });

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();

const PAPEIS = ['admin', 'user'];

/**
 * Lê "Authorization: Bearer <ID token>" e devolve o usuário se ele estiver
 * ativo (tem users/{uid} e ativo != false). Senão, null.
 */
async function usuarioAtivo(req) {
  const m = String(req.get('Authorization') || '').match(/^Bearer (.+)$/);
  if (!m) return null;
  try {
    const decod = await admin.auth().verifyIdToken(m[1]);
    const snap = await db().doc(`users/${decod.uid}`).get();
    if (!snap.exists) return null;
    const dados = snap.data() || {};
    if (dados.ativo === false) return null;
    return { uid: decod.uid, email: decod.email || '', role: dados.role || 'user', dados };
  } catch (e) {
    logger.warn('Token inválido', e.message);
    return null;
  }
}

/** Envolve um handler com CORS + só POST + erro 500 padrão. */
function postComCors(handler) {
  return onRequest((req, res) =>
    cors(req, res, async () => {
      if (req.method !== 'POST') return res.status(405).send('Método não permitido');
      try {
        await handler(req, res);
      } catch (e) {
        logger.error(e);
        if (!res.headersSent) res.status(500).json({ erro: 'Erro interno' });
      }
    }),
  );
}

// ── 1. NPS público ─────────────────────────────────────────────────────────

/**
 * Pesquisa NPS respondida pelo cliente (sem login). Corpo:
 *   { acao: 'verificar', claimId, token }
 *   { acao: 'responder', claimId, token, nota, pontosFortes, pontosFracos, reclamacoes, sugestoes }
 * Mesma lógica que o app fazia em lib/services/nps_service.dart.
 */
exports.npsPublico = postComCors(async (req, res) => {
  const { acao, claimId, token } = req.body || {};
  if (typeof claimId !== 'string' || !claimId || typeof token !== 'string' || !token || claimId.includes('/')) {
    return res.status(400).json({ erro: 'Dados incompletos' });
  }
  const refPesquisa = db().collection('nps_pesquisas').doc(claimId);
  const pesquisa = await refPesquisa.get();
  if (!pesquisa.exists || pesquisa.data().token !== token) {
    return res.status(404).json({ erro: 'Pesquisa não encontrada' });
  }
  const p = pesquisa.data();

  if (acao === 'verificar') {
    if (p.status === 'respondida') return res.json({ jaRespondida: true });
    let cliente = {};
    if (typeof p.clienteId === 'string' && p.clienteId) {
      const c = await db().collection('clientes').doc(p.clienteId).get();
      cliente = c.exists ? c.data() : {};
    }
    // Só o necessário para a tela (antes o app recebia o cadastro inteiro).
    return res.json({
      jaRespondida: false,
      clienteNome: p.clienteNome || '',
      numeroSinistro: p.numeroSinistro || '',
      tipo: p.tipo || 'sinistro',
      clienteLogoUrl: cliente.logoUrl || '',
      clienteEmpresa: cliente.nomeEmpresa || p.clienteNome || '',
    });
  }

  if (acao !== 'responder') return res.status(400).json({ erro: 'Ação inválida' });
  if (p.status === 'respondida') return res.status(409).json({ erro: 'Pesquisa já respondida' });

  const nota = Number(req.body.nota);
  if (!Number.isInteger(nota) || nota < 0 || nota > 10) return res.status(400).json({ erro: 'Nota inválida' });
  const lista = (v) => (Array.isArray(v) ? v.filter((x) => typeof x === 'string').map((x) => x.slice(0, 200)).slice(0, 20) : []);
  const texto = (v) => (typeof v === 'string' ? v.slice(0, 4000) : '');
  const categoria = nota >= 9 ? 'promotor' : nota >= 7 ? 'neutro' : 'detrator';
  const agora = admin.firestore.FieldValue.serverTimestamp();

  await db().collection('avaliacoes').doc(claimId).set({
    claimId,
    numeroSinistro: p.numeroSinistro || '',
    clienteId: p.clienteId || '',
    clienteNome: p.clienteNome || '',
    tipo: p.tipo || 'sinistro',
    nota,
    categoria,
    pontosFortes: lista(req.body.pontosFortes),
    pontosFracos: lista(req.body.pontosFracos),
    reclamacoes: texto(req.body.reclamacoes),
    sugestoes: texto(req.body.sugestoes),
    respondidoEm: agora,
  });
  await refPesquisa.update({ status: 'respondida', respondidoEm: agora, nota, categoria });

  const colecao = p.tipo === 'assistencia' ? 'assistencias' : 'sinistros';
  try {
    await db().collection(colecao).doc(claimId).update({
      nps_avaliada: true,
      nps_satisfacao: nota,
      nps_categoria: categoria,
      npsDataAvaliacao: agora,
    });
  } catch (e) {
    logger.warn(`NPS: ${colecao}/${claimId} não atualizado`, e.message);
  }

  if (typeof p.clienteId === 'string' && p.clienteId) {
    try {
      const avs = await db().collection('avaliacoes').where('clienteId', '==', p.clienteId).get();
      const notas = avs.docs.map((d) => Number(d.data().nota) || 0);
      if (notas.length) {
        const promotores = notas.filter((n) => n >= 9).length;
        const detratores = notas.filter((n) => n <= 6).length;
        await db().collection('clientes').doc(p.clienteId).update({
          nps: notas.reduce((a, b) => a + b, 0) / notas.length,
          npsScore: Math.round(((promotores - detratores) / notas.length) * 100),
          npsTotal: notas.length,
          npsAtualizado: agora,
        });
      }
    } catch (e) {
      logger.warn('NPS do cliente não atualizado', e.message);
    }
  }
  return res.json({ ok: true });
});

// ── 2. Entrar com usuário ou matrícula ─────────────────────────────────────

/**
 * Corpo: { login } (usuário ou matrícula). Devolve { email } — só o e-mail,
 * nada mais do cadastro. A senha continua sendo conferida pelo Firebase Auth.
 */
exports.apoioLogin = postComCors(async (req, res) => {
  const login = String((req.body || {}).login || '').trim();
  if (!login || login.length > 120) return res.status(400).json({ erro: 'Login inválido' });
  for (const campo of ['username', 'matricula']) {
    const q = await db().collection('users').where(campo, '==', login).limit(1).get();
    if (!q.empty && q.docs[0].data().email) return res.json({ email: q.docs[0].data().email });
  }
  return res.status(404).json({ erro: 'Usuário não encontrado' });
});

// ── 3. Administrador cria usuário ──────────────────────────────────────────

/**
 * Só administrador ativo. Corpo: { nome, email, matricula?, role, telefone? }.
 * Cria a conta (senha aleatória) e o cadastro em users/{uid}; o app depois
 * manda o e-mail de "definir senha" (sendPasswordResetEmail).
 * O usuário novo herda a empresa (empresaId) do administrador.
 */
exports.criarUsuario = postComCors(async (req, res) => {
  const quem = await usuarioAtivo(req);
  if (!quem) return res.status(401).json({ erro: 'Faça login novamente' });
  if (quem.role !== 'admin') return res.status(403).json({ erro: 'Só administradores criam usuários' });

  const b = req.body || {};
  const nome = String(b.nome || '').trim();
  const email = String(b.email || '').trim().toLowerCase();
  const matricula = String(b.matricula || '').trim();
  const role = PAPEIS.includes(b.role) ? b.role : 'user';
  const telefone = b.telefone ? String(b.telefone).trim() : null;
  if (!nome || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return res.status(400).json({ erro: 'Nome e e-mail válidos são obrigatórios' });

  if (matricula) {
    const q = await db().collection('users').where('matricula', '==', matricula).limit(1).get();
    if (!q.empty) return res.status(409).json({ erro: 'Matrícula já cadastrada' });
  }

  let conta;
  try {
    conta = await admin.auth().createUser({
      email,
      password: crypto.randomBytes(24).toString('base64url'),
      displayName: nome,
    });
  } catch (e) {
    if (e.code === 'auth/email-already-exists') return res.status(409).json({ erro: 'Já existe uma conta com este e-mail' });
    throw e;
  }

  await db().doc(`users/${conta.uid}`).set({
    nome,
    email,
    matricula: matricula || null,
    role,
    telefone,
    ativo: true,
    empresaId: quem.dados.empresaId || null,
    criadoPor: quem.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  logger.info(`Usuário ${email} criado por ${quem.email}`);
  return res.json({ uid: conta.uid });
});

exports.usuarioAtivo = usuarioAtivo;
