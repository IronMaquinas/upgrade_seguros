// functions/testes/conta.teste.js — Etapa 25: autocadastro, aprovação, situação, pedidos
// Rodar: cd functions && node testes/conta.teste.js
const F = require('./firebase-falso');
F.instalar();
const admin = require('firebase-admin');
const conta = require('../conta');
const { plataforma } = require('../plataforma');
const { criarUsuario } = require('../seguranca');
const { store, tokens, chamar } = F;
const t = F.placar();

const CNPJ = '11.222.333/0001-81'; // válido
const pedidos = () => Object.keys(store).filter((k) => /^plataforma_pedidos\/[^/]+$/.test(k)).map((k) => ({ id: k.split('/')[1], ...store[k] }));

(async () => {
  // situação efetiva
  const ontem = new Date(Date.now() - 86400000);
  const amanha = new Date(Date.now() + 86400000);
  t.ok(conta.situacaoEfetiva(null) === 'ativa', 'sem conta: ativa');
  t.ok(conta.situacaoEfetiva({ situacao: 'teste', testeAte: { toDate: () => ontem } }) === 'teste_encerrado', 'teste vencido = teste encerrado');
  t.ok(conta.situacaoEfetiva({ situacao: 'teste', testeAte: { toDate: () => amanha } }) === 'teste', 'teste no prazo');
  t.ok(!conta.contaGrava({ situacao: 'suspensa' }) && conta.contaGrava({ situacao: 'inadimplente' }), 'suspensa só lê; inadimplente ainda grava');
  const fim = conta.fimDoDia(14, new Date('2026-11-24T15:00:00Z'));
  t.ok(fim.toISOString() === '2026-12-09T02:59:59.000Z', 'fim do teste: 23:59:59 de Brasília do 14º dia');

  // autocadastro (público)
  const base = {
    cnpj: CNPJ, nomeCorretora: 'Corretora Nova', responsavel: 'Ana', email: 'Ana@Nova.com', telefone: '27 99999-0000',
    receita: { razaoSocial: 'CORRETORA NOVA LTDA', nomeFantasia: 'Corretora Nova', situacao: 'ATIVA' }, aceite: true,
  };
  t.ok((await chamar(conta.autocadastro, { ...base, cnpj: '11.111.111/1111-11' })).code === 400, 'CNPJ inválido: 400');
  t.ok((await chamar(conta.autocadastro, { ...base, email: 'x' })).code === 400, 'e-mail inválido: 400');
  t.ok((await chamar(conta.autocadastro, { ...base, aceite: false })).code === 400, 'sem aceite: 400');
  t.ok((await chamar(conta.autocadastro, { ...base, receita: { situacao: 'BAIXADA' } })).code === 400, 'CNPJ baixado na Receita: 400');
  const isca = await chamar(conta.autocadastro, { ...base, site: 'http://spam' });
  t.ok(isca.code === 200 && pedidos().length === 0, 'isca preenchida: responde ok e não grava');

  store['corretoras/UP'] = { nome: 'Upgrade', cnpj: '22.333.444/0001-81' };
  t.ok((await chamar(conta.autocadastro, { ...base, cnpj: '22.333.444/0001-81' })).code === 409, 'CNPJ de corretora que já usa: 409');
  await admin.auth().createUser({ email: 'ja@tem.com' });
  t.ok((await chamar(conta.autocadastro, { ...base, email: 'ja@tem.com' })).code === 409, 'e-mail que já tem login: 409');

  const r1 = await chamar(conta.autocadastro, base);
  t.ok(r1.code === 200 && pedidos().length === 1, 'pedido gravado');
  const p1 = pedidos()[0];
  t.ok(p1.tipo === 'cadastro' && p1.situacao === 'pendente' && p1.cnpj === '11222333000181' && p1.email === 'ana@nova.com', 'pedido pendente, CNPJ só dígitos, e-mail minúsculo');
  t.ok((await chamar(conta.autocadastro, base)).code === 409, 'pedido repetido (mesmo CNPJ): 409');

  // portal
  tokens.tAdm = { uid: 'adm', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };
  tokens.tGestor = 'g1';
  store['users/g1'] = { empresaId: 'UP', role: 'admin', nome: 'Gestor' };
  t.ok((await chamar(plataforma, { acao: 'pedidos' }, 'tGestor')).code === 403, 'gestor de corretora não vê pedidos');
  const lp = await chamar(plataforma, { acao: 'pedidos' }, 'tAdm');
  t.ok(lp.code === 200 && lp.body.pedidos[0].cnpj === CNPJ, 'portal lista pedidos (CNPJ formatado)');

  t.ok((await chamar(plataforma, { acao: 'pedidoAprovar', id: p1.id, diasTeste: 0 }, 'tAdm')).code === 400, 'dias de teste inválidos: 400');
  const ap = await chamar(plataforma, { acao: 'pedidoAprovar', id: p1.id }, 'tAdm');
  t.ok(ap.code === 200 && ap.body.empresaId && ap.body.email === 'ana@nova.com', 'aprova');
  const e = ap.body.empresaId;
  t.ok(store[`corretoras/${e}`].nome === 'Corretora Nova' && store[`corretoras/${e}`].cnpj === CNPJ && store[`corretoras/${e}`].migradoEtapa16 === true, 'corretora criada (já migrada, CNPJ formatado)');
  const uid = Object.keys(store).find((k) => k.startsWith('users/') && store[k].empresaId === e).split('/')[1];
  t.ok(store[`users/${uid}`].role === 'admin' && store[`users/${uid}`].email === 'ana@nova.com', 'responsável vira gestor');
  const c = store[`plataforma_contas/${e}`];
  const dias = (c.testeAte.toDate().getTime() - Date.now()) / 86400000;
  t.ok(c.situacao === 'teste' && dias > 13 && dias < 15.2 && c.plano.tipo === 'tudo_ligado', 'conta em teste por 14 dias, Tudo ligado');
  t.ok(pedidos().find((p) => p.id === p1.id).situacao === 'aprovado', 'pedido aprovado');
  t.ok((await chamar(plataforma, { acao: 'pedidoAprovar', id: p1.id }, 'tAdm')).code === 409, 'aprovar de novo: 409');

  // corretora nova: Meu plano
  tokens.tAna = uid;
  store['plataforma_planos/P1'] = { nome: 'Essencial', ativo: true, modulos: ['tarefas'], precoCentavos: 19900, franquias: {} };
  store['plataforma_planos/P2'] = { nome: 'Antigo', ativo: false, modulos: [], precoCentavos: 9900, franquias: {} };
  const mp = await chamar(conta.minhaConta, { acao: 'planos' }, 'tAna');
  t.ok(mp.code === 200 && mp.body.planos.length === 1 && mp.body.planos[0].nome === 'Essencial' && !('corretoras' in mp.body.planos[0]), 'corretora vê só os planos ativos (sem o nº de corretoras)');
  t.ok((await chamar(conta.minhaConta, { acao: 'planos' })).code === 401, 'sem login: 401');
  t.ok((await chamar(conta.minhaConta, { acao: 'pedirPlano', planoId: 'P2' }, 'tAna')).code === 400, 'plano desativado: 400');
  await chamar(conta.minhaConta, { acao: 'pedirPlano', planoId: 'P1', mensagem: 'quero' }, 'tAna');
  await chamar(conta.minhaConta, { acao: 'pedirPlano', planoId: 'P1', mensagem: 'quero mesmo' }, 'tAna');
  const contr = pedidos().filter((p) => p.tipo === 'contratacao');
  t.ok(contr.length === 1 && contr[0].mensagem === 'quero mesmo' && contr[0].planoNome === 'Essencial' && contr[0].corretora === 'Corretora Nova', 'um pedido de contratação por corretora (o segundo atualiza)');
  t.ok((await chamar(plataforma, { acao: 'pedidoAtendido', id: contr[0].id, nota: 'liguei' }, 'tAdm')).code === 200
    && pedidos().find((p) => p.id === contr[0].id).situacao === 'atendido', 'portal marca como atendido');

  // situação
  t.ok((await chamar(plataforma, { acao: 'contaDefinirSituacao', empresaId: e, situacao: 'xyz' }, 'tAdm')).code === 400, 'situação inválida: 400');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirSituacao', empresaId: e, situacao: 'teste', testeAte: '2020-01-01' }, 'tAdm')).code === 400, 'teste com data passada: 400');
  await chamar(plataforma, { acao: 'contaDefinirSituacao', empresaId: e, situacao: 'suspensa', motivo: 'teste' }, 'tAdm');
  t.ok(store[`plataforma_contas/${e}`].situacao === 'suspensa' && !('testeAte' in store[`plataforma_contas/${e}`]), 'suspensa (apaga a data do teste)');
  const cu = await chamar(criarUsuario, { nome: 'Bia', email: 'bia@nova.com' }, 'tAna');
  t.ok(cu.code === 403, 'conta só leitura: gestor não cria usuário');
  await chamar(plataforma, { acao: 'contaDefinirSituacao', empresaId: e, situacao: 'ativa' }, 'tAdm');
  t.ok((await chamar(criarUsuario, { nome: 'Bia', email: 'bia@nova.com' }, 'tAna')).code === 200, 'ativa: cria usuário de novo');
  const hist = Object.keys(store).filter((k) => k.startsWith(`plataforma_contas/${e}/historico/`)).map((k) => store[k]);
  t.ok(hist.filter((h) => h.acao === 'situacao').length === 2 && hist.some((h) => h.acao === 'conta_criada'), 'histórico da conta');

  const lista = await chamar(plataforma, { acao: 'corretoras' }, 'tAdm');
  t.ok(lista.body.corretoras.find((x) => x.id === e).conta.situacaoEfetiva === 'ativa', 'lista de corretoras traz a situação efetiva');

  // recusar
  await chamar(conta.autocadastro, { ...base, cnpj: '33.444.555/0001-81', email: 'z@z.com' });
  const p2 = pedidos().find((p) => p.email === 'z@z.com');
  if (!p2) {
    t.ok(false, 'segundo pedido gravado');
  } else {
    await chamar(plataforma, { acao: 'pedidoRecusar', id: p2.id, motivo: 'não é corretora' }, 'tAdm');
    t.ok(pedidos().find((p) => p.id === p2.id).situacao === 'recusado', 'recusa com motivo');
  }

  const acoes = Object.keys(store).filter((k) => k.startsWith('plataforma_auditoria/')).map((k) => store[k].acao);
  t.ok(['cadastro_aprovado', 'pedido_atendido', 'situacao_definida'].every((a) => acoes.includes(a)), 'tudo na auditoria');
  t.fim();
})();
