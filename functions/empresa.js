// functions/empresa.js — Etapa 16 (multi-tenant, preparação)
//
// Até a Etapa 15 os dados de todas as corretoras ficavam nas mesmas coleções da
// raiz do banco (sinistros/, assistencias/, clientes/ …). A partir da Etapa 16
// o app lê e grava dentro da pasta da corretora do usuário:
//
//   corretoras/{empresaId}/sinistros/…   corretoras/{empresaId}/clientes/… etc.
//
// migrarEmpresa (só administrador) faz a passagem:
//   { acao: 'diagnostico' } → o que existe hoje, sem mudar nada:
//       empresaId do administrador, empresaId de cada usuário, corretoras
//       cadastradas e, por coleção, quantos documentos há na raiz e na pasta.
//   { acao: 'copiar' } → COPIA cada documento da raiz para a pasta da corretora
//       do administrador (mesmo id; só os que ainda não existem lá), grava o
//       índice do NPS (nps_indice/{id}) e liga à corretora os usuários sem
//       empresaId. Pode rodar quantas vezes precisar: o que já foi copiado é
//       pulado. A raiz NÃO é apagada (fica de cópia de segurança até a 16b).

const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const cors = require('cors')({ origin: true });
const { usuarioAtivo } = require('./seguranca');

if (!admin.apps.length) admin.initializeApp();
const db = () => admin.firestore();

// Mesma lista de lib/services/empresa_atual.dart (EmpresaAtual.colecoes).
const COLECOES = [
  'sinistros',
  'assistencias',
  'clientes',
  'tasks',
  'workshops',
  'seguradoras',
  'sla_configs',
  'app_config',
  'nps_pesquisas',
  'avaliacoes',
  'pdf_signatures',
  'cotacoes',
  'employees',
];

async function contar(ref) {
  const r = await ref.count().get();
  return r.data().count;
}

async function diagnostico(empresa) {
  const usuarios = (await db().collection('users').get()).docs.map((d) => ({
    email: d.data().email || d.id,
    empresaId: d.data().empresaId || '',
  }));
  const corretoras = (await db().collection('corretoras').listDocuments()).map((r) => r.id);
  const colecoes = {};
  for (const c of COLECOES) {
    colecoes[c] = {
      raiz: await contar(db().collection(c)),
      naCorretora: await contar(db().collection('corretoras').doc(empresa).collection(c)),
    };
  }
  const cadastro = await db().collection('corretoras').doc(empresa).get();
  const migrada = cadastro.exists && cadastro.data().migradoEtapa16 === true;
  return { empresa, migrada, usuarios, corretoras, colecoes };
}

async function copiar(empresa) {
  const destino = db().collection('corretoras').doc(empresa);
  const relatorio = { empresa, colecoes: {}, indiceNps: 0, usuariosLigados: [], usuariosDeOutraEmpresa: [] };

  for (const c of COLECOES) {
    const origem = await db().collection(c).get();
    let copiados = 0;
    let jaExistiam = 0;
    let lote = db().batch();
    let noLote = 0;
    for (const d of origem.docs) {
      const alvo = destino.collection(c).doc(d.id);
      const atual = await alvo.get();
      if (atual.exists) {
        // app_config: ao abrir Configurações, o app novo cria a configuração
        // PADRÃO na pasta se ela não existir. Na primeira cópia, a da raiz
        // (a configuração real: SLA, gatilho, Telegram…) vale mais.
        if (c === 'app_config' && !atual.data()._migradoDaRaiz) {
          lote.set(alvo, { ...atual.data(), ...d.data(), _migradoDaRaiz: true });
          copiados++;
        } else {
          jaExistiam++;
          continue;
        }
      } else {
        lote.set(alvo, c === 'app_config' ? { ...d.data(), _migradoDaRaiz: true } : d.data());
        copiados++;
      }
      if (++noLote === 400) {
        await lote.commit();
        lote = db().batch();
        noLote = 0;
      }
    }
    if (noLote) await lote.commit();
    relatorio.colecoes[c] = { raiz: origem.size, copiados, jaExistiam };
  }

  // Índice do NPS: o cliente responde sem login e o servidor precisa achar a corretora.
  const pesquisas = await destino.collection('nps_pesquisas').get();
  for (const p of pesquisas.docs) {
    const ref = db().collection('nps_indice').doc(p.id);
    if (!(await ref.get()).exists) {
      await ref.set({ empresaId: empresa, criadoEm: admin.firestore.FieldValue.serverTimestamp() });
      relatorio.indiceNps++;
    }
  }

  // Usuários sem empresa → corretora do administrador. Os de outra empresa só são listados.
  const usuarios = await db().collection('users').get();
  for (const u of usuarios.docs) {
    const e = String(u.data().empresaId || '').trim();
    if (!e) {
      await u.ref.update({ empresaId: empresa });
      relatorio.usuariosLigados.push(u.data().email || u.id);
    } else if (e !== empresa) {
      relatorio.usuariosDeOutraEmpresa.push({ email: u.data().email || u.id, empresaId: e });
    }
  }
  // Marca a corretora como migrada: o app (PortaoEmpresa) só libera as telas
  // depois disso — evita alguém trabalhar com a pasta ainda vazia.
  const cad = db().collection('corretoras').doc(empresa);
  const atual = await cad.get();
  await cad.set({
    ...(atual.exists ? atual.data() : {}),
    migradoEtapa16: true,
    migradoEm: admin.firestore.FieldValue.serverTimestamp(),
  });
  return relatorio;
}

exports.migrarEmpresa = onRequest({ timeoutSeconds: 540, memory: '1GiB' }, (req, res) =>
  cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Método não permitido');
    try {
      const quem = await usuarioAtivo(req);
      if (!quem) return res.status(401).json({ erro: 'Faça login novamente' });
      if (quem.role !== 'admin') return res.status(403).json({ erro: 'Só administradores' });
      const empresa = String(quem.dados.empresaId || '').trim();
      if (!empresa || empresa.includes('/')) {
        return res.status(400).json({
          erro: 'O seu usuário (administrador) não tem empresaId no cadastro. Preencha users/{seu uid}.empresaId no console antes.',
        });
      }
      const acao = (req.body || {}).acao;
      if (acao === 'diagnostico') return res.json(await diagnostico(empresa));
      if (acao === 'copiar') {
        const r = await copiar(empresa);
        logger.info(`migrarEmpresa: cópia para ${empresa} feita por ${quem.email}`, r);
        return res.json(r);
      }
      return res.status(400).json({ erro: "acao deve ser 'diagnostico' ou 'copiar'" });
    } catch (e) {
      logger.error(e);
      return res.status(500).json({ erro: 'Erro interno' });
    }
  }),
);

exports.COLECOES = COLECOES;
