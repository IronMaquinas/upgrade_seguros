// functions/modulos.js — Etapa 23: catálogo de módulos (espelho de lib/utils/modulos.dart)
//
// O verificador confere que os ids e as dependências são iguais nos dois lados.
// Sempre ligado (fora da lista): Início, Sinistros, Clientes e apólices,
// Configurações, Usuários e "Meu plano".

const MODULOS = [
  { id: 'assistencias', dependeDe: [] },
  { id: 'videos', dependeDe: [] },
  { id: 'oficinas', dependeDe: [] },
  { id: 'importar_contrato', dependeDe: [] },
  { id: 'tarefas', dependeDe: [] },
  { id: 'relatorios', dependeDe: [] },
  { id: 'relatorios_personalizados', dependeDe: [] },
  { id: 'nps', dependeDe: ['assistencias'] },
  { id: 'telegram', dependeDe: ['assistencias'] },
];

const POR_ID = new Map(MODULOS.map((m) => [m.id, m]));

/** Só ids que existem, sem os que dependem de um módulo desligado. */
function efetivos(marcados) {
  let r = new Set((marcados || []).filter((id) => POR_ID.has(id)));
  for (;;) {
    const antes = r.size;
    r = new Set([...r].filter((id) => POR_ID.get(id).dependeDe.every((d) => r.has(d))));
    if (r.size === antes) return r;
  }
}

/** null = tudo ligado (sem conta, ou plano "tudo ligado"). */
function ligadosDaConta(conta) {
  if (!conta) return null;
  const tipo = (conta.plano && conta.plano.tipo) || 'tudo_ligado';
  if (tipo === 'tudo_ligado') return null;
  return efetivos(Array.isArray(conta.modulos) ? conta.modulos : []);
}

/** O módulo está ligado para esta conta? */
const ligado = (conta, id) => {
  const l = ligadosDaConta(conta);
  return l === null || l.has(id);
};

module.exports = { MODULOS, efetivos, ligadosDaConta, ligado };
