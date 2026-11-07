import 'package:cloud_firestore/cloud_firestore.dart';
import 'bem_segurado_model.dart';  // ← ADICIONA IMPORT
import '../utils/gatilho.dart';

class Apolice {
  String id;
  String ramo; // 'Frota', 'Veículo Individual', 'Residencial', 'Máquinas', 'Vida'
  String seguradora;
  String numeroApolice;
  DateTime dataInicio;
  DateTime dataFim;
  double valorApolice;
  double valorGatilho;
  List<BemSegurado> bensSegurados;  // ← NOVO!

  Apolice({
    required this.id,
    required this.ramo,
    required this.seguradora,
    required this.numeroApolice,
    required this.dataInicio,
    required this.dataFim,
    required this.valorApolice,
    required this.valorGatilho,
    this.bensSegurados = const [],  // ← NOVO
  });

  // Etapa 07: gatilho informado no contrato ou calculado pelo % da corretora.
  bool get gatilhoInformado => GatilhoApolice.informado(valorGatilho);

  /// Gatilho que vale para os cálculos (ver lib/utils/gatilho.dart).
  double gatilhoEfetivo(double percentualPadrao) => GatilhoApolice.efetivo(
        valorApolice: valorApolice,
        valorGatilho: valorGatilho,
        percentual: percentualPadrao,
      );

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ramo': ramo,
      'seguradora': seguradora,
      'numero_apolice': numeroApolice,
      'data_inicio': Timestamp.fromDate(dataInicio),
      'data_fim': Timestamp.fromDate(dataFim),
      'valor_apolice': valorApolice,
      'valor_gatilho': valorGatilho,
      'bens_segurados': bensSegurados.map((b) => b.toMap()).toList(),  // ← NOVO
    };
  }

  factory Apolice.fromMap(Map<String, dynamic> data, String docId) {
    return Apolice(
      id: docId,
      ramo: data['ramo'] ?? '',
      seguradora: data['seguradora'] ?? '',
      numeroApolice: data['numero_apolice'] ?? '',
      dataInicio: (data['data_inicio'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dataFim: (data['data_fim'] as Timestamp?)?.toDate() ?? DateTime.now(),
      valorApolice: (data['valor_apolice'] as num?)?.toDouble() ?? 0.0,
      valorGatilho: (data['valor_gatilho'] as num?)?.toDouble() ?? 0.0,
      bensSegurados: (data['bens_segurados'] as List<dynamic>?)  // ← NOVO
          // ignore: unnecessary_cast
          ?.map((b) => BemSegurado.fromMap(b as Map<String, dynamic>, (b as Map<String, dynamic>)['id'] ?? ''))
          .toList() ?? [],
    );
  }
}