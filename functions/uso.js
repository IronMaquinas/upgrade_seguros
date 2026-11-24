// functions/uso.js — Etapa 27: uso de cada corretora (para as franquias do plano)
//
// Mede, por corretora:
//   • arquivos  tudo em corretoras/{e}/ no Storage, menos a pasta de vídeos
//   • vídeos    corretoras/{e}/videos/
//   • usuários  users com empresaId == e (ativos e desativados)
// e grava em plataforma_contas/{e}.uso = { bytesArquivos, arquivos, bytesVideos,
// videos, usuarios, medidoEm }. A corretora lê a própria conta (Meu plano mostra
// o uso × franquia); o portal usa no Financeiro (GB acima da franquia).
//
// Roda todo dia de madrugada (medirUsoDiario) e pelo botão "Medir uso agora" do
// portal (ação medirUso da Function plataforma). Só LÊ o Storage (lista os nomes
// e tamanhos; não baixa arquivo nenhum).
// As pastas antigas da raiz (até a Etapa 16b) não entram — são apagadas pelo
// cartão 📁 depois da passagem.

const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();
const balde = () => admin.storage().bucket();

const POR_PAGINA = 1000;

/** Soma os arquivos de uma pasta do Storage. */
async function somarPasta(prefixo, ignorar = null) {
  let pagina;
  let bytes = 0;
  let qtd = 0;
  for (;;) {
    const [arquivos, prox] = await balde().getFiles({ prefix: prefixo, maxResults: POR_PAGINA, pageToken: pagina, autoPaginate: false });
    for (const f of arquivos) {
      if (ignorar && f.name.startsWith(ignorar)) continue;
      if (f.name.endsWith('/')) continue; // "pasta" vazia criada pelo console
      bytes += Number((f.metadata || {}).size) || 0;
      qtd++;
    }
    if (prox && prox.pageToken) pagina = prox.pageToken;
    else break;
  }
  return { bytes, qtd };
}

async function contarUsuarios(e) {
  try {
    const s = await db().collection('users').where('empresaId', '==', e).count().get();
    return s.data().count;
  } catch (_) {
    return null;
  }
}

/** Mede uma corretora e grava na conta (se a conta existir). */
async function medirCorretora(e) {
  const raiz = `corretoras/${e}/`;
  const pastaVideos = `${raiz}videos/`;
  const [tudo, videos, usuarios] = await Promise.all([somarPasta(raiz, pastaVideos), somarPasta(pastaVideos), contarUsuarios(e)]);
  const uso = {
    bytesArquivos: tudo.bytes,
    arquivos: tudo.qtd,
    bytesVideos: videos.bytes,
    videos: videos.qtd,
    usuarios,
    medidoEm: admin.firestore.FieldValue.serverTimestamp(),
  };
  const ref = db().collection('plataforma_contas').doc(e);
  if ((await ref.get()).exists) await ref.update({ uso });
  return { empresaId: e, ...uso, medidoEm: new Date().toISOString() };
}

/** Mede todas as corretoras (uma de cada vez — o Storage lista em páginas). */
async function medirTodas() {
  const refs = await db().collection('corretoras').listDocuments();
  const r = [];
  for (const ref of refs) {
    try {
      r.push(await medirCorretora(ref.id));
    } catch (e) {
      logger.error(`medirUso ${ref.id}`, e);
      r.push({ empresaId: ref.id, erro: String(e.message || e) });
    }
  }
  return r;
}

const medirUsoDiario = onSchedule({ schedule: 'every day 03:30', timeZone: 'America/Sao_Paulo', timeoutSeconds: 540 }, async () => {
  const r = await medirTodas();
  logger.info(`Uso medido: ${r.length} corretora(s), ${r.filter((x) => x.erro).length} com erro`);
});

module.exports = { medirCorretora, medirTodas, medirUsoDiario, somarPasta };
