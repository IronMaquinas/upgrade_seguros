// functions/testes/arquivos.teste.js — Etapa 16c
// Testes de functions/arquivos.js (uploadFile, deleteFiles, arquivosEmpresa)
// com o Firebase falso. Rodar: cd functions && node testes/arquivos.teste.js
const F = require('./firebase-falso');
F.instalar();
const A = require('../arquivos.js');
const { converterVideo, ehCaminhoDeVideo } = (() => {
  // converter-video.js carrega ffmpeg-static e o gatilho do Storage: só a função pura interessa aqui.
  const Module = require('module');
  const orig = Module._load;
  Module._load = function (req, ...r) {
    if (req === 'ffmpeg-static') return '/bin/false';
    if (req === 'firebase-functions/v2/storage') return { onObjectFinalized: (_o, fn) => fn };
    if (req === 'firebase-functions') return { logger: { info() {}, error() {} } };
    return orig.call(this, req, ...r);
  };
  return require('../converter-video.js');
})();
const { store, tokens, chamar, objetos, NOME_BUCKET: B } = F;
const { ok, fim } = F.placar();

const antigo = (c) => `https://storage.googleapis.com/${B}/${c}`;
const caminhoDe = (url) => A.lerLink(url).caminho;

(async () => {
  Object.assign(tokens, { 'tok-admin': 'uAdmin', 'tok-user': 'uUser', 'tok-outra': 'uOutra', 'tok-sememp': 'uSem' });
  store['users/uAdmin'] = { role: 'admin', email: 'a@x.com', empresaId: 'emp1' };
  store['users/uUser'] = { role: 'user', email: 'u@x.com', empresaId: 'emp1' };
  store['users/uOutra'] = { role: 'admin', email: 'o@x.com', empresaId: 'emp2' };
  store['users/uSem'] = { role: 'user', email: 's@x.com' };
  store['corretoras/emp1'] = { nome: 'Corretora 1', migradoEtapa16: true, migradoEm: { toMillis: () => Date.now() - 10 * 86400000 } };
  store['corretoras/emp2'] = { nome: 'Corretora 2' };

  // ─── leitura de links ───
  ok(caminhoDe(antigo('sinistros/12/fotos/a b.jpg')) === 'sinistros/12/fotos/a b.jpg', 'lê link antigo (com espaço)');
  const novo = A.linkComToken(B, 'corretoras/emp1/sinistros/SN 1/fotos/a.jpg', 'tk');
  ok(novo.includes('/o/corretoras%2Femp1%2Fsinistros%2FSN%201%2Ffotos%2Fa.jpg?alt=media&token=tk'), 'link novo codifica o caminho');
  ok(caminhoDe(novo) === 'corretoras/emp1/sinistros/SN 1/fotos/a.jpg', 'lê link novo');
  ok(A.lerLink('sinistros/1/a.jpg') === null && A.lerLink('https://exemplo.com/a.jpg') === null, 'texto comum e outro site não são link do Storage');
  ok(A.caminhoNaCorretora('emp1', '/sinistros/1/a.jpg') === 'corretoras/emp1/sinistros/1/a.jpg', 'upload vai para a pasta da corretora');
  ok(A.caminhoNaCorretora('emp1', 'corretoras/emp2/x.jpg') === null, 'upload na pasta de outra corretora = recusado');
  ok(A.caminhoNaCorretora('emp1', 'sinistros/../../x') === null, 'caminho com ".." = recusado');

  // ─── uploadFile ───
  const corpo = { file: Buffer.from('oi').toString('base64'), fileName: 'scaled_a.jpg', filePath: 'sinistros/12/fotos/scaled_a.jpg' };
  let r = await chamar(A.uploadFile, corpo);
  ok(r.code === 401, 'upload sem login = 401');
  r = await chamar(A.uploadFile, corpo, 'tok-sememp');
  ok(r.code === 403, 'upload de usuário sem corretora = 403');
  r = await chamar(A.uploadFile, { ...corpo, filePath: 'corretoras/emp2/sinistros/1/a.jpg' }, 'tok-user');
  ok(r.code === 400 && !objetos['corretoras/emp2/sinistros/1/a.jpg'], 'upload na pasta de outra corretora = 400');
  r = await chamar(A.uploadFile, corpo, 'tok-user');
  const obj = objetos['corretoras/emp1/sinistros/12/fotos/a.jpg'];
  ok(r.code === 200 && !!obj, 'upload grava em corretoras/emp1/…');
  ok(obj && obj.publico === false && obj.contentType === 'image/jpeg', 'arquivo NÃO fica público; tipo pela extensão');
  ok(obj && r.body.url === A.linkComToken(B, 'corretoras/emp1/sinistros/12/fotos/a.jpg', obj.metadata.firebaseStorageDownloadTokens), 'devolve link com o token gravado');

  // ─── deleteFiles ───
  objetos['corretoras/emp1/sinistros/1/x.jpg'] = { tamanho: 1, metadata: {} };
  objetos['corretoras/emp2/sinistros/1/y.jpg'] = { tamanho: 1, metadata: {} };
  objetos['sinistros/1/antigo.jpg'] = { tamanho: 1, metadata: {}, publico: true };
  objetos['backups/2026-11-30/x'] = { tamanho: 1, metadata: {} };
  r = await chamar(A.deleteFiles, { filePaths: ['corretoras/emp1/sinistros/1/x.jpg'] });
  ok(r.code === 401, 'exclusão sem login = 401');
  r = await chamar(A.deleteFiles, {
    filePaths: [
      A.linkComToken(B, 'corretoras/emp1/sinistros/1/x.jpg', 't'),
      'corretoras/emp2/sinistros/1/y.jpg',
      'backups/2026-11-30/x',
      'https://storage.googleapis.com/outro-bucket/sinistros/1/antigo.jpg',
      'nao/existe.jpg',
    ],
  }, 'tok-user');
  ok(r.code === 200 && !objetos['corretoras/emp1/sinistros/1/x.jpg'], 'apaga da própria pasta (pelo link novo)');
  ok(!!objetos['corretoras/emp2/sinistros/1/y.jpg'] && !!objetos['backups/2026-11-30/x'] && !!objetos['sinistros/1/antigo.jpg'], 'não apaga de outra corretora, do backup nem de outro bucket');
  ok(r.body.recusados.length === 4, 'relata os recusados');
  r = await chamar(A.deleteFiles, { filePaths: ['sinistros/1/antigo.jpg'] }, 'tok-outra');
  ok(!!objetos['sinistros/1/antigo.jpg'], 'pasta antiga: corretora que NÃO recebeu os dados antigos não apaga');
  r = await chamar(A.deleteFiles, { filePaths: [antigo('sinistros/1/antigo.jpg'), 'sinistros/1/ja-apagado.jpg'] }, 'tok-user');
  ok(r.code === 200 && !objetos['sinistros/1/antigo.jpg'], 'pasta antiga: a corretora migrada apaga (e ignora o que já não existe)');

  // ─── arquivosEmpresa: permissões ───
  r = await chamar(A.arquivosEmpresa, { acao: 'diagnostico' }, 'tok-user');
  ok(r.code === 403, 'conversão: usuário comum = 403');
  r = await chamar(A.arquivosEmpresa, { acao: 'diagnostico' }, 'tok-outra');
  ok(r.code === 409, 'conversão: corretora sem migração = 409');

  // ─── conversão ───
  const fotoA = 'sinistros/SN1/fotos/a.jpg';
  const fotoB = 'sinistros/SN1/fotos/b.jpg';
  const laudo = 'clientes/K1/apolices/P1/bens/B1/documentos/laudo.pdf';
  const video = 'videos/sinistros/SN1/1700_v.mp4';
  for (const c of [fotoA, fotoB, laudo]) objetos[c] = { tamanho: 10, metadata: {}, publico: true };
  objetos[video] = { tamanho: 99, metadata: { firebaseStorageDownloadTokens: 'tokvideo', convertido: 'sim' } };
  objetos['sinistros/ORFAO/fotos/z.jpg'] = { tamanho: 5, metadata: {}, publico: true };
  const dataAbertura = { toMillis: () => 123, _tipo: 'Timestamp' };
  Object.setPrototypeOf(dataAbertura, { constructor: function Timestamp() {} });
  store['corretoras/emp1/sinistros/S1'] = {
    numero: 'SN1',
    data_abertura: dataAbertura,
    fotos_urls: [antigo(fotoA), antigo(fotoB)],
    videos: [{ url: A.linkComToken(B, video, 'tokvideo'), caminho: video, nome: 'v.mp4' }],
    terceiros: [{ fotos_urls: [antigo('sinistros/SN1/fotos/sumiu.jpg')] }],
    observacao: 'videos/sinistros/SN1/1700_v.mp4 é só um texto citado',
  };
  store['corretoras/emp1/clientes/K1'] = {
    apolices: [{ bens: [{ documentos_urls: [antigo(laudo)] }] }],
    logo: 'https://storage.googleapis.com/outro-bucket/logo.png',
  };
  store['corretoras/emp1/assistencias/A1'] = { arquivos_laudos_urls: [antigo(fotoA)] }; // mesmo arquivo em 2 documentos
  store['corretoras/emp1/sinistros/S2'] = { fotos_urls: [A.linkComToken(B, 'corretoras/emp1/sinistros/SN2/a.jpg', 't')] };

  const antes = JSON.stringify(store);
  r = await chamar(A.arquivosEmpresa, { acao: 'diagnostico' }, 'tok-admin');
  ok(JSON.stringify(store) === antes, 'diagnóstico não muda nada');
  ok(r.code === 200 && r.body.arquivosParaPassar === 5, 'diagnóstico: 5 arquivos antigos citados (4 existem + 1 sumido)');
  ok(r.body.documentosComLinkAntigo === 3 && r.body.arquivosJaNaPasta === 1 && r.body.linksDeOutroBucket === 1, 'diagnóstico: documentos, já na pasta, outro bucket');
  ok(r.body.arquivosPorPasta.sinistros === 3 && r.body.arquivosPorPasta.videos === 1 && r.body.arquivosPorPasta.clientes === 1, 'diagnóstico: por pasta');

  r = await chamar(A.arquivosEmpresa, { acao: 'converter' }, 'tok-admin');
  ok(r.code === 200 && r.body.copiados === 4 && r.body.terminou === true, 'converter: copia os 4 e termina');
  ok(r.body.semOriginal.length === 1 && r.body.semOriginal[0] === 'sinistros/SN1/fotos/sumiu.jpg', 'converter: relata o arquivo que não existe mais');
  const s1 = store['corretoras/emp1/sinistros/S1'];
  ok(s1.fotos_urls.every((u) => caminhoDe(u).startsWith('corretoras/emp1/sinistros/SN1/fotos/') && u.includes('token=')), 'sinistro: fotos com link novo, na pasta');
  ok(objetos['corretoras/emp1/' + fotoA].publico === false && !!objetos[fotoA], 'cópia não é pública; original continua lá');
  ok(s1.videos[0].caminho === 'corretoras/emp1/' + video && s1.videos[0].url.includes('token=tokvideo'), 'vídeo: caminho e link trocados (mesmo token)');
  ok(objetos['corretoras/emp1/' + video].metadata.convertido === 'sim', 'vídeo copiado continua marcado como convertido');
  ok(s1.terceiros[0].fotos_urls[0] === antigo('sinistros/SN1/fotos/sumiu.jpg'), 'link de arquivo sumido fica como estava');
  ok(s1.observacao.startsWith('videos/'), 'texto que só menciona um caminho fica como estava');
  ok(s1.data_abertura === dataAbertura, 'datas e outros tipos do Firestore ficam intactos');
  ok(caminhoDe(store['corretoras/emp1/clientes/K1'].apolices[0].bens[0].documentos_urls[0]) === 'corretoras/emp1/' + laudo, 'cliente: documento dentro de apólice/bem trocado');
  ok(store['corretoras/emp1/clientes/K1'].logo.includes('outro-bucket'), 'link de outro bucket fica como estava');
  ok(store['corretoras/emp1/assistencias/A1'].arquivos_laudos_urls[0] === s1.fotos_urls[0], 'mesmo arquivo em 2 documentos → mesmo link novo');
  ok(store['corretoras/emp1'].arquivosSemOriginal.length === 1 && !!store['corretoras/emp1'].arquivosConvertidosEm, 'cadastro: sem original e data da conversão');

  r = await chamar(A.arquivosEmpresa, { acao: 'converter' }, 'tok-admin');
  ok(r.body.copiados === 0 && r.body.documentosAtualizados === 0 && r.body.terminou, 'converter de novo: nada a fazer (não repete)');
  r = await chamar(A.arquivosEmpresa, { acao: 'diagnostico' }, 'tok-admin');
  ok(r.body.arquivosParaPassar === 0 && r.body.arquivosSemOriginal === 1, 'diagnóstico depois: 0 para passar');

  // ─── apagar originais ───
  r = await chamar(A.arquivosEmpresa, { acao: 'apagarOriginais', confirmacao: 'APAGAR' }, 'tok-admin');
  ok(r.code === 409, 'apagar originais antes do prazo = 409');
  r = await chamar(A.arquivosEmpresa, { acao: 'apagarOriginais' }, 'tok-admin');
  ok(r.code === 400, 'apagar originais sem confirmação = 400');
  store['corretoras/emp1'].arquivosConvertidosEm = { toMillis: () => Date.now() - 8 * 86400000 };
  const outroCorretora = 'corretoras/emp2/sinistros/1/y.jpg';
  let cursor = null;
  let total = { apagados: 0, semCopia: 0 };
  let voltas = 0;
  do {
    r = await chamar(A.arquivosEmpresa, { acao: 'apagarOriginais', confirmacao: 'APAGAR', cursor }, 'tok-admin');
    if (r.code !== 200) break;
    total.apagados += r.body.apagados;
    total.semCopia += r.body.semCopia;
    cursor = r.body.cursor;
    voltas++;
  } while (!r.body.terminou && voltas < 20);
  ok(r.code === 200 && r.body.terminou, 'apagar originais: termina');
  ok(!objetos[fotoA] && !objetos[fotoB] && !objetos[laudo] && !objetos[video], 'originais com cópia apagados');
  ok(!!objetos['sinistros/ORFAO/fotos/z.jpg'] && total.semCopia === 1, 'arquivo antigo sem cópia fica e é contado');
  ok(!!objetos['corretoras/emp1/' + fotoA] && !!objetos[outroCorretora] && !!objetos['backups/2026-11-30/x'], 'cópias, outra corretora e backup intactos');

  // ─── conversão em partes (mais arquivos do que um lote) ───
  for (let i = 0; i < 130; i++) {
    const c = `sinistros/L${i}/fotos/f.jpg`;
    objetos[c] = { tamanho: 1, metadata: {} };
    store[`corretoras/emp1/tasks/T${i}`] = { anexos: [antigo(c)] };
  }
  r = await chamar(A.arquivosEmpresa, { acao: 'converter' }, 'tok-admin');
  ok(r.body.copiados === 100 && r.body.restantes === 30 && !r.body.terminou, 'lote: 100 por chamada, sobram 30');
  r = await chamar(A.arquivosEmpresa, { acao: 'converter' }, 'tok-admin');
  ok(r.body.copiados === 30 && r.body.terminou, 'lote: segunda chamada termina');

  // ─── vídeo: conversão automática reconhece a pasta nova ───
  ok(ehCaminhoDeVideo('corretoras/emp1/videos/sinistros/1/a.mp4') && ehCaminhoDeVideo('videos/sinistros/1/a.mp4'), 'converterVideo: pasta nova e antiga');
  ok(!ehCaminhoDeVideo('corretoras/emp1/sinistros/1/videos/a.mp4') && !ehCaminhoDeVideo('xvideos/a.mp4'), 'converterVideo: ignora outras pastas');
  ok(typeof converterVideo === 'function', 'converterVideo carrega');

  fim();
})();
