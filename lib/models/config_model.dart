// lib/models/config_model.dart
import '../utils/gatilho.dart';
import '../utils/videos.dart';

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

  // Etapa 12: limites de vídeo do sinistro (pensados para variar por plano)
  int videoMaxMb;
  int videosPorSinistro;

  // Etapa 08: SLA de sinistro (dias) por ramo — TODOS os ramos do sistema, na
  // ordem da tela de Configurações. Ramo novo entra aqui com o seu padrão; quem
  // já tem o documento salvo recebe o ramo novo com este valor até alterar.
  static const Map<String, int> slaSinistrosPadrao = {
    'Veículo Individual': 10,
    'Frota': 7,
    'Civil Ônibus (RCO)': 7,
    'Transporte': 5,
    'Máquinas': 10,
    'Residencial': 10,
    'Empresarial': 10,
    'Vida': 10,
  };

  /// Etapa 12
  LimitesVideo get limitesVideo => LimitesVideo(maxMb: videoMaxMb, maxPorSinistro: videosPorSinistro);

  /// Os sinistros gravam o ramo "Vidas"; o SLA sempre foi salvo como "Vida".
  static String chaveSlaRamo(String ramo) => ramo == 'Vidas' ? 'Vida' : ramo;

  /// Padrões + o que está salvo (o salvo vale). Sempre um mapa alterável.
  static Map<String, int> mesclarSlaSinistros(Map? salvo) {
    final resultado = Map<String, int>.from(slaSinistrosPadrao);
    salvo?.forEach((ramo, dias) {
      if (ramo is String && dias is num) resultado[chaveSlaRamo(ramo)] = dias.toInt();
    });
    return resultado;
  }

  // Construtor principal
  AppConfig({
    required this.id,
    this.slaSinistrosDias = 10,
    this.enableNpsSurvey = true,
    this.slaAsistenciasPorTipo = const {'Veicular': 30, 'Residencial': 60},
    this.slaSinistrosPorRamo = slaSinistrosPadrao,
    // Novos campos com valores padrão
    this.notificacoesAtivas = true,
    this.notificacaoHorarioInicio = "22:00",
    this.notificacaoHorarioFim = "08:00",
    this.notificacaoIntervaloMinutos = 30,
    this.notificacaoAtrasoMinimo = 30,
    this.notificacaoTelegramChatIds = const [],
    this.percentualGatilhoPadrao = 70.0,
    this.videoMaxMb = LimitesVideo.padraoMaxMb,
    this.videosPorSinistro = LimitesVideo.padraoMaxPorSinistro,
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
      'videoMaxMb': videoMaxMb,
      'videosPorSinistro': videosPorSinistro,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      id: map['id'] ?? 'config',
      slaSinistrosDias: map['slaSinistrosDias'] ?? 10,
      slaAsistenciasPorTipo: Map<String, int>.from(
        map['slaAsistenciasPorTipo'] ?? {'Veicular': 30, 'Residencial': 60},
      ),
      slaSinistrosPorRamo: mesclarSlaSinistros(map['slaSinistrosPorRamo'] as Map?),
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
      videoMaxMb: LimitesVideo.normalizarMb(map['videoMaxMb'] as num?),
      videosPorSinistro: LimitesVideo.normalizarQuantidade(map['videosPorSinistro'] as num?),
    );
  }
}