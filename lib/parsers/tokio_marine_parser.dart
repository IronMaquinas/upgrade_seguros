// lib/parsers/tokio_marine_parser.dart
import 'package:intl/intl.dart';
import '../models/contrato_dto.dart';

class TokioMarineParser {
  static ContratoDTO parse(String texto) {
    // 🔥 Estratégia V3: Extrair direto do texto completo (sem esperar quebras perfeitas)

    print('📄 Analisando texto completo para extrair dados...');

    // Extrair dados diretamente do texto completo usando regex
    String? nome = _extractNomeFromTexto(texto);
    String? cpf = _extractCpfFromTexto(texto);
    String? celular = _extractTelefoneFromTexto(texto); // Usamos celular em vez de telefone
    String? email = _extractEmailFromTexto(texto);
    String? endereco = _extractEnderecoFromTexto(texto);

    // Dados do veículo
    String? placa = _extractPlacaFromTexto(texto);
    String? chassi = _extractChassiFromTexto(texto);
    String? marca = _extractMarcaFromTexto(texto);
    String? modelo = _extractModeloFromTexto(texto);
    int? ano = _extractAnoFromTexto(texto);
    int? anoModelo = _extractAnoModeloFromTexto(texto);

    // Dados da apólice
    String? numeroApolice = _extractApoliceFromTexto(texto);
    DateTime? dataFim = _extractDataFimFromTexto(texto);
    DateTime dataInicio = dataFim?.subtract(const Duration(days: 365)) ?? DateTime.now();

    // Valores
    double valorPremioTotal = _extractValorPremioFromTexto(texto) ?? 0.0;
    double? valorFranquia = _extractValorFranquiaFromTexto(texto);

    print('📋 Dados extraídos (V3):');
    print('  Nome: $nome');
    print('  CPF: $cpf');
    print('  Celular: $celular');
    print('  Email: $email');
    print('  Placa: $placa');
    print('  Apólice: $numeroApolice');
    print('  Valor: $valorPremioTotal');

    final veiculo = VeiculoDTO(
      placa: placa ?? '',
      chassi: chassi ?? '',
      marca: marca ?? '',
      modelo: modelo ?? '',
      ano: ano ?? 0,
      anoModelo: anoModelo ?? 0,
      cor: '',
      proprietarioNome: nome,
      proprietarioCPF: cpf,
    );

    return ContratoDTO(
      seguradora: 'Tokio Marine',
      numeroApolice: numeroApolice ?? '',
      dataFim: dataFim ?? DateTime.now().add(const Duration(days: 365)),
      dataInicio: dataInicio,
      cnpjCpfProponente: cpf ?? '',
      nomeProponente: nome ?? '',
      endereco: endereco,
      telefone: celular, // Celular em vez de telefone
      email: email,
      contato: nome ?? '',
      veiculos: [veiculo],
      valorPremioTotal: valorPremioTotal,
      valorFranquia: valorFranquia,
      ramo: 'Veículo Individual',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 NOVOS MÉTODOS - Extração direto do texto completo
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extrai nome procurando por "MARCONY DOS REIS MONTEIRO" ou similar
  /// Pattern: Nome está depois de "Proponente" ou antes de CPF
  static String? _extractNomeFromTexto(String texto) {
    // Procura por: "nome completo" seguido de CPF
    final match = RegExp(
      r'([A-Z]{2,}(?:\s+[A-Z]{2,})+)\s+(\d{3}\.\d{3}\.\d{3}-\d{2})',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final nome = match.group(1)?.trim();
      print('✅ Nome encontrado: $nome');
      return nome;
    }

    return null;
  }

  /// Extrai CPF no formato "075.208.487-95"
  static String? _extractCpfFromTexto(String texto) {
    final match = RegExp(
      r'(\d{3}\.\d{3}\.\d{3}-\d{2})',
    ).firstMatch(texto);

    if (match != null) {
      final cpf = match.group(1)?.trim();
      print('✅ CPF encontrado: $cpf');
      return cpf;
    }

    return null;
  }

  /// Extrai celular (prioridade) ou telefone fixo
  static String? _extractTelefoneFromTexto(String texto) {
    // 1. Tenta encontrar "Celular" seguido de número
    var match = RegExp(
      r'Celular\s*\((\d{2})\)\s*(\d{4,5})-?(\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final ddd = match.group(1);
      final parte1 = match.group(2);
      final parte2 = match.group(3);
      final numero = '($ddd) $parte1-$parte2';
      print('✅ Celular encontrado: $numero');
      return numero;
    }

    // 2. Fallback: "Telefone" fixo
    match = RegExp(
      r'Telefone\s*\((\d{2})\)\s*(\d{4,5})-?(\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final ddd = match.group(1);
      final parte1 = match.group(2);
      final parte2 = match.group(3);
      final numero = '($ddd) $parte1-$parte2';
      print('✅ Telefone encontrado (fallback): $numero');
      return numero;
    }

    // 3. Fallback genérico: prioriza celular (9 dígitos)
    match = RegExp(
      r'\((\d{2})\)\s*(\d{5})-?(\d{4})',
    ).firstMatch(texto);

    if (match != null) {
      final ddd = match.group(1);
      final parte1 = match.group(2);
      final parte2 = match.group(3);
      final numero = '($ddd) $parte1-$parte2';
      print('✅ Celular encontrado (fallback genérico): $numero');
      return numero;
    }

    // 4. Último fallback: qualquer número (XX) XXXX-XXXX
    match = RegExp(
      r'\((\d{2})\)\s*(\d{4,5})-?(\d{4})',
    ).firstMatch(texto);

    if (match != null) {
      final ddd = match.group(1);
      final parte1 = match.group(2);
      final parte2 = match.group(3);
      final numero = '($ddd) $parte1-$parte2';
      print('✅ Número encontrado (fallback genérico): $numero');
      return numero;
    }

    return null;
  }

  /// Extrai email
  static String? _extractEmailFromTexto(String texto) {
    // Procura por: email@domain.com seguido de caractere (não número)
    final match = RegExp(
      r'([\w\.-]+@[\w\.-]+\.com)[A-Z\s]',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final email = match.group(1)?.trim();
      print('✅ Email encontrado: $email');
      return email;
    }

    return null;
  }

  /// Extrai endereço (começa com "RODOVIA", "RUA", "AVENIDA", etc)
  static String? _extractEnderecoFromTexto(String texto) {
    final match = RegExp(
      r'((?:RODOVIA|RUA|AVENIDA|TRAVESSA|PRAÇA|ALAMEDA)\s+[A-Z0-9\s,.]+?)(?:\s+(?:VL\s+DE|BAIRRO|CIDADE))',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final endereco = match.group(1)?.trim();
      print('✅ Endereço encontrado: $endereco');
      return endereco;
    }

    return null;
  }

  /// Extrai placa - padrão: "KXP-7994" ou similar
  static String? _extractPlacaFromTexto(String texto) {
    // Procura por: "Sim KXP-799495" ou similar
    // Em [30] vem: "...15/03/2027 Sim KXP-799495 PJU..."
    var match = RegExp(
      r'Sim\s+([A-Z]{3})[\s-]?(\d{4,5})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final letras = match.group(1) ?? '';
      final numeros = match.group(2) ?? '';

      // Valida: números devem ter no máximo 4 dígitos para placa válida
      if (numeros.length >= 4) {
        final numerosLimpos = numeros.substring(0, 4);
        final placa = '$letras-$numerosLimpos';
        print('✅ Placa encontrada: $placa');
        return placa;
      }
    }

    return null;
  }

   /// Extrai chassi - prioriza "Chassi" label e padrões de VIN
  static String? _extractChassiFromTexto(String texto) {
    // 1. Tenta VIN de 17 caracteres
    var match = RegExp(r'\b([A-HJ-NPR-Z0-9]{17})\b').firstMatch(texto);
    if (match != null) {
      final vin = match.group(1)?.toUpperCase();
      if (vin != null && _isValidVin(vin)) {
        return vin;
      }
    }

    // 2. Tenta "Chassi" label
    match = RegExp(r'Chassi\s*(?:decodificado)?\s*([A-HJ-NPR-Z0-9\s]{10,20})', caseSensitive: false).firstMatch(texto);
    if (match != null) {
      final vinComEspacos = match.group(1)?.trim() ?? '';
      final vin = vinComEspacos.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
      if (vin.length == 17 && _isValidVin(vin)) {
        return vin;
      }
    }

    // Se não encontrar, retorna null
    return null;
  }

  static bool _isValidVin(String vin) {
    if (vin.length != 17) return false;
    if (vin.contains(RegExp(r'[IOQ]'))) return false;
    final letters = vin.replaceAll(RegExp(r'[0-9]'), '').length;
    final digits = vin.replaceAll(RegExp(r'[A-Z]'), '').length;
    return letters >= 3 && digits >= 3;
  }

    /// Extrai marca/fabricante - "HYUNDAI", "FORD", etc
    static String? _extractMarcaFromTexto(String texto) {
      // Procura por marcas conhecidas (com espaços ou não)
      var match = RegExp(
        r'(HYUNDAI|FORD|VOLKSWAGEN|FIAT|CHEVROLET|RENAULT|TOYOTA|HONDA|BMW|AUDI|NISSAN|PEUGEOT|CITROËN)',
        caseSensitive: false,
      ).firstMatch(texto);

      if (match != null) {
        final marca = match.group(1)?.trim().toUpperCase();
        print('✅ Marca encontrada: $marca');
        return marca;
      }

      return null;
    }

  /// Extrai modelo - "IX35 2.0 16V 2WD FLEX AUT"
  static String? _extractModeloFromTexto(String texto) {
    // Padrão: HYUNDAI seguido de modelo
    // Exemplo em [30]: "HYUNDAIIX 35 2.0 16 V 2 WD FLEX AUT"
    var match = RegExp(
      r'HYUNDAI\s*([A-Z0-9\s\.]+?)(?=\s+Combustível|\s+Flex|\s+Lotação|$)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      var modelo = match.group(1)?.trim() ?? '';
      // Remove espaços extras
      modelo = modelo.replaceAll(RegExp(r'\s+'), ' ');
      // Remove lixo no final
      modelo = modelo.replaceAll(RegExp(r'\s*[A-Z]\s*$'), '').trim();

      if (modelo.isNotEmpty && modelo.length > 2) {
        print('✅ Modelo encontrado: $modelo');
        return modelo;
      }
    }

    return null;
  }

  /// Extrai ano de fabricação - "2015"
  static int? _extractAnoFromTexto(String texto) {
    // Padrão 1: após placa (KXP-7994) vem dados do carro incluindo ano
    // "KXP-7994 ... 2015"
    var match = RegExp(
      r'[A-Z]{3}-\d+\s+[A-Z0-9\s]+?(20\d{2})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final ano = int.tryParse(match.group(1) ?? '');
      if (ano != null && ano > 2000 && ano < 2030) {
        print('✅ Ano encontrado: $ano');
        return ano;
      }
    }

    // Padrão 2: procura direto por "2015" ou similar (evita 2004-74 do SUSEP)
    // Mas garante que é após placa/veículo
    match = RegExp(
      r'\b(20(?:1[0-9]|2[0-9]))\b(?!-)',
    ).firstMatch(texto);

    if (match != null) {
      final ano = int.tryParse(match.group(1) ?? '');
      if (ano != null && ano > 2000 && ano < 2030) {
        // Verifica se não é do SUSEP (2004-74)
        if (!texto.contains('2004-74')) {
          print('✅ Ano encontrado (direto): $ano');
          return ano;
        }
      }
    }

    return null;
  }

  /// Extrai ano modelo (geralmente o mesmo que ano)
  static int? _extractAnoModeloFromTexto(String texto) {
    return _extractAnoFromTexto(texto);
  }

  /// Extrai número da apólice - "35033157"
  static String? _extractApoliceFromTexto(String texto) {
    // Padrão 1: 8 dígitos + espaço + 11 dígitos (com espaço)
    var match = RegExp(
      r'\b(\d{8})\s+\d{11}',
    ).firstMatch(texto);

    if (match != null) {
      final apolice = match.group(1)?.trim();
      print('✅ Apólice encontrada: $apolice');
      return apolice;
    }

    // Padrão 2: 8 dígitos + 11 dígitos (SEM espaço - concatenado)
    // Exemplo: 35033157619257779106271
    match = RegExp(
      r'\b(\d{8})(\d{11})',
    ).firstMatch(texto);

    if (match != null) {
      final apolice = match.group(1)?.trim();
      print('✅ Apólice encontrada (sem espaço): $apolice');
      return apolice;
    }

    return null;
  }

  /// Extrai data de fim de vigência - prioriza "Fim de vigência" ou intervalo de renovação
  static DateTime? _extractDataFimFromTexto(String texto) {
    // 1. Tenta "Fim de vigência" (label)
    var match = RegExp(r'Fim\s*de\s*vigência\s*(\d{2}/\d{2}/\d{4})', caseSensitive: false).firstMatch(texto);
    if (match != null) {
      try {
        return DateFormat('dd/MM/yyyy').parse(match.group(1)!);
      } catch (_) {}
    }

    // 2. Tenta "Renovação Tokio" com intervalo (ex: 15/03/2026 - 15/03/2027) e pega a última data
    match = RegExp(r'Renovação\s*Tokio\s*(\d{2}/\d{2}/\d{4})\s*-\s*(\d{2}/\d{2}/\d{4})', caseSensitive: false)
        .firstMatch(texto);
    if (match != null) {
      try {
        final dataFim = DateFormat('dd/MM/yyyy').parse(match.group(2)!);
        return dataFim;
      } catch (_) {}
    }

    // 3. Tenta "Vigência" em outros contextos (como linha [21])
    match = RegExp(r'Vigência\s*(\d{2}/\d{2}/\d{4})', caseSensitive: false).firstMatch(texto);
    if (match != null) {
      try {
        return DateFormat('dd/MM/yyyy').parse(match.group(1)!);
      } catch (_) {}
    }

    // 4. Fallback: pega a primeira data (pode ser a de impressão, evite se possível)
    match = RegExp(r'(\d{2}/\d{2}/\d{4})').firstMatch(texto);
    if (match != null) {
      try {
        return DateFormat('dd/MM/yyyy').parse(match.group(1)!);
      } catch (_) {}
    }

    return null;
  }

  /// Extrai valor do prêmio - "R$ 2.369,87"
  static double? _extractValorPremioFromTexto(String texto) {
    final match = RegExp(
      r'Prêmio\s*Líquido\s*total\s+R\$\s*([\d\.,]+)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final valorStr = match.group(1);
      if (valorStr != null) {
        try {
          final cleaned = valorStr
              .replaceAll('.', '')
              .replaceAll(',', '.');
          final valor = double.tryParse(cleaned);
          print('✅ Valor prêmio encontrado: $valor');
          return valor;
        } catch (e) {
          print('❌ Erro ao parsear valor: $valorStr');
        }
      }
    }

    return null;
  }

  /// Extrai valor da franquia - "R$ 4.570,00"
  static double? _extractValorFranquiaFromTexto(String texto) {
    final match = RegExp(
      r'Indenização\s*Parcial\s*do\s*Veículo\s+R\$\s*([\d\.,]+)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final valorStr = match.group(1);
      if (valorStr != null) {
        try {
          final cleaned = valorStr
              .replaceAll('.', '')
              .replaceAll(',', '.');
          final valor = double.tryParse(cleaned);
          print('✅ Valor franquia encontrado: $valor');
          return valor;
        } catch (e) {
          print('❌ Erro ao parsear franquia: $valorStr');
        }
      }
    }

    return null;
  }
}
