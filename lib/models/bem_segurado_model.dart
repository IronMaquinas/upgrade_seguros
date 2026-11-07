import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:upgrade_seguros/models/business_model.dart';

class BemSegurado {
  String id;
  String tipo; // 'Veículo Individual', 'Frota', 'Equipamento', 'Residencial', 'Vida'
  
  // Dados genéricos
  String descricao;
  DateTime dataCadastro;

  // Veículo Individual
  String? placa;
  String? marca;
  String? modelo;
  int? ano;
  int? anoModelo;
  String? cor;
  String? chassi;
  String? proprietarioNome;
  String? proprietarioCPF;
  List<String>? crlvUrls;              // 🆕 Lista de URLs (suporta múltiplos PDFs)
  DateTime? dataVencimentoCRLV;        // 🆕 Data de vencimento do CRLV

  // Frota (Cavalo + Carreta)
  String? tipoCavalo;
  String? placaCavalo;
  String? marcaCavalo;
  String? modeloCavalo;
  int? anoCavalo;
  int? anoFabricacaoCavalo;
  int? anoModeloCavalo;
  String? chassiCavalo;
  
  String? tipoCarreta;
  String? placaCarreta;
  String? marcaCarreta;
  String? modeloCarreta;
  int? anoCarreta;
  String? chassiCarreta;
  int? anoFabricacaoCarreta;
  int? anoModeloCarreta;

  // Equipamento
  String? modeloEquipamento;
  String? numeroSerie;
  String? fabricante;

  // Empresarial
  String? nomeEmpresa;
  String? cnpjEmpresa;
  String? enderecoEmpresa;
  final Business? businessData;

  // Endereço (Residencial)
  String? logradouro;
  String? numero;
  String? complemento;
  String? bairro;
  String? cidade;
  String? estado;
  String? cep;
  String? numeroDocumento;
  List<String>? documentosUrls;  

  // Vida
  String? cpfVida;
  DateTime? dataVida;
  double? capitalSegurado;

  BemSegurado({
    this.id = '',
    required this.tipo,
    required this.descricao,
    required this.dataCadastro,
    // Veículo
    this.placa,
    this.marca,
    this.modelo,
    this.ano,
    this.anoModelo,
    this.cor,
    this.chassi,
    this.proprietarioNome,
    this.proprietarioCPF,
    this.crlvUrls,                     // 🆕
    this.dataVencimentoCRLV,           // 🆕

    // Frota
    this.tipoCavalo,
    this.placaCavalo,
    this.marcaCavalo,
    this.modeloCavalo,
    this.anoCavalo,
    this.tipoCarreta,
    this.placaCarreta,
    this.marcaCarreta,
    this.modeloCarreta,
    this.anoCarreta,
    this.anoFabricacaoCavalo,
    this.anoModeloCavalo,
    this.anoFabricacaoCarreta,
    this.anoModeloCarreta,
    this.chassiCavalo,
    this.chassiCarreta,

    // Equipamento
    this.modeloEquipamento,
    this.numeroSerie,
    this.fabricante,

    // Empresarial
    this.nomeEmpresa,
    this.cnpjEmpresa,
    this.enderecoEmpresa,
    this.businessData,

    // Endereço
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.estado,
    this.cep,
    this.numeroDocumento,
    this.documentosUrls,
    // Vida
    this.cpfVida,
    this.dataVida,
    this.capitalSegurado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'descricao': descricao,
      'data_cadastro': Timestamp.fromDate(dataCadastro),
      // Veículo
      'placa': placa,
      'marca': marca,
      'modelo': modelo,
      'ano': ano,
      'ano_modelo': anoModelo,
      'cor': cor,
      'chassi': chassi,
      'proprietario_nome': proprietarioNome,
      'proprietario_cpf': proprietarioCPF,
      'crlv_urls': crlvUrls,                    // 🆕
      'data_vencimento_crlv': dataVencimentoCRLV != null ? Timestamp.fromDate(dataVencimentoCRLV!) : null,  // 🆕
      
      // Frota
      'tipo_cavalo': tipoCavalo,
      'placa_cavalo': placaCavalo,
      'marca_cavalo': marcaCavalo,
      'modelo_cavalo': modeloCavalo,
      'ano_cavalo': anoCavalo,
      'ano_fabricacao_cavalo': anoFabricacaoCavalo,
      'ano_modelo_cavalo': anoModeloCavalo,
      'chassi_cavalo': chassiCavalo,
      
      'tipo_carreta': tipoCarreta,
      'placa_carreta': placaCarreta,
      'marca_carreta': marcaCarreta,
      'modelo_carreta': modeloCarreta,
      'ano_carreta': anoCarreta,
      'chassi_carreta': chassiCarreta,
      'ano_fabricacao_carreta': anoFabricacaoCarreta,
      'ano_modelo_carreta': anoModeloCarreta,

      // Equipamento
      'modelo_equipamento': modeloEquipamento,
      'numero_serie': numeroSerie,
      'fabricante': fabricante,

      // Empresarial
      'nome_empresa': nomeEmpresa,
      'endereco_empresa': enderecoEmpresa,
      'cnpj_empresa': cnpjEmpresa,
      'business_data': businessData?.toMap(),

      // Endereço
      'logradouro': logradouro,
      'numero': numero,
      'complemento': complemento,
      'bairro': bairro,
      'cidade': cidade,
      'estado': estado,
      'cep': cep,
      'numero_documento': numeroDocumento,
      'documentos_urls': documentosUrls,
      // Vida
      'cpf_vida': cpfVida,
      'data_vida': dataVida != null ? Timestamp.fromDate(dataVida!) : null,
      'capital_segurado': capitalSegurado,
    };
  }

  factory BemSegurado.fromMap(Map<String, dynamic> data, String docId) {
    return BemSegurado(
      id: docId,
      tipo: data['tipo'] ?? '',
      descricao: data['descricao'] ?? '',
      dataCadastro: (data['data_cadastro'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Veículo
      placa: data['placa'],
      marca: data['marca'],
      modelo: data['modelo'],
      ano: data['ano'],
      anoModelo: data['ano_modelo'],
      cor: data['cor'],
      chassi: data['chassi'],
      proprietarioNome: data['proprietario_nome'],
      proprietarioCPF: data['proprietario_cpf'],
      crlvUrls: List<String>.from(data['crlv_urls'] ?? []),  // 🆕
      dataVencimentoCRLV: (data['data_vencimento_crlv'] as Timestamp?)?.toDate(),  // 🆕
      
      // Frota
      tipoCavalo: data['tipo_cavalo'],
      placaCavalo: data['placa_cavalo'],
      marcaCavalo: data['marca_cavalo'],
      modeloCavalo: data['modelo_cavalo'],
      anoCavalo: data['ano_cavalo'],
      anoFabricacaoCavalo: data['ano_fabricacao_cavalo'],
      anoModeloCavalo: data['ano_modelo_cavalo'],
      chassiCavalo: data['chassi_cavalo'],
      
      tipoCarreta: data['tipo_carreta'],
      placaCarreta: data['placa_carreta'],
      marcaCarreta: data['marca_carreta'],
      modeloCarreta: data['modelo_carreta'],
      anoCarreta: data['ano_carreta'],
      chassiCarreta: data['chassi_carreta'],
      anoFabricacaoCarreta: data['ano_fabricacao_carreta'],
      anoModeloCarreta: data['ano_modelo_carreta'],
      
      // Equipamento
      modeloEquipamento: data['modelo_equipamento'],
      numeroSerie: data['numero_serie'],
      fabricante: data['fabricante'],

      // Empresarial
      nomeEmpresa: data['nome_empresa'] ?? '',
      enderecoEmpresa: data['endereco_empresa'],
      cnpjEmpresa: data['cnpj_empresa'],
      businessData: data['business_data'] != null 
          ? Business.fromMap(data['business_data']) 
          : null,

      // Endereço
      logradouro: data['logradouro'],
      numero: data['numero'],
      complemento: data['complemento'],
      bairro: data['bairro'],
      cidade: data['cidade'],
      estado: data['estado'],
      cep: data['cep'],
      // Vida
      cpfVida: data['cpf_vida'],
      dataVida: (data['data_vida'] as Timestamp?)?.toDate(),
      capitalSegurado: (data['capital_segurado'] as num?)?.toDouble(),
      numeroDocumento: data['numero_documento'],
documentosUrls: data['documentos_urls'] != null ? List<String>.from(data['documentos_urls']) : null,
    );
  }
}