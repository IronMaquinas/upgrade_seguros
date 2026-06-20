import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuração de SLA para cada tipo de assistência
/// Exemplo: Guincho tem 30min, Vidro tem 120min, etc.
class AssistSlaConfig {
  String id; // ID do documento no Firestore
  String tipoAssistencia; // "guincho", "vidro", "combustivel", etc.
  String labelTipo; // "Guincho", "Vidro Quebrado", etc.
  int duracao_minutos; // 30, 60, 120, etc.
  bool alertar_gerente; // Se deve notificar gerente ao exceder
  bool notificar_cliente; // Se deve notificar cliente por SMS/email
  int percentual_alerta; // Em que % do SLA avisar (padrão 80%)
  DateTime data_criacao;
  DateTime data_atualizacao;

  AssistSlaConfig({
    this.id = '',
    required this.tipoAssistencia,
    required this.labelTipo,
    required this.duracao_minutos,
    this.alertar_gerente = true,
    this.notificar_cliente = false,
    this.percentual_alerta = 80,
    DateTime? data_criacao,
    DateTime? data_atualizacao,
  })  : data_criacao = data_criacao ?? DateTime.now(),
        data_atualizacao = data_atualizacao ?? DateTime.now();

  /// Converte para mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'tipo_assistencia': tipoAssistencia,
      'label_tipo': labelTipo,
      'duracao_minutos': duracao_minutos,
      'alertar_gerente': alertar_gerente,
      'notificar_cliente': notificar_cliente,
      'percentual_alerta': percentual_alerta,
      'data_criacao': Timestamp.fromDate(data_criacao),
      'data_atualizacao': Timestamp.fromDate(data_atualizacao),
    };
  }

  /// Cria a partir de um mapa do Firestore
  factory AssistSlaConfig.fromMap(Map<String, dynamic> map, String id) {
    return AssistSlaConfig(
      id: id,
      tipoAssistencia: map['tipo_assistencia'] ?? '',
      labelTipo: map['label_tipo'] ?? '',
      duracao_minutos: map['duracao_minutos'] ?? 60,
      alertar_gerente: map['alertar_gerente'] ?? true,
      notificar_cliente: map['notificar_cliente'] ?? false,
      percentual_alerta: map['percentual_alerta'] ?? 80,
      data_criacao: map['data_criacao'] != null
          ? (map['data_criacao'] as Timestamp).toDate()
          : DateTime.now(),
      data_atualizacao: map['data_atualizacao'] != null
          ? (map['data_atualizacao'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Cria a partir de um DocumentSnapshot
  factory AssistSlaConfig.fromFirestore(DocumentSnapshot doc) {
    return AssistSlaConfig.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  /// Cria uma cópia com campos atualizados
  AssistSlaConfig copyWith({
    String? id,
    String? tipoAssistencia,
    String? labelTipo,
    int? duracao_minutos,
    bool? alertar_gerente,
    bool? notificar_cliente,
    int? percentual_alerta,
    DateTime? data_criacao,
    DateTime? data_atualizacao,
  }) {
    return AssistSlaConfig(
      id: id ?? this.id,
      tipoAssistencia: tipoAssistencia ?? this.tipoAssistencia,
      labelTipo: labelTipo ?? this.labelTipo,
      duracao_minutos: duracao_minutos ?? this.duracao_minutos,
      alertar_gerente: alertar_gerente ?? this.alertar_gerente,
      notificar_cliente: notificar_cliente ?? this.notificar_cliente,
      percentual_alerta: percentual_alerta ?? this.percentual_alerta,
      data_criacao: data_criacao ?? this.data_criacao,
      data_atualizacao: data_atualizacao ?? DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AssistSlaConfig(tipo: $tipoAssistencia, duracao: ${duracao_minutos}min, alerta: ${percentual_alerta}%)';
  }
}

/// Configurações padrão para cada tipo de assistência
/// Estas são sugestões iniciais; podem ser customizadas no Settings
class AssistSlaDefaults {
  static const Map<String, Map<String, dynamic>> defaults = {
    'guincho': {
      'label': 'Guincho',
      'minutos': 30,
      'alertar_gerente': true,
      'notificar_cliente': true,
      'percentual_alerta': 80,
    },
    'vidro': {
      'label': 'Vidro Quebrado',
      'minutos': 120,
      'alertar_gerente': true,
      'notificar_cliente': false,
      'percentual_alerta': 80,
    },
    'combustivel': {
      'label': 'Combustível',
      'minutos': 45,
      'alertar_gerente': true,
      'notificar_cliente': true,
      'percentual_alerta': 80,
    },
    'pane_eletrica': {
      'label': 'Pane Elétrica',
      'minutos': 90,
      'alertar_gerente': true,
      'notificar_cliente': false,
      'percentual_alerta': 80,
    },
    'carga_bateria': {
      'label': 'Carga de Bateria',
      'minutos': 40,
      'alertar_gerente': true,
      'notificar_cliente': true,
      'percentual_alerta': 80,
    },
    'falta': {
      'label': 'Falta de Peça',
      'minutos': 60,
      'alertar_gerente': true,
      'notificar_cliente': false,
      'percentual_alerta': 80,
    },
    'reboque': {
      'label': 'Reboque',
      'minutos': 45,
      'alertar_gerente': true,
      'notificar_cliente': true,
      'percentual_alerta': 80,
    },
    'outro': {
      'label': 'Outro',
      'minutos': 120,
      'alertar_gerente': true,
      'notificar_cliente': false,
      'percentual_alerta': 80,
    },
  };

  /// Retorna a configuração padrão para um tipo
  static AssistSlaConfig getDefault(String tipoAssistencia) {
    final cfg = defaults[tipoAssistencia] ?? defaults['outro']!;
    return AssistSlaConfig(
      tipoAssistencia: tipoAssistencia,
      labelTipo: (cfg['label'] as String?) ?? 'Outro',
      duracao_minutos: (cfg['minutos'] as int?) ?? 120,
      alertar_gerente: (cfg['alertar_gerente'] as bool?) ?? true,
      notificar_cliente: (cfg['notificar_cliente'] as bool?) ?? false,
      percentual_alerta: (cfg['percentual_alerta'] as int?) ?? 80,
    );
  }

  /// Retorna todas as configurações padrão
  static List<AssistSlaConfig> getAll() {
    return defaults.entries
        .map((e) => getDefault(e.key))
        .toList();
  }
}