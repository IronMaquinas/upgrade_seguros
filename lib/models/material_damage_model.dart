// material_damage_model.dart
// Modelo para dados de danos materiais em sinistros

import 'package:image_picker/image_picker.dart';

class MaterialDamage {
  String id;
  String nome;
  String cpfCnpj;
  String endereco;
  String telefone;
  String numeroSinistro;
  String email;
  String relato;
  String tipoPatrimonio; // "Casa", "Estabelecimento", "Veículo", "Outros"
  String descricao;

  // Propriedades para arquivos
  List<XFile>? fotos;           // fotos locais (não vai pro Firestore)
  List<String>? fotosUrls;      // urls salvas no Firestore
  List<XFile>? documentos;       // documentos locais
  List<String>? documentosUrls; // urls dos documentos no Firestore

  MaterialDamage({
    required this.id,
    required this.nome,
    required this.cpfCnpj,
    required this.endereco,
    required this.telefone,
    required this.numeroSinistro,
    required this.email,
    required this.relato,
    required this.tipoPatrimonio,
    required this.descricao,
    this.fotos,
    this.fotosUrls,
    this.documentos,
    this.documentosUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cpf_cnpj': cpfCnpj,
      'endereco': endereco,
      'telefone': telefone,
      'numero_sinistro': numeroSinistro,
      'email': email,
      'relato': relato,
      'tipo_patrimonio': tipoPatrimonio,
      'descricao': descricao,
      'fotos_urls': fotosUrls ?? [],
      'documentos_urls': documentosUrls ?? [],
    };
  }

  factory MaterialDamage.fromMap(Map<String, dynamic> map) {
    return MaterialDamage(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      cpfCnpj: map['cpf_cnpj'] ?? '',
      endereco: map['endereco'] ?? '',
      telefone: map['telefone'] ?? '',
      numeroSinistro: map['numero_sinistro'] ?? '',
      email: map['email'] ?? '',
      relato: map['relato'] ?? '',
      tipoPatrimonio: map['tipo_patrimonio'] ?? '',
      descricao: map['descricao'] ?? '',
      fotosUrls: map['fotos_urls'] != null 
          ? List<String>.from(map['fotos_urls']) 
          : [],
      documentosUrls: map['documentos_urls'] != null 
          ? List<String>.from(map['documentos_urls']) 
          : [],
    );
  }
}