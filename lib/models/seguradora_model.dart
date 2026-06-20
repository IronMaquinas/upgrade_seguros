import 'package:cloud_firestore/cloud_firestore.dart';

class Seguradora {
  String id;
  String nome;
  String telefone;
  String email;
  String contato;  // (pessoa de contato, não é uma lista, é apenas um nome)
  bool ativa;
  DateTime dataCriacao;

  Seguradora({
    this.id = '',
    required this.nome,
    this.telefone = '',
    this.email = '',
    this.contato = '',
    this.ativa = true,
    DateTime? dataCriacao,
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