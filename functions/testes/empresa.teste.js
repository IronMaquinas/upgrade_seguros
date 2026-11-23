// functions/testes/empresa.teste.js — Etapa 16
// Testes de functions/empresa.js (migrarEmpresa) com o Firebase falso.
// Rodar: cd functions && node testes/empresa.teste.js
const F = require('./firebase-falso');
F.instalar();
const { migrarEmpresa, COLECOES } = require('../empresa.js');
const { store, tokens, chamar } = F;
const { ok, fim } = F.placar();

(async () => {
  Object.assign(tokens, { 'tok-admin': 'uAdmin', 'tok-user': 'uUser', 'tok-sememp': 'uSemEmp' });
  store['users/uAdmin'] = { role: 'admin', email: 'a@x.com', empresaId: 'emp1' };
  store['users/uUser'] = { role: 'user', email: 'u@x.com' }; // sem empresa
  store['users/uOutra'] = { role: 'user', email: 'o@x.com', empresaId: 'emp2' };
  store['users/uSemEmp'] = { role: 'admin', email: 's@x.com' };
  store['corretoras/emp1'] = { nome: 'Corretora 1' };
  store['sinistros/S1'] = { numero: 1, status_atual: 'Aberto' };
  store['sinistros/S2'] = { numero: 2, status_atual: 'Concluído' };
  store['assistencias/A1'] = { numero: 3 };
  store['clientes/K1'] = { nome: 'Cliente' };
  store['app_config/config'] = { percentualGatilhoPadrao: 70 };
  store['nps_pesquisas/S1'] = { token: 'T' };

  // permissões
  let r = await chamar(migrarEmpresa, { acao: 'diagnostico' });
  ok(r.code === 401, 'sem login = 401');
  r = await chamar(migrarEmpresa, { acao: 'diagnostico' }, 'tok-user');
  ok(r.code === 403, 'usuário comum = 403');
  r = await chamar(migrarEmpresa, { acao: 'diagnostico' }, 'tok-sememp');
  ok(r.code === 400, 'admin sem empresaId = 400');
  r = await chamar(migrarEmpresa, { acao: 'outra' }, 'tok-admin');
  ok(r.code === 400, 'ação inválida = 400');

  // diagnóstico não muda nada
  const antes = JSON.stringify(store);
  r = await chamar(migrarEmpresa, { acao: 'diagnostico' }, 'tok-admin');
  ok(r.code === 200 && r.body.empresa === 'emp1', 'diagnóstico: empresa do admin');
  ok(r.body.colecoes.sinistros.raiz === 2 && r.body.colecoes.sinistros.naCorretora === 0, 'diagnóstico: conta raiz × corretora');
  ok(r.body.corretoras.includes('emp1') && r.body.usuarios.length === 4, 'diagnóstico: corretoras e usuários');
  ok(r.body.migrada === false, 'diagnóstico: ainda não migrada');
  ok(Object.keys(r.body.colecoes).length === COLECOES.length, 'diagnóstico: todas as coleções');
  ok(JSON.stringify(store) === antes, 'diagnóstico: não grava nada');

  // cópia
  store['corretoras/emp1/sinistros/S2'] = { numero: 2, status_atual: 'Concluído', editadoNaPasta: true }; // já existia
  store['corretoras/emp1/app_config/config'] = { percentualGatilhoPadrao: 50, padrao: true }; // criada pelo app novo antes da cópia
  r = await chamar(migrarEmpresa, { acao: 'copiar' }, 'tok-admin');
  ok(r.code === 200, 'copiar: ok');
  ok(store['corretoras/emp1/sinistros/S1'].numero === 1 && store['corretoras/emp1/assistencias/A1'].numero === 3, 'copiar: copia com o mesmo id');
  ok(store['corretoras/emp1/sinistros/S2'].editadoNaPasta === true, 'copiar: não sobrescreve o que já está na pasta');
  ok(r.body.colecoes.sinistros.copiados === 1 && r.body.colecoes.sinistros.jaExistiam === 1, 'copiar: relatório por coleção');
  ok(store['corretoras/emp1/app_config/config'].percentualGatilhoPadrao === 70 && store['corretoras/emp1/app_config/config']._migradoDaRaiz === true, 'copiar: configuração da raiz vale mais que a padrão criada pelo app novo');
  ok(store['sinistros/S1'] && store['clientes/K1'], 'copiar: raiz continua (cópia de segurança)');
  ok(store['corretoras/emp1'].migradoEtapa16 === true && store['corretoras/emp1'].nome === 'Corretora 1', 'copiar: marca a corretora como migrada (sem apagar o cadastro)');
  ok(store['nps_indice/S1'].empresaId === 'emp1' && r.body.indiceNps === 1, 'copiar: índice do NPS');
  ok(store['users/uUser'].empresaId === 'emp1' && r.body.usuariosLigados.includes('u@x.com'), 'copiar: usuário sem empresa ligado à corretora');
  ok(store['users/uOutra'].empresaId === 'emp2' && r.body.usuariosDeOutraEmpresa.length === 1, 'copiar: usuário de outra empresa só é listado');

  // de novo: idempotente
  store['sinistros/S3'] = { numero: 9 }; // criado pelo app antigo depois da 1ª cópia
  r = await chamar(migrarEmpresa, { acao: 'copiar' }, 'tok-admin');
  ok(r.body.colecoes.sinistros.copiados === 1 && store['corretoras/emp1/sinistros/S3'].numero === 9, 'copiar de novo: só o que faltava');
  ok(r.body.indiceNps === 0 && r.body.usuariosLigados.length === 0, 'copiar de novo: nada repetido');
  store['corretoras/emp1/app_config/config'].percentualGatilhoPadrao = 80; // gestor mudou depois da migração
  r = await chamar(migrarEmpresa, { acao: 'copiar' }, 'tok-admin');
  ok(store['corretoras/emp1/app_config/config'].percentualGatilhoPadrao === 80, 'copiar de novo: não desfaz configuração alterada depois');

  // ── Etapa 16b: apagar a raiz ──
  r = await chamar(migrarEmpresa, { acao: 'apagarRaiz' }, 'tok-admin');
  ok(r.code === 400, 'apagarRaiz: sem a confirmação = 400');
  r = await chamar(migrarEmpresa, { acao: 'apagarRaiz', confirmacao: 'APAGAR' }, 'tok-user');
  ok(r.code === 403, 'apagarRaiz: usuário comum = 403');
  store['corretoras/emp1'].migradoEm = { toDate: () => new Date(Date.now() - 2 * 86400000) };
  await chamar(migrarEmpresa, { acao: 'copiar' }, 'tok-admin');
  ok(store['corretoras/emp1'].migradoEm.toDate, 'copiar de novo: mantém a data da primeira migração');
  r = await chamar(migrarEmpresa, { acao: 'diagnostico' }, 'tok-admin');
  ok(r.body.diasDesdeMigracao === 2 && r.body.podeApagarRaiz === false, 'diagnóstico: 2 dias, ainda não pode apagar');
  r = await chamar(migrarEmpresa, { acao: 'apagarRaiz', confirmacao: 'APAGAR' }, 'tok-admin');
  ok(r.code === 409 && store['sinistros/S1'], 'apagarRaiz: antes de 7 dias = 409 e nada apagado');
  store['corretoras/emp1'].migradoEm = { toDate: () => new Date(Date.now() - 8 * 86400000) };
  store['clientes/K9'] = { nome: 'Só na raiz' }; // sem cópia
  r = await chamar(migrarEmpresa, { acao: 'diagnostico' }, 'tok-admin');
  ok(r.body.podeApagarRaiz === true, 'diagnóstico: 8 dias, pode apagar');
  r = await chamar(migrarEmpresa, { acao: 'apagarRaiz', confirmacao: 'APAGAR' }, 'tok-admin');
  ok(r.code === 200 && !store['sinistros/S1'] && !store['sinistros/S3'] && !store['app_config/config'], 'apagarRaiz: apaga da raiz o que tem cópia');
  ok(store['clientes/K9'] && r.body.colecoes.clientes.semCopia.includes('K9'), 'apagarRaiz: o que NÃO tem cópia fica e é listado');
  ok(store['corretoras/emp1/sinistros/S1'] && store['corretoras/emp1/clientes/K1'], 'apagarRaiz: pasta da corretora intacta');
  ok(store['corretoras/emp1'].nome === 'Corretora 1' && store['corretoras/emp1'].raizApagadaEm, 'apagarRaiz: registra quando apagou');
  ok(store['nps_indice/S1'] && store['users/uUser'], 'apagarRaiz: não mexe em users nem no índice do NPS');
  fim();
})();
