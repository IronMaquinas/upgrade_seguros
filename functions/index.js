// functions/index.js
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require('cors')({ origin: true });

admin.initializeApp();
const bucket = admin.storage().bucket();

// Etapa 15: segurança — NPS público, login por usuário/matrícula e criação de
// usuário pelo administrador passam pelo servidor; upload/exclusão exigem login.
const seguranca = require('./seguranca');
exports.npsPublico = seguranca.npsPublico;
exports.apoioLogin = seguranca.apoioLogin;
exports.criarUsuario = seguranca.criarUsuario;

exports.uploadFile = functions.https.onRequest(async (request, response) => {
  cors(request, response, async () => {
    if (request.method !== 'POST') {
      return response.status(405).send('Método não permitido');
    }

    // Etapa 15: só usuário logado e ativo (antes qualquer um na internet subia arquivo).
    if (!(await seguranca.usuarioAtivo(request))) {
      return response.status(401).send('Faça login novamente');
    }

    try {
      const { file, fileName, filePath, contentType } = request.body;

      if (!file || !fileName || !filePath) {
        return response.status(400).send('Dados incompletos: file, fileName ou filePath ausentes');
      }

      // ✅ Remove prefixo 'scaled_' (opcional, comum no web)
      const cleanFileName = fileName.replace('scaled_', '');
      const cleanFilePath = filePath.replace('scaled_', '');

      // ✅ Valida base64
      let fileBuffer;
      try {
        fileBuffer = Buffer.from(file, 'base64');
      } catch (e) {
        functions.logger.error('Erro ao decodificar base64:', e);
        return response.status(400).send('Base64 inválido');
      }

      // ✅ Define o contentType com base na extensão, se não for fornecido
      const extension = cleanFileName.split('.').pop().toLowerCase();
      const inferredType = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'pdf': 'application/pdf',
        'doc': 'application/msword',
        'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
      }[extension] || 'application/octet-stream';

      const finalContentType = contentType || inferredType;

      const fileRef = bucket.file(cleanFilePath);

      const metadata = {
        contentType: finalContentType,
      };

      const stream = fileRef.createWriteStream({
        metadata: metadata,
        resumable: false
      });

      stream.on('error', (err) => {
        functions.logger.error('Erro no stream:', err);
        return response.status(500).send('Erro no upload');
      });

      stream.on('finish', async () => {
        await fileRef.makePublic();
        // ✅ URL sem espaços
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${cleanFilePath}`;
        functions.logger.info('Upload concluído:', publicUrl);
        return response.status(200).json({ url: publicUrl });
      });

      stream.end(fileBuffer);

    } catch (e) {
      functions.logger.error('Erro interno:', e);
      return response.status(500).send('Erro interno');
    }
  });
});

// Importar as funções de notificação
const { verificarAssistenciasAtradasTelegram } = require("./notificacoes-telegram");
exports.verificarAssistenciasAtradasTelegram = verificarAssistenciasAtradasTelegram;

// Etapa 12: converte vídeos dos sinistros para MP4 720p depois do envio
exports.converterVideo = require('./converter-video').converterVideo;

// ✅ ✅ ✅ ADICIONE ESTA NOVA FUNÇÃO
exports.deleteFiles = functions.https.onRequest(async (request, response) => {
  cors(request, response, async () => {
    if (request.method !== 'POST') {
      return response.status(405).send('Método não permitido');
    }

    // Etapa 15: só usuário logado e ativo (antes qualquer um na internet apagava arquivo).
    if (!(await seguranca.usuarioAtivo(request))) {
      return response.status(401).send('Faça login novamente');
    }

    try {
      const { filePaths } = request.body;

      if (!filePaths || !Array.isArray(filePaths)) {
        return response.status(400).send('filePaths array é obrigatório');
      }

      functions.logger.info(`Excluindo ${filePaths.length} arquivos:`, filePaths);

      const deletePromises = filePaths.map(filePath => {
        return bucket.file(filePath).delete().catch(error => {
          // Ignora erro se arquivo não existir (código 404)
          if (error.code !== 404) {
            functions.logger.error(`Erro ao excluir arquivo ${filePath}:`, error);
            throw error;
          }
          functions.logger.info(`Arquivo não encontrado (já excluído?): ${filePath}`);
          return null;
        });
      });

      await Promise.all(deletePromises);
      functions.logger.info('Todos os arquivos excluídos com sucesso');
      
      return response.status(200).send('Arquivos excluídos com sucesso');
      
    } catch (error) {
      functions.logger.error('Erro em deleteFiles:', error);
      return response.status(500).send('Erro interno ao excluir arquivos');
    }
  });
});