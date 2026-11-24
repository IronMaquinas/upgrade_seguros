// functions/beta-interpretar.js — Etapa 28: Beta, o intérprete SEM IA
//
// Transforma a pergunta num pedido estruturado, só com padrões de texto:
//   { intencao, alvo, numero, numeroSeguradora, placa, cliente }
// intencao: contato · veiculo · status · pendencias · sinistros_cliente · dono_placa
// alvo (de quem): segurado · contato_segurado · motorista · terceiro ·
//                 contato_terceiro · motorista_terceiro · contato_local · oficina
//
// Quando a pergunta não traz o número, o servidor usa o ASSUNTO da conversa
// (último atendimento/cliente citado) — "e o telefone do terceiro?".
// Se as regras não bastarem, o servidor pergunta ao Haiku, que devolve este
// mesmo formato (functions/beta.js). Sem Firebase: testado em testes/beta.teste.js.

const INTENCOES = ['contato', 'veiculo', 'status', 'pendencias', 'sinistros_cliente', 'dono_placa'];
const ALVOS = ['segurado', 'contato_segurado', 'motorista', 'terceiro', 'contato_terceiro', 'motorista_terceiro', 'contato_local', 'oficina'];

const normalizar = (s) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/\s+/g, ' ').trim();

function numeroDoAtendimento(t) {
  const m = t.match(/\b(sn|as)\s?-?\s?(\d{14})\b/i);
  return m ? `${m[1].toUpperCase()}${m[2]}` : null;
}

function placaDe(t) {
  const m = t.match(/\b([a-z]{3})\s?-?\s?(\d[a-z0-9]\d{2})\b/i);
  return m ? `${m[1]}${m[2]}`.toUpperCase() : null;
}

/** De quem a pergunta fala (do mais específico para o mais geral). */
function alvoDe(t) {
  if (/contato (do |da )?terceir/.test(t)) return 'contato_terceiro';
  if (/(motorista|condutor) (do |da )?terceir/.test(t)) return 'motorista_terceiro';
  if (/terceir/.test(t)) return 'terceiro';
  if (/motorista|condutor/.test(t)) return 'motorista';
  if (/contato (no |do |de )?local|no local/.test(t)) return 'contato_local';
  // 28.1: "telefone de contato do X" = contato do segurado/cliente
  if (/(telefone|numero|fone|celular|whats\w*) de contato/.test(t)) return 'contato_segurado';
  if (/oficina/.test(t)) return 'oficina';
  if (/contato (do |da )?(segurad|client)/.test(t) || /\bcontato\b/.test(t) && !/telefone (do |da )?(segurad|client)/.test(t) && /(segurad|client)/.test(t)) return 'contato_segurado';
  if (/\b(bem|bens) segurad/.test(t)) return null; // 28.2: "bem segurado" é o veículo, não a pessoa
  if (/segurad|client/.test(t)) return 'segurado';
  return null;
}

function intencaoDe(t, placa) {
  if (placa && /de quem|dono|proprietari|qual cliente|qual segurado/.test(t)) return 'dono_placa';
  if (/(quais|lista|numeros?|todos) (os )?sinistros|sinistros (do|da|de) /.test(t)) return 'sinistros_cliente';
  if (/\b(sinistros|atendimentos|assistencias)\b/.test(t)) return 'sinistros_cliente'; // 28.1: "e os sinistros dele?"
  if (/pendent|pendencia|tarefa|\bacao\b|\bacoes\b|falta fazer/.test(t)) return 'pendencias';
  if (/status|situacao|andamento|como esta|em que pe/.test(t)) return 'status';
  if (/veiculo|carro|placa|modelo|chassi|marca|caminhao|moto\b|\b(bem|bens)( segurados?)?\b|frota/.test(t)) return 'veiculo'; // 28.2: "bem segurado", "frota"
  if (/telefone|fone|celular|whats|zap|ligar|contato|e-?mail|numero (do|da) (segurad|client|terceir|motorist|oficin)/.test(t)) return 'contato';
  return null;
}

/** Nome do cliente depois de "do cliente", "do segurado", "sinistros do/da". */
function clienteDe(t) {
  const m = t.match(/(?:sinistros|veiculos?|telefone|contato|apolices?)\s(?:do|da|de)\s(?:cliente\s|segurad[oa]\s)?(.+?)(?:\?|$)/)
    || t.match(/(?:cliente|segurad[oa])\s(?!do\b|da\b)(.+?)(?:\?|$)/);
  if (!m) return null;
  let nome = m[1].replace(/\b(sn|as)\d{14}\b/g, '').replace(/\b(do|da|de) sinistro.*$/, '').trim();
  // 28.1: tira o que sobrou da pergunta ("contato do", "cliente", "segurado"…) antes do nome
  const sobra = /^(contato|telefone|fone|celular|whatsapp|whats|zap|e-?mail|numero|cliente|segurad[oa])\s(?:(?:do|da|de)\s)?/;
  while (sobra.test(nome)) nome = nome.replace(sobra, '').trim();
  if (!nome || nome.length < 3 || /^(do|da|de|o|a)$/.test(nome)) return null;
  // 28.2: "que ele tem", "dele", "desse cliente" → é o cliente da conversa, não um nome
  if (/^(que|qual|quais|ele|ela|eles|dele|dela|deles|desse|dessa|deste|desta|esse|essa|este|esta|isso|tem|o mesmo|a mesma)\b/.test(nome)) return null;
  if (/^(sinistro|assistencia|terceiro|motorista)/.test(nome)) return null;
  return nome;
}

/**
 * @param {string} pergunta
 * @param {{intencao?:string}} assunto  conversa anterior (para "e do terceiro?")
 */
function interpretar(pergunta, assunto = {}) {
  const t = normalizar(pergunta);
  const numero = numeroDoAtendimento(t);
  const placa = numero ? null : placaDe(t);
  const seg = !numero && !placa ? (t.match(/\b(\d{6,})\b/) || [])[1] || null : null;
  const alvo = alvoDe(t);
  let intencao = intencaoDe(t, placa);
  // "e do terceiro?" — sem verbo: repete o que foi perguntado antes
  if (!intencao && alvo && assunto.intencao) intencao = assunto.intencao;
  const cliente = intencao === 'sinistros_cliente' || (!numero && !placa && !seg && !assunto.atendimentoId) ? clienteDe(t) : null;
  return { intencao, alvo, numero, numeroSeguradora: seg, placa, cliente };
}

/** As regras resolvem sozinhas? (senão, pergunta ao Haiku) */
function bastaSemIa(p, assunto = {}) {
  if (!p.intencao) return false;
  if (p.intencao === 'dono_placa') return !!p.placa;
  if (p.intencao === 'sinistros_cliente') return !!(p.cliente || assunto.clienteId);
  return !!(p.numero || p.numeroSeguradora || p.placa || p.cliente || assunto.atendimentoId || assunto.clienteId);
}

/** Confere o JSON que veio do Haiku (só aceita o catálogo). */
function validarDaIa(j) {
  if (!j || typeof j !== 'object') return null;
  const s = (v) => (typeof v === 'string' && v.trim() ? v.trim().slice(0, 120) : null);
  const intencao = INTENCOES.includes(j.intencao) ? j.intencao : null;
  return {
    intencao,
    alvo: ALVOS.includes(j.alvo) ? j.alvo : null,
    numero: s(j.numero) && /^(SN|AS)\d{14}$/i.test(j.numero.trim()) ? j.numero.trim().toUpperCase() : null,
    numeroSeguradora: s(j.numeroSeguradora),
    placa: s(j.placa) ? j.placa.replace(/[^a-z0-9]/gi, '').toUpperCase() : null,
    cliente: s(j.cliente) ? normalizar(j.cliente) : null,
  };
}

module.exports = { interpretar, bastaSemIa, validarDaIa, normalizar, INTENCOES, ALVOS };
