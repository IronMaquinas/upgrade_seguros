// lib/services/config_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/config_model.dart';
import '../utils/gatilho.dart';

class ConfigService {
  final _db = FirebaseFirestore.instance;
  static const String _configDoc = 'config';
  static const String _configCollection = 'app_config';

  // Garantir que o documento existe
  Future<void> _ensureConfigExists() async {
    final doc = await _db.collection(_configCollection).doc(_configDoc).get();
    if (!doc.exists) {
      await _db.collection(_configCollection).doc(_configDoc).set(
        AppConfig(id: _configDoc).toMap(),
      );
    }
  }

  // Buscar configurações
  Future<AppConfig> getConfig() async {
    try {
      await _ensureConfigExists();  // ← GARANTE QUE EXISTE
      final doc = await _db.collection(_configCollection).doc(_configDoc).get();
      if (doc.exists) {
        return AppConfig.fromMap(doc.data()!);
      }
      return AppConfig(id: _configDoc);
    } catch (e) {
      print('Erro ao buscar config: $e');
      return AppConfig(id: _configDoc);
    }
  }

  // ── Etapa 07: % padrão do gatilho da apólice ──────────────────────────────
  // Guardado em memória depois da 1ª leitura (é usado em várias telas).
  static double? _percentualGatilhoCache;

  Future<double> getPercentualGatilho() async {
    final cache = _percentualGatilhoCache;
    if (cache != null) return cache;
    final config = await getConfig();
    _percentualGatilhoCache = config.percentualGatilhoPadrao;
    return config.percentualGatilhoPadrao;
  }

  Future<void> updatePercentualGatilho(double percentual) async {
    final valor = GatilhoApolice.normalizarPercentual(percentual);
    await _ensureConfigExists();
    await _db.collection(_configCollection).doc(_configDoc).update({
      'percentualGatilhoPadrao': valor,
    });
    _percentualGatilhoCache = valor;
  }

  // Atualizar SLA Sinistros
  Future<void> updateSlaSinistro(String ramo, int dias) async {
    await _ensureConfigExists();
    final config = await getConfig();
    config.slaSinistrosPorRamo[AppConfig.chaveSlaRamo(ramo)] = dias;
    
    await _db.collection(_configCollection).doc(_configDoc).update({
      'slaSinistrosPorRamo': config.slaSinistrosPorRamo,
    });
  }

  // Atualizar SLA Assistências
  Future<void> updateSlaAssistencia(String tipo, int minutos) async {
    await _ensureConfigExists();
    final config = await getConfig();
    config.slaAsistenciasPorTipo[tipo] = minutos;
    
    await _db.collection(_configCollection).doc(_configDoc).update({
      'slaAsistenciasPorTipo': config.slaAsistenciasPorTipo,
    });
  }

  // Getter: buscar SLA de assistência por tipo
  Future<int> getSlaAssistencia(String tipo) async {
    final config = await getConfig();
    return config.slaAsistenciasPorTipo[tipo] ?? 30;
  }

  // Getter: buscar SLA de sinistro por ramo
  Future<int> getSlaSinistro(String ramo) async {
    final config = await getConfig();
    // Etapa 08: "Vidas" (ramo do sinistro) usa o SLA salvo como "Vida".
    return config.slaSinistrosPorRamo[AppConfig.chaveSlaRamo(ramo)] ?? 10;
  }

  // Atualizar toggle NPS
  Future<void> updateNpsEnabled(bool enabled) async {
    await _ensureConfigExists();  // ← GARANTE QUE EXISTE
    await _db.collection(_configCollection).doc(_configDoc).update({
      'enableNpsSurvey': enabled,
    });
  }

  // --- Configurações de Envio de Notificações ---
  Future<void> updateNotificacaoConfig({
    required bool ativas,
    required String horarioInicio,
    required String horarioFim,
    required int intervaloMinutos,
    required int atrasoMinimo,
    required List<String> chatIds,
  }) async {
    await _ensureConfigExists();
    await _db.collection(_configCollection).doc(_configDoc).update({
      'notificacoesAtivas': ativas,
      'notificacaoHorarioInicio': horarioInicio,
      'notificacaoHorarioFim': horarioFim,
      'notificacaoIntervaloMinutos': intervaloMinutos,
      'notificacaoAtrasoMinimo': atrasoMinimo,
      'notificacaoTelegramChatIds': chatIds,
    });
  }

  // Getter individual (opcional)
  Future<bool> getNotificacoesAtivas() async {
    final config = await getConfig();
    return config.notificacoesAtivas;
  }

}