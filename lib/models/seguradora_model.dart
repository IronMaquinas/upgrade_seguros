import 'package:cloud_firestore/cloud_firestore.dart';

class Seguradora {
  String id;
  String nome;
  String telefone;
  String email;
  String contato;  // (pessoa de contato, não é uma lista, é apenas um nome)
  bool ativa;
  DateTime dataCriacao;

  // Etapa 22: catálogo único de seguradoras.
  /// Id em catalogo_seguradoras (vazio = só no cadastro desta corretora).
  String catalogoId;
  /// Sugerida por esta corretora, aguardando aprovação da plataforma (não é gravado).
  bool pendente;
  /// CNPJ do catálogo (não é gravado no cadastro da corretora).
  String cnpj;
  /// No cadastro da corretora, mas sem entrada no catálogo (não é gravado).
  bool foraDoCatalogo = false;

  Seguradora({
    this.id = '',
    required this.nome,
    this.telefone = '',
    this.email = '',
    this.contato = '',
    this.ativa = true,
    DateTime? dataCriacao,
    this.catalogoId = '',
    this.pendente = false,
    this.cnpj = '',
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  /// Converte para Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'contato': contato,
      'ativa': ativa,
      'data_criacao': Timestamp.fromDate(dataCriacao),
      if (catalogoId.isNotEmpty) 'catalogoId': catalogoId, // Etapa 22
    };
  }

  /// Cria Seguradora a partir de Map do Firestore
  factory Seguradora.fromMap(Map<String, dynamic> map) {
    return Seguradora(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
      email: map['email'] ?? '',
      contato: map['contato'] ?? '',
      ativa: map['ativa'] ?? true,
      dataCriacao: (map['data_criacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
      catalogoId: (map['catalogoId'] ?? '') as String,
    );
  }

  /// Cria Seguradora a partir de DocumentSnapshot
  factory Seguradora.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Seguradora.fromMap({
      ...data,
      'id': doc.id,
    });
  }

  @override
  String toString() => 'Seguradora(id: $id, nome: $nome, ativa: $ativa)';
}