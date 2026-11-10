// functions/testes/seguranca.teste.js — Etapa 15
// Testes de functions/seguranca.js com um Firebase falso em memória (não
// acessa o projeto real). Rodar: cd functions && node testes/seguranca.teste.js
const Module = require('module');
const store = {};               // 'col/id' -> data
const contas = {};              // email -> uid
const tokens = { 'tok-admin': 'uAdmin', 'tok-user': 'uUser', 'tok-inativo': 'uInativo', 'tok-semdoc': 'uSemDoc' };
const SV = { __sv: true };
function docRef(path) {
  return {
    path,
    async get() { const d = store[path]; return { exists: !!d, data: () => d && { ...d } }; },
    async set(v) { store[path] = { ...v }; },
    async update(v) { if (!store[path]) throw new Error('NOT_FOUND ' + path); store[path] = { ...store[path], ...v }; },
  };
}
function col(name) {
  const where = [];
  const q = {
    doc: (id) => docRef(`${name}/${id}`),
    where(f, op, v) { where.push([f, v]); return q; },
    limit() { return q; },
    async get() {
      const docs = Object.entries(store).filter(([k, d]) => k.split('/')[0] === name && k.split('/').length === 2 && where.every(([f, v]) => d[f] === v))
        .map(([k, d]) => ({ id: k.split('/')[1], data: () => ({ ...d }) }));
      return { empty: !docs.length, docs };
    },
  };
  return q;
}
const fakeAdmin = {
  apps: [1], initializeApp() {},
  firestore: Object.assign(() => ({ collection: col, doc: (p) => docRef(p) }), { FieldValue: { serverTimestamp: () => SV } }),
  auth: () => ({
    async verifyIdToken(t) { if (!tokens[t]) throw new Error('bad'); return { uid: tokens[t], email: tokens[t] + '@x.com' }; },
    async createUser({ email }) { if (contas[email]) { const e = new Error('x'); e.code = 'auth/email-already-exists'; throw e; } contas[email] = 'novo_' + Object.keys(contas).length; return { uid: contas[email] }; },
  }),
};
const fakeHttps = { onRequest: (h) => h };
const fakeLogger = { info() {}, warn() {}, error(e) { console.error('LOG', e); } };
const orig = Module._load;
Module._load = function (req, ...r) {
  if (req === 'firebase-admin') return fakeAdmin;
  if (req === 'firebase-functions/v2/https') return fakeHttps;
  if (req === 'firebase-functions/logger') return fakeLogger;
  if (req === 'cors') return () => (req, res, next) => next();
  return orig.call(this, req, ...r);
};
const s = require('../seguranca.js');

function chamar(fn, body, auth) {
  return new Promise((ok) => {
    const res = { headersSent: false, code: 200, status(c) { this.code = c; return this; },
      json(b) { this.headersSent = true; ok({ code: this.code, body: b }); }, send(b) { this.headersSent = true; ok({ code: this.code, body: b }); } };
    fn({ method: 'POST', body, get: (h) => (h === 'Authorization' && auth ? 'Bearer ' + auth : undefined) }, res);
  });
}
let falhas = 0;
const ok = (c, m) => { if (!c) { falhas++; console.log('✗', m); } else console.log('✓', m); };

(async () => {
  store['users/uAdmin'] = { role: 'admin', email: 'a@x.com', empresaId: 'emp1', username: 'ana', matricula: '77' };
  store['users/uUser'] = { role: 'user', email: 'u@x.com' };
  store['users/uInativo'] = { role: 'admin', email: 'i@x.com', ativo: false };
  store['nps_pesquisas/C1'] = { token: 'T1', status: 'enviada', clienteId: 'K1', clienteNome: 'Fulano', numeroSinistro: 'S-1', tipo: 'sinistro' };
  store['clientes/K1'] = { nomeEmpresa: 'Empresa K', logoUrl: 'http://logo', cpf: 'SEGREDO' };
  store['sinistros/C1'] = { status_atual: 'Aberto' };

  // usuarioAtivo
  ok((await s.usuarioAtivo({ get: () => 'Bearer tok-admin' }))?.role === 'admin', 'usuarioAtivo: admin');
  ok((await s.usuarioAtivo({ get: () => 'Bearer tok-inativo' })) === null, 'usuarioAtivo: desativado = null');
  ok((await s.usuarioAtivo({ get: () => 'Bearer tok-semdoc' })) === null, 'usuarioAtivo: sem cadastro = null');
  ok((await s.usuarioAtivo({ get: () => undefined })) === null, 'usuarioAtivo: sem token = null');

  // NPS
  let r = await chamar(s.npsPublico, { acao: 'verificar', claimId: 'C1', token: 'errado' });
  ok(r.code === 404, 'NPS: token errado = 404');
  r = await chamar(s.npsPublico, { acao: 'verificar', claimId: 'C1', token: 'T1' });
  ok(r.code === 200 && r.body.clienteEmpresa === 'Empresa K' && !JSON.stringify(r.body).includes('SEGREDO'), 'NPS: verificar devolve só o necessário');
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C1', token: 'T1', nota: 11 });
  ok(r.code === 400, 'NPS: nota 11 recusada');
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C1', token: 'T1', nota: 9, pontosFortes: ['Rapidez'], reclamacoes: 'nada' });
  ok(r.code === 200, 'NPS: responder ok');
  ok(store['avaliacoes/C1'].categoria === 'promotor' && store['nps_pesquisas/C1'].status === 'respondida', 'NPS: grava avaliação e marca respondida');
  ok(store['sinistros/C1'].nps_satisfacao === 9 && store['clientes/K1'].npsScore === 100, 'NPS: atualiza sinistro e NPS do cliente');
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C1', token: 'T1', nota: 3 });
  ok(r.code === 409, 'NPS: não responde duas vezes');
  r = await chamar(s.npsPublico, { acao: 'verificar', claimId: 'C1', token: 'T1' });
  ok(r.body.jaRespondida === true, 'NPS: verificar depois = jaRespondida');
  r = await chamar(s.npsPublico, { acao: 'verificar', claimId: '../users/uAdmin', token: 'T1' });
  ok(r.code === 400, 'NPS: id com barra recusado');

  // apoioLogin
  r = await chamar(s.apoioLogin, { login: 'ana' });
  ok(r.code === 200 && r.body.email === 'a@x.com' && Object.keys(r.body).length === 1, 'login: usuário → só e-mail');
  r = await chamar(s.apoioLogin, { login: '77' });
  ok(r.body.email === 'a@x.com', 'login: matrícula → e-mail');
  r = await chamar(s.apoioLogin, { login: 'ninguem' });
  ok(r.code === 404, 'login: não encontrado = 404');

  // criarUsuario
  r = await chamar(s.criarUsuario, { nome: 'Bia', email: 'b@x.com', role: 'admin' });
  ok(r.code === 401, 'criar: sem login = 401');
  r = await chamar(s.criarUsuario, { nome: 'Bia', email: 'b@x.com', role: 'admin' }, 'tok-user');
  ok(r.code === 403, 'criar: usuário comum = 403');
  r = await chamar(s.criarUsuario, { nome: 'Bia', email: 'b@x.com', role: 'admin' }, 'tok-inativo');
  ok(r.code === 401, 'criar: admin desativado = 401');
  r = await chamar(s.criarUsuario, { nome: 'Bia', email: 'B@X.com', matricula: '88', role: 'user', telefone: '119' }, 'tok-admin');
  const novo = store[`users/${r.body.uid}`];
  ok(r.code === 200 && novo.email === 'b@x.com' && novo.ativo === true && novo.role === 'user' && novo.empresaId === 'emp1', 'criar: admin cria, herda empresa');
  r = await chamar(s.criarUsuario, { nome: 'Outro', email: 'c@x.com', matricula: '88', role: 'user' }, 'tok-admin');
  ok(r.code === 409, 'criar: matrícula repetida = 409');
  r = await chamar(s.criarUsuario, { nome: 'Bia2', email: 'b@x.com', role: 'user' }, 'tok-admin');
  ok(r.code === 409, 'criar: e-mail repetido = 409');
  r = await chamar(s.criarUsuario, { nome: 'Ze', email: 'z@x.com', role: 'superadmin' }, 'tok-admin');
  ok(store[`users/${r.body.uid}`].role === 'user', 'criar: papel desconhecido vira user');
  console.log(falhas ? `${falhas} falha(s)` : 'todos ok');
  process.exitCode = falhas ? 1 : 0;
})();
