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
  // Etapa 17: perfil completo da corretora (cabeçalho dos PDFs)
  String? razaoSocial;
  String? susep;
  String? site;
  String? logoCaminho; // caminho no Storage (para apagar a logo anterior)
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
    this.razaoSocial,
    this.susep,
    this.site,
    this.logoCaminho,
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
      'razaoSocial': razaoSocial,
      'susep': susep,
      'site': site,
      'logoCaminho': logoCaminho,
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
      razaoSocial: map['razaoSocial'],
      susep: map['susep'],
      site: map['site'],
      logoCaminho: map['logoCaminho'],
      ativa: map['ativa'] ?? true,
      dataCriacao: map['dataCriacao'] is Timestamp ? (map['dataCriacao'] as Timestamp).toDate() : DateTime.now(),
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
    String? razaoSocial,
    String? susep,
    String? site,
    String? logoCaminho,
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
      razaoSocial: razaoSocial ?? this.razaoSocial,
      susep: susep ?? this.susep,
      site: site ?? this.site,
      logoCaminho: logoCaminho ?? this.logoCaminho,
      ativa: ativa ?? this.ativa,
      dataCriacao: dataCriacao ?? this.dataCriacao,
    );
  }

  /// Etapa 17: só os campos do perfil (o que a tela "Dados da corretora"
  /// grava). Não leva dataCriacao/ativa nem os campos da migração.
  Map<String, dynamic> dadosPerfil() => {
        'nome': nome.trim(),
        'razaoSocial': (razaoSocial ?? '').trim(),
        'cnpj': (cnpj ?? '').trim(),
        'susep': (susep ?? '').trim(),
        'endereco': (endereco ?? '').trim(),
        'telefone': telefone.trim(),
        'email': email.trim(),
        'site': (site ?? '').trim(),
        'logo': logo,
        'logoCaminho': logoCaminho,
      };

  @override
  String toString() => 'Corretora(id: $id, nome: $nome)';
}
