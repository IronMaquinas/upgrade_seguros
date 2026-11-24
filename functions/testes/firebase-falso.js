// functions/testes/firebase-falso.js — Etapa 16
// Firebase de mentira, em memória, para testar as Functions sem acessar o
// projeto real. Guarda documentos por caminho completo ("a/b/c/d").
// Uso: carregar este arquivo, chamar F.instalar() e só depois carregar a Function a testar.

const Module = require('module');

const store = {};
const tokens = {};
const contas = {};
const SV = { __serverTimestamp: true };
const APAGAR = { __apagarCampo: true }; // Etapa 23: FieldValue.delete()
let proximoId = 0; // Etapa 21: doc() sem id

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
      for (const k of Object.keys(v)) if (v[k] === APAGAR) delete store[path][k];
    },
    async delete() { delete store[path]; },
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
    doc: (id) => docRef(`${path}/${id === undefined ? 'auto' + ++proximoId : id}`),
    where(f, _op, v) { filtros.push([f, v]); return q; },
    orderBy() { return q; }, // Etapa 21 (a ordem não é conferida nos testes)
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
    delete(ref) { ops.push(() => ref.delete()); },
    async commit() { for (const o of ops) await o(); },
  };
}

// Etapa 16c: transação simples (lê e grava na hora; basta para os testes).
async function runTransaction(fn) {
  return fn({
    get: (ref) => ref.get(),
    set: (ref, v) => ref.set(v),
    update: (ref, v) => ref.update(v),
  });
}

// Etapa 16c: Storage de mentira. objetos[caminho] = { conteudo, metadata, publico }
const objetos = {};
const NOME_BUCKET = 'balde-teste';
function arquivoRef(nome) {
  return {
    name: nome,
    get metadata() { return { size: String((objetos[nome] && objetos[nome].tamanho) || 0) }; },
    async exists() { return [!!objetos[nome]]; },
    async save(buf, opts = {}) {
      const m = opts.metadata || {};
      objetos[nome] = { tamanho: buf.length, contentType: m.contentType, metadata: { ...(m.metadata || {}) }, publico: false };
    },
    async delete() {
      if (!objetos[nome]) { const e = new Error('No such object'); e.code = 404; throw e; }
      delete objetos[nome];
    },
    async copy(destino) {
      if (!objetos[nome]) { const e = new Error('No such object'); e.code = 404; throw e; }
      const o = objetos[nome];
      // como no GCS: copia os metadados, mas NÃO o "público"
      objetos[destino.name] = { ...o, metadata: { ...o.metadata }, publico: false };
    },
    async getMetadata() {
      const o = objetos[nome];
      return [{ contentType: o.contentType, metadata: { ...o.metadata } }];
    },
    async setMetadata({ metadata }) { objetos[nome].metadata = { ...objetos[nome].metadata, ...metadata }; },
  };
}
const balde = {
  name: NOME_BUCKET,
  file: (n) => arquivoRef(n),
  async getFiles({ prefix = '', maxResults = 1000, pageToken } = {}) {
    const nomes = Object.keys(objetos).filter((k) => k.startsWith(prefix)).sort();
    const ini = pageToken ? Number(pageToken) : 0;
    const pagina = nomes.slice(ini, ini + maxResults).map(arquivoRef);
    const prox = ini + maxResults < nomes.length ? { pageToken: String(ini + maxResults) } : null;
    return [pagina, prox];
  },
};

const firestore = Object.assign(
  () => ({ collection: (n) => colRef(n), doc: (p) => docRef(p), batch, runTransaction }),
  {
    FieldValue: { serverTimestamp: () => SV, delete: () => APAGAR },
    Timestamp: { fromDate: (d) => ({ toDate: () => d }) }, // Etapa 24
  },
);

const fakeAdmin = {
  apps: [1],
  initializeApp() {},
  firestore,
  storage: () => ({ bucket: () => balde }),
  auth: () => ({
    async verifyIdToken(t) {
      if (!tokens[t]) throw new Error('token inválido');
      // Etapa 21: tokens[t] pode ser { uid, marcas } (ex.: { plataforma: true })
      if (typeof tokens[t] === 'object') return { uid: tokens[t].uid, email: tokens[t].uid + '@x.com', ...(tokens[t].marcas || {}) };
      return { uid: tokens[t], email: tokens[t] + '@x.com' };
    },
    async getUserByEmail(email) { // Etapa 25
      if (contas[email]) return { uid: contas[email], email };
      const e = new Error('x'); e.code = 'auth/user-not-found'; throw e;
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
    if (req === 'firebase-functions/v2/scheduler') return { onSchedule: (a, b) => (typeof a === 'function' ? a : b) }; // Etapa 27
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

module.exports = { instalar, store, tokens, chamar, placar, objetos, NOME_BUCKET };
