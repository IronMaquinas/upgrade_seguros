#!/usr/bin/env node
// functions/scripts/admin-plataforma.js — Etapa 21
//
// Única forma de criar/remover administrador da PLATAFORMA (o portal admin).
// Não existe tela para isso, de propósito. Roda no SEU computador, com o seu
// login do Google Cloud (dono do projeto). A senha é digitada escondida e nunca
// aparece no terminal nem vai para o chat.
//
// Preparar (uma vez):
//   gcloud auth application-default login
//   gcloud auth application-default set-quota-project upgrade-seguros
//
// Usar (na pasta functions/):
//   node scripts/admin-plataforma.js adicionar admin@seudominio.com   → cria (ou troca a senha) e dá o acesso
//   node scripts/admin-plataforma.js remover   admin@seudominio.com   → tira o acesso na hora
//   node scripts/admin-plataforma.js listar
//
// Regras:
//   • o e-mail do admin NÃO pode ser de um usuário de corretora (use um e-mail só para isso);
//   • senha com no mínimo 10 caracteres;
//   • tudo vai para plataforma_auditoria.

const admin = require('firebase-admin');
const readline = require('readline');

const PROJETO = 'upgrade-seguros';
admin.initializeApp({ projectId: PROJETO });
const db = admin.firestore();
const auth = admin.auth();

function perguntarEscondido(pergunta) {
  return new Promise((ok) => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: true });
    rl._writeToOutput = function (txt) {
      if (txt.includes(pergunta)) rl.output.write(txt);
      else rl.output.write('*');
    };
    rl.question(pergunta, (r) => {
      rl.close();
      process.stdout.write('\n');
      ok(r);
    });
  });
}

async function buscar(email) {
  try {
    return await auth.getUserByEmail(email);
  } catch (e) {
    if (e.code === 'auth/user-not-found') return null;
    throw e;
  }
}

async function auditar(acao, email, detalhes = {}) {
  await db.collection('plataforma_auditoria').doc().set({
    em: admin.firestore.FieldValue.serverTimestamp(),
    uid: 'script',
    email: 'script (computador do dono)',
    acao,
    alvoTipo: 'admin',
    alvoId: email,
    detalhes,
  });
}

async function senhaNova() {
  const s1 = await perguntarEscondido('Senha (mín. 10 caracteres): ');
  if (s1.length < 10) throw new Error('Senha curta: mínimo 10 caracteres.');
  const s2 = await perguntarEscondido('Repita a senha: ');
  if (s1 !== s2) throw new Error('As senhas não conferem.');
  return s1;
}

async function adicionar(email) {
  let u = await buscar(email);
  if (u && (await db.collection('users').doc(u.uid).get()).exists) {
    throw new Error('Este e-mail é de um usuário de corretora. O admin da plataforma precisa de um e-mail só para isso.');
  }
  if (!u) {
    console.log(`Criando a conta ${email}…`);
    u = await auth.createUser({ email, password: await senhaNova(), emailVerified: true });
  } else {
    const r = await perguntarEscondido('Conta já existe. Nova senha (Enter = manter a atual): ');
    if (r) {
      if (r.length < 10) throw new Error('Senha curta: mínimo 10 caracteres.');
      await auth.updateUser(u.uid, { password: r });
      console.log('Senha trocada.');
    }
  }
  await auth.setCustomUserClaims(u.uid, { ...(u.customClaims || {}), plataforma: true });
  const ref = db.collection('plataforma_admins').doc(u.uid);
  const antes = await ref.get();
  await ref.set({
    email,
    ativo: true,
    desde: antes.exists && antes.data().desde ? antes.data().desde : admin.firestore.FieldValue.serverTimestamp(),
  });
  await auditar('admin_adicionado', email);
  console.log(`✓ ${email} é admin da plataforma. Entre no portal com essa conta.`);
}

async function remover(email) {
  const u = await buscar(email);
  if (!u) throw new Error('Conta não encontrada.');
  const marcas = { ...(u.customClaims || {}) };
  delete marcas.plataforma;
  await auth.setCustomUserClaims(u.uid, marcas);
  await db.collection('plataforma_admins').doc(u.uid).set({ email, ativo: false }, { merge: true });
  await auth.revokeRefreshTokens(u.uid);
  await auditar('admin_removido', email);
  console.log(`✓ ${email} não é mais admin da plataforma (sessões abertas encerradas).`);
}

async function listar() {
  const s = await db.collection('plataforma_admins').get();
  if (s.empty) return console.log('(nenhum admin)');
  for (const d of s.docs) console.log(`${d.data().ativo ? '✓ ativo   ' : '✗ removido'}  ${d.data().email}`);
}

(async () => {
  const [acao, email] = process.argv.slice(2);
  try {
    if (acao === 'listar') await listar();
    else if (acao === 'adicionar' && email) await adicionar(email.trim().toLowerCase());
    else if (acao === 'remover' && email) await remover(email.trim().toLowerCase());
    else console.log('Uso: node scripts/admin-plataforma.js adicionar|remover <email>  |  listar');
  } catch (e) {
    const msg = String(e.message || e);
    console.error('✗ ' + msg);
    if (/quota project|Could not load the default credentials|invalid_grant/i.test(msg)) {
      console.error('  Rode antes:  gcloud auth application-default login');
      console.error('               gcloud auth application-default set-quota-project ' + PROJETO);
    }
    process.exitCode = 1;
  }
  process.exit();
})();
