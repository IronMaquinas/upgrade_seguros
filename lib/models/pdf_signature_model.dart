// lib/models/pdf_signature_model.dart

/// Opções para assinatura em PDF - de onde vem cada dado
enum SignatureSource {
  funcionario,  // Usar dados do funcionário logado
  corretora;    // Usar dados da corretora/seguradora

  String get label => this == SignatureSource.funcionario 
      ? 'Funcionário' 
      : 'Corretora';
}

/// Modelo simplificado para configuração de assinatura em PDFs de sinistros
class PdfSignatureConfig {
  /// De onde vem o nome na assinatura
  final SignatureSource nomeSource;

  /// De onde vem o telefone na assinatura
  final SignatureSource telefoneSource;

  /// De onde vem o email na assinatura
  final SignatureSource emailSource;

  /// ID da seguradora (para referência)
  final String seguradoraId;

  /// Data de última atualização
  final DateTime? updatedAt;

  PdfSignatureConfig({
    this.nomeSource = SignatureSource.funcionario,
    this.telefoneSource = SignatureSource.funcionario,
    this.emailSource = SignatureSource.funcionario,
    required this.seguradoraId,
    this.updatedAt,
    // ← Removidos parâmetros antigos para evitar confusão
  });

  // ─── GETTERS DE COMPATIBILIDADE (backward compatibility) ─────────────────
  // Estes getters mantêm o código antigo funcionando sem quebras
  
  /// DEPRECATED: Use nomeSource, telefoneSource, emailSource
  bool get enableSeguradora => true; // Sempre true na nova versão
  
  /// DEPRECATED: Use nomeSource, telefoneSource, emailSource
  bool get enableFuncionario => true; // Sempre true na nova versão
  
  /// DEPRECATED: Use telefoneSource
  bool get showTelefoneSeguradora => telefoneSource == SignatureSource.corretora;
  
  /// DEPRECATED: Use emailSource
  bool get showEmailSeguradora => emailSource == SignatureSource.corretora;
  
  /// DEPRECATED: Use telefoneSource
  bool get showTelefoneFuncionario => telefoneSource == SignatureSource.funcionario;
  
  /// DEPRECATED: Use emailSource
  bool get showEmailFuncionario => emailSource == SignatureSource.funcionario;

  /// Converte para JSON para enviar ao Firestore
  Map<String, dynamic> toJson() {
    return {
      'nomeSource': nomeSource.name,
      'telefoneSource': telefoneSource.name,
      'emailSource': emailSource.name,
      'seguradoraId': seguradoraId,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Cria a partir de JSON do Firestore
  factory PdfSignatureConfig.fromJson(Map<String, dynamic> json) {
    return PdfSignatureConfig(
      nomeSource: SignatureSource.values.byName(json['nomeSource'] ?? 'funcionario'),
      telefoneSource: SignatureSource.values.byName(json['telefoneSource'] ?? 'funcionario'),
      emailSource: SignatureSource.values.byName(json['emailSource'] ?? 'funcionario'),
      seguradoraId: json['seguradoraId'] ?? '',
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  /// Cria uma cópia com alterações
  PdfSignatureConfig copyWith({
    SignatureSource? nomeSource,
    SignatureSource? telefoneSource,
    SignatureSource? emailSource,
    String? seguradoraId,
    DateTime? updatedAt,
    // ← Removidos parâmetros antigos
  }) {
    return PdfSignatureConfig(
      nomeSource: nomeSource ?? this.nomeSource,
      telefoneSource: telefoneSource ?? this.telefoneSource,
      emailSource: emailSource ?? this.emailSource,
      seguradoraId: seguradoraId ?? this.seguradoraId,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  String toString() => 'PdfSignatureConfig('
      'nome: ${nomeSource.label}, '
      'telefone: ${telefoneSource.label}, '
      'email: ${emailSource.label})';
}