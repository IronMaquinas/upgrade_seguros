// functions/testes/uso.teste.js — Etapa 27: uso de cada corretora
// Rodar: cd functions && node testes/uso.teste.js
const F = require('./firebase-falso');
F.instalar();
const uso = require('../uso');
const { plataforma } = require('../plataforma');
const { store, tokens, chamar, objetos } = F;
const t = F.placar();

const arquivo = (nome, bytes) => { objetos[nome] = { tamanho: bytes, metadata: {} }; };

(async () => {
  store['corretoras/A'] = { nome: 'A' };
  store['corretoras/B'] = { nome: 'B' };
  store['corretoras/AB'] = { nome: 'AB (prefixo parecido)' };
  store['plataforma_contas/A'] = { situacao: 'ativa', plano: { tipo: 'tudo_ligado' } };
  store['plataforma_contas/AB'] = { situacao: 'ativa', plano: { tipo: 'tudo_ligado' } };
  store['users/u1'] = { empresaId: 'A' };
  store['users/u2'] = { empresaId: 'A', ativo: false };
  store['users/u3'] = { empresaId: 'B' };

  arquivo('corretoras/A/sinistros/1/foto.jpg', 1000);
  arquivo('corretoras/A/clientes/9/doc.pdf', 500);
  arquivo('corretoras/A/videos/1/v.mp4', 3000);
  arquivo('corretoras/A/videos/1/v2.mp4', 2000);
  arquivo('corretoras/A/vazia/', 0);
  arquivo('corretoras/AB/sinistros/x.jpg', 7777); // não pode somar na A
  arquivo('sinistros/antigo.jpg', 99999); // pasta antiga da raiz: fora

  const a = await uso.medirCorretora('A');
  t.ok(a.bytesArquivos === 1500 && a.arquivos === 2, 'arquivos sem os vídeos (e sem "pasta" vazia)');
  t.ok(a.bytesVideos === 5000 && a.videos === 2, 'vídeos à parte');
  t.ok(a.usuarios === 2, 'usuários da corretora (ativos e desativados)');
  t.ok(store['plataforma_contas/A'].uso.bytesVideos === 5000 && store['plataforma_contas/A'].situacao === 'ativa', 'grava na conta sem mexer no resto');

  const b = await uso.medirCorretora('B');
  t.ok(b.bytesArquivos === 0 && b.usuarios === 1 && !store['plataforma_contas/B'], 'corretora sem conta: mede, mas não cria conta');

  // várias páginas
  for (let i = 0; i < 2500; i++) arquivo(`corretoras/AB/lote/${String(i).padStart(5, '0')}.jpg`, 10);
  const ab = await uso.medirCorretora('AB');
  t.ok(ab.arquivos === 2501 && ab.bytesArquivos === 7777 + 25000, 'soma todas as páginas da listagem');

  // portal
  tokens.tAdm = { uid: 'adm', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };
  tokens.tUsu = 'u1';
  t.ok((await chamar(plataforma, { acao: 'medirUso' }, 'tUsu')).code === 403, 'usuário de corretora não mede');
  const r = await chamar(plataforma, { acao: 'medirUso' }, 'tAdm');
  t.ok(r.code === 200 && r.body.medidas.length === 3, 'portal mede todas');
  const r1 = await chamar(plataforma, { acao: 'medirUso', empresaId: 'A' }, 'tAdm');
  t.ok(r1.body.medidas.length === 1 && r1.body.medidas[0].empresaId === 'A', 'ou só uma');
  const lista = await chamar(plataforma, { acao: 'corretoras' }, 'tAdm');
  const ca = lista.body.corretoras.find((c) => c.id === 'A');
  t.ok(ca.conta.uso.bytesArquivos === 1500 && ca.conta.uso.usuarios === 2, 'lista de corretoras traz o uso');
  t.ok(Object.keys(store).some((k) => k.startsWith('plataforma_auditoria/') && store[k].acao === 'uso_medido'), 'na auditoria');

  // rotina diária
  await uso.medirUsoDiario();
  t.ok(store['plataforma_contas/AB'].uso.arquivos === 2501, 'rotina diária mede todas');
  t.fim();
})();
