// functions/testes/planos.teste.js — Etapa 24: planos-modelo e plano da corretora
// Rodar: cd functions && node testes/planos.teste.js
const F = require('./firebase-falso');
F.instalar();
const { plataforma } = require('../plataforma');
const { store, tokens, chamar } = F;
const t = F.placar();

const conta = (e) => store[`plataforma_contas/${e}`];
const historico = (e) => Object.keys(store).filter((k) => k.startsWith(`plataforma_contas/${e}/historico/`)).map((k) => store[k]);

(async () => {
  store['corretoras/C1'] = { nome: 'Upgrade' };
  store['corretoras/C2'] = { nome: 'Teste' };
  store['corretoras/C3'] = { nome: 'Sem conta' };
  store['plataforma_contas/C1'] = { situacao: 'ativa', plano: { tipo: 'tudo_ligado', nome: 'Tudo ligado' }, cortesia: true };
  store['plataforma_contas/C2'] = { situacao: 'ativa', plano: { tipo: 'tudo_ligado', nome: 'Tudo ligado' }, cortesia: false };
  tokens.tAdm = { uid: 'adm', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };
  tokens.tUsu = 'u1';
  store['users/u1'] = { empresaId: 'C1', role: 'admin' };

  const essencial = {
    acao: 'planoSalvar',
    nome: 'Essencial',
    descricao: 'Para começar',
    modulos: ['tarefas', 'nps', 'videos'],
    precoCentavos: 19900,
    franquias: { usuarios: { incluido: 5, extraCentavos: 4900 }, gb: { incluido: 10, extraCentavos: 500 } },
  };

  // permissões e validação
  t.ok((await chamar(plataforma, essencial, 'tUsu')).code === 403, 'usuário de corretora não cria plano');
  t.ok((await chamar(plataforma, { ...essencial, nome: '' }, 'tAdm')).code === 400, 'sem nome: 400');
  t.ok((await chamar(plataforma, { ...essencial, nome: 'tudo ligado' }, 'tAdm')).code === 400, 'nome reservado: 400');
  t.ok((await chamar(plataforma, { ...essencial, precoCentavos: -1 }, 'tAdm')).code === 400, 'preço negativo: 400');
  t.ok((await chamar(plataforma, { ...essencial, precoCentavos: 19.9 }, 'tAdm')).code === 400, 'preço não inteiro (centavos): 400');
  t.ok((await chamar(plataforma, { ...essencial, franquias: { usuarios: { incluido: -2 } } }, 'tAdm')).code === 400, 'franquia negativa: 400');

  // criar
  const r1 = await chamar(plataforma, essencial, 'tAdm');
  t.ok(r1.code === 200 && r1.body.id, 'cria o plano');
  const id = r1.body.id;
  const p = store[`plataforma_planos/${id}`];
  t.ok(JSON.stringify(p.modulos) === JSON.stringify(['tarefas', 'videos']), 'módulos efetivos (NPS sem Assistências cai)');
  t.ok(p.franquias.usuarios.incluido === 5 && p.franquias.gb_video.incluido === null, 'franquias: as não informadas ficam sem limite');
  t.ok((await chamar(plataforma, { ...essencial, nome: 'ESSENCIAL' }, 'tAdm')).code === 409, 'nome repetido: 409');

  // corretora no plano-modelo
  t.ok((await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C3', tipo: 'modelo', planoId: id }, 'tAdm')).code === 409, 'corretora sem conta: 409');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C2', tipo: 'modelo', planoId: 'xyz' }, 'tAdm')).code === 400, 'plano inexistente: 400');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C2', tipo: 'abc' }, 'tAdm')).code === 400, 'tipo inválido: 400');
  const r2 = await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C2', tipo: 'modelo', planoId: id, cortesia: true, cortesiaAte: '2026-12-31' }, 'tAdm');
  t.ok(r2.code === 200, 'define o plano-modelo');
  t.ok(conta('C2').plano.tipo === 'modelo' && conta('C2').plano.planoId === id && conta('C2').plano.precoCentavos === 19900, 'conta guarda a cópia do plano (nome, preço, franquias)');
  t.ok(JSON.stringify(conta('C2').modulos) === JSON.stringify(['tarefas', 'videos']), 'conta recebe os módulos do plano');
  t.ok(conta('C2').cortesia === true && conta('C2').cortesiaAte.toDate().toISOString().startsWith('2027-01-01T02:59'), 'cortesia com validade (fim do dia, horário de Brasília)');
  t.ok(historico('C2').length === 1 && historico('C2')[0].de.plano.tipo === 'tudo_ligado', 'histórico de → para');

  // lista com uso
  const l = await chamar(plataforma, { acao: 'planos' }, 'tAdm');
  t.ok(l.code === 200 && l.body.planos.length === 1 && l.body.planos[0].corretoras === 1, 'lista de planos com nº de corretoras');

  // editar o modelo regrava a conta
  const r3 = await chamar(plataforma, { ...essencial, id, nome: 'Essencial 2', precoCentavos: 24900, modulos: ['tarefas', 'assistencias', 'nps'] }, 'tAdm');
  t.ok(r3.code === 200 && r3.body.contas === 1, 'editar avisa quantas corretoras foram atualizadas');
  t.ok(conta('C2').plano.nome === 'Essencial 2' && conta('C2').plano.precoCentavos === 24900, 'conta com o nome e o preço novos');
  t.ok(JSON.stringify(conta('C2').modulos) === JSON.stringify(['assistencias', 'nps', 'tarefas']), 'conta com os módulos novos');
  t.ok(historico('C2').some((h) => h.acao === 'plano_atualizado'), 'histórico registra a atualização pelo modelo');
  t.ok(conta('C1').plano.tipo === 'tudo_ligado', 'conta em outro plano não muda');

  // excluir / desativar
  t.ok((await chamar(plataforma, { acao: 'planoExcluir', id }, 'tAdm')).code === 409, 'não exclui plano em uso');
  await chamar(plataforma, { ...essencial, id, nome: 'Essencial 2', ativo: false }, 'tAdm');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C1', tipo: 'modelo', planoId: id }, 'tAdm')).code === 400, 'plano desativado não entra em corretora nova');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C2', tipo: 'modelo', planoId: id }, 'tAdm')).code === 200, '…mas quem já está nele pode continuar');

  // personalizado
  const r4 = await chamar(plataforma, {
    acao: 'contaDefinirPlano', empresaId: 'C2', tipo: 'personalizado', modulos: ['oficinas'], precoCentavos: 15000,
    franquias: { usuarios: { incluido: 3, extraCentavos: 3000 } }, cortesia: false,
  }, 'tAdm');
  t.ok(r4.code === 200 && conta('C2').plano.tipo === 'personalizado' && conta('C2').plano.precoCentavos === 15000, 'personalizado com preço próprio');
  t.ok(conta('C2').cortesia === false && !('cortesiaAte' in conta('C2')), 'tirar a cortesia apaga a validade');
  t.ok((await chamar(plataforma, { acao: 'planoExcluir', id }, 'tAdm')).code === 200 && !store[`plataforma_planos/${id}`], 'sem corretoras, exclui');

  // tudo ligado
  await chamar(plataforma, { acao: 'contaDefinirPlano', empresaId: 'C2', tipo: 'tudo_ligado' }, 'tAdm');
  t.ok(conta('C2').plano.tipo === 'tudo_ligado' && !('modulos' in conta('C2')), 'volta para tudo ligado (apaga a lista)');
  t.ok(conta('C2').cortesia === false, 'sem "cortesia" no pedido, a cortesia não muda');

  const acoes = Object.keys(store).filter((k) => k.startsWith('plataforma_auditoria/')).map((k) => store[k].acao);
  t.ok(['plano_criado', 'plano_editado', 'plano_excluido', 'plano_da_corretora'].every((a) => acoes.includes(a)), 'tudo na auditoria');
  t.fim();
})();
