// lib/models/contrato_dto.dart
class ContratoDTO {
  final String seguradora;
  final String numeroApolice;
  final DateTime dataFim;
  final DateTime dataInicio;
  final String cnpjCpfProponente;
  final String nomeProponente;
  final String? endereco;
  final String? telefone;
  final String? email;
  final String? contato;
  final List<VeiculoDTO> veiculos;
  final double valorPremioTotal;
  final double? valorFranquia;
  final String ramo; // 'Veículo Individual', 'Frota', etc.

  ContratoDTO({
    required this.seguradora,
    required this.numeroApolice,
    required this.dataFim,
    required this.dataInicio,
    required this.cnpjCpfProponente,
    required this.nomeProponente,
    this.endereco,
    this.telefone,
    this.email,
    this.contato,
    required this.veiculos,
    required this.valorPremioTotal,
    this.valorFranquia,
    required this.ramo,
  });
}

class VeiculoDTO {
  final String placa;
  final String chassi;
  final String marca;
  final String modelo;
  final int ano;
  final int anoModelo;
  final String cor;
  final String? proprietarioNome; // 🔥 NOVO
  final String? proprietarioCPF; 

  VeiculoDTO({
    required this.placa,
    required this.chassi,
    required this.marca,
    required this.modelo,
    required this.ano,
    required this.anoModelo,
    required this.cor,
    this.proprietarioNome,
    this.proprietarioCPF,
  });
}