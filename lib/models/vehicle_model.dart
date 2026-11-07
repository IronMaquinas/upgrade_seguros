import 'package:image_picker/image_picker.dart';

class Vehicle {
  String chassi;
  String marca;
  String modelo;
  String nomeCondutor;
  String cpfCondutor;
  String nomeCondutorMotorista;
  String cpfCondutorMotorista;
  String cnhCondutorMotorista;
  String cor;
  int ano;
  int anomodelo;
  String placa;
  List<String> fotosUrls;
  final List<XFile> fotos; // ✅ Adicione este campo


  Vehicle({
    required this.chassi,
    required this.marca,
    required this.modelo,
    this.nomeCondutor = '',
    this.cpfCondutor = '',
    this.nomeCondutorMotorista = '', 
    this.cpfCondutorMotorista = '',
    this.cnhCondutorMotorista = '',
    this.cor = '',
    required this.ano,
    required this.anomodelo,
    this.placa = '',
    this.fotosUrls = const [],
    this.fotos = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'chassi': chassi,
      'marca': marca,
      'modelo': modelo,
      'nomeCondutor': nomeCondutor,
      'cpfCondutor': cpfCondutor,
      'nomeCondutorMotorista': nomeCondutorMotorista, 
      'cpfCondutorMotorista': cpfCondutorMotorista,
      'cnhCondutorMotorista': cnhCondutorMotorista,
      'cor': cor,
      'ano': ano,
      'anomodelo': anomodelo,
      'placa': placa,
      'fotosUrls': fotosUrls, // <- Adicionado aqui
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      chassi: map['chassi'] ?? '',
      marca: map['marca'] ?? '',
      modelo: map['modelo'] ?? '',
      nomeCondutor: map['nomeCondutor'] ?? '',
      cpfCondutor: map['cpfCondutor'] ?? '',
      nomeCondutorMotorista: map['nomeCondutorMotorista'] ?? '', 
      cpfCondutorMotorista: map['cpfCondutorMotorista'] ?? '',
      cnhCondutorMotorista: map['cnhCondutorMotorista'] ?? '',
      cor: map['cor'] ?? '',
      ano: map['ano'] ?? 0,
      anomodelo: map['anomodelo'] ?? 0,
      placa: map['placa'] ?? '',
      fotosUrls: List<String>.from(map['fotosUrls'] ?? []), // <- Adicionado aqui
    );
  }
}
