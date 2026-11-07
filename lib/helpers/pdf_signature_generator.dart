// lib/helpers/pdf_signature_generator.dart

import 'package:upgrade_seguros/models/signature_data_model.dart';
import 'package:upgrade_seguros/models/pdf_signature_model.dart';
import 'package:upgrade_seguros/models/seguradora_model.dart';

/// Classe para auxiliar na geração de assinatura em PDF
/// Baseado na configuração de assinatura da seguradora
class PdfSignatureGenerator {
  /// Gera dados de assinatura baseado na configuração e dados da seguradora
  static SignatureData generateSignature({
    required PdfSignatureConfig config,
    required Seguradora seguradora,
    String? funcionarioNome,
    String? funcionarioTelefone,
    String? funcionarioEmail,
  }) {
    // Determina qual assinatura usar (funcionário tem prioridade)
    if (config.enableFuncionario &&
        funcionarioNome != null &&
        funcionarioNome.isNotEmpty) {
      return SignatureData(
        nome: funcionarioNome,
        telefone: config.showTelefoneFuncionario ? funcionarioTelefone : null,
        email: config.showEmailFuncionario ? funcionarioEmail : null,
        rodape: null,
      );
    }

    // Caso contrário, usa dados da seguradora
    if (config.enableSeguradora) {
      return SignatureData(
        nome: seguradora.nome,
        telefone: config.showTelefoneSeguradora ? seguradora.telefone : null,
        email: config.showEmailSeguradora ? seguradora.email : null,
        rodape: null,
      );
    }

    // Se nada estiver habilitado, retorna vazio
    return SignatureData(nome: '');
  }

  /// Gera assinatura para múltiplas seções (com ambas seguradora e funcionário)
  static List<SignatureData> generateMultipleSignatures({
    required PdfSignatureConfig config,
    required Seguradora seguradora,
    String? funcionarioNome,
    String? funcionarioTelefone,
    String? funcionarioEmail,
  }) {
    final signatures = <SignatureData>[];

    // Adiciona assinatura da seguradora se habilitada
    if (config.enableSeguradora) {
      signatures.add(SignatureData(
        nome: seguradora.nome,
        telefone: config.showTelefoneSeguradora ? seguradora.telefone : null,
        email: config.showEmailSeguradora ? seguradora.email : null,
        rodape: null,
      ));
    }

    // Adiciona assinatura do funcionário se habilitada
    if (config.enableFuncionario &&
        funcionarioNome != null &&
        funcionarioNome.isNotEmpty) {
      signatures.add(SignatureData(
        nome: funcionarioNome,
        telefone: config.showTelefoneFuncionario ? funcionarioTelefone : null,
        email: config.showEmailFuncionario ? funcionarioEmail : null,
        rodape: null,
      ));
    }

    return signatures;
  }
}