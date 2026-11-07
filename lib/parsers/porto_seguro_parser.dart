// lib/parsers/porto_seguro_parser.dart
import 'package:intl/intl.dart';
import '../models/contrato_dto.dart';

class PortoSeguroParser {
  static ContratoDTO parse(String texto) {
    print('📄 [Porto Seguro] Analisando texto completo para extrair dados...');

    // Extrair dados diretamente do texto
    String? nome = _extractNomeFromTexto(texto);
    String? cpf = _extractCpfFromTexto(texto);
    String? celular = _extractCelularFromTexto(texto);
    String? email = _extractEmailFromTexto(texto);
    String? endereco = _extractEnderecoFromTexto(texto);

    // Dados do veículo (pega o primeiro item da frota)
    String? placa = _extractPlacaFromTexto(texto);
    String? chassi = _extractChassiFromTexto(texto);
    String? marca = _extractMarcaFromTexto(texto);
    String? modelo = _extractModeloFromTexto(texto);
    int? ano = _extractAnoFromTexto(texto);

    // Dados da apólice
    String? numeroApolice = _extractApoliceFromTexto(texto);
    DateTime? dataInicio = _extractDataInicioFromTexto(texto);
    DateTime? dataFim = _extractDataFimFromTexto(texto);

    // Valores
    double valorPremioTotal = _extractValorPremioFromTexto(texto) ?? 0.0;

    print('📋 [Porto Seguro] Dados extraídos:');
    print('  Nome: $nome');
    print('  CNPJ/CPF: $cpf');
    print('  Celular: $celular');
    print('  Email: $email');
    print('  Placa: $placa');
    print('  Chassi: $chassi');
    print('  Apólice: $numeroApolice');
    print('  Valor: $valorPremioTotal');

    final veiculo = VeiculoDTO(
      placa: placa ?? '',
      chassi: chassi ?? '',
      marca: marca ?? '',
      modelo: modelo ?? '',
      ano: ano ?? 0,
      anoModelo: ano ?? 0,
      cor: '',
      proprietarioNome: nome,
      proprietarioCPF: cpf,
    );

    return ContratoDTO(
      seguradora: 'Porto Seguro',
      numeroApolice: numeroApolice ?? '',
      dataFim: dataFim ?? DateTime.now().add(const Duration(days: 365)),
      dataInicio: dataInicio ?? DateTime.now(),
      cnpjCpfProponente: cpf ?? '',
      nomeProponente: nome ?? '',
      endereco: endereco,
      telefone: celular,
      email: email,
      contato: nome ?? '',
      veiculos: [veiculo],
      valorPremioTotal: valorPremioTotal,
      ramo: 'Veículo Individual',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 MÉTODOS DE EXTRAÇÃO ESPECÍFICOS PARA PORTO SEGURO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extrai nome do segurado
  static String? _extractNomeFromTexto(String texto) {
    // Padrão Porto: "Segurado(a): Adilson Resende Vieira - Transportadora"
    final match = RegExp(
      r'Segurado\(a\):\s*([A-Z][A-Z\s]+?)(?:\s*-|\s+CNPJ)',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final nome = match.group(1)?.trim();
      print('✅ Nome encontrado: $nome');
      return nome;
    }

    return null;
  }

  /// Extrai CNPJ/CPF
  static String? _extractCpfFromTexto(String texto) {
    // Porto usa CNPJ/CPF formatado: "07.552.654/0001-77"
    final match = RegExp(
      r'CNPJ/CPF:\s*(\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final cpf = match.group(1)?.trim();
      print('✅ CNPJ/CPF encontrado: $cpf');
      return cpf;
    }

    return null;
  }

  /// Extrai celular/whatsapp
  static String? _extractCelularFromTexto(String texto) {
    // Porto tem Whatsapp ou Celular
    var match = RegExp(
      r'Whatsapp:\s*(\d{2}\s*\d{4,5}\s*\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final celular = match.group(1)?.replaceAll(RegExp(r'\s+'), '');
      if (celular != null && celular.length >= 10) {
        print('✅ Celular encontrado: $celular');
        return celular;
      }
    }

    // Fallback: procura por padrão de telefone
    match = RegExp(r'\((\d{2})\)\s*(\d{4,5})-(\d{4})').firstMatch(texto);
    if (match != null) {
      final ddd = match.group(1);
      final numero = match.group(2);
      final final4 = match.group(3);
      final celular = '($ddd) $numero-$final4';
      print('✅ Celular encontrado: $celular');
      return celular;
    }

    return null;
  }

  /// Extrai email
  static String? _extractEmailFromTexto(String texto) {
    // Porto tem "E-mail: comercial.re@upgradeseguros.com.br"
    final match = RegExp(
      r'E-mail:\s*([\w\.-]+@[\w\.-]+\.[a-z]{2,})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final email = match.group(1)?.trim();
      print('✅ Email encontrado: $email');
      return email;
    }

    return null;
  }

  /// Extrai endereço
  static String? _extractEnderecoFromTexto(String texto) {
    // Porto: "Endereço: R Maria Jose de Souza, 464 - Rezende..."
    final match = RegExp(
      r'Endereço:\s*([A-Z][\w\s\.,\-]+?)(?:\nAtividade|$)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final endereco = match.group(1)?.trim();
      print('✅ Endereço encontrado: $endereco');
      return endereco;
    }

    return null;
  }

  /// Extrai placa
  static String? _extractPlacaFromTexto(String texto) {
    // Procura por "Placa: PUW8774" ou "Placa: RMM6612"
    final match = RegExp(
      r'Placa:\s*([A-Z]{3}\d[A-Z0-9]\d{2})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final placa = match.group(1)?.trim();
      print('✅ Placa encontrada: $placa');
      return placa;
    }

    return null;
  }

  /// Extrai chassi
  static String? _extractChassiFromTexto(String texto) {
    // Porto: "Chassi: 9BM693328EB969880" ou "Chassi: 9BM958264MB206129"
    final match = RegExp(
      r'Chassi:\s*([A-HJ-NPR-Z0-9]{17})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final chassi = match.group(1)?.trim();
      print('✅ Chassi encontrado: $chassi');
      return chassi;
    }

    return null;
  }

  /// Extrai marca
  static String? _extractMarcaFromTexto(String texto) {
    // Porto lista: "Veículo: MERCEDES BENZ CAMINHAO ATRON..."
    final marcas = [
      'MERCEDES BENZ', 'FORD', 'CHEVROLET', 'VOLKSWAGEN', 'FIAT',
      'RENAULT', 'TOYOTA', 'HONDA', 'BMW', 'AUDI', 'SCANIA', 'SCHIFFER', 'RAM'
    ];

    for (final marca in marcas) {
      if (texto.contains(marca)) {
        print('✅ Marca encontrada: $marca');
        return marca;
      }
    }

    return null;
  }

  /// Extrai modelo
  static String? _extractModeloFromTexto(String texto) {
    // Procura por "Veículo: MARCA MODELO..."
    final match = RegExp(
      r'Veículo:\s*([A-Z]{2,})\s+([A-Z0-9\s]+?)(?:\n|Fabricação)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final marca = match.group(1);
      final modelo = match.group(2)?.trim();

      // Remove a marca do modelo se estiver lá
      final modeloLimpo = modelo?.replaceFirst(RegExp(marca!), '').trim();

      if (modeloLimpo != null && modeloLimpo.isNotEmpty) {
        print('✅ Modelo encontrado: $modeloLimpo');
        return modeloLimpo;
      }
    }

    return null;
  }

  /// Extrai ano
  static int? _extractAnoFromTexto(String texto) {
    // Porto: "Fabricação/Modelo: 2014 / 2014" ou "2021 / 2021"
    final match = RegExp(
      r'Fabricação/Modelo:\s*(\d{4})\s*/\s*(\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final ano = int.tryParse(match.group(1) ?? '');
      if (ano != null && ano >= 1990 && ano <= 2030) {
        print('✅ Ano encontrado: $ano');
        return ano;
      }
    }

    return null;
  }

  /// Extrai apólice
  static String? _extractApoliceFromTexto(String texto) {
    // Porto: "Apólice atual: 0531 13 9238250"
    var match = RegExp(
      r'Apólice atual:\s*(\d{4}\s+\d{2}\s+\d{7})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final apolice = match.group(1)?.replaceAll(RegExp(r'\s+'), '');
      print('✅ Apólice encontrada: $apolice');
      return apolice;
    }

    // Fallback: procura só os dígitos
    match = RegExp(r'Apólice\s+atual:\s+(\d+)').firstMatch(texto);
    if (match != null) {
      final apolice = match.group(1);
      print('✅ Apólice encontrada: $apolice');
      return apolice;
    }

    return null;
  }

  /// Extrai data de início da vigência
  static DateTime? _extractDataInicioFromTexto(String texto) {
    // Porto: "Vigência da apólice: A partir das 24h do dia 31/05/2026 até as 24h do dia 31/05/2027"
    var match = RegExp(
      r'A partir das 24h do dia\s+(\d{2})/(\d{2})/(\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data início vigência encontrada (padrão 1): $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data início (padrão 1): $e');
      }
    }

    // Fallback: "Vigência: 31/05/2026 ATÉ 31/05/2027" ou "Vigência do item: 31/05/2026 ATÉ"
    match = RegExp(
      r'Vigência(?:\s+do\s+item)?:\s*(\d{2})/(\d{2})/(\d{4})\s+ATÉ',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data início vigência encontrada (padrão fallback): $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data início (padrão fallback): $e');
      }
    }

    return null;
  }

  /// Extrai data de vigência (fim)
  static DateTime? _extractDataFimFromTexto(String texto) {
    // Porto: "Vigência da apólice: A partir das 24h do dia 31/05/2026 até as 24h do dia 31/05/2027"
    var match = RegExp(
      r'até\s+as\s+24h\s+do\s+dia\s+(\d{2})/(\d{2})/(\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data vigência fim encontrada (padrão 1): $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data fim (padrão 1): $e');
      }
    }

    // Fallback: "Vigência: 31/05/2026 ATÉ 31/05/2027" ou "Vigência do item: 31/05/2026 ATÉ 31/05/2027"
    match = RegExp(
      r'Vigência(?:\s+do\s+item)?:.*?ATÉ\s+(\d{2})/(\d{2})/(\d{4})',
      caseSensitive: false,
      multiLine: true,
      dotAll: true,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data vigência fim encontrada (padrão fallback): $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data fim (padrão fallback): $e');
      }
    }

    return null;
  }

  /// Extrai valor do prêmio
  static double? _extractValorPremioFromTexto(String texto) {
    // Porto: "Valor total: R$ 107.909,89"
    final match = RegExp(
      r'Valor total:\s*R\$\s*([\d.]+,\d{2})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final valorStr = match.group(1)?.replaceAll('.', '').replaceAll(',', '.');
      final valor = double.tryParse(valorStr ?? '');
      if (valor != null) {
        print('✅ Valor prêmio encontrado: $valor');
        return valor;
      }
    }

    return null;
  }
}