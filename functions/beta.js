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
      return { id: d.id, colecao: c, ...d.data() };
    }
  }
  return null;
}
async function atendimentoPorId(e, id) {
  for (const c of ['sinistros', 'assistencias']) {
    const d = await col(e, c).doc(id).get();
    if (d.exists) return { id: d.id, colecao: c, ...d.data() };
  }
  return null;
}
async function cliente(e, id) {
  if (!id) return null;
  const d = await col(e, 'clientes').doc(id).get();
  return d.exists ? { id: d.id, ...d.data() } : null;
}
async function clientesPorNome(e, nome) {
  // 28.1: palavras da pergunta que não fazem parte do nome não podem atrapalhar a busca
  const ignorar = ['do', 'da', 'de', 'dos', 'das', 'e', 'o', 'a', 'contato', 'telefone', 'fone', 'celular', 'whatsapp', 'email', 'cliente', 'segurado', 'segurada', 'numero', 'qual'];
  const partes = normalizar(nome).split(' ').filter((p) => p.length > 1 && !ignorar.includes(p));
  if (!partes.length) return [];
  const s = await col(e, 'clientes').get();
  return s.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((c) => { const n = normalizar(c.nome); return partes.every((p) => n.includes(p)); })
    .slice(0, 6);
}

// ── respostas por intenção ──────────────────────────────────────────────────
function respostaContato(alvo, at, cli) {
  const a = alvo || 'segurado';
  if (a === 'segurado') {
    return [pessoa('Segurado', (at && at.client_nome) || (cli && cli.nome), (at && at.telefone_cliente) || (cli && cli.contato_telefone), cli && cli.email)];
  }
  if (a === 'contato_segurado') {
    if (at && (at.nomeContatoSinistro || at.telefoneContatoSinistro)) return [pessoa('Contato do segurado (neste atendimento)', at.nomeContatoSinistro, at.telefoneContatoSinistro)];
    return [pessoa('Contato do segurado', cli && cli.contato, cli && cli.contato_telefone, cli && cli.email)];
  }
  if (!at) return null; // os demais dependem de um atendimento
  if (a === 'contato_local') return [pessoa('Contato no local', at.nome_contato, at.telefone_contato_local)];
  if (a === 'oficina') return [pessoa('Oficina', [at.nome_oficina, at.nome_contato_oficina && `Contato: ${at.nome_contato_oficina}`].filter(Boolean).join(' · '), at.telefone_contato_oficina, null, [at.endereco_oficina])];
  if (a === 'motorista') {
    const v = at.veiculo_selecionado || {};
    return [pessoa('Motorista do segurado', v.nomeCondutorMotorista || v.nomeCondutor, null, null, [v.cpfCondutorMotorista && `CPF: ${v.cpfCondutorMotorista}`, v.cnhCondutorMotorista && `CNH: ${v.cnhCondutorMotorista}`, 'Telefone do motorista não é cadastrado no sinistro.'])];
  }
  const ts = Array.isArray(at.terceiros) ? at.terceiros : [];
  if (!ts.length) return [{ titulo: 'Terceiros', linhas: ['Este atendimento não tem terceiros cadastrados.'], acoes: [], vazio: true }];
  return ts.map((t, i) => {
    const n = ts.length > 1 ? ` ${i + 1}` : '';
    if (a === 'contato_terceiro') return pessoa(`Contato do terceiro${n}`, t.nomeContatoTerceiro, t.telefoneContatoTerceiro);
    if (a === 'motorista_terceiro') {
      return t.motoristaMesmoProprietario
        ? pessoa(`Motorista do terceiro${n} (o próprio dono)`, t.nome, t.contato, t.email)
        : pessoa(`Motorista do terceiro${n}`, t.nomeMotorista, t.telefoneMotorista, t.emailMotorista);
    }
    return pessoa(`Terceiro${n}`, t.nome, t.contato, t.email, [t.placa && `Placa: ${t.placa}`]);
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
  const vs = (cli && Array.isArray(cli.veiculos_segurados) ? cli.veiculos_segurados : []).slice(0, 10);
  if (vs.length) return vs.map((v, i) => ({ titulo: `Veículo ${i + 1} de ${cli.nome}`, linhas: linhasV(v), acoes: [] }));
  return null;
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

async function executar(e, p, assunto) {
  if (!p || !p.intencao) return { ...FORA('fora_do_escopo'), assunto };

  // dono da placa
  if (p.intencao === 'dono_placa') {
    const s = await col(e, 'clientes').get();
    const achados = s.docs.map((d) => ({ id: d.id, ...d.data() }))
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
    const c = s.docs.map((d) => ({ id: d.id, ...d.data() })).find((x) => (x.veiculos_segurados || []).some((v) => String(v.placa || '').replace(/[^a-z0-9]/gi, '').toUpperCase() === p.placa));
    if (c) cli = c;
  }
  if (!at && !cli) {
    if (assunto.atendimentoId) at = await atendimentoPorId(e, assunto.atendimentoId);
    else if (assunto.clienteId) cli = await cliente(e, assunto.clienteId);
  }
  if (!at && !cli) return { ...FORA('sem_assunto', 'De qual sinistro ou cliente? Me diga o número (SN… / AS…) ou o nome do cliente.'), assunto: { ...assunto, pendente: { intencao: p.intencao, alvo: p.alvo } } };
  if (at && !cli) cli = await cliente(e, at.id_cliente);

  const novoAssunto = at
    ? { atendimentoId: at.id, clienteId: at.id_cliente || null, rotulo: rotuloAt(at), intencao: p.intencao }
    : { atendimentoId: null, clienteId: cli.id, rotulo: `Cliente ${cli.nome}`, intencao: p.intencao };

  switch (p.intencao) {
    case 'contato': {
      const itens = respostaContato(p.alvo, at, cli);
      if (!itens) return { ...FORA('nao_encontrado', 'Para isso eu preciso de um sinistro ou assistência. Qual o número?'), assunto: novoAssunto };
      const tudoVazio = itens.every((i) => i.vazio);
      return { texto: tudoVazio ? 'Não há telefone nem e-mail cadastrados para isso.' : (at ? rotuloAt(at) : cli.nome), itens, acoes: at ? [abrir(at)] : [], assunto: novoAssunto };
    }
    case 'veiculo': {
      const itens = respostaVeiculo(p.alvo, at, cli);
      if (!itens) return { ...FORA('nao_encontrado', 'Não há veículo cadastrado para isso.'), assunto: novoAssunto };
      return { texto: at ? rotuloAt(at) : cli.nome, itens, assunto: novoAssunto };
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
      const lista = [];
      for (const nome of ['sinistros', 'assistencias']) {
        const s = await col(e, nome).where('id_cliente', '==', c.id).get();
        s.docs.forEach((d) => lista.push({ id: d.id, ...d.data() }));
      }
      lista.sort((a, b) => String(b.numero_sinistro || '').localeCompare(String(a.numero_sinistro || '')));
      return {
        texto: lista.length ? `${c.nome}: ${lista.length} atendimento(s).` : `${c.nome} não tem sinistros nem assistências.`,
        itens: lista.slice(0, 15).map((x) => ({ titulo: `${x.tipo === 'assistencia' ? 'Assistência' : 'Sinistro'} ${x.numero_sinistro || ''}`, linhas: [`Status: ${x.status_atual || x.status || '—'}`, x.data_abertura && `Aberto em ${dataBr(x.data_abertura)}`].filter(Boolean), acoes: [abrir(x)] })),
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
  const perguntas = ps.docs.map((d) => ({ id: d.id, ...d.data() }))
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
