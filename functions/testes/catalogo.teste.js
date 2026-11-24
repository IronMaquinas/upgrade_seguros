// functions/testes/catalogo.teste.js — Etapa 22: catálogo global de seguradoras
// Rodar: cd functions && node testes/catalogo.teste.js
const F = require('./firebase-falso');
F.instalar();
const cat = require('../catalogo');
const { plataforma } = require('../plataforma');
const { store, tokens, chamar } = F;
const t = F.placar();

// CNPJ válido a partir de 12 dígitos
function comDv(base) {
  const dv = (b, pesos) => { const r = pesos.reduce((s, p, i) => s + Number(b[i]) * p, 0) % 11; return r < 2 ? 0 : 11 - r; };
  const d1 = dv(base, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
  return base + d1 + dv(base + d1, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
}
const CNPJ_MAPFRE = comDv('612230880001');
const CNPJ_XYZ = comDv('112223330001');
const CNPJ_AXA = comDv('445556660001');
const CNPJ_NAO_EXISTE = comDv('998887770001');

// Receita de mentira
const receita = {
  [CNPJ_MAPFRE]: { razao_social: 'MAPFRE SEGUROS GERAIS S.A.', nome_fantasia: 'MAPFRE', descricao_situacao_cadastral: 'ATIVA' },
  [CNPJ_XYZ]: { razao_social: 'XYZ SEGURADORA S.A.', nome_fantasia: '', descricao_situacao_cadastral: 'ATIVA' },
  [CNPJ_AXA]: { razao_social: 'AXA SEGUROS S.A.', nome_fantasia: 'AXA SEGUROS', descricao_situacao_cadastral: 'ATIVA' },
};
global.fetch = async (url) => {
  const c = url.split('/').pop();
  if (!receita[c]) return { status: 404, json: async () => ({}) };
  return { status: 200, json: async () => receita[c] };
};

// pref termina em '/': pega só os documentos desse nível (não os das subcoleções)
const pegar = (pref) => Object.keys(store).filter((k) => k.startsWith(pref) && k.split('/').length === pref.split('/').length);
const doCatalogo = (nome) => {
  const k = pegar('catalogo_seguradoras/').find((x) => store[x].nome === nome);
  return k ? { id: k.split('/')[1], ...store[k] } : null;
};

(async () => {
  // regras de nome e CNPJ
  t.ok(cat.chave('Chubb Seguros S.A.') === 'CHUBB' && cat.chave('chubb') === 'CHUBB', 'chave: Chubb Seguros S.A. = chubb');
  t.ok(cat.chave('Porto Seguro') === 'PORTO SEGURO', 'chave: Porto Seguro fica');
  t.ok(cat.chave('Seguradora Líder') === 'SEGURADORA LIDER', 'chave: sem acento');
  t.ok(cat.cnpjValido(CNPJ_MAPFRE) && !cat.cnpjValido('11111111111111') && !cat.cnpjValido('123'), 'CNPJ: dígitos verificadores');

  // três corretoras com cadastro e registros
  store['corretoras/C1'] = { nome: 'Upgrade' };
  store['corretoras/C1/seguradoras/a'] = { nome: 'AXA', telefone: '0800', ativa: true };
  store['corretoras/C1/seguradoras/b'] = { nome: 'Chubb', ativa: true };
  store['corretoras/C1/sinistros/s1'] = { seguradora: 'Chubb' };
  store['corretoras/C2'] = { nome: 'Outra' };
  store['corretoras/C2/seguradoras/x'] = { nome: 'CHUBB SEGUROS', ativa: true };
  store['corretoras/C2/sinistros/s1'] = { seguradora: 'CHUBB SEGUROS' };
  store['corretoras/C2/clientes/k1'] = { nome: 'Cli', apolices: [{ numero: '1', seguradora: 'CHUBB SEGUROS' }, { numero: '2', seguradora: 'AXA' }] };
  store['corretoras/C3'] = { nome: 'Terceira' };
  store['corretoras/C3/seguradoras/y'] = { nome: 'Chubb', ativa: false };
  store['users/u1'] = { empresaId: 'C1', role: 'user' };
  store['users/u2'] = { empresaId: 'C2', role: 'admin' };
  tokens.t1 = 'u1';
  tokens.t2 = 'u2';
  tokens.tAdm = { uid: 'adm', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };

  // antes de montar o catálogo, a corretora não consegue sugerir (a lista dela ficaria só com a pendente)
  t.ok((await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: CNPJ_MAPFRE, nome: 'MAPFRE' }, 't1')).code === 409, 'catálogo vazio: sugerir dá 409');
  t.ok(pegar('catalogo_seguradoras/').length === 0, 'catálogo vazio: nada criado');

  // ── importar ──
  const imp = await chamar(plataforma, { acao: 'catalogoImportar' }, 'tAdm');
  t.ok(imp.code === 200 && imp.body.criadas === 2, 'importar: 2 entradas (AXA, Chubb)');
  const chubb = doCatalogo('Chubb');
  t.ok(chubb && chubb.situacao === 'aprovada' && chubb.apelidos.includes('CHUBB SEGUROS'), 'grafia mais usada vira o nome; a outra, apelido');
  t.ok(store['corretoras/C2/sinistros/s1'].seguradora === 'Chubb', 'registros da outra corretora passam para o nome do catálogo');
  t.ok(store['corretoras/C2/clientes/k1'].apolices[0].seguradora === 'Chubb' && store['corretoras/C2/clientes/k1'].apolices[1].seguradora === 'AXA', 'apólices também (só a que mudou)');
  t.ok(store['corretoras/C2/seguradoras/x'].nome === 'Chubb' && store['corretoras/C2/seguradoras/x'].catalogoId === chubb.id, 'cadastro da corretora renomeado e vinculado');
  t.ok(store['corretoras/C1/seguradoras/a'].catalogoId === doCatalogo('AXA').id && store['corretoras/C1/seguradoras/a'].telefone === '0800', 'vincula sem perder o telefone');
  t.ok(store['corretoras/C3/seguradoras/y'].ativa === false && store['corretoras/C3/seguradoras/y'].catalogoId === chubb.id, '"não trabalho com essa" continua');
  const imp2 = await chamar(plataforma, { acao: 'catalogoImportar' }, 'tAdm');
  t.ok(imp2.body.criadas === 0 && pegar('catalogo_seguradoras/').length === 2, 'importar de novo não duplica');

  // ── corretora: consultar e sugerir ──
  t.ok((await chamar(cat.catalogoSeguradoras, { acao: 'consultarCnpj', cnpj: CNPJ_MAPFRE })).code === 403, 'sem login: 403');
  t.ok((await chamar(cat.catalogoSeguradoras, { acao: 'consultarCnpj', cnpj: '123' }, 't1')).code === 400, 'CNPJ inválido: 400');
  t.ok((await chamar(cat.catalogoSeguradoras, { acao: 'consultarCnpj', cnpj: CNPJ_NAO_EXISTE }, 't1')).code === 404, 'CNPJ fora da Receita: 404');
  const cons = await chamar(cat.catalogoSeguradoras, { acao: 'consultarCnpj', cnpj: CNPJ_MAPFRE }, 't1');
  t.ok(cons.body.receita && cons.body.receita.nomeFantasia === 'MAPFRE' && cons.body.receita.razaoSocial.startsWith('MAPFRE'), 'consulta devolve os nomes da Receita');

  const sug = await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: CNPJ_MAPFRE, nome: 'mapfre' }, 't1');
  t.ok(sug.code === 200 && sug.body.existente === false && sug.body.seguradora.situacao === 'pendente' && sug.body.seguradora.nome === 'MAPFRE', 'sugerir: pendente com o nome OFICIAL');
  const mapfre = doCatalogo('MAPFRE');
  t.ok(mapfre.criadaPor.empresaId === 'C1' && mapfre.cnpj === CNPJ_MAPFRE, 'pendente guarda quem sugeriu e o CNPJ');
  const sugInventado = await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: CNPJ_XYZ, nome: 'NOME INVENTADO' }, 't1');
  t.ok(sugInventado.body.seguradora.nome === 'XYZ SEGURADORA S.A.', 'nome que não é da Receita é trocado pelo oficial');
  const sugDeNovo = await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: CNPJ_MAPFRE, nome: 'MAPFRE' }, 't1');
  t.ok(sugDeNovo.body.existente === true && pegar('catalogo_seguradoras/').length === 4, 'mesmo CNPJ de novo: devolve a existente');
  t.ok((await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: CNPJ_MAPFRE, nome: 'MAPFRE' }, 't2')).code === 409, 'pendente de outra corretora: 409, sem duplicar');
  const sugAxa = await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: CNPJ_AXA, nome: 'AXA SEGUROS' }, 't2');
  t.ok(sugAxa.body.existente === true && sugAxa.body.seguradora.nome === 'AXA', 'nome parecido com uma aprovada: usa a aprovada');

  // ── portal ──
  const lista = await chamar(plataforma, { acao: 'catalogo' }, 'tAdm');
  const pm = lista.body.seguradoras.find((x) => x.nome === 'MAPFRE');
  t.ok(pm && pm.situacao === 'pendente' && pm.criadaPor.corretora === 'Upgrade' && pm.cnpj.includes('/'), 'portal lista a pendente com a corretora e o CNPJ formatado');

  store['corretoras/C1/sinistros/s2'] = { seguradora: 'MAPFRE' };
  const apr = await chamar(plataforma, { acao: 'catalogoAprovar', id: mapfre.id, nome: 'Mapfre' }, 'tAdm');
  t.ok(apr.code === 200 && store[`catalogo_seguradoras/${mapfre.id}`].situacao === 'aprovada', 'aprovar');
  t.ok(store['corretoras/C1/sinistros/s2'].seguradora === 'Mapfre', 'aprovar com outro nome troca nos registros');
  t.ok(store[`catalogo_seguradoras/${mapfre.id}`].apelidos.length === 0, 'só caixa diferente (MAPFRE × Mapfre) não precisa de apelido');

  const conflito = await chamar(plataforma, { acao: 'catalogoEditar', id: chubb.id, nome: 'axa' }, 'tAdm');
  t.ok(conflito.code === 409, 'renomear para nome de outra: 409');
  const ren = await chamar(plataforma, { acao: 'catalogoEditar', id: chubb.id, nome: 'Chubb Seguros' }, 'tAdm');
  t.ok(ren.code === 200 && store['corretoras/C1/sinistros/s1'].seguradora === 'Chubb Seguros' && store['corretoras/C2/sinistros/s1'].seguradora === 'Chubb Seguros', 'renomear troca em todas as corretoras');
  t.ok(store[`catalogo_seguradoras/${chubb.id}`].apelidos.includes('Chubb'), 'nome antigo vira apelido');
  t.ok((await chamar(plataforma, { acao: 'catalogoEditar', id: chubb.id, cnpj: '123' }, 'tAdm')).code === 400, 'CNPJ inválido na edição: 400');
  await chamar(plataforma, { acao: 'catalogoEditar', id: chubb.id, cnpj: CNPJ_AXA, susep: '01234', ativa: false }, 'tAdm');
  t.ok(store[`catalogo_seguradoras/${chubb.id}`].situacao === 'inativa' && store[`catalogo_seguradoras/${chubb.id}`].susep === '01234', 'editar CNPJ/SUSEP e desativar');
  await chamar(plataforma, { acao: 'catalogoEditar', id: chubb.id, ativa: true }, 'tAdm');
  t.ok(store[`catalogo_seguradoras/${chubb.id}`].situacao === 'aprovada', 'reativar');

  // pendente em uso → recusar não deixa; juntar resolve
  const xyz = doCatalogo('XYZ SEGURADORA S.A.');
  store['corretoras/C1/assistencias/a1'] = { seguradora: 'XYZ SEGURADORA S.A.' };
  const uso = await chamar(plataforma, { acao: 'catalogoUso', id: xyz.id }, 'tAdm');
  t.ok(uso.body.total === 1 && uso.body.assistencias === 1, 'uso conta os registros');
  t.ok((await chamar(plataforma, { acao: 'catalogoRecusar', id: xyz.id, motivo: 'x' }, 'tAdm')).code === 409, 'recusar em uso: 409');
  const axa = doCatalogo('AXA');
  const jun = await chamar(plataforma, { acao: 'catalogoJuntar', de: xyz.id, para: axa.id }, 'tAdm');
  t.ok(jun.code === 200 && store['corretoras/C1/assistencias/a1'].seguradora === 'AXA', 'juntar troca nos registros');
  t.ok(store[`catalogo_seguradoras/${xyz.id}`].situacao === 'juntada' && store[`catalogo_seguradoras/${axa.id}`].apelidos.includes('XYZ SEGURADORA S.A.'), 'juntada vira apelido da certa');
  t.ok(store[`catalogo_seguradoras/${axa.id}`].cnpj === CNPJ_XYZ || store[`catalogo_seguradoras/${axa.id}`].cnpj === '', 'CNPJ: herda se a certa não tinha');

  // pendente sem uso → recusar
  const sugAxa2 = await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: comDv('556667770001'), nome: 'x' }, 't1');
  t.ok(sugAxa2.code === 404, 'CNPJ desconhecido não cria nada');
  receita[comDv('556667770001')] = { razao_social: 'NOVA SEG S.A.', nome_fantasia: 'NOVA SEG' };
  const nova = await chamar(cat.catalogoSeguradoras, { acao: 'sugerir', cnpj: comDv('556667770001'), nome: 'NOVA SEG' }, 't1');
  const rec = await chamar(plataforma, { acao: 'catalogoRecusar', id: nova.body.seguradora.id, motivo: 'não é seguradora' }, 'tAdm');
  t.ok(rec.code === 200 && store[`catalogo_seguradoras/${nova.body.seguradora.id}`].situacao === 'recusada', 'recusar sem uso');

  const acoes = pegar('plataforma_auditoria/').map((k) => store[k].acao);
  t.ok(['catalogo_importado', 'seguradora_aprovada', 'seguradora_editada', 'seguradoras_juntadas', 'seguradora_recusada'].every((a) => acoes.includes(a)), 'tudo na auditoria');
  t.ok((await chamar(plataforma, { acao: 'catalogo' }, 't1')).code === 403, 'usuário de corretora não usa as ações do portal');
  t.fim();
})();
