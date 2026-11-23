// lib/services/empresa_atual.dart
//
// Etapa 16 — multi-tenant (preparação).
//
// Cada corretora (empresa) passa a ter os próprios dados numa "pasta" do banco:
//
//   corretoras/{empresaId}                 ← cadastro da corretora (já existia)
//   corretoras/{empresaId}/sinistros/…     ← antes: sinistros/… (raiz)
//   corretoras/{empresaId}/assistencias/…  ← antes: assistencias/…
//   … (mesma coisa para as demais coleções da lista [colecoes])
//
// Ficam na raiz, compartilhados: users/ (cadastro de login, com o empresaId
// de cada um) e corretoras/ (o cadastro de cada corretora).
//
// Por que pastas e não um campo "empresaId" em cada documento: com pastas as
// consultas do app continuam iguais e os índices do Firestore continuam
// valendo (o Firestore indexa pelo NOME da coleção, não pelo caminho). Com um
// campo, cada consulta com filtro/ordenação precisaria de um índice composto
// novo — e cada índice esquecido quebraria uma tela.
//
// O empresaId do usuário logado é lido UMA vez (users/{uid}.empresaId) por
// [carregar], chamado antes do Dashboard. Depois disso [col] é síncrono.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmpresaNaoDefinida implements Exception {
  final String mensagem;
  const EmpresaNaoDefinida(this.mensagem);
  @override
  String toString() => mensagem;
}

class EmpresaAtual {
  EmpresaAtual._();

  /// Coleções que pertencem a uma corretora (ficam dentro de corretoras/{id}/).
  /// A Function migrarEmpresa (functions/empresa.js) usa a MESMA lista.
  static const colecoes = <String>[
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
    'modelos_relatorio', // Etapa 19b: modelos de relatório da corretora
  ];

  static String? _id;
  static Future<String>? _carregando;

  /// empresaId do usuário logado. Lança StateError se [carregar] ainda não rodou.
  static String get id {
    final v = _id;
    if (v == null) {
      throw StateError('EmpresaAtual.carregar() não foi chamado antes de acessar o banco');
    }
    return v;
  }

  static bool get carregada => _id != null;

  /// Lê users/{uid}.empresaId do usuário logado (uma vez por sessão).
  static Future<String> carregar({bool forcar = false}) {
    if (_id != null && !forcar) return Future.value(_id!);
    return _carregando ??= _ler().whenComplete(() => _carregando = null);
  }

  static Future<String> _ler() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw const EmpresaNaoDefinida('Faça login novamente.');
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final e = (doc.data()?['empresaId'] as String?)?.trim() ?? '';
    if (e.isEmpty) {
      throw const EmpresaNaoDefinida(
        'Seu usuário não está ligado a nenhuma corretora. Peça ao administrador para conferir o seu cadastro.',
      );
    }
    _id = e;
    return e;
  }

  /// Ao sair (logout).
  static void limpar() {
    _id = null;
    _carregando = null;
  }

  /// corretoras/{empresaId}
  static DocumentReference<Map<String, dynamic>> get doc =>
      FirebaseFirestore.instance.collection('corretoras').doc(id);

  /// corretoras/{empresaId}/{nome}
  static CollectionReference<Map<String, dynamic>> col(String nome) {
    assert(colecoes.contains(nome), 'Coleção "$nome" não está na lista de coleções da corretora');
    return doc.collection(nome);
  }
}
