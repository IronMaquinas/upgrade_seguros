// functions/beta.js — Etapa 28: Beta, a assistente da corretora
//
// Responde SÓ com dados do banco da corretora de quem pergunta. A IA (Claude
// Haiku) nunca escreve a resposta: quando as regras de texto não bastam, ela só
// transforma a pergunta no pedido estruturado (beta-interpretar.js); quem busca
// e monta a resposta é este código.
//
//   POST beta (logado)  { mensagem, novaConversa?, escolherClienteId? }
//     → { texto, itens:[{titulo, linhas[], acoes[]}], acoes:[{tipo, valor, rotulo}], semIa, foraDoEscopo }
//   acoes.tipo: ligar · whatsapp · email · abrir (atendimento) · escolher (cliente)
//
// Conversa: corretoras/{e}/beta_conversas/{uid} guarda o ASSUNTO (último
// atendimento/cliente e a última intenção) — "e o telefone do terceiro?" usa o
// sinistro anterior sem repetir o número. Só o assunto vai para a IA, nunca o
// histórico, para cada pergunta continuar barata.
//
// Custo: cada chamada à IA soma tokens e US$ em plataforma_contas/{e}.beta.{AAAA-MM};
// teto mensal (betaTetoUsd na conta, padrão TETO_PADRAO_USD) — passou do teto,
// a Beta segue só com as regras. Sem resposta → plataforma_beta_perguntas
// (o admin vê no portal → Beta).
// Módulo do plano: 'beta' (functions/modulos.js).

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });

const { interpretar, bastaSemIa, validarDaIa, normalizar, INTENCOES, ALVOS } = require('./beta-interpretar');
const { ligado } = require('./modulos');

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();
const agora = () => admin.firestore.FieldValue.serverTimestamp();
const inc = (n) => admin.firestore.FieldValue.increment(n);

const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');

// ── IA: modelo e preço (US$ por milhão de tokens) — conferir na tabela da Anthropic ──
const MODELO = 'claude-haiku-5-5';
const PRECO_ENTRADA_USD_MTOK = 1.0;
const PRECO_SAIDA_USD_MTOK = 5.0;
const TETO_PADRAO_USD = 5; // por corretora, por mês (betaTetoUsd na conta muda)

const mesAtual = () => {
  const d = new Date(Date.now() - 3 * 3600000); // mês de Brasília
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
};

const PROMPT = `Você converte perguntas de funcionários de uma corretora de seguros em JSON. Não responda a pergunta.
(apolices = apólices do cliente: ramo, vencimento, valor, bens segurados, gasto com sinistros × gatilho.)
Devolva SÓ um objeto JSON: {"intencao":…, "alvo":…, "numero":…, "numeroSeguradora":…, "placa":…, "cliente":…}
intencao: ${INTENCOES.join(' | ')} | null (fora do escopo)
  contato = telefone/e-mail/WhatsApp de alguém; veiculo = dados do veículo; status = situação do sinistro/assistência;
  pendencias = tarefas/ações pendentes; sinistros_cliente = sinistros de um cliente; dono_placa = de quem é uma placa.
alvo: ${ALVOS.join(' | ')} | null
numero: número do registro no formato SN + 14 dígitos ou AS + 14 dígitos, se houver. numeroSeguradora: número do sinistro na seguradora, se houver.
cliente: nome do cliente/segurado citado, se houver. Use null para o que não aparece.
Se a pergunta continua a conversa ("e do terceiro?"), use o assunto informado. Qualquer outro assunto: intencao null.`;

// ── chamada ao Haiku (substituível nos testes) ──────────────────────────────
let chamarIa = async (pergunta, assunto) => {
  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-api-key': ANTHROPIC_API_KEY.value(), 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({
      model: MODELO,
      max_tokens: 120,
      system: PROMPT,
      messages: [{ role: 'user', content: `Assunto atual: ${assunto.rotulo || 'nenhum'}${assunto.intencao ? ` (última pergunta: ${assunto.intencao})` : ''}\nPergunta: ${pergunta}` }],
    }),
  });
  if (!resp.ok) throw new Error(`IA ${resp.status}`);
  const j = await resp.json();
  const texto = ((j.content || [])[0] || {}).text || '';
  const m = texto.match(/\{[\s\S]*\}/);
  return { json: m ? JSON.parse(m[0]) : null, entrada: (j.usage || {}).input_tokens || 0, saida: (j.usage || {}).output_tokens || 0 };
};
const _trocarIa = (f) => { chamarIa = f; };

// ── utilidades de resposta ──────────────────────────────────────────────────
const digitos = (s) => String(s || '').replace(/\D/g, '');
function acoesDoTelefone(tel, quem) {
  const d = digitos(tel);
  if (d.length < 8) return [];
  const zap = d.length === 10 || d.length === 11 ? `55${d}` : d;
  return [
    { tipo: 'ligar', valor: d, rotulo: `Ligar para ${quem}` },
    { tipo: 'whatsapp', valor: zap, rotulo: 'WhatsApp' },
  ];
}
function pessoa(titulo, nome, tel, email, extra = []) {
  const linhas = [];
  if (nome) linhas.push(nome);
  if (tel) linhas.push(`Telefone: ${tel}`);
  if (email) linhas.push(`E-mail: ${email}`);
  linhas.push(...extra.filter(Boolean));
  const acoes = acoesDoTelefone(tel, nome || titulo.toLowerCase());
  if (email) acoes.push({ tipo: 'email', valor: email, rotulo: 'E-mail' });
  return { titulo, linhas: linhas.length ? linhas : ['Sem dados cadastrados.'], acoes, vazio: !tel && !email };
}
const rotuloAt = (at) => `${at.tipo === 'assistencia' ? 'Assistência' : 'Sinistro'} ${at.numero_sinistro || ''} — ${at.client_nome || ''}`.trim();
const abrir = (at) => ({ tipo: 'abrir', valor: at.id, tipoAtendimento: at.tipo === 'assistencia' ? 'assistencia' : 'sinistro', rotulo: `Abrir ${at.numero_sinistro || 'atendimento'}` });
const dataBr = (v) => {
  const d = v && typeof v.toDate === 'function' ? v.toDate() : v ? new Date(v) : null;
  return d && !Number.isNaN(d.getTime()) ? d.toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' }) : '';
};

// ── buscas (sempre dentro da corretora) ─────────────────────────────────────
const col = (e, c) => db().collection('corretoras').doc(e).collection(c);

async function atendimentoPor(e, campo, valor) {
  for (const c of ['sinistros', 'assistencias']) {
    const s = await col(e, c).where(campo, '==', valor).limit(1).get();
    if (!s.empty) {
      const d = s.docs[0];
      return { ...d.data(), id: d.id, colecao: c };
    }
  }
  return null;
}
async function atendimentoPorId(e, id) {
  for (const c of ['sinistros', 'assistencias']) {
    const d = await col(e, c).doc(id).get();
    if (d.exists) return { ...d.data(), id: d.id, colecao: c };
  }
  return null;
}
async function cliente(e, id) {
  if (!id) return null;
  const d = await col(e, 'clientes').doc(id).get();
  return d.exists ? { ...d.data(), id: d.id } : null;
}
async function clientesPorNome(e, nome) {
  // 28.1: palavras da pergunta que não fazem parte do nome não podem atrapalhar a busca
  const ignorar = ['do', 'da', 'de', 'dos', 'das', 'e', 'o', 'a', 'contato', 'telefone', 'fone', 'celular', 'whatsapp', 'email', 'cliente', 'segurado', 'segurada', 'numero', 'qual'];
  const partes = normalizar(nome).split(' ').filter((p) => p.length > 1 && !ignorar.includes(p));
  if (!partes.length) return [];
  const s = await col(e, 'clientes').get();
  return s.docs
    .map((d) => ({ ...d.data(), id: d.id }))
    .filter((c) => { const n = normalizar(c.nome); return partes.every((p) => n.includes(p)); })
    .slice(0, 6);
}

// ── respostas por intenção ──────────────────────────────────────────────────
// 28.9: no sinistro, 3 pessoas de cada lado (o que não foi preenchido aparece como "não informado").
const SEM_INFO = 'Não há essa informação neste sinistro.';
function pessoaDoSinistro(titulo, nome, tel, email, extra = []) {
  const ex = extra.filter(Boolean);
  if (!nome && !tel && !email && !ex.length) return { titulo, linhas: [SEM_INFO], acoes: [], vazio: true };
  const r = pessoa(titulo, nome, tel, email, ex);
  if (!tel && !email) r.linhas.push('Sem telefone ou e-mail cadastrados para esta pessoa no sinistro.');
  return { ...r, vazio: false };
}
const soDigitos = (v) => String(v || '').replace(/\D/g, '');

function respostaContato(alvo, at, cli) {
  const a = alvo || 'segurado';
  if (a === 'segurado') {
    return [pessoa('Segurado', (at && at.client_nome) || (cli && cli.nome), (at && at.telefone_cliente) || (cli && cli.contato_telefone), cli && cli.email)];
  }
  if (a === 'contato_segurado') {
    if (at) return [pessoaDoSinistro('Contato do sinistro (segurado)', at.nomeContatoSinistro, at.telefoneContatoSinistro)];
    return [pessoa('Contato do segurado', cli && cli.contato, cli && cli.contato_telefone, cli && cli.email)];
  }
  if (!at) return null; // os demais dependem de um atendimento
  if (a === 'contato_local') return [pessoa('Contato no local', at.nome_contato, at.telefone_contato_local)];
  if (a === 'oficina') return [pessoa('Oficina', [at.nome_oficina, at.nome_contato_oficina && `Contato: ${at.nome_contato_oficina}`].filter(Boolean).join(' · '), at.telefone_contato_oficina, null, [at.endereco_oficina])];
  if (a === 'proprietario') {
    const v = at.veiculo_selecionado || {};
    // proprietário é o próprio segurado (mesmo CPF/CNPJ)? então o contato do cadastro serve
    const ehOSegurado = soDigitos(v.cpfCondutor) && cli && soDigitos(v.cpfCondutor) === soDigitos(cli.cnpj_cpf);
    return [pessoaDoSinistro('Proprietário do veículo (segurado)', v.nomeCondutor, ehOSegurado ? cli.contato_telefone : null, ehOSegurado ? cli.email : null,
      [v.cpfCondutor && `CPF/CNPJ: ${v.cpfCondutor}`, v.placa && `Placa: ${v.placa}`, ehOSegurado && 'É o próprio segurado (contato do cadastro).'])];
  }
  if (a === 'motorista') {
    const v = at.veiculo_selecionado || {};
    const tr = at.transporte || {};
    return [pessoaDoSinistro('Condutor do veículo (segurado)', v.nomeCondutorMotorista || tr.nomeMotorista, null, null,
      [(v.cpfCondutorMotorista || tr.cpfMotorista) && `CPF: ${v.cpfCondutorMotorista || tr.cpfMotorista}`, v.cnhCondutorMotorista && `CNH: ${v.cnhCondutorMotorista}`])];
  }
  const ts = Array.isArray(at.terceiros) ? at.terceiros : [];
  if (!ts.length) return [{ titulo: 'Terceiros', linhas: ['Não houve terceiros neste sinistro.'], acoes: [], vazio: false }];
  return ts.map((t, i) => {
    const n = ts.length > 1 ? ` ${i + 1}` : '';
    if (a === 'contato_terceiro') return pessoaDoSinistro(`Contato do sinistro (terceiro${n})`, t.nomeContatoTerceiro, t.telefoneContatoTerceiro);
    if (a === 'motorista_terceiro') {
      return t.motoristaMesmoProprietario
        ? pessoaDoSinistro(`Condutor do veículo do terceiro${n} (o próprio proprietário)`, t.nome, t.contato, t.email, [t.cpf && `CPF/CNPJ: ${t.cpf}`])
        : pessoaDoSinistro(`Condutor do veículo do terceiro${n}`, t.nomeMotorista, t.telefoneMotorista, t.emailMotorista, [t.cpfMotorista && `CPF: ${t.cpfMotorista}`, t.cnhMotorista && `CNH: ${t.cnhMotorista}`]);
    }
    return pessoaDoSinistro(`Proprietário do veículo do terceiro${n}`, t.nome, t.contato, t.email, [t.cpf && `CPF/CNPJ: ${t.cpf}`, t.placa && `Placa: ${t.placa}`]);
  });
}

function respostaVeiculo(alvo, at, cli) {
  const linhasV = (v) => [
    [v.marca || v.marcaTerceiro, v.modelo || v.modeloTerceiro].filter(Boolean).join(' '),
    v.placa && `Placa: ${v.placa}`,
    v.cor && `Cor: ${v.cor}`,
    (v.ano || v.anoFabricacaoTerceiro) && `Ano: ${v.ano || v.anoFabricacaoTerceiro}${v.anomodelo || v.anoModeloTerceiro ? `/${v.anomodelo || v.anoModeloTerceiro}` : ''}`,
    v.chassi && `Chassi: ${v.chassi}`,
  ].filter(Boolean);
  if (at && alvo && alvo.includes('terceiro')) {
    const ts = Array.isArray(at.terceiros) ? at.terceiros : [];
    if (!ts.length) return [{ titulo: 'Veículo do terceiro', linhas: ['Sem terceiros neste atendimento.'], acoes: [], vazio: true }];
    return ts.map((t, i) => ({ titulo: `Veículo do terceiro${ts.length > 1 ? ` ${i + 1}` : ''}`, linhas: linhasV(t), acoes: [] }));
  }
  if (at && at.veiculo_selecionado) return [{ titulo: 'Veículo segurado', linhas: linhasV(at.veiculo_selecionado), acoes: [abrir(at)] }];
  // 28.4: os bens ficam nas apólices do cadastro (um ou mais ramos, uma ou mais apólices)
  const bens = bensDoCliente(cli);
  if (bens.length) return bens.slice(0, 15).map((b, i) => ({ titulo: `Bem ${i + 1} — ${b.apolice}`, linhas: b.linhas, acoes: [] }));
  const vs = (cli && Array.isArray(cli.veiculos_segurados) ? cli.veiculos_segurados : []).slice(0, 10);
  if (vs.length) return vs.map((v, i) => ({ titulo: `Veículo ${i + 1} de ${cli.nome}`, linhas: linhasV(v), acoes: [] }));
  return null;
}

// ── 28.4: apólices e bens do cadastro do cliente ────────────────────────────
const paraData = (v) => (v && typeof v.toDate === 'function' ? v.toDate() : v ? new Date(v) : null);
const reais = (n) => `R$ ${Number(n || 0).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
const diaBr = (d) => (d ? d.toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' }) : '—');
const apolicesDe = (cli) => (cli && Array.isArray(cli.apolices) ? cli.apolices : []);
const rotuloApolice = (a) => `${a.ramo || 'Apólice'}${a.numero_apolice ? ` • ${a.numero_apolice}` : ''}`;

function linhasDoBem(b) {
  const veic = [b.marca, b.modelo].filter(Boolean).join(' ');
  const cavalo = [b.marca_cavalo, b.modelo_cavalo].filter(Boolean).join(' ');
  const end = [b.logradouro, b.numero, b.bairro, b.cidade && `${b.cidade}${b.estado ? `/${b.estado}` : ''}`].filter(Boolean).join(', ');
  return [
    b.tipo && `Tipo: ${b.tipo}`,
    b.descricao,
    veic,
    b.placa && `Placa: ${b.placa}`,
    (b.ano || b.ano_modelo) && `Ano: ${[b.ano, b.ano_modelo].filter(Boolean).join('/')}`,
    b.cor && `Cor: ${b.cor}`,
    b.chassi && `Chassi: ${b.chassi}`,
    (cavalo || b.placa_cavalo) && `Cavalo: ${[cavalo, b.placa_cavalo && `placa ${b.placa_cavalo}`].filter(Boolean).join(' · ')}`,
    b.placa_carreta && `Carreta: placa ${b.placa_carreta}`,
    end,
    b.capital_segurado && `Capital segurado: ${reais(b.capital_segurado)}`,
    b.numero_documento && `Documento: ${b.numero_documento}`,
  ].filter(Boolean);
}

function bensDoCliente(cli) {
  const r = [];
  for (const a of apolicesDe(cli)) {
    for (const b of Array.isArray(a.bens_segurados) ? a.bens_segurados : []) {
      const linhas = linhasDoBem(b);
      if (linhas.length) r.push({ apolice: rotuloApolice(a), linhas });
    }
  }
  return r;
}

/** Gasto de cada apólice: sinistros (não cancelados/negados) dentro da vigência — mesma conta do app (recomendacao_cliente.dart). */
function gastosPorApolice(apolices, sinistros) {
  const dia = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());
  const conta = (a, s) => {
    const ini = paraData(a.data_inicio); const fim = paraData(a.data_fim); const oc = paraData(s.data_ocorrencia);
    if (!ini || !fim || !oc) return false;
    if (['Cancelado', 'Negado'].includes(String(s.status_atual || '').trim())) return false;
    const f = dia(fim); f.setDate(f.getDate() + 1);
    return oc >= dia(ini) && oc < f;
  };
  const ramo = (r) => (String(r || '').trim() === 'Vidas' ? 'Vida' : String(r || '').trim());
  const ids = new Set(apolices.map((a) => a.id));
  const gasto = {};
  const qtd = {};
  for (const s of sinistros) {
    let alvo = null;
    if (s.apolice_id && ids.has(s.apolice_id)) alvo = apolices.find((a) => a.id === s.apolice_id);
    else {
      alvo = apolices.filter((a) => ramo(a.ramo) === ramo(s.ramo_sinistro) && conta(a, s))
        .sort((x, y) => (paraData(y.data_inicio) || 0) - (paraData(x.data_inicio) || 0))[0] || null;
    }
    if (!alvo || !conta(alvo, s)) continue;
    gasto[alvo.id] = (gasto[alvo.id] || 0) + (Number(s.valor_total_sinistro) || 0);
    qtd[alvo.id] = (qtd[alvo.id] || 0) + 1;
  }
  return { gasto, qtd };
}

async function respostaApolices(e, cli, detalhe) {
  const aps = apolicesDe(cli).slice().sort((x, y) => (paraData(y.data_fim) || 0) - (paraData(x.data_fim) || 0));
  if (!aps.length) return { texto: `${cli.nome} não tem apólices cadastradas.`, itens: [] };
  const hoje = new Date();
  let gastos = null;
  let pct = 70;
  if (detalhe === 'gastos') {
    const s = await col(e, 'sinistros').where('id_cliente', '==', cli.id).get();
    gastos = gastosPorApolice(aps, s.docs.map((d) => d.data()).filter((x) => (x.tipo || 'sinistro') === 'sinistro'));
    const cfg = await col(e, 'app_config').doc('config').get();
    const p = Number(((cfg.exists && cfg.data()) || {}).percentualGatilhoPadrao);
    if (p > 0) pct = p > 1 ? p : p * 100;
  }
  const vigentes = aps.filter((a) => { const i = paraData(a.data_inicio); const f = paraData(a.data_fim); return i && f && i <= hoje && hoje <= new Date(f.getTime() + 86400000); });
  const itens = aps.slice(0, 10).map((a) => {
    const ini = paraData(a.data_inicio); const fim = paraData(a.data_fim);
    const vig = vigentes.includes(a);
    const dias = fim ? Math.ceil((fim - hoje) / 86400000) : null;
    const linhas = [
      a.seguradora && `Seguradora: ${a.seguradora}`,
      `Vigência: ${diaBr(ini)} até ${diaBr(fim)}${vig ? (dias !== null && dias <= 30 ? ` — vence em ${dias} dia(s)` : ' — vigente') : fim && fim < hoje ? ' — vencida' : ''}`,
      Number(a.valor_apolice) > 0 && `Valor: ${reais(a.valor_apolice)}`,
    ];
    if (gastos) {
      const g = gastos.gasto[a.id] || 0;
      const gat = Number(a.valor_gatilho) > 0.01 ? Number(a.valor_gatilho) : (Number(a.valor_apolice) || 0) * pct / 100;
      linhas.push(`Gasto com sinistros na vigência: ${reais(g)} (${gastos.qtd[a.id] || 0} sinistro(s))`);
      if (gat > 0) linhas.push(`Gatilho: ${reais(gat)} — ${Math.round((g / gat) * 100)}% usado`);
    }
    const bens = Array.isArray(a.bens_segurados) ? a.bens_segurados : [];
    if (detalhe === 'bens') bens.slice(0, 8).forEach((b, i) => linhas.push(`Bem ${i + 1}: ${linhasDoBem(b).slice(0, 4).join(' · ')}`));
    else if (bens.length) linhas.push(`${bens.length} bem(ns) segurado(s)`);
    return { titulo: rotuloApolice(a), linhas: linhas.filter(Boolean), acoes: [] };
  });
  return {
    texto: `${cli.nome}: ${aps.length} apólice(s), ${vigentes.length} vigente(s).`,
    itens,
  };
}

// ── o pedido completo ───────────────────────────────────────────────────────
async function responder(e, quem, corpo, conta) {
  const mensagem = String(corpo.mensagem || '').trim().slice(0, 500);
  const conversaRef = col(e, 'beta_conversas').doc(quem.uid);
  let assunto = {};
  if (!corpo.novaConversa) {
    const c = await conversaRef.get();
    if (c.exists) assunto = c.data().assunto || {};
  }
  if (!mensagem && !corpo.escolherClienteId) return { texto: 'Oi! Pergunte, por exemplo: "telefone do segurado do sinistro SN…".', itens: [], acoes: [], semIa: true };

  const mes = mesAtual();
  const usoMes = ((conta.beta || {})[mes]) || {};
  const teto = typeof conta.betaTetoUsd === 'number' ? conta.betaTetoUsd : TETO_PADRAO_USD;
  const registro = { perguntas: inc(1) };

  // 1) regras; 2) IA se precisar e se houver saldo
  let p;
  let semIa = true;
  let limite = false;
  if (corpo.escolherClienteId) {
    p = { ...(assunto.pendente || { intencao: 'contato', alvo: 'segurado' }), cliente: null, numero: null, numeroSeguradora: null, placa: null };
    assunto = { ...assunto, clienteId: String(corpo.escolherClienteId), atendimentoId: null, pendente: null };
  } else {
    p = interpretar(mensagem, assunto);
    // 28.3: a Beta tinha perguntado "de qual sinistro ou cliente?" e a resposta veio
    // só com o nome/número — completa o pedido anterior.
    // Só quando a mensagem parece uma resposta curta (um nome ou número), não outra pergunta.
    const pareceResposta = !/\?/.test(mensagem) && mensagem.split(/\s+/).length <= 6
      && !/^(qual|quais|quem|como|quando|onde|o que|por ?que|me |quero|preciso|tem |existe)/i.test(normalizar(mensagem));
    if (!p.intencao && pareceResposta && assunto.pendente && assunto.pendente.intencao) {
      const soEntidade = p.numero || p.numeroSeguradora || p.placa;
      p = { ...p, intencao: assunto.pendente.intencao, alvo: p.alvo || assunto.pendente.alvo, cliente: soEntidade ? null : p.cliente || normalizar(mensagem) };
    }
    if (!bastaSemIa(p, assunto)) {
      if ((usoMes.custoUsd || 0) >= teto) {
        limite = true;
      } else {
        try {
          const r = await chamarIa(mensagem, assunto);
          semIa = false;
          const custo = (r.entrada * PRECO_ENTRADA_USD_MTOK + r.saida * PRECO_SAIDA_USD_MTOK) / 1e6;
          Object.assign(registro, { comIa: inc(1), tokensEntrada: inc(r.entrada), tokensSaida: inc(r.saida), custoUsd: inc(custo) });
          const daIa = validarDaIa(r.json);
          if (daIa) p = { ...daIa, alvo: daIa.alvo || p.alvo, numero: daIa.numero || p.numero, placa: daIa.placa || p.placa };
        } catch (err) {
          logger.warn('Beta: IA falhou', err.message);
        }
      }
    }
  }

  const r = await executar(e, p, assunto);
  const foraDoEscopo = !!r.foraDoEscopo;
  if (foraDoEscopo) {
    registro.semResposta = inc(1);
    await db().collection('plataforma_beta_perguntas').doc().set({
      empresaId: e, uid: quem.uid, email: quem.email || '', pergunta: mensagem, motivo: r.motivo || 'fora_do_escopo',
      interpretado: p, visto: false, criadoEm: agora(),
    });
  }
  await db().collection('plataforma_contas').doc(e).set({ beta: { [mes]: registro } }, { merge: true }).catch(() => {});
  await conversaRef.set({ assunto: r.assunto || assunto, atualizadoEm: agora() });
  return {
    texto: limite && foraDoEscopo ? 'O limite de uso da Beta neste mês acabou. Perguntas diretas (ex.: "telefone do segurado do SN…") continuam funcionando.' : r.texto,
    itens: (r.itens || []).map(({ vazio, ...i }) => i),
    acoes: r.acoes || [],
    semIa,
    foraDoEscopo,
  };
}

const FORA = (motivo, texto) => ({
  foraDoEscopo: true,
  motivo,
  texto: texto || 'Isso não está no meu escopo. Guardei a pergunta para a equipe da plataforma avaliar.',
});

// 28.6/28.10: atendimentos do cliente — ligados pelo id, pelo CNPJ/CPF ou só pelo nome
// (registros antigos); junta sem repetir.
const FINALIZADOS = ['Concluído', 'Cancelado', 'Negado'];
const emCurso = (x) => !FINALIZADOS.includes(String(x.status_atual || x.status || '').trim());
async function atendimentosDoCliente(e, c, so) {
  const lista = [];
  const vistos = new Set();
  for (const nome of so ? [so] : ['sinistros', 'assistencias']) {
    const buscas = [col(e, nome).where('id_cliente', '==', c.id).get()];
    if (c.cnpj_cpf) buscas.push(col(e, nome).where('client_cnpj_cpf', '==', c.cnpj_cpf).get());
    if (c.nome) buscas.push(col(e, nome).where('client_nome', '==', c.nome).get());
    for (const r of await Promise.all(buscas)) {
      r.docs.forEach((d) => {
        if (vistos.has(d.id)) return;
        vistos.add(d.id);
        lista.push({ ...d.data(), id: d.id, tipo: d.data().tipo || (nome === 'assistencias' ? 'assistencia' : 'sinistro') });
      });
    }
  }
  return lista;
}

async function executar(e, p, assunto) {
  if (!p || !p.intencao) return { ...FORA('fora_do_escopo'), assunto };

  // dono da placa
  if (p.intencao === 'dono_placa') {
    const s = await col(e, 'clientes').get();
    const achados = s.docs.map((d) => ({ ...d.data(), id: d.id }))
      .filter((c) => (c.veiculos_segurados || []).some((v) => String(v.placa || '').replace(/[^a-z0-9]/gi, '').toUpperCase() === p.placa));
    if (!achados.length) return { ...FORA('nao_encontrado', `Não achei a placa ${p.placa} nos veículos dos clientes.`), assunto };
    const c = achados[0];
    return {
      texto: `A placa ${p.placa} é de ${c.nome}.`,
      itens: [pessoa('Cliente', c.nome, c.contato_telefone, c.email)],
      assunto: { clienteId: c.id, rotulo: `Cliente ${c.nome}`, intencao: 'contato' },
    };
  }

  // atendimento: número do registro, da seguradora, ou o assunto
  let at = null;
  if (p.numero) at = await atendimentoPor(e, 'numero_sinistro', p.numero);
  else if (p.numeroSeguradora) at = await atendimentoPor(e, 'numero_seguradora', p.numeroSeguradora);
  if ((p.numero || p.numeroSeguradora) && !at) return { ...FORA('nao_encontrado', `Não achei o atendimento ${p.numero || p.numeroSeguradora}.`), assunto };

  // cliente pelo nome (pode precisar escolher)
  let cli = null;
  if (!at && p.cliente) {
    const lista = await clientesPorNome(e, p.cliente);
    if (!lista.length) return { ...FORA('nao_encontrado', `Não achei cliente com "${p.cliente}".`), assunto };
    if (lista.length > 1) {
      return {
        texto: 'Achei mais de um cliente. Qual deles?',
        acoes: lista.map((c) => ({ tipo: 'escolher', valor: c.id, rotulo: c.nome })),
        assunto: { ...assunto, pendente: { intencao: p.intencao, alvo: p.alvo } },
      };
    }
    cli = lista[0];
  }
  if (!at && !cli && p.placa) {
    const s = await col(e, 'clientes').get();
    const c = s.docs.map((d) => ({ ...d.data(), id: d.id })).find((x) => (x.veiculos_segurados || []).some((v) => String(v.placa || '').replace(/[^a-z0-9]/gi, '').toUpperCase() === p.placa));
    if (c) cli = c;
  }
  if (!at && !cli) {
    if (assunto.atendimentoId) at = await atendimentoPorId(e, assunto.atendimentoId);
    else if (assunto.clienteId) cli = await cliente(e, assunto.clienteId);
  }
  if (!at && !cli) return { ...FORA('sem_assunto', 'De qual sinistro ou cliente? Me diga o número (SN… / AS…) ou o nome do cliente.'), assunto: { ...assunto, pendente: { intencao: p.intencao, alvo: p.alvo } } };
  if (at && !cli) cli = await cliente(e, at.id_cliente);

  // 28.10: pessoa DO SINISTRO (proprietário, condutor, contato do sinistro, terceiros…) pedida
  // pelo nome do cliente, sem número: usa os sinistros em andamento dele. Um só → responde
  // direto; vários → o mesmo dado de cada um, com o número.
  const DO_SINISTRO = ['proprietario', 'motorista', 'terceiro', 'contato_terceiro', 'motorista_terceiro', 'contato_local', 'oficina'];
  if (p.intencao === 'contato' && !at && cli && (DO_SINISTRO.includes(p.alvo) || (p.alvo === 'contato_segurado' && p.doSinistro))) {
    const abertos = (await atendimentosDoCliente(e, cli, p.doAssistencia ? 'assistencias' : null)).filter(emCurso)
      .sort((a, b) => String(b.numero_sinistro || '').localeCompare(String(a.numero_sinistro || '')));
    if (abertos.length === 1) at = abertos[0];
    else {
      const assuntoCli = { atendimentoId: null, clienteId: cli.id, rotulo: `Cliente ${cli.nome}`, intencao: p.intencao };
      if (!abertos.length) return { texto: `${cli.nome} não tem sinistro nem assistência em andamento. Me diga o número (SN… / AS…) para eu olhar um encerrado.`, itens: [], acoes: [], assunto: assuntoCli };
      const itens = [];
      for (const a of abertos.slice(0, 6)) {
        for (const i of respostaContato(p.alvo, a, cli) || []) itens.push({ ...i, titulo: `${a.numero_sinistro} — ${i.titulo}`, acoes: [...(i.acoes || []), abrir(a)] });
      }
      return { texto: `${cli.nome} tem ${abertos.length} atendimento(s) em andamento:`, itens, acoes: [], assunto: assuntoCli };
    }
  }

  const novoAssunto = at
    ? { atendimentoId: at.id, clienteId: at.id_cliente || null, rotulo: rotuloAt(at), intencao: p.intencao }
    : { atendimentoId: null, clienteId: cli.id, rotulo: `Cliente ${cli.nome}`, intencao: p.intencao };

  // 28.6: status/pendência pede um atendimento; se veio um CLIENTE (não um número),
  // responde com os atendimentos em andamento dele.
  if ((p.intencao === 'status' || p.intencao === 'pendencias') && !at && cli) {
    p = { ...p, intencao: 'sinistros_cliente', filtro: { ...(p.filtro || {}), emCurso: true } };
  }
  switch (p.intencao) {
    case 'contato': {
      const itens = respostaContato(p.alvo, at, cli);
      if (!itens) return { ...FORA('nao_encontrado', 'Para isso eu preciso de um sinistro ou assistência. Qual o número?'), assunto: novoAssunto };
      const tudoVazio = itens.every((i) => i.vazio);
      return { texto: tudoVazio ? 'Não há telefone nem e-mail cadastrados para isso.' : (at ? rotuloAt(at) : cli.nome), itens, acoes: at ? [abrir(at)] : [], assunto: novoAssunto };
    }
    case 'veiculo': {
      const itens = respostaVeiculo(p.alvo, at, cli);
      // 28.5: tem apólice, mas nenhum bem cadastrado nela — diz isso (não é "fora do escopo")
      if (!itens && !at && cli && apolicesDe(cli).length) {
        const aps = apolicesDe(cli);
        return {
          texto: `${cli.nome} tem ${aps.length} apólice(s), mas nenhum bem cadastrado nelas.`,
          itens: aps.slice(0, 10).map((a) => ({ titulo: rotuloApolice(a), linhas: [a.seguradora && `Seguradora: ${a.seguradora}`, 'Sem bens cadastrados — dá para incluir no cadastro do cliente, em Apólices por Ramo.'].filter(Boolean), acoes: [] })),
          assunto: novoAssunto,
        };
      }
      if (!itens) return { ...FORA('nao_encontrado', 'Não há veículo cadastrado para isso.'), assunto: novoAssunto };
      return { texto: at ? rotuloAt(at) : cli.nome, itens, assunto: novoAssunto };
    }
    case 'apolices': {
      const c = cli || (await cliente(e, at && at.id_cliente));
      if (!c) return { ...FORA('nao_encontrado'), assunto: novoAssunto };
      const r = await respostaApolices(e, c, p.detalhe);
      return { ...r, assunto: { atendimentoId: null, clienteId: c.id, rotulo: `Cliente ${c.nome}`, intencao: 'apolices' } };
    }
    case 'status': {
      if (!at) return { ...FORA('nao_encontrado', 'De qual sinistro ou assistência? Me diga o número.'), assunto: novoAssunto };
      return {
        texto: rotuloAt(at),
        itens: [{
          titulo: 'Situação',
          linhas: [
            `Status: ${at.status_atual || at.status || '—'}`,
            at.seguradora && `Seguradora: ${at.seguradora}${at.numero_seguradora ? ` · nº ${at.numero_seguradora}` : ''}`,
            at.data_abertura && `Aberto em ${dataBr(at.data_abertura)}`,
            at.data_ultima_atualizacao && `Última atualização: ${dataBr(at.data_ultima_atualizacao)}`,
          ].filter(Boolean),
          acoes: [abrir(at)],
        }],
        assunto: novoAssunto,
      };
    }
    case 'pendencias': {
      if (!at) return { ...FORA('nao_encontrado', 'De qual sinistro ou assistência? Me diga o número.'), assunto: novoAssunto };
      const s = await col(e, 'tasks').where('claimId', '==', at.id).get();
      const abertas = s.docs.map((d) => d.data()).filter((t) => !/conclu/i.test(String(t.status || '')));
      return {
        texto: abertas.length ? `${rotuloAt(at)}: ${abertas.length} tarefa(s) pendente(s).` : `${rotuloAt(at)}: nenhuma tarefa pendente.`,
        itens: abertas.slice(0, 10).map((t) => ({ titulo: t.descricao || 'Tarefa', linhas: [t.prazo ? `Prazo: ${dataBr(t.prazo)}` : 'Sem prazo', t.responsavelEmail && `Responsável: ${t.responsavelEmail}`].filter(Boolean), acoes: [] })),
        acoes: [abrir(at)],
        assunto: novoAssunto,
      };
    }
    case 'sinistros_cliente': {
      const c = cli || (await cliente(e, at && at.id_cliente));
      if (!c) return { ...FORA('nao_encontrado'), assunto: novoAssunto };
      // 28.6: filtro — só sinistros / só assistências / só em curso (mesma regra das listas)
      const f = p.filtro || {};
      const lista = await atendimentosDoCliente(e, c, f.so);
      const filtrada = f.emCurso ? lista.filter(emCurso) : lista;
      filtrada.sort((a, b) => String(b.numero_sinistro || '').localeCompare(String(a.numero_sinistro || '')));
      const oque = f.so === 'assistencias' ? 'assistência(s)' : f.so === 'sinistros' ? 'sinistro(s)' : 'atendimento(s)';
      const nenhum = f.so === 'assistencias' ? 'nenhuma assistência' : f.so === 'sinistros' ? 'nenhum sinistro' : 'nenhum sinistro nem assistência';
      const lista2 = filtrada;
      return {
        texto: lista2.length ? `${c.nome}: ${lista2.length} ${oque}${f.emCurso ? ' em andamento' : ''}.` : `${c.nome} não tem ${nenhum}${f.emCurso ? ' em andamento' : ''}.`,
        itens: lista2.slice(0, 15).map((x) => ({ titulo: `${x.tipo === 'assistencia' ? 'Assistência' : 'Sinistro'} ${x.numero_sinistro || ''}`, linhas: [`Status: ${x.status_atual || x.status || '—'}`, x.data_abertura && `Aberto em ${dataBr(x.data_abertura)}`].filter(Boolean), acoes: [abrir(x)] })),
        assunto: { atendimentoId: null, clienteId: c.id, rotulo: `Cliente ${c.nome}`, intencao: 'sinistros_cliente' },
      };
    }
    default:
      return { ...FORA('fora_do_escopo'), assunto };
  }
}

// ── a Function ──────────────────────────────────────────────────────────────
const beta = onRequest({ secrets: [ANTHROPIC_API_KEY] }, (req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const { usuarioAtivo } = require('./seguranca');
      const quem = await usuarioAtivo(req);
      if (!quem) return res.status(401).json({ erro: 'Faça login novamente.' });
      const e = String(quem.dados.empresaId || '');
      if (!e) return res.status(400).json({ erro: 'Seu usuário não tem corretora.' });
      const contaDoc = await db().collection('plataforma_contas').doc(e).get();
      const conta = contaDoc.exists ? contaDoc.data() : null;
      if (!ligado(conta, 'beta')) return res.status(403).json({ erro: 'A Beta não está no plano da corretora.' });
      return res.json(await responder(e, quem, req.body || {}, conta || {}));
    } catch (err) {
      logger.error(err);
      if (!res.headersSent) res.status(500).json({ erro: 'Erro interno' });
    }
  }),
);

// ── portal: resumo e perguntas sem resposta ─────────────────────────────────
async function resumoPortal() {
  const mes = mesAtual();
  const contas = await db().collection('plataforma_contas').get();
  const corretoras = [];
  for (const d of contas.docs) {
    const c = d.data() || {};
    const u = (c.beta || {})[mes];
    if (!u) continue;
    const nome = ((await db().collection('corretoras').doc(d.id).get()).data() || {}).nome || d.id;
    corretoras.push({
      empresaId: d.id, nome, perguntas: u.perguntas || 0, comIa: u.comIa || 0, semResposta: u.semResposta || 0,
      tokensEntrada: u.tokensEntrada || 0, tokensSaida: u.tokensSaida || 0, custoUsd: u.custoUsd || 0,
      tetoUsd: typeof c.betaTetoUsd === 'number' ? c.betaTetoUsd : TETO_PADRAO_USD,
    });
  }
  const ps = await db().collection('plataforma_beta_perguntas').get();
  const perguntas = ps.docs.map((d) => ({ ...d.data(), id: d.id }))
    .map((p) => ({ id: p.id, empresaId: p.empresaId, email: p.email, pergunta: p.pergunta, motivo: p.motivo, visto: p.visto === true,
      criadoEm: p.criadoEm && typeof p.criadoEm.toDate === 'function' ? p.criadoEm.toDate().toISOString() : null }))
    .sort((a, b) => String(b.criadoEm || '').localeCompare(String(a.criadoEm || '')))
    .slice(0, 300);
  return { mes, modelo: MODELO, precoEntrada: PRECO_ENTRADA_USD_MTOK, precoSaida: PRECO_SAIDA_USD_MTOK, tetoPadraoUsd: TETO_PADRAO_USD, corretoras, perguntas };
}

async function marcarVista(id) {
  await db().collection('plataforma_beta_perguntas').doc(String(id || '')).update({ visto: true });
  return { ok: true };
}

module.exports = { beta, responder, executar, resumoPortal, marcarVista, _trocarIa, mesAtual, TETO_PADRAO_USD };
