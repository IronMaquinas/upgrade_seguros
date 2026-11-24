// functions/testes/plataforma.teste.js — Etapa 21: portal da plataforma
// Rodar: cd functions && node testes/plataforma.teste.js
const F = require('./firebase-falso');
F.instalar();
const { plataforma } = require('../plataforma');
const { store, tokens, chamar } = F;
const t = F.placar();

(async () => {
  // corretora com dados, usuário comum, admin da plataforma
  store['corretoras/C1'] = { nome: 'Upgrade Seguros', cnpj: '54.885.154/0001-37' };
  store['corretoras/C1/sinistros/s1'] = { seguradora: 'AXA' };
  store['corretoras/C1/sinistros/s2'] = { seguradora: 'AXA' };
  store['users/u1'] = { empresaId: 'C1', role: 'admin' };
  store['corretoras/C2/clientes/x'] = { nome: 'só subcoleção' }; // sem documento de cadastro
  tokens.tUsuario = 'u1';
  tokens.tUsuarioComMarca = { uid: 'u1', marcas: { plataforma: true } };
  tokens.tAdmin = { uid: 'adm', marcas: { plataforma: true } };
  tokens.tSemRegistro = { uid: 'adm2', marcas: { plataforma: true } };
  tokens.tDesligado = { uid: 'adm3', marcas: { plataforma: true } };
  store['plataforma_admins/adm'] = { email: 'adm@x.com', ativo: true };
  store['plataforma_admins/adm3'] = { email: 'adm3@x.com', ativo: false };

  // quem NÃO entra
  t.ok((await chamar(plataforma, { acao: 'eu' })).code === 403, 'sem login: 403');
  t.ok((await chamar(plataforma, { acao: 'eu' }, 'tUsuario')).code === 403, 'usuário de corretora: 403');
  t.ok((await chamar(plataforma, { acao: 'eu' }, 'tUsuarioComMarca')).code === 403, 'usuário de corretora mesmo com a marca: 403');
  t.ok((await chamar(plataforma, { acao: 'eu' }, 'tSemRegistro')).code === 403, 'marca sem plataforma_admins: 403');
  t.ok((await chamar(plataforma, { acao: 'eu' }, 'tDesligado')).code === 403, 'admin desligado: 403');

  // admin
  const eu = await chamar(plataforma, { acao: 'eu', entrada: true }, 'tAdmin');
  t.ok(eu.code === 200 && eu.body.email === 'adm@x.com', 'admin entra');
  const aud1 = Object.keys(store).filter((k) => k.startsWith('plataforma_auditoria/'));
  t.ok(aud1.length === 1 && store[aud1[0]].acao === 'entrada', 'entrada registrada na auditoria');

  const r = await chamar(plataforma, { acao: 'corretoras' }, 'tAdmin');
  const c1 = r.body.corretoras.find((c) => c.id === 'C1');
  const c2 = r.body.corretoras.find((c) => c.id === 'C2');
  t.ok(r.body.corretoras.length === 2, 'lista as 2 corretoras (inclusive a sem cadastro)');
  t.ok(c1.nome === 'Upgrade Seguros' && c1.sinistros === 2 && c1.usuarios === 1 && c1.conta === null, 'contagens e conta ausente');
  t.ok(c2.nome === '(sem cadastro)' && c2.clientes === 1, 'corretora só com subcoleção');

  const cr = await chamar(plataforma, { acao: 'criarContasQueFaltam' }, 'tAdmin');
  t.ok(cr.body.criadas.length === 2, 'cria as contas que faltam');
  t.ok(store['plataforma_contas/C1'].situacao === 'ativa' && store['plataforma_contas/C1'].cortesia === true, 'conta ativa, cortesia');
  t.ok(Object.keys(store).some((k) => k.startsWith('plataforma_contas/C1/historico/')), 'histórico da conta');
  const cr2 = await chamar(plataforma, { acao: 'criarContasQueFaltam' }, 'tAdmin');
  t.ok(cr2.body.criadas.length === 0, 'rodar de novo não duplica');

  const r2 = await chamar(plataforma, { acao: 'corretoras' }, 'tAdmin');
  t.ok(r2.body.corretoras.find((c) => c.id === 'C1').conta.plano.tipo === 'tudo_ligado', 'lista mostra a conta');

  const a = await chamar(plataforma, { acao: 'auditoria' }, 'tAdmin');
  t.ok(a.body.acoes.some((x) => x.acao === 'contas_criadas'), 'auditoria lista a criação das contas');
  t.ok((await chamar(plataforma, { acao: 'xyz' }, 'tAdmin')).code === 400, 'ação desconhecida: 400');

  // dados das corretoras não foram tocados
  t.ok(store['corretoras/C1/sinistros/s1'].seguradora === 'AXA', 'não mexe nos dados da corretora');
  t.fim();
})();
