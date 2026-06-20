import 'package:cloud_firestore/cloud_firestore.dart';

class Workshop {
  String id;
  String nome;
  String? contato;
  String? telefone;
  String? email;
  String? endereco;
  String tipo; // 'segurado' ou 'terceiro'
  List<String> documentosUrls;
  DateTime dataCriacao;
  String? responsavelEmail;

  Workshop({
    required this.id,
    required this.nome,
    this.contato,
    this.telefone,
    this.email,
    this.endereco,
    required this.tipo,
    this.documentosUrls = const [],
    required this.dataCriacao,
    this.responsavelEmail,
  });

  // Converter para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'contato': contato,
      'telefone': telefone,
      'email': email,
      'endereco': endereco,
      'tipo': tipo,
      'documentos_urls': documentosUrls,
      'data_criacao': dataCriacao,
      'responsavel_email': responsavelEmail,
    };
  }

  // Criar a partir de Map (Firestore)
  factory Workshop.fromMap(Map<String, dynamic> map) {
    return Workshop(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      contato: map['contato'],
      telefone: map['telefone'],
      email: map['email'],
      endereco: map['endereco'],
      tipo: map['tipo'] ?? 'segurado',
      documentosUrls: List<String>.from(map['documentos_urls'] ?? []),
      dataCriacao: (map['data_criacao'] as Timestamp).toDate(),
      responsavelEmail: map['responsavel_email'],
    );
  }
}