// functions/testes/modulos.teste.js — Etapa 23: módulos por corretora
// Rodar: cd functions && node testes/modulos.teste.js
const F = require('./firebase-falso');
F.instalar();
const mod = require('../modulos');
const { plataforma } = require('../plataforma');
const { store, tokens, chamar } = F;
const t = F.placar();

(async () => {
  // catálogo
  t.ok(mod.ligadosDaConta(null) === null, 'sem conta: tudo ligado');
  t.ok(mod.ligadosDaConta({ plano: { tipo: 'tudo_ligado' } }) === null, 'plano tudo ligado');
  const l = mod.ligadosDaConta({ plano: { tipo: 'personalizado' }, modulos: ['nps', 'tarefas', 'xyz'] });
  t.ok(l.has('tarefas') && !l.has('nps') && !l.has('xyz'), 'personalizado: NPS sem Assistências cai; id desconhecido some');
  t.ok(mod.ligado({ plano: { tipo: 'personalizado' }, modulos: ['assistencias', 'telegram'] }, 'telegram'), 'telegram com assistências: ligado');
  t.ok(!mod.ligado({ plano: { tipo: 'personalizado' }, modulos: [] }, 'telegram'), 'telegram fora: desligado');

  // portal
  store['corretoras/C1'] = { nome: 'Upgrade' };
  store['corretoras/C2'] = { nome: 'Sem conta' };
  store['plataforma_contas/C1'] = { situacao: 'ativa', plano: { tipo: 'tudo_ligado', nome: 'Tudo ligado' }, cortesia: true };
  tokens.tAdm = { uid: 'adm', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };
  tokens.tUsu = 'u1';
  store['users/u1'] = { empresaId: 'C1', role: 'admin' };

  t.ok((await chamar(plataforma, { acao: 'contaDefinirModulos', empresaId: 'C1', tipo: 'personalizado', modulos: [] }, 'tUsu')).code === 403, 'gestor da corretora não muda o próprio plano');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirModulos', empresaId: 'C2', tipo: 'personalizado', modulos: [] }, 'tAdm')).code === 409, 'corretora sem conta: 409');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirModulos', empresaId: 'C1', tipo: 'xyz' }, 'tAdm')).code === 400, 'tipo inválido: 400');

  const r = await chamar(plataforma, { acao: 'contaDefinirModulos', empresaId: 'C1', tipo: 'personalizado', modulos: ['tarefas', 'nps', 'videos'] }, 'tAdm');
  t.ok(r.code === 200 && JSON.stringify(store['plataforma_contas/C1'].modulos) === JSON.stringify(['tarefas', 'videos']), 'grava só os válidos (NPS sem Assistências cai)');
  t.ok(store['plataforma_contas/C1'].plano.tipo === 'personalizado' && store['plataforma_contas/C1'].cortesia === true, 'plano personalizado; o resto da conta fica');
  const hist = Object.keys(store).filter((k) => k.startsWith('plataforma_contas/C1/historico/'));
  t.ok(hist.length === 1 && store[hist[0]].de.plano.tipo === 'tudo_ligado' && store[hist[0]].para.modulos.length === 2, 'histórico com de → para');

  const lista = await chamar(plataforma, { acao: 'corretoras' }, 'tAdm');
  t.ok(lista.body.corretoras.find((c) => c.id === 'C1').conta.modulos.length === 2, 'lista de corretoras mostra os módulos');

  await chamar(plataforma, { acao: 'contaDefinirModulos', empresaId: 'C1', tipo: 'tudo_ligado' }, 'tAdm');
  t.ok(store['plataforma_contas/C1'].plano.tipo === 'tudo_ligado' && !('modulos' in store['plataforma_contas/C1']), 'volta para tudo ligado (apaga a lista)');
  t.ok(Object.keys(store).some((k) => k.startsWith('plataforma_auditoria/') && store[k].acao === 'modulos_definidos'), 'na auditoria');
  t.fim();
})();
