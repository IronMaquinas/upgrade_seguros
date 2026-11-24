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

/**
 * POST { acao, ... } com "Authorization: Bearer <ID token>" do admin.
 *   eu          { entrada?: true }  → { email }   (entrada: registra o login na auditoria)
 *   corretoras                      → { corretoras: [...] }
 *   auditoria                       → { acoes: [...] }
 *   criarContasQueFaltam            → { criadas: [ids] }
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
        default:
          return res.status(400).json({ erro: 'Ação desconhecida' });
      }
    } catch (e) {
      logger.error(e);
      if (!res.headersSent) res.status(500).json({ erro: 'Erro interno' });
    }
  }),
);

module.exports = { plataforma, adminDaPlataforma, SITUACOES };
