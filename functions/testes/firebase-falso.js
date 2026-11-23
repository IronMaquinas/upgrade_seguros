// functions/testes/firebase-falso.js — Etapa 16
// Firebase de mentira, em memória, para testar as Functions sem acessar o
// projeto real. Guarda documentos por caminho completo ("a/b/c/d").
// Uso: carregar este arquivo, chamar F.instalar() e só depois carregar a Function a testar.

const Module = require('module');

const store = {};
const tokens = {};
const contas = {};
const SV = { __serverTimestamp: true };

function docRef(path) {
  const id = path.split('/').pop();
  return {
    id,
    path,
    async get() {
      const d = store[path];
      return { id, exists: !!d, ref: docRef(path), data: () => d && { ...d } };
    },
    async set(v) { store[path] = { ...v }; },
    async update(v) {
      if (!store[path]) throw new Error('NOT_FOUND ' + path);
      store[path] = { ...store[path], ...v };
    },
    collection: (nome) => colRef(`${path}/${nome}`),
  };
}

function colRef(path) {
  const filtros = [];
  const nivel = path.split('/').length + 1;
  const docsDaColecao = () =>
    Object.keys(store)
      .filter((k) => k.startsWith(path + '/') && k.split('/').length === nivel)
      .filter((k) => filtros.every(([f, v]) => store[k][f] === v));
  const q = {
    path,
    doc: (id) => docRef(`${path}/${id}`),
    where(f, _op, v) { filtros.push([f, v]); return q; },
    limit() { return q; },
    async get() {
      const docs = docsDaColecao().map((k) => ({ id: k.split('/').pop(), ref: docRef(k), data: () => ({ ...store[k] }) }));
      return { empty: !docs.length, size: docs.length, docs };
    },
    count: () => ({ get: async () => ({ data: () => ({ count: docsDaColecao().length }) }) }),
    async listDocuments() {
      // como no Firebase: inclui documentos que só têm subcoleções
      const ids = new Set();
      for (const k of Object.keys(store)) {
        if (k.startsWith(path + '/')) ids.add(k.slice(path.length + 1).split('/')[0]);
      }
      return [...ids].map((id) => docRef(`${path}/${id}`));
    },
  };
  return q;
}

function batch() {
  const ops = [];
  return {
    set(ref, v) { ops.push(() => ref.set(v)); },
    update(ref, v) { ops.push(() => ref.update(v)); },
    async commit() { for (const o of ops) await o(); },
  };
}

const firestore = Object.assign(
  () => ({ collection: (n) => colRef(n), doc: (p) => docRef(p), batch }),
  { FieldValue: { serverTimestamp: () => SV } },
);

const fakeAdmin = {
  apps: [1],
  initializeApp() {},
  firestore,
  auth: () => ({
    async verifyIdToken(t) {
      if (!tokens[t]) throw new Error('token inválido');
      return { uid: tokens[t], email: tokens[t] + '@x.com' };
    },
    async createUser({ email }) {
      if (contas[email]) { const e = new Error('x'); e.code = 'auth/email-already-exists'; throw e; }
      contas[email] = 'novo_' + Object.keys(contas).length;
      return { uid: contas[email] };
    },
  }),
};

function instalar() {
  const orig = Module._load;
  Module._load = function (req, ...r) {
    if (req === 'firebase-admin') return fakeAdmin;
    if (req === 'firebase-functions/v2/https') {
      return { onRequest: (a, b) => (typeof a === 'function' ? a : b) };
    }
    if (req === 'firebase-functions/logger') return { info() {}, warn() {}, error(e) { console.error('LOG', e); } };
    if (req === 'cors') return () => (req2, res, next) => next();
    return orig.call(this, req, ...r);
  };
}

/** Chama um handler HTTP e devolve { code, body }. */
function chamar(fn, body, token) {
  return new Promise((ok) => {
    const res = {
      headersSent: false,
      code: 200,
      status(c) { this.code = c; return this; },
      json(b) { this.headersSent = true; ok({ code: this.code, body: b }); },
      send(b) { this.headersSent = true; ok({ code: this.code, body: b }); },
    };
    fn({ method: 'POST', body, get: (h) => (h === 'Authorization' && token ? 'Bearer ' + token : undefined) }, res);
  });
}

function placar() {
  let falhas = 0;
  return {
    ok(c, m) { if (!c) { falhas++; console.log('✗', m); } else console.log('✓', m); },
    fim() { console.log(falhas ? `${falhas} falha(s)` : 'todos ok'); process.exitCode = falhas ? 1 : 0; },
  };
}

module.exports = { instalar, store, tokens, chamar, placar };
