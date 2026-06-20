import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

  /// Formatadores padrão Brasil - Use em qualquer lugar do app
  class BRFormatters {
    /// Formata moeda em R$ (ex: 1500.50 → R$ 1.500,50)
    static String formatarMoeda(dynamic valor) {
    if (valor == null) return 'R\$ 0,00';
    
    double v;
    if (valor is String) {
      // Remove pontos de milhar e converte vírgula para ponto
      final clean = valor.replaceAll('.', '').replaceAll(',', '.');
      v = double.tryParse(clean) ?? 0;
    } else {
      v = valor as double;
    }
    
    return NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    ).format(v);
  }

  /// Parse moeda de string formatada para double
  static double parseFromMoeda(String moedaFormatada) {
    final cleaned = moedaFormatada
        .replaceAll('R\$', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Formata CNPJ no padrão brasileiro (ex: 04.884.082/0001-35 ou 1A.3BC.45D/0001-EF)
  /// Suporta CNPJ alfanumérico (Receita Federal, julho/2026)
  static String formatarCNPJ(String cnpj) {
    final cleaned = cnpj.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length != 14) return cnpj;
    return '${cleaned.substring(0, 2)}.${cleaned.substring(2, 5)}.${cleaned.substring(5, 8)}/'
        '${cleaned.substring(8, 12)}-${cleaned.substring(12)}';
  }

  /// Parse CNPJ formatado para apenas letras e dígitos (sem máscara)
  static String parseFromCNPJ(String cnpjFormatado) {
    return cnpjFormatado.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// Valida CNPJ
  static bool validarCNPJ(String cnpj) {
    final cleaned = cnpj.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return cleaned.length == 14;
  }

  /// Formata telefone no padrão brasileiro (ex: 11987654321 → (11) 98765-4321)
  static String formatarTelefone(String telefone) {
    final cleaned = telefone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length < 10) return telefone;
    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 6)}-${cleaned.substring(6)}';
    }
    return '(${cleaned.substring(0, 2)}) ${cleaned.substring(2, 7)}-${cleaned.substring(7)}';
  }

  /// Parse telefone formatado para apenas dígitos
  static String parseFromTelefone(String telefoneFormatado) {
    return telefoneFormatado.replaceAll(RegExp(r'\D'), '');
  }

  /// Formata CPF no padrão brasileiro (ex: 12345678900 → 123.456.789-00)
  static String formatarCPF(String cpf) {
    final cleaned = cpf.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 11) return cpf;
    return '${cleaned.substring(0, 3)}.${cleaned.substring(3, 6)}.${cleaned.substring(6, 9)}-${cleaned.substring(9)}';
  }

  /// Parse CPF formatado para apenas dígitos
  static String parseFromCPF(String cpfFormatado) {
    return cpfFormatado.replaceAll(RegExp(r'\D'), '');
  }

  /// Valida CPF
  static bool validarCPF(String cpf) {
    final cleaned = cpf.replaceAll(RegExp(r'\D'), '');
    return cleaned.length == 11;
  }

  /// Formata CEP no padrão brasileiro (ex: 01234567 → 01234-567)
  static String formatarCEP(String cep) {
    final cleaned = cep.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 8) return cep;
    return '${cleaned.substring(0, 5)}-${cleaned.substring(5)}';
  }

  /// Parse CEP formatado para apenas dígitos
  static String parseFromCEP(String cepFormatado) {
    return cepFormatado.replaceAll(RegExp(r'\D'), '');
  }

  /// Valida CEP
  static bool validarCEP(String cep) {
    final cleaned = cep.replaceAll(RegExp(r'\D'), '');
    return cleaned.length == 8;
  }

  /// Formata peso com decimais brasileiro (ex: 1500.5 → 1.500,5)
  static String formatarPeso(dynamic peso, {String sufixo = ' kg'}) {
    if (peso == null) return '0,00$sufixo';
    final p = peso is String ? double.tryParse(peso) ?? 0 : peso as double;
    final formatter = NumberFormat.decimalPattern('pt_BR');
    return formatter.format(p) + sufixo;
  }

  /// Parse peso formatado para double
  static double parseFromPeso(String pesoFormatado) {
    final cleaned = pesoFormatado
        .replaceAll(RegExp(r'[^\d,]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Formata data para padrão brasileiro (ex: 01/01/2024)
  static String formatarData(dynamic data) {
    if (data == null) return '—';
    try {
      final d = data is Timestamp ? data.toDate() : data as DateTime;
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (e) {
      return '—';
    }
  }

  /// Formata data e hora (ex: 01/01/2024 14:30)
  static String formatarDataHora(dynamic data) {
    if (data == null) return '—';
    try {
      final d = data is Timestamp ? data.toDate() : data as DateTime;
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (e) {
      return '—';
    }
  }

  /// Formata dimensão com decimais brasileiro (ex: 100.5 → 100,5 cm)
  static String formatarDimensao(dynamic dimensao, {String sufixo = ' cm'}) {
    if (dimensao == null) return '0,00$sufixo';
    final d = dimensao is String ? double.tryParse(dimensao) ?? 0 : dimensao as double;
    final formatter = NumberFormat.decimalPattern('pt_BR');
    return formatter.format(d) + sufixo;
  }

  /// Parse dimensão formatada para double
  static double parseFromDimensao(String dimensaoFormatada) {
    final cleaned = dimensaoFormatada
        .replaceAll(RegExp(r'[^\d,]'), '')
        .replaceAll(',', '.');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Input Formatters para TextField
  static final moedaFormatter = CurrencyInputFormatter();
  static final cnpjFormatter = CNPJInputFormatter();
  static final cpfFormatter = CPFInputFormatter();
  static final cpfCnpjFormatter = CpfCnpjInputFormatter();
  static final telefoneFormatter = TelefoneInputFormatter();
  static final cepFormatter = CEPInputFormatter();
  static final pesoFormatter = DecimalInputFormatter();
}

// ════════════════════════════════════════════════════════════════════════════════
// INPUT FORMATTERS (para usar no TextField)
// ════════════════════════════════════════════════════════════════════════════════

/// Formata entrada de moeda em tempo real
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final numericText = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (numericText.isEmpty) return TextEditingValue.empty;

    final intValue = int.tryParse(numericText) ?? 0;
    final value = intValue / 100;

    final formatted = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$ ',
      decimalDigits: 2,
    ).format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata entrada de CNPJ em tempo real (XX.XXX.XXX/XXXX-XX)
/// Suporta CNPJ alfanumérico (Receita Federal, julho/2026)
class CNPJInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Aceita letras e números (alfanumérico), remove apenas pontuação/máscara
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (raw.length > 14) return oldValue;

    String formatted = '';
    for (int i = 0; i < raw.length; i++) {
      if (i == 2 || i == 5) formatted += '.';
      if (i == 8) formatted += '/';
      if (i == 12) formatted += '-';
      formatted += raw[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata entrada de CPF em tempo real (XXX.XXX.XXX-XX)
class CPFInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final numericText = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (numericText.length > 11) return oldValue;

    String formatted = '';
    for (int i = 0; i < numericText.length; i++) {
      if (i == 3 || i == 6) formatted += '.';
      if (i == 9) formatted += '-';
      formatted += numericText[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata CPF ou CNPJ automaticamente pelo tamanho digitado.
/// Até 11 chars → CPF  (XXX.XXX.XXX-XX)  — só dígitos
/// 12–14 chars  → CNPJ (XX.XXX.XXX/XXXX-XX) — alfanumérico (jul/2026)
///
/// A detecção CPF vs CNPJ usa o comprimento dos caracteres brutos:
/// enquanto o usuário digita até 11 dígitos trata como CPF;
/// ao 12º caractere (letra ou número extra) muda para CNPJ.
class CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Remove apenas pontuação/máscara, preserva letras para CNPJ alfanumérico
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (raw.length > 14) return oldValue;

    // CPF só aceita dígitos — se o usuário digitar letra, trata como CNPJ
    final isCpf = raw.length <= 11 && RegExp(r'^\d*$').hasMatch(raw);

    final formatted = isCpf ? _formatCPF(raw) : _formatCNPJ(raw);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatCPF(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buf.write('.');
      if (i == 9) buf.write('-');
      buf.write(digits[i]);
    }
    return buf.toString();
  }

  String _formatCNPJ(String raw) {
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      if (i == 2 || i == 5) buf.write('.');
      if (i == 8) buf.write('/');
      if (i == 12) buf.write('-');
      buf.write(raw[i]);
    }
    return buf.toString();
  }
}

/// Formata entrada de Telefone em tempo real ((XX) XXXXX-XXXX ou (XX) XXXX-XXXX)
class TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final numericText = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (numericText.length > 11) return oldValue;

    String formatted = '';
    if (numericText.length <= 2) {
      formatted = '(${numericText}';
    } else if (numericText.length <= 7) {
      formatted = '(${numericText.substring(0, 2)}) ${numericText.substring(2)}';
    } else if (numericText.length == 10) {
      formatted = '(${numericText.substring(0, 2)}) ${numericText.substring(2, 6)}-${numericText.substring(6)}';
    } else {
      formatted = '(${numericText.substring(0, 2)}) ${numericText.substring(2, 7)}-${numericText.substring(7)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata entrada de CEP em tempo real (XXXXX-XXX)
class CEPInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final numericText = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (numericText.length > 8) return oldValue;

    String formatted = '';
    if (numericText.length <= 5) {
      formatted = numericText;
    } else {
      formatted = '${numericText.substring(0, 5)}-${numericText.substring(5)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata entrada de decimal com padrão brasileiro (ex: 100,5)
class DecimalInputFormatter extends TextInputFormatter {
  final int casasDecimais;

  DecimalInputFormatter({this.casasDecimais = 2});

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Remove tudo exceto dígitos e vírgula
    String cleaned = newValue.text.replaceAll(RegExp(r'[^\d,]'), '');
    
    // Limita a quantidade de vírgulas
    if (cleaned.split(',').length > 2) return oldValue;
    
    // Se tem vírgula, limita casas decimais
    if (cleaned.contains(',')) {
      final parts = cleaned.split(',');
      if (parts[1].length > casasDecimais) {
        cleaned = '${parts[0]},${parts[1].substring(0, casasDecimais)}';
      }
    }
    
    // Adiciona separadores de milhar (opcional, mas agradável)
    String formatted = cleaned;
    if (!cleaned.contains(',')) {
      // Sem casas decimais, só separadores de milhar
      formatted = _formatIntegerPart(cleaned);
    } else {
      final parts = cleaned.split(',');
      final integerPart = _formatIntegerPart(parts[0]);
      formatted = '$integerPart,${parts[1]}';
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
  
  String _formatIntegerPart(String intPart) {
    if (intPart.isEmpty) return '';
    // Adiciona ponto a cada 3 dígitos da direita para a esquerda
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      buffer.write(intPart[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return buffer.toString().split('').reversed.join();
  }
}