// functions/arquivos.js — Etapa 16c (multi-tenant, parte 3: arquivos)
//
// Até a 16b os arquivos (fotos, laudos, documentos, vídeos) ficavam em pastas
// comuns a todas as corretoras (sinistros/…, clientes/…, videos/…) e o
// uploadFile deixava cada arquivo PÚBLICO (makePublic): quem tivesse o
// endereço abria, sem login e sem prazo.
//
// A partir da 16c:
//  • uploadFile grava dentro da pasta da corretora do usuário
//    (corretoras/{empresaId}/sinistros/…) e devolve um link com chave de
//    acesso própria do Firebase ("token"), sem deixar o arquivo público.
//  • deleteFiles só apaga arquivos da pasta da própria corretora (e, para a
//    corretora que recebeu os dados antigos, das pastas antigas).
//  • arquivosEmpresa (só administrador) passa os arquivos antigos para a
//    pasta da corretora:
//      { acao: 'diagnostico' } → quantos links antigos ainda existem, sem mudar nada.
//      { acao: 'converter' }   → COPIA um lote de arquivos antigos para a pasta
//          da corretora e troca os links gravados nos documentos. O app chama
//          de novo até não sobrar nada. O original não é apagado.
//      { acao: 'apagarOriginais', confirmacao: 'APAGAR', cursor } → depois de
//          DIAS_ANTES_DE_APAGAR dias da conversão completa, apaga das pastas
//          antigas só os arquivos que JÁ TÊM cópia na pasta da corretora. Os
//          links públicos antigos param de funcionar. Arquivos antigos sem
//          cópia (não usados por nenhum documento) ficam e aparecem no relatório.

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const crypto = require('crypto');
const { usuarioAtivo } = require('./seguranca');
const { COLECOES } = require('./empresa');

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();
const balde = () => admin.storage().bucket();

// Pastas que o app usava antes da 16c (Storage, raiz do bucket).
const PASTAS_ANTIGAS = ['sinistros', 'clientes', 'videos', 'veiculos'];
// Arquivos por chamada de "converter" (cada chamada tem até 9 minutos).
const LOTE_CONVERTER = 100;
// Objetos olhados por chamada de "apagarOriginais".
const LOTE_APAGAR = 300;
// Prazo entre a conversão completa e a limpeza das pastas antigas.
const DIAS_ANTES_DE_APAGAR = 7;
// Teto da lista de arquivos antigos que não existem mais (para não reler).
const MAX_SEM_ORIGINAL = 1000;

// ─── Links e caminhos ─────────────────────────────────────────────────────────

function decodificar(s) {
  try {
    return decodeURIComponent(s);
  } catch (_) {
    return s;
  }
}

/** Lê um link do Storage (formato antigo ou novo). Devolve { bucket, caminho } ou null. */
function lerLink(s) {
  if (typeof s !== 'string' || !/^https?:\/\//i.test(s)) return null;
  let u;
  try {
    u = new URL(s);
  } catch (_) {
    return null;
  }
  if (u.hostname === 'firebasestorage.googleapis.com') {
    const m = u.pathname.match(/^\/v0\/b\/([^/]+)\/o\/(.+)$/);
    return m ? { bucket: decodificar(m[1]), caminho: decodificar(m[2]) } : null;
  }
  if (u.hostname === 'storage.googleapis.com') {
    const m = u.pathname.match(/^\/([^/]+)\/(.+)$/);
    return m ? { bucket: decodificar(m[1]), caminho: decodificar(m[2]) } : null;
  }
  if (u.hostname.endsWith('.storage.googleapis.com')) {
    const bucket = u.hostname.slice(0, -'.storage.googleapis.com'.length);
    const caminho = decodificar(u.pathname.replace(/^\/+/, ''));
    return caminho ? { bucket, caminho } : null;
  }
  return null;
}

/** Link com chave de acesso (o mesmo formato do getDownloadURL do app). */
function linkComToken(bucket, caminho, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(caminho)}?alt=media&token=${token}`;
}

/** Caminho limpo, sem "/" no começo; null se tiver ".." ou ficar vazio. */
function limpar(c) {
  const s = String(c || '').trim().replace(/^\/+/, '');
  if (!s || s.split('/').some((p) => p === '..' || p === '.')) return null;
  return s;
}

/**
 * Onde gravar um arquivo enviado pelo app: sempre dentro da pasta da corretora.
 * "sinistros/12/fotos/a.jpg" → "corretoras/{empresa}/sinistros/12/fotos/a.jpg".
 * Caminho de OUTRA corretora → null.
 */
function caminhoNaCorretora(empresa, caminho) {
  const c = limpar(caminho);
  if (!c || !empresa) return null;
  const minha = `corretoras/${empresa}/`;
  if (c.startsWith('corretoras/')) return c.startsWith(minha) && c.length > minha.length ? c : null;
  return minha + c;
}

function ehPastaAntiga(caminho) {
  return PASTAS_ANTIGAS.includes(String(caminho).split('/')[0]);
}

/** A corretora recebeu os dados antigos (migração da 16)? Só ela mexe nas pastas antigas. */
async function recebeuDadosAntigos(empresa) {
  const s = await db().collection('corretoras').doc(empresa).get();
  return s.exists && !!(s.data() || {}).migradoEm;
}

function empresaDe(quem) {
  const e = String((quem && quem.dados && quem.dados.empresaId) || '').trim();
  return e && !e.includes('/') ? e : '';
}

const TIPOS = {
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

// ─── uploadFile / deleteFiles (usados pelo app) ───────────────────────────────

const uploadFile = onRequest((req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const quem = await usuarioAtivo(req);
      if (!quem) return res.status(401).send('Faça login novamente');
      const empresa = empresaDe(quem);
      if (!empresa) return res.status(403).send('Seu usuário não está ligado a nenhuma corretora');

      const { file, fileName, filePath, contentType } = req.body || {};
      if (!file || !fileName || !filePath) {
        return res.status(400).send('Dados incompletos: file, fileName ou filePath ausentes');
      }
      // Remove prefixo 'scaled_' (comum no web), como antes.
      const nome = String(fileName).replace('scaled_', '');
      const destino = caminhoNaCorretora(empresa, String(filePath).replace('scaled_', ''));
      if (!destino) return res.status(400).send('Caminho do arquivo inválido');

      const conteudo = Buffer.from(String(file), 'base64');
      const tipo = contentType || TIPOS[nome.split('.').pop().toLowerCase()] || 'application/octet-stream';
      const token = crypto.randomUUID();
      const b = balde();
      await b.file(destino).save(conteudo, {
        resumable: false,
        metadata: { contentType: tipo, metadata: { firebaseStorageDownloadTokens: token } },
      });
      // Sem makePublic: o arquivo só abre com o link (chave) ou com login pelas regras.
      const url = linkComToken(b.name, destino, token);
      logger.info('Upload concluído', { caminho: destino, por: quem.email });
      return res.status(200).json({ url, caminho: destino });
    } catch (e) {
      logger.error('Erro no upload', e);
      return res.status(500).send('Erro no upload');
    }
  }),
);

const deleteFiles = onRequest((req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const quem = await usuarioAtivo(req);
      if (!quem) return res.status(401).send('Faça login novamente');
      const empresa = empresaDe(quem);
      if (!empresa) return res.status(403).send('Seu usuário não está ligado a nenhuma corretora');

      const { filePaths } = req.body || {};
      if (!Array.isArray(filePaths)) return res.status(400).send('filePaths array é obrigatório');

      const b = balde();
      let antigosPermitidos = null; // só consulta se precisar
      const excluir = [];
      const recusados = [];
      for (const item of filePaths) {
        const link = lerLink(item);
        if (link && link.bucket !== b.name) {
          recusados.push(String(item));
          continue;
        }
        const c = limpar(link ? link.caminho : item);
        if (!c) {
          recusados.push(String(item));
          continue;
        }
        if (c.startsWith(`corretoras/${empresa}/`)) {
          excluir.push(c);
        } else if (!c.startsWith('corretoras/') && ehPastaAntiga(c)) {
          if (antigosPermitidos === null) antigosPermitidos = await recebeuDadosAntigos(empresa);
          (antigosPermitidos ? excluir : recusados).push(c);
        } else {
          recusados.push(c);
        }
      }
      if (recusados.length) logger.warn('deleteFiles: caminhos recusados', { por: quem.email, recusados });

      await Promise.all(
        excluir.map((c) =>
          b.file(c).delete().catch((e) => {
            if (e.code !== 404) throw e; // já não existia
          }),
        ),
      );
      return res.status(200).json({ excluidos: excluir.length, recusados });
    } catch (e) {
      logger.error('Erro em deleteFiles', e);
      return res.status(500).send('Erro interno ao excluir arquivos');
    }
  }),
);

// ─── Conversão dos arquivos antigos ───────────────────────────────────────────

function ehObjetoSimples(v) {
  return v !== null && typeof v === 'object' && Object.getPrototypeOf(v) === Object.prototype;
}

/** Percorre um valor do Firestore e chama fn(texto) para cada texto. */
function cadaTexto(v, fn) {
  if (typeof v === 'string') fn(v);
  else if (Array.isArray(v)) v.forEach((x) => cadaTexto(x, fn));
  else if (ehObjetoSimples(v)) Object.values(v).forEach((x) => cadaTexto(x, fn));
}

/**
 * Troca, dentro de um valor, os links (e os campos "caminho") dos arquivos
 * que já foram copiados. Datas, referências etc. ficam como estão.
 */
function trocar(v, mapa, bucket) {
  if (typeof v === 'string') {
    const l = lerLink(v);
    if (l && l.bucket === bucket && mapa[l.caminho]) return mapa[l.caminho].url;
    if (!l && mapa[v]) return mapa[v].caminho; // campo "caminho" dos vídeos
    return v;
  }
  if (Array.isArray(v)) return v.map((x) => trocar(x, mapa, bucket));
  if (ehObjetoSimples(v)) {
    const o = {};
    for (const [k, x] of Object.entries(v)) o[k] = trocar(x, mapa, bucket);
    return o;
  }
  return v;
}

/** Caminhos antigos (fora de corretoras/) citados num documento. */
function antigosDoDocumento(dados, bucket, contagem) {
  const achados = new Set();
  cadaTexto(dados, (s) => {
    const l = lerLink(s);
    if (!l) return;
    if (l.bucket !== bucket) {
      if (contagem) contagem.outrosBuckets++;
      return;
    }
    if (l.caminho.startsWith('corretoras/')) {
      if (contagem) contagem.jaNaPasta.add(l.caminho);
      return;
    }
    if (l.caminho.startsWith('backups/')) return;
    achados.add(l.caminho);
  });
  return achados;
}

/** Documentos da corretora (13 coleções + o próprio cadastro) com links antigos. */
async function varrer(empresa, bucket, contagem) {
  const base = db().collection('corretoras').doc(empresa);
  const lista = [];
  const cad = await base.get();
  if (cad.exists) {
    const a = antigosDoDocumento(cad.data(), bucket, contagem);
    if (a.size) lista.push({ ref: base, colecao: '(cadastro da corretora)', antigos: a });
  }
  for (const c of COLECOES) {
    const snap = await base.collection(c).get();
    for (const d of snap.docs) {
      const a = antigosDoDocumento(d.data(), bucket, contagem);
      if (a.size) lista.push({ ref: d.ref, colecao: c, antigos: a });
    }
  }
  return lista;
}

/** Copia um arquivo antigo para a pasta da corretora. null se o original não existe. */
async function copiarParaCorretora(b, empresa, caminho) {
  const destino = `corretoras/${empresa}/${caminho}`;
  const novo = b.file(destino);
  const [jaExiste] = await novo.exists();
  if (!jaExiste) {
    const [existe] = await b.file(caminho).exists();
    if (!existe) return null;
    // Cópia dentro do próprio bucket (rápida). A cópia NÃO herda o "público"
    // do original. Vídeo copiado já vem marcado como convertido.
    await b.file(caminho).copy(novo);
  }
  const [meta] = await novo.getMetadata();
  let token = String(((meta || {}).metadata || {}).firebaseStorageDownloadTokens || '').split(',')[0].trim();
  if (!token) {
    token = crypto.randomUUID();
    await novo.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
  }
  return { caminho: destino, url: linkComToken(b.name, destino, token) };
}

/** Troca os links de um documento lendo a versão MAIS RECENTE (transação). */
async function atualizarDocumento(ref, mapa, bucket) {
  return db().runTransaction(async (t) => {
    const s = await t.get(ref);
    if (!s.exists) return false;
    const atual = s.data();
    const novo = trocar(atual, mapa, bucket);
    if (JSON.stringify(novo) === JSON.stringify(atual)) return false;
    t.set(ref, novo);
    return true;
  });
}

function dias(desde) {
  if (!desde) return null;
  const ms = typeof desde.toMillis === 'function' ? desde.toMillis() : Number(desde);
  if (!ms) return null;
  return Math.floor((Date.now() - ms) / 86400000);
}

async function diagnostico(empresa) {
  const b = balde();
  const contagem = { outrosBuckets: 0, jaNaPasta: new Set() };
  const lista = await varrer(empresa, b.name, contagem);
  const cad = (await db().collection('corretoras').doc(empresa).get()).data() || {};
  const semOriginal = new Set(cad.arquivosSemOriginal || []);
  const pendentes = new Set();
  const porColecao = {};
  const porPasta = {};
  for (const d of lista) {
    let n = 0;
    for (const c of d.antigos) {
      if (semOriginal.has(c)) continue;
      pendentes.add(c);
      n++;
    }
    if (n) porColecao[d.colecao] = (porColecao[d.colecao] || 0) + 1;
  }
  for (const c of pendentes) {
    const p = c.split('/')[0];
    porPasta[p] = (porPasta[p] || 0) + 1;
  }
  const diasConvertido = dias(cad.arquivosConvertidosEm);
  return {
    empresa,
    recebeuDadosAntigos: !!cad.migradoEm,
    arquivosParaPassar: pendentes.size,
    documentosComLinkAntigo: Object.values(porColecao).reduce((a, n) => a + n, 0),
    documentosPorColecao: porColecao,
    arquivosPorPasta: porPasta,
    arquivosJaNaPasta: contagem.jaNaPasta.size,
    linksDeOutroBucket: contagem.outrosBuckets,
    arquivosSemOriginal: semOriginal.size,
    diasDesdeConversao: diasConvertido,
    podeApagarOriginais: pendentes.size === 0 && diasConvertido !== null && diasConvertido >= DIAS_ANTES_DE_APAGAR,
    diasMinimos: DIAS_ANTES_DE_APAGAR,
  };
}

async function converter(empresa) {
  const b = balde();
  const cadRef = db().collection('corretoras').doc(empresa);
  const cad = (await cadRef.get()).data() || {};
  const semOriginal = new Set(cad.arquivosSemOriginal || []);
  const lista = await varrer(empresa, b.name, null);

  const mapa = {};
  const faltando = [];
  let copiados = 0;
  let documentos = 0;
  let parouNoDocumento = lista.length;
  for (let i = 0; i < lista.length; i++) {
    const d = lista[i];
    const novos = [...d.antigos].filter((c) => !semOriginal.has(c) && !mapa[c]);
    if (copiados > 0 && copiados + novos.length > LOTE_CONVERTER) {
      parouNoDocumento = i;
      break;
    }
    for (const c of novos) {
      const r = await copiarParaCorretora(b, empresa, c);
      if (r) {
        mapa[c] = r;
        copiados++;
      } else {
        semOriginal.add(c);
        faltando.push(c);
      }
    }
    if ([...d.antigos].some((c) => mapa[c]) && (await atualizarDocumento(d.ref, mapa, b.name))) documentos++;
  }

  // O que sobrou para a próxima chamada.
  const restantes = new Set();
  for (const d of lista.slice(parouNoDocumento)) {
    for (const c of d.antigos) if (!semOriginal.has(c) && !mapa[c]) restantes.add(c);
  }

  const atualizacao = {};
  if (faltando.length) atualizacao.arquivosSemOriginal = [...semOriginal].slice(0, MAX_SEM_ORIGINAL);
  if (restantes.size === 0 && !cad.arquivosConvertidosEm) {
    // Guarda a data em que a conversão terminou (o prazo para apagar conta dela).
    atualizacao.arquivosConvertidosEm = admin.firestore.FieldValue.serverTimestamp();
  }
  if (Object.keys(atualizacao).length) await cadRef.update(atualizacao);

  return {
    empresa,
    copiados,
    documentosAtualizados: documentos,
    semOriginal: faltando,
    restantes: restantes.size,
    terminou: restantes.size === 0,
  };
}

/**
 * Apaga das pastas antigas os arquivos que já têm cópia na pasta da corretora.
 * Vai por partes: o app manda de volta o `cursor` recebido até `terminou`.
 */
async function apagarOriginais(empresa, cursor) {
  const b = balde();
  const d = await diagnostico(empresa);
  if (!d.recebeuDadosAntigos) return { erro: 'Esta corretora não recebeu os dados antigos.' };
  if (d.arquivosParaPassar > 0) {
    return { erro: `Ainda há ${d.arquivosParaPassar} arquivo(s) para passar. Rode "Passar arquivos" antes.` };
  }
  if (!d.podeApagarOriginais) {
    return { erro: `Só depois de ${DIAS_ANTES_DE_APAGAR} dias da conversão (hoje: ${d.diasDesdeConversao ?? 'conversão não concluída'}).` };
  }

  let pasta = Number((cursor && cursor.pasta) || 0);
  let pagina = (cursor && cursor.pagina) || undefined;
  const resultado = { apagados: 0, semCopia: 0, bytesSemCopia: 0, exemplosSemCopia: [] };
  let olhados = 0;
  while (pasta < PASTAS_ANTIGAS.length && olhados < LOTE_APAGAR) {
    const [arquivos, prox] = await b.getFiles({
      prefix: `${PASTAS_ANTIGAS[pasta]}/`,
      maxResults: LOTE_APAGAR - olhados,
      pageToken: pagina,
      autoPaginate: false,
    });
    for (const f of arquivos) {
      olhados++;
      const [temCopia] = await b.file(`corretoras/${empresa}/${f.name}`).exists();
      if (temCopia) {
        await f.delete().catch((e) => {
          if (e.code !== 404) throw e;
        });
        resultado.apagados++;
      } else {
        resultado.semCopia++;
        resultado.bytesSemCopia += Number((f.metadata || {}).size) || 0;
        if (resultado.exemplosSemCopia.length < 20) resultado.exemplosSemCopia.push(f.name);
      }
    }
    if (prox && prox.pageToken) {
      pagina = prox.pageToken;
    } else {
      pasta++;
      pagina = undefined;
    }
  }
  const terminou = pasta >= PASTAS_ANTIGAS.length;
  if (terminou) {
    await db().collection('corretoras').doc(empresa).update({
      arquivosOriginaisApagadosEm: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
  return { ...resultado, terminou, cursor: terminou ? null : { pasta, pagina: pagina || null } };
}

const arquivosEmpresa = onRequest({ timeoutSeconds: 540, memory: '1GiB' }, (req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const quem = await usuarioAtivo(req);
      if (!quem) return res.status(401).json({ erro: 'Faça login novamente' });
      if (quem.role !== 'admin') return res.status(403).json({ erro: 'Só administradores' });
      const empresa = empresaDe(quem);
      if (!empresa) return res.status(400).json({ erro: 'O seu usuário não tem empresaId no cadastro.' });
      if (!(await recebeuDadosAntigos(empresa))) {
        return res.status(409).json({ erro: 'Faça primeiro a migração dos dados (Etapa 16).' });
      }
      const corpo = req.body || {};
      if (corpo.acao === 'diagnostico') return res.json(await diagnostico(empresa));
      if (corpo.acao === 'converter') {
        const r = await converter(empresa);
        logger.info(`arquivosEmpresa: conversão para ${empresa} por ${quem.email}`, r);
        return res.json(r);
      }
      if (corpo.acao === 'apagarOriginais') {
        if (corpo.confirmacao !== 'APAGAR') return res.status(400).json({ erro: 'Confirmação ausente' });
        const r = await apagarOriginais(empresa, corpo.cursor);
        if (r.erro) return res.status(409).json(r);
        logger.info(`arquivosEmpresa: originais apagados para ${empresa} por ${quem.email}`, r);
        return res.json(r);
      }
      return res.status(400).json({ erro: "acao deve ser 'diagnostico', 'converter' ou 'apagarOriginais'" });
    } catch (e) {
      logger.error(e);
      return res.status(500).json({ erro: 'Erro interno' });
    }
  }),
);

module.exports = {
  uploadFile,
  deleteFiles,
  arquivosEmpresa,
  // para os testes
  lerLink,
  linkComToken,
  caminhoNaCorretora,
  trocar,
  PASTAS_ANTIGAS,
  DIAS_ANTES_DE_APAGAR,
};
