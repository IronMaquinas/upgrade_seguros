import 'dart:io';
import 'package:image_picker/image_picker.dart';

class Transport {
  String? nomeMotorista;
  String? cpfMotorista;
  String? placaCarreta;
  String? placaCavalo;
  String? numeroAverbacao;
  String? reguladora;
  String? nfe;
  String? cte;
  String? vpo;
  String? marca;
  String? modelo;
  String? cor;
  int ano;
  int anomodelo;
  int anoCarreta;
  int anoModeloCarreta;
  String? chassi;
  String? chassiCarreta;
  String? marcaCarreta;
  String? modeloCarreta;
  String? rctrc; // não

  // novas propriedades
  List<XFile>? fotos;        // fotos locais (não vai pro Firestore)
  List<String>? fotosUrls;   // urls salvas no Firestore

  List<File>? documentos;           // documentos locais
  List<String>? documentosUrls;     // urls salvas no Firestore

  Transport({
    required this.nomeMotorista,
    required this.cpfMotorista,
    required this.placaCarreta,
    required this.placaCavalo,
    required this.numeroAverbacao,
    required this.reguladora,
    required this.nfe,
    required this.chassi,
    required this.chassiCarreta,
    required this.cte,
    required this.marcaCarreta,
    required this.modeloCarreta,
    required this.rctrc,
    required this.vpo,
    required this.ano,
    required this.anomodelo,
    required this.anoCarreta,
    required this.anoModeloCarreta,
    this.marca = '',
    this.modelo = '',
    this.cor = '',
    this.fotos,
    this.fotosUrls,
    this.documentos,
    this.documentosUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'nomeMotorista': nomeMotorista,
      'cpfMotorista': cpfMotorista,
      'placaCarreta': placaCarreta,
      'placaCavalo': placaCavalo,
      'numeroAverbacao': numeroAverbacao,
      'reguladora': reguladora,
      'ano': ano,
      'anomodelo': anomodelo,
      'anoCarreta': anoCarreta,
      'anoModeloCarreta': anoModeloCarreta,
      'nfe': nfe,
      'chassi': chassi,
      'chassiCarreta': chassiCarreta,
      'cte': cte,
      'marcaCarreta': marcaCarreta,
      'modeloCarreta': modeloCarreta,
      'rctrc': rctrc,
      'vpo': vpo,
      'marca': marca,
      'modelo': modelo,
      'cor': cor,
      'fotosUrls': fotosUrls ?? [],
      'documentosUrls': documentosUrls ?? [],
    };
  }

  factory Transport.fromMap(Map<String, dynamic> map) {
    return Transport(
      nomeMotorista: map['nomeMotorista'] ?? '',
      cpfMotorista: map['cpfMotorista'] ?? '',
      placaCarreta: map['placaCarreta'] ?? '',
      placaCavalo: map['placaCavalo'] ?? '',
      numeroAverbacao: map['numeroAverbacao'] ?? '',
      reguladora: map['reguladora'] ?? '',
      ano: map['ano'] ?? 0,
      anomodelo: map['anomodelo'] ?? 0,
      anoCarreta: map['anoCarreta'] ?? 0,
      anoModeloCarreta: map['anoModeloCarreta'] ?? 0,
      nfe: map['nfe'] ?? '',
      chassi: map['chassi'] ?? '',
      chassiCarreta: map['chassiCarreta'] ?? '',
      cte: map['cte'] ?? '',
      marcaCarreta: map['marcaCarreta'] ?? '',
      modeloCarreta: map['modeloCarreta'] ?? '',
      rctrc: map['rctrc'] ?? '',
      vpo: map['vpo'] ?? '',
      marca: map['marca'] ?? '',
      modelo: map['modelo'] ?? '',
      cor: map['cor'] ?? '',
      fotosUrls: map['fotosUrls'] != null ? List<String>.from(map['fotosUrls']) : [],
      documentosUrls: map['documentosUrls'] != null ? List<String>.from(map['documentosUrls']) : [],
    );
  }
}