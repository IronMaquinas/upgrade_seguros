// Third_party_model.dart file in lib/models
import 'package:image_picker/image_picker.dart';
import 'vehicle_model.dart';

class ThirdParty {
  String nome;
  String cpf;
  String contato;
  String email;
  Vehicle veiculo;
  String relato;
  String placa;
  String chassi;
  String cor;
  String marcaTerceiro;
  String modeloTerceiro;
  String anoFabricacaoTerceiro;
  String anoModeloTerceiro;
  String numeroSinistroTerceiro;
  String enderecoTerceiro;

  // propriedades
  List<XFile>? fotos;        // fotos locais (não vai pro Firestore)
  List<String>? fotosUrls;  // urls salvas no Firestore
  List<XFile>? documentos;   // documentos locais
  List<String>? documentosUrls; // urls dos documentos no Firestore
  double franquia; // valor da franquia

  ThirdParty({
    required this.nome,
    required this.cpf,
    required this.contato,
    required this.email,
    required this.veiculo,
    required this.relato,
    required this.placa,
    required this.chassi,
    this.marcaTerceiro = '',
    this.modeloTerceiro = '',
    this.anoFabricacaoTerceiro = '',
    this.anoModeloTerceiro = '',
    this.numeroSinistroTerceiro = '',
    this.cor = '',
    this.fotos,
    this.fotosUrls,
    this.documentos,
    this.documentosUrls,
    this.franquia = 0.0,
    required this.enderecoTerceiro,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'cpf': cpf,
      'contato': contato,
      'email': email,
      'placa': placa,
      'chassi': chassi,
      'cor': cor,
      'marcaTerceiro': marcaTerceiro,
      'modeloTerceiro': modeloTerceiro,
      'anoFabricacaoTerceiro': anoFabricacaoTerceiro,
      'anoModeloTerceiro': anoModeloTerceiro,
      'numeroSinistroTerceiro': numeroSinistroTerceiro,
      'veiculo': veiculo.toMap(),
      'relato': relato,
      'fotosUrls': fotosUrls ?? [],
      'documentosUrls': documentosUrls ?? [],
      'franquia': franquia,
      'endereco_terceiro': enderecoTerceiro,
    };
  }

  factory ThirdParty.fromMap(Map<String, dynamic> map) {
    return ThirdParty(
      nome: map['nome'] ?? '',
      cpf: map['cpf'] ?? '',
      contato: map['contato'] ?? '',
      email: map['email'] ?? '',
      placa: map['placa'] ?? '',
      chassi: map['chassi'] ?? '',
      cor: map['cor'] ?? '',
      marcaTerceiro: map['marcaTerceiro'] ?? '',
      modeloTerceiro: map['modeloTerceiro'] ?? '',
      anoFabricacaoTerceiro: map['anoFabricacaoTerceiro'] ?? '',
      anoModeloTerceiro: map['anoModeloTerceiro'] ?? '',
      numeroSinistroTerceiro: map['numeroSinistroTerceiro'] ?? '',
      veiculo: Vehicle.fromMap(map['veiculo'] ?? {}),
      relato: map['relato'] ?? '',
      fotosUrls: map['fotosUrls'] != null ? List<String>.from(map['fotosUrls']) : [],
      documentosUrls: map['documentosUrls'] != null ? List<String>.from(map['documentosUrls']) : [],
      franquia: (map['franquia'] ?? 0.0).toDouble(),
      enderecoTerceiro: map['endereco_terceiro'] ?? '',
    );
  }
}