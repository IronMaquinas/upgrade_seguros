// lib/services/pdf_signature_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:upgrade_seguros/models/pdf_signature_model.dart';

/// Service para gerenciar configurações de assinatura em PDFs
class PdfSignatureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collectionName = 'pdf_signatures';

  /// Obtém a configuração de assinatura para uma seguradora
  Future<PdfSignatureConfig> getSignatureConfig(String seguradoraId) async {
    try {
      final doc = await _db
          .collection(_collectionName)
          .doc(seguradoraId)
          .get();

      if (doc.exists) {
        return PdfSignatureConfig.fromJson(doc.data() as Map<String, dynamic>);
      }

      // Se não existe, retorna padrão
      return PdfSignatureConfig(seguradoraId: seguradoraId);
    } catch (e) {
      print('Erro ao buscar configuração de assinatura: $e');
      return PdfSignatureConfig(seguradoraId: seguradoraId);
    }
  }

  /// Salva a configuração de assinatura
  Future<void> saveSignatureConfig(PdfSignatureConfig config) async {
    try {
      await _db
          .collection(_collectionName)
          .doc(config.seguradoraId)
          .set(
            config.copyWith(updatedAt: DateTime.now()).toJson(),
            SetOptions(merge: true),
          );
    } catch (e) {
      print('Erro ao salvar configuração de assinatura: $e');
      rethrow;
    }
  }

  /// Atualiza um campo específico
  Future<void> updateField(
    String seguradoraId,
    String fieldName,
    bool value,
  ) async {
    try {
      await _db
          .collection(_collectionName)
          .doc(seguradoraId)
          .update({
            fieldName: value,
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Erro ao atualizar campo "$fieldName": $e');
      rethrow;
    }
  }

  /// Habilita/Desabilita assinatura da seguradora
  Future<void> toggleSeguradora(String seguradoraId, bool enable) async {
    await updateField(seguradoraId, 'enableSeguradora', enable);
  }

  /// Habilita/Desabilita assinatura do funcionário
  Future<void> toggleFuncionario(String seguradoraId, bool enable) async {
    await updateField(seguradoraId, 'enableFuncionario', enable);
  }

  /// Habilita/Desabilita telefone da seguradora
  Future<void> toggleTelefoneSeguradora(String seguradoraId, bool show) async {
    await updateField(seguradoraId, 'showTelefoneSeguradora', show);
  }

  /// Habilita/Desabilita email da seguradora
  Future<void> toggleEmailSeguradora(String seguradoraId, bool show) async {
    await updateField(seguradoraId, 'showEmailSeguradora', show);
  }

  /// Habilita/Desabilita telefone do funcionário
  Future<void> toggleTelefoneFuncionario(String seguradoraId, bool show) async {
    await updateField(seguradoraId, 'showTelefoneFuncionario', show);
  }

  /// Habilita/Desabilita email do funcionário
  Future<void> toggleEmailFuncionario(String seguradoraId, bool show) async {
    await updateField(seguradoraId, 'showEmailFuncionario', show);
  }

  /// Stream para monitorar mudanças em tempo real
  Stream<PdfSignatureConfig> watchSignatureConfig(String seguradoraId) {
    return _db
        .collection(_collectionName)
        .doc(seguradoraId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            return PdfSignatureConfig.fromJson(doc.data() as Map<String, dynamic>);
          }
          return PdfSignatureConfig(seguradoraId: seguradoraId);
        });
  }
}
