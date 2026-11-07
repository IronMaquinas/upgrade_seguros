// lib/models/corretora_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Corretora {
  String id;
  String nome;
  String telefone;
  String email;
  String? logo; // URL da logo
  String? endereco;
  String? cnpj;
  bool ativa;
  DateTime dataCriacao;

  Corretora({
    this.id = '',
    required this.nome,
    this.telefone = '',
    this.email = '',
    this.logo,
    this.endereco,
    this.cnpj,
    this.ativa = true,
    DateTime? dataCriacao,
  }) : dataCriacao = dataCriacao ?? DateTime.now();

  /// Converte para Map para salvar no Firestore
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'telefone': telefone,
      'email': email,
      'logo': logo,
      'endereco': endereco,
      'cnpj': cnpj,
      'ativa': ativa,
      'dataCriacao': Timestamp.fromDate(dataCriacao),
    };
  }

  /// Cria Corretora a partir de Map do Firestore
  factory Corretora.fromMap(Map<String, dynamic> map, String id) {
    return Corretora(
      id: id,
      nome: map['nome'] ?? '',
      telefone: map['telefone'] ?? '',
      email: map['email'] ?? '',
      logo: map['logo'],
      endereco: map['endereco'],
      cnpj: map['cnpj'],
      ativa: map['ativa'] ?? true,
      dataCriacao: (map['dataCriacao'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Cria Corretora a partir de DocumentSnapshot
  factory Corretora.fromFirestore(DocumentSnapshot doc) {
    return Corretora.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Cria uma cópia com alterações
  Corretora copyWith({
    String? id,
    String? nome,
    String? telefone,
    String? email,
    String? logo,
    String? endereco,
    String? cnpj,
    bool? ativa,
    DateTime? dataCriacao,
  }) {
    return Corretora(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      logo: logo ?? this.logo,
      endereco: endereco ?? this.endereco,
      cnpj: cnpj ?? this.cnpj,
      ativa: ativa ?? this.ativa,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  @override
  String toString() => 'Corretora(id: $id, nome: $nome)';
}
