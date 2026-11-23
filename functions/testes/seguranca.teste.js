// functions/testes/seguranca.teste.js — Etapas 15 e 16
// Testes de functions/seguranca.js com um Firebase falso em memória (não
// acessa o projeto real). Rodar: cd functions && node testes/seguranca.teste.js
const F = require('./firebase-falso');
F.instalar();
const s = require('../seguranca.js');
const { store, tokens, chamar } = F;
const { ok, fim } = F.placar();

(async () => {
  Object.assign(tokens, { 'tok-admin': 'uAdmin', 'tok-user': 'uUser', 'tok-inativo': 'uInativo', 'tok-semdoc': 'uSemDoc', 'tok-sememp': 'uSemEmp' });
  store['users/uAdmin'] = { role: 'admin', email: 'a@x.com', empresaId: 'emp1', username: 'ana', matricula: '77' };
  store['users/uUser'] = { role: 'user', email: 'u@x.com', empresaId: 'emp1' };
  store['users/uInativo'] = { role: 'admin', email: 'i@x.com', ativo: false, empresaId: 'emp1' };
  store['users/uSemEmp'] = { role: 'admin', email: 's@x.com' };

  // usuarioAtivo
  ok((await s.usuarioAtivo({ get: () => 'Bearer tok-admin' }))?.role === 'admin', 'usuarioAtivo: admin');
  ok((await s.usuarioAtivo({ get: () => 'Bearer tok-inativo' })) === null, 'usuarioAtivo: desativado = null');
  ok((await s.usuarioAtivo({ get: () => 'Bearer tok-semdoc' })) === null, 'usuarioAtivo: sem cadastro = null');
  ok((await s.usuarioAtivo({ get: () => undefined })) === null, 'usuarioAtivo: sem token = null');

  // NPS — Etapa 16: dados dentro da corretora, achada pelo nps_indice
  store['nps_indice/C1'] = { empresaId: 'emp1' };
  store['corretoras/emp1/nps_pesquisas/C1'] = { token: 'T1', status: 'enviada', clienteId: 'K1', clienteNome: 'Fulano', numeroSinistro: 'S-1', tipo: 'sinistro' };
  store['corretoras/emp1/clientes/K1'] = { nomeEmpresa: 'Empresa K', logoUrl: 'http://logo', cpf: 'SEGREDO' };
  store['corretoras/emp1/sinistros/C1'] = { status_atual: 'Aberto' };

  let r = await chamar(s.npsPublico, { acao: 'verificar', claimId: 'C1', token: 'errado' });
  ok(r.code === 404, 'NPS: token errado = 404');
  r = await chamar(s.npsPublico, { acao: 'verificar', claimId: 'C1', token: 'T1' });
  ok(r.code === 200 && r.body.clienteEmpresa === 'Empresa K' && !JSON.stringify(r.body).includes('SEGREDO'), 'NPS: verificar devolve só o necessário');
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C1', token: 'T1', nota: 11 });
  ok(r.code === 400, 'NPS: nota 11 recusada');
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C1', token: 'T1', nota: 9, pontosFortes: ['Rapidez'], reclamacoes: 'nada' });
  ok(r.code === 200, 'NPS: responder ok');
  ok(store['corretoras/emp1/avaliacoes/C1'].categoria === 'promotor' && store['corretoras/emp1/nps_pesquisas/C1'].status === 'respondida', 'NPS: grava avaliação DENTRO da corretora e marca respondida');
  ok(store['corretoras/emp1/sinistros/C1'].nps_satisfacao === 9 && store['corretoras/emp1/clientes/K1'].npsScore === 100, 'NPS: atualiza sinistro e NPS do cliente da corretora');
  ok(!store['avaliacoes/C1'], 'NPS: nada gravado na raiz');
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C1', token: 'T1', nota: 3 });
  ok(r.code === 409, 'NPS: não responde duas vezes');
  r = await chamar(s.npsPublico, { acao: 'verificar', claimId: 'C1', token: 'T1' });
  ok(r.body.jaRespondida === true, 'NPS: verificar depois = jaRespondida');
  r = await chamar(s.npsPublico, { acao: 'verificar', claimId: '../users/uAdmin', token: 'T1' });
  ok(r.code === 400, 'NPS: id com barra recusado');

  // NPS sem índice (link antigo, antes da migração) → coleções da raiz
  store['nps_pesquisas/C2'] = { token: 'T2', status: 'enviada', clienteNome: 'Velho', numeroSinistro: 'S-2', tipo: 'assistencia' };
  store['assistencias/C2'] = { status_atual: 'Concluído' };
  r = await chamar(s.npsPublico, { acao: 'responder', claimId: 'C2', token: 'T2', nota: 7 });
  ok(r.code === 200 && store['avaliacoes/C2'].categoria === 'neutro' && store['assistencias/C2'].nps_satisfacao === 7, 'NPS: link antigo sem índice usa a raiz');

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
  r = await chamar(s.criarUsuario, { nome: 'Bia', email: 'b@x.com', role: 'user' }, 'tok-sememp');
  ok(r.code === 400, 'criar: admin sem corretora = 400 (Etapa 16)');
  r = await chamar(s.criarUsuario, { nome: 'Bia', email: 'B@X.com', matricula: '88', role: 'user', telefone: '119' }, 'tok-admin');
  const novo = store[`users/${r.body.uid}`];
  ok(r.code === 200 && novo.email === 'b@x.com' && novo.ativo === true && novo.role === 'user' && novo.empresaId === 'emp1', 'criar: admin cria, herda empresa');
  r = await chamar(s.criarUsuario, { nome: 'Outro', email: 'c@x.com', matricula: '88', role: 'user' }, 'tok-admin');
  ok(r.code === 409, 'criar: matrícula repetida = 409');
  r = await chamar(s.criarUsuario, { nome: 'Bia2', email: 'b@x.com', role: 'user' }, 'tok-admin');
  ok(r.code === 409, 'criar: e-mail repetido = 409');
  r = await chamar(s.criarUsuario, { nome: 'Ze', email: 'z@x.com', role: 'superadmin' }, 'tok-admin');
  ok(store[`users/${r.body.uid}`].role === 'user', 'criar: papel desconhecido vira user');
  fim();
})();
