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
  // 28.6: singular e "em andamento"
  p = interpretar('qual sinistro da fibra minas?');
  t.ok(p.intencao === 'sinistros_cliente' && p.cliente === 'fibra minas' && p.filtro.so === 'sinistros' && bastaSemIa(p), '28.6: "qual sinistro da X" sem IA');
  p = interpretar('o cliente Sem Fronteiras possui assistência em andamento?', { atendimentoId: 'x', intencao: 'contato' });
  t.ok(p.intencao === 'sinistros_cliente' && p.cliente === 'sem fronteiras' && p.filtro.so === 'assistencias' && p.filtro.emCurso, '28.6: "possui assistência em andamento" com outro assunto');
  t.ok(interpretar(`o sinistro ${SN} tem ação pendente?`).intencao === 'pendencias' && interpretar('qual o status desse sinistro?', { atendimentoId: 'x' }).intencao === 'status', '28.6: pendência e status continuam');
  // 28.2: o print do Marcony
  p = interpretar('qual o bem segurado que ele tem?', { clienteId: 'x', intencao: 'contato' });
  t.ok(p.intencao === 'veiculo' && p.cliente === null && p.alvo === null, '28.2: "bem segurado que ele tem" = veículo do cliente da conversa');
  t.ok(interpretar('qual a frota dele?', { clienteId: 'x' }).intencao === 'veiculo', '28.2: frota');
  // 28.4
  p = interpretar('quais os bens e apólices Iury Guaru possui?');
  t.ok(p.intencao === 'apolices' && p.cliente === 'iury guaru' && p.detalhe === 'bens', '28.4: "bens e apólices <cliente> possui"');
  p = interpretar('O Iury Guaru tem bens segurados?');
  t.ok(p.intencao === 'veiculo' && p.cliente === 'iury guaru', '28.4: "<cliente> tem bens segurados?"');
  t.ok(interpretar('qual o total de gastos da apólice do Iury Guaru?').detalhe === 'gastos', '28.4: gastos da apólice');
  t.ok(interpretar('Iury Guaru tem apólice').cliente === 'iury guaru', '28.4: "<cliente> tem apólice"');
  // 28.3
  p = interpretar('quais os bens segurados do Iury Guaru?');
  t.ok(p.intencao === 'veiculo' && p.cliente === 'iury guaru', '28.3: "bens segurados do <cliente>"');
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
  t.ok(r.body.itens[0].titulo === 'Proprietário do veículo do terceiro' && r.body.itens[0].linhas.includes('Telefone: (27) 96666-0000'), 'continuação: terceiro');
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
  // 28.3: a Beta pergunta "de qual cliente?" e a resposta vem só com o nome
  r = await per('qual o veículo?', { novaConversa: true });
  t.ok(/De qual sinistro/.test(r.body.texto), '28.3: sem assunto, pergunta de qual');
  r = await per('Transportes Silva Ltda');
  t.ok(r.body.itens[0] && r.body.itens[0].linhas.includes('Placa: ABC1D23'), '28.3: resposta só com o nome completa o pedido');
  r = await per('quais os bens segurados do transportes silva ltda?', { novaConversa: true });
  t.ok(r.body.itens[0] && r.body.itens[0].linhas.includes('Volvo FH'), '28.3: bens segurados do cliente');
  // 28.4: apólices e bens no cadastro (dois ramos, duas apólices de frota)
  const ts = (d) => ({ toDate: () => new Date(d) });
  store[`corretoras/${E}/clientes/cli3`] = { nome: 'IURY GUARU TRANSPORTES LTDA', contato_telefone: '(79) 9903-5735', apolices: [
    { id: 'ap1', ramo: 'Frota', numero_apolice: '950001854', seguradora: 'SURA', data_inicio: ts('2025-09-24T03:00:00Z'), data_fim: ts('2026-09-24T03:00:00Z'), valor_apolice: 149920.28, valor_gatilho: 0,
      bens_segurados: [{ tipo: 'Caminhão', marca: 'Scania', modelo: 'R450', placa: 'QWE1R23' }, { tipo: 'Carreta', placa_carreta: 'ZZZ9Z99', descricao: 'Carreta graneleira' }] },
    { id: 'ap2', ramo: 'Frota', numero_apolice: '950009999', seguradora: 'SURA', data_inicio: ts('2026-09-24T03:00:00Z'), data_fim: ts('2027-09-24T03:00:00Z'), valor_apolice: 100000, valor_gatilho: 50000, bens_segurados: [] },
    { id: 'ap3', ramo: 'Residencial', numero_apolice: 'R-77', seguradora: 'Porto', data_inicio: ts('2026-01-10T03:00:00Z'), data_fim: ts('2027-01-10T03:00:00Z'), valor_apolice: 1200,
      bens_segurados: [{ tipo: 'Residência', logradouro: 'Rua A', numero: '10', cidade: 'Aracaju', estado: 'SE' }] },
  ] };
  store[`corretoras/${E}/sinistros/s9`] = { numero_sinistro: 'SN20260301000000', id_cliente: 'cli3', tipo: 'sinistro', ramo_sinistro: 'Frota', status_atual: 'Em análise', data_ocorrencia: ts('2026-03-01T15:00:00Z'), valor_total_sinistro: 20000 };
  store[`corretoras/${E}/sinistros/s10`] = { numero_sinistro: 'SN20260302000000', id_cliente: 'cli3', tipo: 'sinistro', ramo_sinistro: 'Frota', status_atual: 'Negado', data_ocorrencia: ts('2026-03-02T15:00:00Z'), valor_total_sinistro: 99999 };
  store[`corretoras/${E}/app_config/config`] = { percentualGatilhoPadrao: 70 };
  r = await per('O Iury Guaru tem bens segurados?', { novaConversa: true });
  t.ok(r.body.itens.length === 3 && r.body.itens[0].titulo === 'Bem 1 — Frota • 950001854' && r.body.itens[0].linhas.includes('Placa: QWE1R23'), '28.4: bens vêm das apólices (todos os ramos)');
  t.ok(r.body.itens.some((i) => i.titulo.includes('Residencial') && i.linhas.some((l) => l.includes('Aracaju'))), '28.4: bem residencial com endereço');
  r = await per('quais os bens e apólices Iury Guaru possui?', { novaConversa: true });
  t.ok(r.body.texto.includes('3 apólice(s)') && r.body.itens.some((i) => i.linhas.some((l) => l.startsWith('Bem 1: Tipo: Caminhão'))), '28.4: apólices com os bens');
  r = await per('quando vence a apólice do Iury Guaru?', { novaConversa: true });
  t.ok(r.body.itens.some((i) => i.titulo === 'Frota • 950001854' && i.linhas.some((l) => l.startsWith('Vigência: 24/09/2025 até 24/09/2026'))), '28.4: vigência/vencimento');
  r = await per('qual o total de gastos da apólice do Iury Guaru?', { novaConversa: true });
  const a1 = r.body.itens.find((i) => i.titulo === 'Frota • 950001854');
  t.ok(a1.linhas.includes('Gasto com sinistros na vigência: R$ 20.000,00 (1 sinistro(s))') && a1.linhas.some((l) => l.startsWith('Gatilho: R$ 104.944,20 — 19% usado')), '28.4: gasto × gatilho (negado não conta; 70% do valor)');
  store[`corretoras/${E}/clientes/cli4`] = { nome: 'MAIS ALIMENTOS LTDA', apolices: [{ id: 'm1', ramo: 'Frota', numero_apolice: '31.69.2026.0488237', seguradora: 'LIBERTY', data_inicio: ts('2026-04-19T03:00:00Z'), data_fim: ts('2027-04-19T03:00:00Z'), valor_apolice: 59611.01, bens_segurados: [] }] };
  r = await per('quais os bens segurados da mais alimentos?', { novaConversa: true });
  t.ok(!r.body.foraDoEscopo && r.body.texto === 'MAIS ALIMENTOS LTDA tem 1 apólice(s), mas nenhum bem cadastrado nelas.' && r.body.itens[0].titulo === 'Frota • 31.69.2026.0488237', '28.5: apólice sem bens: diz isso (não é "sem resposta")');
  // 28.6: prints do Marcony — sinistro/assistência no singular, e "em andamento" com outro assunto na conversa
  store[`corretoras/${E}/clientes/cli5`] = { nome: 'SEM FRONTEIRAS' };
  store[`corretoras/${E}/assistencias/a1`] = { numero_sinistro: 'AS20261022102913', id_cliente: 'cli5', tipo: 'assistencia', status_atual: 'Aberto' };
  store[`corretoras/${E}/assistencias/a2`] = { numero_sinistro: 'AS20260101000000', id_cliente: 'cli5', tipo: 'assistencia', status_atual: 'Concluído' };
  store[`corretoras/${E}/sinistros/s11`] = { numero_sinistro: 'SN20260505000000', id_cliente: 'cli5', tipo: 'sinistro', status_atual: 'Em análise' };
  r = await per('qual sinistro da transportes silva ltda?', { novaConversa: true });
  t.ok(!r.body.foraDoEscopo && r.body.itens.length === 1 && r.body.itens[0].titulo === `Sinistro ${SN}`, '28.6: "qual sinistro da <cliente>?"');
  r = await per('qual a assistência da Sem Fronteiras?', { novaConversa: true });
  t.ok(!r.body.foraDoEscopo && r.body.itens.length === 2 && r.body.itens.every((i) => i.titulo.startsWith('Assistência')), '28.6: "qual a assistência da <cliente>?" — só assistências');
  r = await per(`quem é o contato do sinistro ${SN}?`, { novaConversa: true });
  r = await per('o cliente Sem Fronteiras possui assistência em andamento?');
  t.ok(r.body.texto === 'SEM FRONTEIRAS: 1 assistência(s) em andamento.' && r.body.itens[0].titulo === 'Assistência AS20261022102913', '28.6: cliente citado vence o sinistro da conversa; só em andamento');
  r = await per('a Transportes Silva Ltda tem assistência em andamento?', { novaConversa: true });
  t.ok(r.body.texto === 'Transportes Silva Ltda não tem nenhuma assistência em andamento.', '28.6: nenhuma em andamento');
  // 28.6 (2º print): assistência antiga ligada ao cliente só pelo nome/CNPJ (id_cliente diferente)
  store[`corretoras/${E}/clientes/cli6`] = { id: '', nome: 'PLUMA REAL', cnpj_cpf: '11.222.333/0001-44', contato: 'JOSE', contato_telefone: '(27) 99747-0688', apolices: [{ id: 'pr1', ramo: 'Frota', numero_apolice: '0531 13 9133962', seguradora: 'PORTO SEGURO', data_inicio: ts('2026-11-04T03:00:00Z'), data_fim: ts('2027-11-04T03:00:00Z'), valor_apolice: 410952.98 }] }; // o app grava id: '' dentro do cliente
  store[`corretoras/${E}/assistencias/a3`] = { numero_sinistro: 'AS20261008122926', id_cliente: 'idAntigo', client_nome: 'PLUMA REAL', client_cnpj_cpf: '11.222.333/0001-44', tipo: 'assistencia', status_atual: 'Aberto' };
  r = await per('pluma real possui assistência am andamento?', { novaConversa: true });
  t.ok(r.body.texto === 'PLUMA REAL: 1 assistência(s) em andamento.' && r.body.itens[0].titulo === 'Assistência AS20261008122926', '28.6: acha assistência pelo CNPJ/nome quando o id_cliente é antigo');
  // 28.7: conversa do print — o "id" vazio gravado no cliente não pode apagar o assunto
  r = await per('qual o telefone de contato da pluma real?');
  t.ok(r.body.itens[0].linhas.includes('JOSE'), '28.7: contato do cliente');
  r = await per('e possui apólice vigente?');
  t.ok(r.body.texto === 'PLUMA REAL: 1 apólice(s), 1 vigente(s).', '28.7: continua com o cliente (id do documento, não o "id" vazio gravado nele)');
  r = await per('Sem fronteiras está com assistência em andamento?', { novaConversa: true });
  t.ok(r.body.texto === 'SEM FRONTEIRAS: 1 assistência(s) em andamento.', '28.6: "está com assistência em andamento"');
  r = await per('qual a situação?', { novaConversa: true });
  r = await per('sem fronteiras');
  t.ok(!r.body.foraDoEscopo && /SEM FRONTEIRAS: \d+ atendimento\(s\) em andamento\./.test(r.body.texto), '28.6: status + resposta com nome do cliente → atendimentos em andamento');
  // 28.9: as 3 pessoas de cada lado do sinistro (print da Lube)
  store[`corretoras/${E}/clientes/cli7`] = { id: '', nome: 'LUBE DISTRIBUIDORA LTDA', cnpj_cpf: '11.111.111/0001-11' };
  store[`corretoras/${E}/sinistros/s20`] = { numero_sinistro: 'SN20261124180447', id_cliente: 'cli7', client_nome: 'LUBE DISTRIBUIDORA LTDA', tipo: 'sinistro', status_atual: 'Aberto',
    veiculo_selecionado: { placa: 'SFP9B84', nomeCondutor: 'L LOG TRANSPORTES E SERVICOS LTDA.', cpfCondutor: '29.380.230/0001-05', nomeCondutorMotorista: 'RAPHAEL RIBEIRO ERPES', cpfCondutorMotorista: '139.118.277-41', cnhCondutorMotorista: '05906467495' },
    terceiros: [] };
  r = await per('qual o nome do condutor do SN20261124180447?', { novaConversa: true });
  t.ok(r.body.itens.length === 1 && r.body.itens[0].titulo === 'Condutor do veículo (segurado)' && r.body.itens[0].linhas[0] === 'RAPHAEL RIBEIRO ERPES' && r.body.itens[0].linhas.includes('CNH: 05906467495'), '28.9: condutor do segurado (o print)');
  r = await per('e o proprietário do veículo?');
  t.ok(r.body.itens[0].linhas[0] === 'L LOG TRANSPORTES E SERVICOS LTDA.' && r.body.itens[0].linhas.includes('CPF/CNPJ: 29.380.230/0001-05'), '28.9: proprietário (CRLV)');
  r = await per('qual o contato para o sinistro?');
  t.ok(r.body.itens[0].linhas[0] === 'Não há essa informação neste sinistro.', '28.9: contato do sinistro não informado');
  r = await per('e o condutor do veículo do terceiro?');
  t.ok(r.body.itens[0].linhas[0] === 'Não houve terceiros neste sinistro.', '28.9: sem terceiros');
  r = await per(`quem é o proprietário do veículo do terceiro no ${SN}?`, { novaConversa: true });
  t.ok(r.body.itens[0].titulo === 'Proprietário do veículo do terceiro' && r.body.itens[0].linhas[0] === 'Carlos', '28.9: proprietário do terceiro');
  r = await per('dados de contato do condutor do veículo do terceiro');
  t.ok(r.body.itens[0].linhas[0] === 'Bruno' && r.body.itens[0].linhas.includes('Telefone: 27 94444-0000'), '28.9: condutor do terceiro');
  r = await per('contato para o sinistro do terceiro');
  t.ok(r.body.itens[0].linhas[0] === 'Ana', '28.9: contato do sinistro do terceiro');
  r = await per('quando vence a apólice do Iury Guaru?', { novaConversa: true });
  r = await per('e ele tem apólice vigente?');
  t.ok(r.body.texto.includes('vigente'), '28.4: continua com o cliente da conversa');
  r = await per('de quem é a placa ABC-1D23?');
  t.ok(r.body.texto.includes('Transportes Silva Ltda'), 'dono da placa');

  // IA
  respostaIa = { intencao: 'contato', alvo: 'oficina', numero: null };
  const iaAntes = chamadasIa;
  r = await per('me passa o fone da funilaria desse sinistro aí', { novaConversa: true });
  t.ok(chamadasIa === iaAntes + 1 && !r.body.semIa, 'pergunta torta vai para a IA');
  t.ok(r.body.foraDoEscopo && /De qual sinistro/.test(r.body.texto), 'conversa nova sem assunto: pede o número');
  respostaIa = { intencao: null };
  r = await per('qual a previsão do tempo?');
  t.ok(r.body.foraDoEscopo, 'fora do escopo');
  const fora = Object.keys(store).filter((k) => k.startsWith('plataforma_beta_perguntas/')).map((k) => store[k]);
  t.ok(fora.some((x) => x.pergunta === 'qual a previsão do tempo?' && x.empresaId === E && x.visto === false), 'pergunta sem resposta guardada para o admin');

  // uso e custo
  const mes = B.mesAtual();
  const u = store[`plataforma_contas/${E}`].beta[mes];
  t.ok(u.comIa === 4 && u.tokensEntrada === 1600 && u.tokensSaida === 160 && u.perguntas === 44, 'mede perguntas, IA e tokens');
  t.ok(Math.abs(u.custoUsd - 4 * (400 * 1 + 40 * 5) / 1e6) < 1e-12, 'custo em US$ pelos preços do modelo');

  // teto
  store[`plataforma_contas/${E}`].betaTetoUsd = 0.0001;
  const antes = chamadasIa;
  r = await per('quero saber das coisas', { novaConversa: true });
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
  t.ok(rs.code === 200 && rs.body.corretoras[0].nome === 'Upgrade' && rs.body.corretoras[0].comIa === 4 && rs.body.perguntas.length >= 2, 'portal: uso por corretora e perguntas');
  await chamar(plataforma, { acao: 'betaPerguntaVista', id: rs.body.perguntas[0].id }, 'tAdm');
  t.ok(store[`plataforma_beta_perguntas/${rs.body.perguntas[0].id}`].visto === true, 'marcar como vista');
  t.ok((await chamar(plataforma, { acao: 'contaDefinirTetoBeta', empresaId: E, tetoUsd: 10 }, 'tAdm')).code === 200 && store[`plataforma_contas/${E}`].betaTetoUsd === 10, 'teto por corretora');
  t.fim();
})();
