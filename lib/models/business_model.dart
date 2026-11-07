import 'package:cloud_firestore/cloud_firestore.dart';

class Business {
  final String id;
  final String nomeEmpresa;
  final String cnpjEmpresa;
  final String enderecoEmpresa;
  final String? ramoAtividade;
  final String? numeroCnae;
  final int? anoFundacao;
  final String? descricaoImovel;
  final double? areaM2;
  final String? tipoEstrutura; // concreto, alvenaria, misto, etc
  final int? numeroAndares;
  final String? sistemaSeguranca;
  final String? situacaoImovel; // alugado, próprio, etc
  final List<String>? anexos; // URLs de documentos

  Business({
    required this.id,
    required this.nomeEmpresa,
    required this.cnpjEmpresa,
    required this.enderecoEmpresa,
    this.ramoAtividade,
    this.numeroCnae,
    this.anoFundacao,
    this.descricaoImovel,
    this.areaM2,
    this.tipoEstrutura,
    this.numeroAndares,
    this.sistemaSeguranca,
    this.situacaoImovel,
    this.anexos,
  });

  factory Business.fromMap(Map<String, dynamic> map) {
    return Business(
      id: map['id'] as String? ?? '',
      nomeEmpresa: map['nome_empresa'] as String? ?? '',
      cnpjEmpresa: map['cnpj_empresa'] as String? ?? '',
      enderecoEmpresa: map['endereco_empresa'] as String? ?? '',
      ramoAtividade: map['ramo_atividade'] as String?,
      numeroCnae: map['numero_cnae'] as String?,
      anoFundacao: map['ano_fundacao'] as int?,
      descricaoImovel: map['descricao_imovel'] as String?,
      areaM2: (map['area_m2'] as num?)?.toDouble(),
      tipoEstrutura: map['tipo_estrutura'] as String?,
      numeroAndares: map['numero_andares'] as int?,
      sistemaSeguranca: map['sistema_seguranca'] as String?,
      situacaoImovel: map['situacao_imovel'] as String?,
      anexos: List<String>.from(map['anexos'] as List? ?? []),
    );
  }

  factory Business.fromFirestore(DocumentSnapshot doc) {
    return Business.fromMap({...doc.data() as Map, 'id': doc.id});
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome_empresa': nomeEmpresa,
      'cnpj_empresa': cnpjEmpresa,
      'endereco_empresa': enderecoEmpresa,
      'ramo_atividade': ramoAtividade,
      'numero_cnae': numeroCnae,
      'ano_fundacao': anoFundacao,
      'descricao_imovel': descricaoImovel,
      'area_m2': areaM2,
      'tipo_estrutura': tipoEstrutura,
      'numero_andares': numeroAndares,
      'sistema_seguranca': sistemaSeguranca,
      'situacao_imovel': situacaoImovel,
      'anexos': anexos ?? [],
    };
  }

  Business copyWith({
    String? id,
    String? nomeEmpresa,
    String? cnpjEmpresa,
    String? enderecoEmpresa,
    String? ramoAtividade,
    String? numeroCnae,
    int? anoFundacao,
    String? descricaoImovel,
    double? areaM2,
    String? tipoEstrutura,
    int? numeroAndares,
    String? sistemaSeguranca,
    String? situacaoImovel,
    List<String>? anexos,
  }) {
    return Business(
      id: id ?? this.id,
      nomeEmpresa: nomeEmpresa ?? this.nomeEmpresa,
      cnpjEmpresa: cnpjEmpresa ?? this.cnpjEmpresa,
      enderecoEmpresa: enderecoEmpresa ?? this.enderecoEmpresa,
      ramoAtividade: ramoAtividade ?? this.ramoAtividade,
      numeroCnae: numeroCnae ?? this.numeroCnae,
      anoFundacao: anoFundacao ?? this.anoFundacao,
      descricaoImovel: descricaoImovel ?? this.descricaoImovel,
      areaM2: areaM2 ?? this.areaM2,
      tipoEstrutura: tipoEstrutura ?? this.tipoEstrutura,
      numeroAndares: numeroAndares ?? this.numeroAndares,
      sistemaSeguranca: sistemaSeguranca ?? this.sistemaSeguranca,
      situacaoImovel: situacaoImovel ?? this.situacaoImovel,
      anexos: anexos ?? this.anexos,
    );
  }
}