// functions/testes/beta.teste.js — Etapa 28: Beta
// Rodar: cd functions && node testes/beta.teste.js
const F = require('./firebase-falso');
F.instalar();
const { interpretar, bastaSemIa, validarDaIa } = require('../beta-interpretar');
const B = require('../beta');
const { plataforma } = require('../plataforma');
const { store, tokens, chamar } = F;
const t = F.placar();

const SN = 'SN20261110554460';
let chamadasIa = 0;
let respostaIa = null;
B._trocarIa(async () => { chamadasIa++; return { json: respostaIa, entrada: 400, saida: 40 }; });

(async () => {
  // ── intérprete (sem IA) ──
  let p = interpretar(`qual o telefone do segurado do sinistro ${SN}?`);
  t.ok(p.intencao === 'contato' && p.alvo === 'segurado' && p.numero === SN, 'telefone do segurado + número');
  p = interpretar('e o telefone de contato do segurado?', { atendimentoId: 'x', intencao: 'contato' });
  t.ok(p.intencao === 'contato' && p.alvo === 'contato_segurado' && !p.numero, 'continuação: contato do segurado, sem número');
  p = interpretar('e do terceiro?', { atendimentoId: 'x', intencao: 'contato' });
  t.ok(p.intencao === 'contato' && p.alvo === 'terceiro' && bastaSemIa(p, { atendimentoId: 'x' }), '"e do terceiro?" repete a intenção anterior');
  t.ok(interpretar('telefone do motorista do terceiro').alvo === 'motorista_terceiro', 'motorista do terceiro');
  t.ok(interpretar('contato do terceiro').alvo === 'contato_terceiro', 'contato do terceiro');
  p = interpretar(`qual o veículo segurado do sinistro sn ${SN.slice(2)}`);
  t.ok(p.intencao === 'veiculo' && p.numero === SN, 'veículo + número com espaço');
  t.ok(interpretar(`o sinistro ${SN} tem ação pendente?`).intencao === 'pendencias', 'ação pendente');
  p = interpretar('quais os sinistros do cliente Transportes Silva?');
  t.ok(p.intencao === 'sinistros_cliente' && p.cliente === 'transportes silva', 'sinistros do cliente (nome)');
  p = interpretar('de quem é a placa ABC-1D23?');
  t.ok(p.intencao === 'dono_placa' && p.placa === 'ABC1D23', 'dono da placa (Mercosul)');
  t.ok(!bastaSemIa(interpretar('me conta uma piada')), 'fora do escopo precisa da IA');
  // 28.1: o print do Marcony
  p = interpretar('qual o telefone de contato do iury guaru');
  t.ok(p.intencao === 'contato' && p.alvo === 'contato_segurado' && p.cliente === 'iury guaru', '28.1: "telefone de contato do <cliente>" → nome limpo');
  t.ok(interpretar('telefone do contato do cliente iury guaru').cliente === 'iury guaru', '28.1: "do contato do cliente" também');
  t.ok(interpretar('qual o telefone de contato do terceiro').alvo === 'contato_terceiro', '28.1: contato do terceiro continua');
  t.ok(interpretar('e os sinistros dele?', { clienteId: 'x' }).intencao === 'sinistros_cliente' && bastaSemIa(interpretar('e os sinistros dele?', { clienteId: 'x' }), { clienteId: 'x' }), '28.1: "e os sinistros dele?" sem IA');
  // 28.2: o print do Marcony
  p = interpretar('qual o bem segurado que ele tem?', { clienteId: 'x', intencao: 'contato' });
  t.ok(p.intencao === 'veiculo' && p.cliente === null && p.alvo === null, '28.2: "bem segurado que ele tem" = veículo do cliente da conversa');
  t.ok(interpretar('qual a frota dele?', { clienteId: 'x' }).intencao === 'veiculo', '28.2: frota');
  t.ok(interpretar('telefone desse cliente', { clienteId: 'x' }).cliente === null, '28.2: "desse cliente" não vira nome');
  t.ok(validarDaIa({ intencao: 'hackear', alvo: 'x' }).intencao === null && validarDaIa({ intencao: 'contato', numero: 'sn20261110554460' }).numero === SN, 'IA: só aceita o catálogo');

  // ── dados ──
  const E = 'C1';
  store[`corretoras/${E}`] = { nome: 'Upgrade' };
  store[`corretoras/${E}/clientes/cli1`] = { nome: 'Transportes Silva Ltda', contato: 'Maria', contato_telefone: '(27) 99999-1111', email: 'silva@x.com',
    veiculos_segurados: [{ placa: 'ABC1D23', marca: 'Volvo', modelo: 'FH', ano: 2020, anomodelo: 2021 }] };
  store[`corretoras/${E}/clientes/cli2`] = { nome: 'Silva Transportes ME', contato_telefone: '27 3333-2222' };
  store[`corretoras/${E}/sinistros/s1`] = {
    numero_sinistro: SN, id_cliente: 'cli1', client_nome: 'Transportes Silva Ltda', tipo: 'sinistro', status_atual: 'Em análise',
    telefone_cliente: '(27) 98888-0000', nomeContatoSinistro: 'João', telefoneContatoSinistro: '(27) 97777-0000', seguradora: 'Mapfre', numero_seguradora: '123456789',
    veiculo_selecionado: { placa: 'ABC1D23', marca: 'Volvo', modelo: 'FH', nomeCondutorMotorista: 'Pedro' },
    terceiros: [{ nome: 'Carlos', contato: '(27) 96666-0000', placa: 'XYZ9A99', marcaTerceiro: 'Fiat', modeloTerceiro: 'Uno', nomeContatoTerceiro: 'Ana', telefoneContatoTerceiro: '27 95555-0000', motoristaMesmoProprietario: false, nomeMotorista: 'Bruno', telefoneMotorista: '27 94444-0000' }],
  };
  store[`corretoras/${E}/tasks/t1`] = { claimId: 's1', descricao: 'Cobrar orçamento', status: 'Pendente' };
  store[`corretoras/${E}/tasks/t2`] = { claimId: 's1', descricao: 'Ligar', status: 'Concluída' };
  store[`plataforma_contas/${E}`] = { situacao: 'ativa', plano: { tipo: 'tudo_ligado' } };
  tokens.tFunc = 'f1';
  store['users/f1'] = { empresaId: E, role: 'user', ativo: true };
  const per = (mensagem, extra = {}) => chamar(B.beta, { mensagem, ...extra }, 'tFunc');

  // ── conversa ──
  let r = await per(`qual o telefone do segurado do sinistro ${SN}?`);
  t.ok(r.code === 200 && r.body.itens[0].linhas.includes('Telefone: (27) 98888-0000') && r.body.semIa, 'telefone do segurado, sem IA');
  t.ok(r.body.itens[0].acoes.some((a) => a.tipo === 'ligar' && a.valor === '27988880000') && r.body.itens[0].acoes.some((a) => a.tipo === 'whatsapp' && a.valor === '5527988880000'), 'botões ligar e WhatsApp');
  r = await per('e o telefone de contato do segurado?');
  t.ok(r.body.itens[0].linhas.includes('Telefone: (27) 97777-0000'), 'continuação: contato do segurado do mesmo sinistro');
  r = await per('e do terceiro?');
  t.ok(r.body.itens[0].titulo === 'Terceiro' && r.body.itens[0].linhas.includes('Telefone: (27) 96666-0000'), 'continuação: terceiro');
  r = await per('e o motorista do terceiro?');
  t.ok(r.body.itens[0].linhas.includes('Bruno'), 'motorista do terceiro');
  r = await per('qual o veículo segurado?');
  t.ok(r.body.itens[0].linhas.includes('Volvo FH') && r.body.itens[0].linhas.includes('Placa: ABC1D23'), 'veículo segurado do assunto');
  r = await per('tem ação pendente?');
  t.ok(r.body.itens.length === 1 && r.body.itens[0].titulo === 'Cobrar orçamento', 'pendências (só as abertas)');
  r = await per('qual a situação?');
  t.ok(r.body.itens[0].linhas[0] === 'Status: Em análise', 'status');
  t.ok(chamadasIa === 0, 'tudo isso sem chamar a IA');

  // número da seguradora
  r = await per('telefone do segurado do sinistro 123456789');
  t.ok(r.body.itens[0].linhas.includes('Telefone: (27) 98888-0000'), 'acha pelo número da seguradora');

  // cliente ambíguo → escolher
  r = await per('quais os sinistros do cliente silva transportes?');
  t.ok(r.body.acoes.filter((a) => a.tipo === 'escolher').length === 2, 'dois clientes: pede para escolher');
  r = await per('', { escolherClienteId: 'cli1' });
  t.ok(r.body.texto.startsWith('Transportes Silva Ltda: 1 atendimento') && r.body.itens[0].acoes[0].tipo === 'abrir', 'escolheu: lista os sinistros com "abrir"');

  r = await per('qual o telefone de contato do transportes silva ltda', { novaConversa: true });
  t.ok(r.body.itens[0].titulo === 'Contato do segurado' && r.body.itens[0].linhas.includes('Maria'), '28.1: contato do cliente pelo nome');
  r = await per('qual o telefone do transportes silva ltda', { novaConversa: true });
  r = await per('qual o bem segurado que ele tem?');
  t.ok(r.body.itens[0].titulo.startsWith('Veículo 1 de Transportes Silva') && r.body.itens[0].linhas.includes('Placa: ABC1D23'), '28.2: veículos do cliente da conversa');
  r = await per('de quem é a placa ABC-1D23?');
  t.ok(r.body.texto.includes('Transportes Silva Ltda'), 'dono da placa');

  // IA
  respostaIa = { intencao: 'contato', alvo: 'oficina', numero: null };
  r = await per('me passa o fone da funilaria desse sinistro aí', { novaConversa: true });
  t.ok(chamadasIa === 1 && !r.body.semIa, 'pergunta torta vai para a IA');
  t.ok(r.body.foraDoEscopo && /De qual sinistro/.test(r.body.texto), 'conversa nova sem assunto: pede o número');
  respostaIa = { intencao: null };
  r = await per('qual a previsão do tempo?');
  t.ok(r.body.foraDoEscopo, 'fora do escopo');
  const fora = Object.keys(store).filter((k) => k.startsWith('plataforma_beta_perguntas/')).map((k) => store[k]);
  t.ok(fora.some((x) => x.pergunta === 'qual a previsão do tempo?' && x.empresaId === E && x.visto === false), 'pergunta sem resposta guardada para o admin');

  // uso e custo
  const mes = B.mesAtual();
  const u = store[`plataforma_contas/${E}`].beta[mes];
  t.ok(u.comIa === 2 && u.tokensEntrada === 800 && u.tokensSaida === 80 && u.perguntas === 16, 'mede perguntas, IA e tokens');
  t.ok(Math.abs(u.custoUsd - 2 * (400 * 1 + 40 * 5) / 1e6) < 1e-12, 'custo em US$ pelos preços do modelo');

  // teto
  store[`plataforma_contas/${E}`].betaTetoUsd = 0.0001;
  const antes = chamadasIa;
  r = await per('quero saber das coisas');
  t.ok(chamadasIa === antes && /limite de uso/.test(r.body.texto), 'passou do teto: não chama a IA e avisa');
  r = await per(`telefone do segurado do ${SN}`);
  t.ok(r.body.itens[0].linhas.includes('Telefone: (27) 98888-0000'), 'passou do teto: perguntas diretas continuam');

  // módulo
  store[`plataforma_contas/${E}`].plano = { tipo: 'modelo' };
  store[`plataforma_contas/${E}`].modulos = ['tarefas'];
  t.ok((await per('oi')).code === 403, 'sem o módulo Beta no plano: 403');
  t.ok((await chamar(B.beta, { mensagem: 'oi' })).code === 401, 'sem login: 401');

  // portal
  tokens.tAdm = { uid: 'adm', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };
  t.ok((await chamar(plataforma, { acao: 'betaResumo' }, 'tFunc')).code === 403, 'funcionário não vê o resumo');
  const rs = await chamar(plataforma, { acao: 'betaResumo' }, 'tAdm');
  t.ok(rs.code === 200 && rs.body.corretoras[0].nome === 'Upgrade' && rs.body.corretoras[0].comIa === 2 && rs.body.perguntas.length >= 2, 'portal: uso por corretora e perguntas');
  await chamar(plataforma, { acao: 'betaPerguntaVista', id: rs.body.perguntas[0].id }, 'tAdm');
  t.ok(store[`plataforma_beta_perguntas/${rs.body.perguntas[0].id}`].visto === true, 'marcar como vista');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirTetoBeta', empresaId: E, tetoUsd: 10 }, 'tAdm')).code === 200 && store[`plataforma_contas/${E}`].betaTetoUsd === 10, 'teto por corretora');
  t.fim();
})();
