// functions/index.js
const admin = require("firebase-admin");

admin.initializeApp();

// Etapa 15: segurança — NPS público, login por usuário/matrícula e criação de
// usuário pelo administrador passam pelo servidor; upload/exclusão exigem login.
const seguranca = require('./seguranca');
exports.npsPublico = seguranca.npsPublico;
exports.apoioLogin = seguranca.apoioLogin;
exports.criarUsuario = seguranca.criarUsuario;

// Etapa 16: multi-tenant — cópia dos dados da raiz para a pasta da corretora.
exports.migrarEmpresa = require('./empresa').migrarEmpresa;

// Etapa 16c: arquivos na pasta da corretora e links com chave de acesso
// (o upload não deixa mais o arquivo público). O código de uploadFile e
// deleteFiles saiu daqui e foi para functions/arquivos.js — mesmos nomes e
// mesmos endereços, o app continua chamando igual.
const arquivos = require('./arquivos');
exports.uploadFile = arquivos.uploadFile;
exports.deleteFiles = arquivos.deleteFiles;
exports.arquivosEmpresa = arquivos.arquivosEmpresa;

// Importar as funções de notificação
const { verificarAssistenciasAtradasTelegram } = require("./notificacoes-telegram");
exports.verificarAssistenciasAtradasTelegram = verificarAssistenciasAtradasTelegram;

// Etapa 12: converte vídeos dos sinistros para MP4 720p depois do envio
exports.converterVideo = require('./converter-video').converterVideo;

// Etapa 21: portal da plataforma (admin do SaaS) — só admin com a marca "plataforma"
exports.plataforma = require('./plataforma').plataforma;

// Etapa 22: catálogo global de seguradoras — corretora consulta CNPJ e sugere seguradora nova
exports.catalogoSeguradoras = require('./catalogo').catalogoSeguradoras;
