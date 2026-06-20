// lib/services/config_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/config_model.dart';

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

  // Atualizar SLA Sinistros
  Future<void> updateSlaSinistro(String ramo, int dias) async {
    await _ensureConfigExists();
    final config = await getConfig();
    config.slaSinistrosPorRamo[ramo] = dias;
    
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
    return config.slaSinistrosPorRamo[ramo] ?? 10;
  }

  // Atualizar toggle NPS
  Future<void> updateNpsEnabled(bool enabled) async {
    await _ensureConfigExists();  // ← GARANTE QUE EXISTE
    await _db.collection(_configCollection).doc(_configDoc).update({
      'enableNpsSurvey': enabled,
    });
  }
}