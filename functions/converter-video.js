// functions/converter-video.js
//
// Etapa 12: converte os vídeos dos sinistros para MP4 720p (H.264 + AAC) logo
// depois do envio.
//  • Por quê: vídeo de celular é grande (1080p/4K) e o do iPhone (.mov, HEVC)
//    não toca no Chrome. 720p é suficiente para acompanhar o evento e fica
//    bem menor (CRF 28, "veryfast").
//  • Onde: só arquivos em "videos/" (o app envia para videos/sinistros/{nº}/...).
//  • Como: baixa para /tmp, converte com ffmpeg (pacote ffmpeg-static) e grava
//    POR CIMA, no mesmo caminho, mantendo o token de download — o link salvo
//    no sinistro continua valendo e passa a entregar o vídeo convertido.
//  • Marca o arquivo com metadata `convertido=sim` (ou `falhou`) para não
//    converter de novo quando a gravação por cima disparar o gatilho outra vez.
//  • Se o original já é MP4 e a conversão não ficar menor, mantém o original.

const { onObjectFinalized } = require('firebase-functions/v2/storage');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const ffmpegPath = require('ffmpeg-static');
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Lado menor até 720 px (vídeo em pé continua em pé), sem aumentar vídeo pequeno.
const FILTRO_720P = "scale='if(gt(iw,ih),-2,min(720,iw))':'if(gt(iw,ih),min(720,ih),-2)'";

function argumentosFfmpeg(entrada, saida) {
  return [
    '-y',
    '-i', entrada,
    '-vf', FILTRO_720P,
    '-c:v', 'libx264',
    '-preset', 'veryfast',
    '-crf', '28',
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac',
    '-b:a', '96k',
    '-movflags', '+faststart',
    saida,
  ];
}

/** Decide o que gravar: 'convertido' ou 'original'. */
function decidir({ nome, tamanhoOriginal, tamanhoConvertido }) {
  const ext = String(nome).split('.').pop().toLowerCase();
  const formatoUniversal = ext === 'mp4' || ext === 'm4v';
  if (formatoUniversal && tamanhoConvertido >= tamanhoOriginal) return 'original';
  return 'convertido';
}

function rodarFfmpeg(args) {
  return new Promise((resolve, reject) => {
    const p = spawn(ffmpegPath, args);
    let erro = '';
    p.stderr.on('data', (d) => {
      erro = (erro + d.toString()).slice(-4000);
    });
    p.on('error', reject);
    p.on('close', (code) => (code === 0 ? resolve() : reject(new Error(`ffmpeg saiu com código ${code}: ${erro}`))));
  });
}

const converterVideo = onObjectFinalized(
  { memory: '2GiB', cpu: 2, timeoutSeconds: 540 },
  async (event) => {
    const obj = event.data;
    const nome = obj.name || '';
    const meta = obj.metadata || {};
    if (!nome.startsWith('videos/')) return;
    if (!String(obj.contentType || '').startsWith('video/')) return;
    if (meta.convertido === 'sim' || meta.convertido === 'falhou') return;

    const arquivo = admin.storage().bucket(obj.bucket).file(nome);
    const entrada = path.join(os.tmpdir(), `in_${Date.now()}_${path.basename(nome)}`);
    const saida = path.join(os.tmpdir(), `out_${Date.now()}.mp4`);
    try {
      await arquivo.download({ destination: entrada });
      await rodarFfmpeg(argumentosFfmpeg(entrada, saida));

      const tamanhoOriginal = Number(obj.size) || fs.statSync(entrada).size;
      const tamanhoConvertido = fs.statSync(saida).size;
      const escolha = decidir({ nome, tamanhoOriginal, tamanhoConvertido });

      if (escolha === 'original') {
        await arquivo.setMetadata({
          metadata: { convertido: 'sim', tamanhoConvertido: String(tamanhoOriginal), observacao: 'original mantido (menor)' },
        });
      } else {
        await admin.storage().bucket(obj.bucket).upload(saida, {
          destination: nome,
          resumable: false,
          metadata: {
            contentType: 'video/mp4',
            // mantém o token: o link salvo no sinistro continua funcionando
            metadata: { ...meta, convertido: 'sim', tamanhoConvertido: String(tamanhoConvertido) },
          },
        });
      }
      logger.info('Vídeo convertido', { nome, tamanhoOriginal, tamanhoConvertido, escolha });
    } catch (e) {
      logger.error('Falha ao converter vídeo', { nome, erro: String(e && e.message ? e.message : e) });
      await arquivo.setMetadata({ metadata: { convertido: 'falhou' } }).catch(() => {});
    } finally {
      for (const f of [entrada, saida]) fs.rm(f, { force: true }, () => {});
    }
  },
);

module.exports = { converterVideo, argumentosFfmpeg, decidir, rodarFfmpeg };
