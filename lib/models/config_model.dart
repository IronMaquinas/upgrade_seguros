// lib/models/config_model.dart
import '../utils/gatilho.dart';

class AppConfig {
  String id; // sempre 'config'

  // SLAs existentes
  int slaSinistrosDias;
  bool enableNpsSurvey;
  Map<String, int> slaAsistenciasPorTipo;
  Map<String, int> slaSinistrosPorRamo;

  // 🔥 NOVOS CAMPOS DE NOTIFICAÇÃO
  bool notificacoesAtivas;                  // true/false – liga/desliga global
  String notificacaoHorarioInicio;          // "22:00"
  String notificacaoHorarioFim;             // "08:00"
  int notificacaoIntervaloMinutos;          // 30 – reenvio a cada X minutos
  int notificacaoAtrasoMinimo;              // 30 – atraso mínimo para disparar
  List<String> notificacaoTelegramChatIds;  // lista de chat_ids

  // Etapa 07: % do valor da apólice usado como gatilho quando o contrato não
  // traz o valor (padrão 70%).
  double percentualGatilhoPadrao;

  // Construtor principal
  AppConfig({
    required this.id,
    this.slaSinistrosDias = 10,
    this.enableNpsSurvey = true,
    this.slaAsistenciasPorTipo = const {'Veicular': 30, 'Residencial': 60},
    this.slaSinistrosPorRamo = const {
      'Veículo Individual': 10,
      'Frota': 7,
      'Transporte': 5,
      'Máquinas': 10,
      'Residencial': 10,
      'Vida': 10,
    },
    // Novos campos com valores padrão
    this.notificacoesAtivas = true,
    this.notificacaoHorarioInicio = "22:00",
    this.notificacaoHorarioFim = "08:00",
    this.notificacaoIntervaloMinutos = 30,
    this.notificacaoAtrasoMinimo = 30,
    this.notificacaoTelegramChatIds = const [],
    this.percentualGatilhoPadrao = 70.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'slaSinistrosDias': slaSinistrosDias,
      'slaAsistenciasPorTipo': slaAsistenciasPorTipo,
      'slaSinistrosPorRamo': slaSinistrosPorRamo,
      'enableNpsSurvey': enableNpsSurvey,
      // Novos campos
      'notificacoesAtivas': notificacoesAtivas,
      'notificacaoHorarioInicio': notificacaoHorarioInicio,
      'notificacaoHorarioFim': notificacaoHorarioFim,
      'notificacaoIntervaloMinutos': notificacaoIntervaloMinutos,
      'notificacaoAtrasoMinimo': notificacaoAtrasoMinimo,
      'notificacaoTelegramChatIds': notificacaoTelegramChatIds,
      'percentualGatilhoPadrao': percentualGatilhoPadrao,
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
      // Novos campos com fallback
      notificacoesAtivas: map['notificacoesAtivas'] ?? true,
      notificacaoHorarioInicio: map['notificacaoHorarioInicio'] ?? "22:00",
      notificacaoHorarioFim: map['notificacaoHorarioFim'] ?? "08:00",
      notificacaoIntervaloMinutos: map['notificacaoIntervaloMinutos'] ?? 30,
      notificacaoAtrasoMinimo: map['notificacaoAtrasoMinimo'] ?? 30,
      notificacaoTelegramChatIds: List<String>.from(
        map['notificacaoTelegramChatIds'] ?? [],
      ),
      percentualGatilhoPadrao: GatilhoApolice.normalizarPercentual(map['percentualGatilhoPadrao'] as num?),
    );
  }
}