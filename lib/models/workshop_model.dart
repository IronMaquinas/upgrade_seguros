// lib/models/workshop_model.dart
// ✨ VERSÃO ATUALIZADA COM copyWith E CAMPO ativo

import 'package:cloud_firestore/cloud_firestore.dart';

class Workshop {
  String id;
  String nome;
  String? contato;
  String? telefone;
  String? email;
  String? enderecoEmpresa;
  String? endereco;
  String? cnpjEmpresa;
  String tipo; // 'segurado' ou 'terceiro'
  List<String> documentosUrls;
  DateTime dataCriacao;
  String? responsavelEmail;
  final double? valorImovel;
  bool? ativo; // ← NOVO CAMPO

  Workshop({
    required this.id,
    required this.nome,
    this.contato,
    this.telefone,
    this.email,
    this.enderecoEmpresa,
    this.endereco,
    this.cnpjEmpresa,
    required this.tipo,
    this.documentosUrls = const [],
    required this.dataCriacao,
    this.responsavelEmail,
    this.valorImovel,
    this.ativo = true, // ← NOVO PADRÃO
  });

  // Converter para Map (Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'contato': contato,
      'telefone': telefone,
      'email': email,
      'endereco_empresa': enderecoEmpresa,
      'nome': nome,
      'endereco': endereco,
      'cnpj_empresa': cnpjEmpresa,
      'tipo': tipo,
      'documentos_urls': documentosUrls,
      'data_criacao': dataCriacao,
      'responsavel_email': responsavelEmail,
      'ativo': ativo ?? true, // ← NOVO CAMPO
      if (valorImovel != null) 'valorImovel': valorImovel,
    };
  }

  // Criar a partir de Map (Firestore)
  factory Workshop.fromMap(Map<String, dynamic> map) {
    return Workshop(
      id: map['id'] ?? '',
      contato: map['contato'],
      telefone: map['telefone'],
      email: map['email'],
      enderecoEmpresa: map['endereco_empresa'],
      nome: map['nome'] ?? '',
      endereco: map['endereco'],
      cnpjEmpresa: map['cnpj_empresa'],
      tipo: map['tipo'] ?? 'segurado',
      documentosUrls: List<String>.from(map['documentos_urls'] ?? []),
      dataCriacao: (map['data_criacao'] as Timestamp).toDate(),
      responsavelEmail: map['responsavel_email'],
      valorImovel: map['valorImovel'],
      ativo: map['ativo'] ?? true, // ← NOVO CAMPO
    );
  }

  // ✨ Método copyWith (NOVO)
  Workshop copyWith({
    String? id,
    String? nome,
    String? contato,
    String? telefone,
    String? email,
    String? enderecoEmpresa,
    String? endereco,
    String? cnpjEmpresa,
    String? tipo,
    List<String>? documentosUrls,
    DateTime? dataCriacao,
    String? responsavelEmail,
    double? valorImovel,
    bool? ativo,
  }) {
    return Workshop(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      contato: contato ?? this.contato,
      telefone: telefone ?? this.telefone,
      email: email ?? this.email,
      enderecoEmpresa: enderecoEmpresa ?? this.enderecoEmpresa,
      endereco: endereco ?? this.endereco,
      cnpjEmpresa: cnpjEmpresa ?? this.cnpjEmpresa,
      tipo: tipo ?? this.tipo,
      documentosUrls: documentosUrls ?? this.documentosUrls,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      responsavelEmail: responsavelEmail ?? this.responsavelEmail,
      valorImovel: valorImovel ?? this.valorImovel,
      ativo: ativo ?? this.ativo,
    );
  }
}