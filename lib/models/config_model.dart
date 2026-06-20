// lib/models/config_model.dart
class AppConfig {
  String id; // sempre 'config'
  int slaSinistrosDias;
  bool enableNpsSurvey;
  Map<String, int> slaAsistenciasPorTipo; // {'Veicular': 30, 'Residencial': 60}
  Map<String, int> slaSinistrosPorRamo; // {'Frota': 7, 'Veículo': 10, ...}

  AppConfig({
    required this.id,
    this.slaSinistrosDias = 10,
    this.slaAsistenciasPorTipo = const {'Veicular': 30, 'Residencial': 60},
    this.slaSinistrosPorRamo = const {
      'Veículo Individual': 10,
      'Frota': 7,
      'Transporte': 5,
      'Máquinas': 10,
      'Residencial': 10,
      'Vida': 10,
    },
    this.enableNpsSurvey = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slaSinistrosDias': slaSinistrosDias,
      'slaAsistenciasPorTipo': slaAsistenciasPorTipo,
      'slaSinistrosPorRamo': slaSinistrosPorRamo,
      'enableNpsSurvey': enableNpsSurvey,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      id: map['id'] ?? 'config',
      slaSinistrosDias: map['slaSinistrosDias'] ?? 10,
      slaAsistenciasPorTipo: Map<String, int>.from(
        map['slaAsistenciasPorTipo'] ?? {'Veicular': 30, 'Residencial': 60},
      ),
      slaSinistrosPorRamo: Map<String, int>.from(
        map['slaSinistrosPorRamo'] ?? {
          'Veículo Individual': 10,
          'Frota': 7,
          'Transporte': 5,
          'Máquinas': 10,
          'Residencial': 10,
          'Vida': 10,
        },
      ),
      enableNpsSurvey: map['enableNpsSurvey'] ?? true,
    );
  }
}