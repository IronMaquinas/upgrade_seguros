// lib/parsers/axa_parser.dart
import 'package:intl/intl.dart';
import '../models/contrato_dto.dart';

class AxaParser {
  static ContratoDTO parse(String texto) {
    print('📄 [AXA] Analisando texto completo para extrair dados...');

    // Extrair dados do cliente
    String? nome = _extractNomeFromTexto(texto);
    String? cpf = _extractCpfFromTexto(texto);
    String? celular = _extractCelularFromTexto(texto);
    String? email = _extractEmailFromTexto(texto);
    String? endereco = _extractEnderecoFromTexto(texto);

    // Dados do veículo (pega o primeiro item)
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

    print('📋 [AXA] Dados extraídos:');
    print('  Nome: $nome');
    print('  CNPJ/CPF: $cpf');
    print('  Celular: $celular');
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
      seguradora: 'AXA Seguros',
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
  // 🔧 MÉTODOS DE EXTRAÇÃO ESPECÍFICOS PARA AXA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extrai nome do segurado
  /// Padrão AXA: "Segurado: L TRANSPORTES LTDA ME"
  static String? _extractNomeFromTexto(String texto) {
    final match = RegExp(
      r'Segurado:\s+([A-Z][A-Z0-9\s\.]+?)(?:\nCNPJ:|$)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final nome = match.group(1)?.trim();
      if (nome != null && nome.isNotEmpty) {
        print('✅ Nome encontrado: $nome');
        return nome;
      }
    }

    return null;
  }

  /// Extrai CNPJ/CPF
  /// Padrão AXA: "CNPJ: 44.164.738/0001-60"
  static String? _extractCpfFromTexto(String texto) {
    final match = RegExp(
      r'CNPJ:\s*(\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})',
    ).firstMatch(texto);

    if (match != null) {
      final cpf = match.group(1)?.trim();
      print('✅ CNPJ/CPF encontrado: $cpf');
      return cpf;
    }

    return null;
  }

  /// Extrai celular/telefone
  /// AXA geralmente não tem telefone do cliente no PDF
  static String? _extractCelularFromTexto(String texto) {
    // Por enquanto retorna null - AXA não tem telefone na apólice
    print('⚠️ Telefone do cliente não encontrado na apólice AXA');
    return null;
  }

  /// Extrai email
  /// AXA geralmente não tem email do cliente
  static String? _extractEmailFromTexto(String texto) {
    print('⚠️ Email do cliente não encontrado na apólice AXA');
    return null;
  }

  /// Extrai endereço
  /// Padrão AXA: "Endereço: DIST SAO JOAQUIM S N LT SIT DU PONTES,"
  static String? _extractEnderecoFromTexto(String texto) {
    final match = RegExp(
      r'Endereço:\s+([A-Z0-9\s\.,]+?)(?:\nBairro:|$)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final endereco = match.group(1)?.trim();
      print('✅ Endereço encontrado: $endereco');
      return endereco;
    }

    return null;
  }

  /// Extrai placa do veículo
  /// Padrão AXA: "Placa: SGG8D95" ou pode estar vazia
  static String? _extractPlacaFromTexto(String texto) {
    // Procura por "Placa: " seguido de letra/números
    final match = RegExp(
      r'Placa:\s+([A-Z0-9]{4,8})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final placa = match.group(1)?.trim();
      // Validar se parece uma placa real (não vazia, não apenas espaços)
      if (placa != null && placa.isNotEmpty && !placa.contains('Marca')) {
        print('✅ Placa encontrada: $placa');
        return placa;
      }
    }

    return null;
  }

  /// Extrai chassi do veículo
  /// Padrão AXA: "Chassi: 9539K8TJ3SR203236"
  static String? _extractChassiFromTexto(String texto) {
    final match = RegExp(
      r'Chassi:\s+([A-HJ-NPR-Z0-9]{17})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final chassi = match.group(1)?.trim();
      print('✅ Chassi encontrado: $chassi');
      return chassi;
    }

    return null;
  }

  /// Extrai marca do veículo
  /// Padrão AXA: "Marca: VOLKSWAGEN"
  static String? _extractMarcaFromTexto(String texto) {
    final match = RegExp(
      r'Marca:\s+([A-Z][A-Z\s]+?)(?:\nAno|$)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final marca = match.group(1)?.trim();
      if (marca != null && marca.isNotEmpty && !marca.contains('Modelo')) {
        print('✅ Marca encontrada: $marca');
        return marca;
      }
    }

    // Fallback: procura por marcas conhecidas
    final marcas = [
      'VOLKSWAGEN', 'TOYOTA', 'FORD', 'CHEVROLET', 'FIAT', 'RENAULT',
      'MERCEDES BENZ', 'SCANIA', 'VOLVO', 'HONDA', 'BMW', 'AUDI'
    ];

    for (final marca in marcas) {
      if (texto.contains(marca)) {
        print('✅ Marca encontrada (fallback): $marca');
        return marca;
      }
    }

    return null;
  }

  /// Extrai modelo do veículo
  /// Padrão AXA: "Modelo: Meteor 29.530 6x4 2p (diesel)(E6)"
  static String? _extractModeloFromTexto(String texto) {
    final match = RegExp(
      r'Modelo:\s+([A-Za-z0-9\s\.\(\)\-]+?)(?:\nChassi:|$)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final modelo = match.group(1)?.trim();
      if (modelo != null && modelo.isNotEmpty) {
        print('✅ Modelo encontrado: $modelo');
        return modelo;
      }
    }

    return null;
  }

  /// Extrai ano do veículo
  /// Padrão AXA: "Ano Modelo: 2025"
  static int? _extractAnoFromTexto(String texto) {
    final match = RegExp(
      r'Ano Modelo:\s+(\d{4})',
      multiLine: true,
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

  /// Extrai número da apólice
  /// Padrão AXA: "Apólice: 02852.2025.0027.0531.0002446"
  static String? _extractApoliceFromTexto(String texto) {
    final match = RegExp(
      r'Apólice:\s+([\d\.]+)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final apolice = match.group(1)?.trim().replaceAll('.', '');
      print('✅ Apólice encontrada: $apolice');
      return apolice;
    }

    return null;
  }

  /// Extrai data de início da vigência
  /// Padrão AXA: "Início de Vigência das 24h de 17/11/2025"
  static DateTime? _extractDataInicioFromTexto(String texto) {
    final match = RegExp(
      r'Início de Vigência das 24h de (\d{2})/(\d{2})/(\d{4})',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data início encontrada: $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data início: $e');
      }
    }

    return null;
  }

  /// Extrai data de fim da vigência
  /// Padrão AXA: "Final de Vigência até 24h de 17/11/2026"
  static DateTime? _extractDataFimFromTexto(String texto) {
    final match = RegExp(
      r'Final de Vigência até 24h de (\d{2})/(\d{2})/(\d{4})',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data fim encontrada: $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data fim: $e');
      }
    }

    return null;
  }

  /// Extrai valor do prêmio total
  /// Padrão AXA: "Prêmio Total: R$ 113.885,41"
  static double? _extractValorPremioFromTexto(String texto) {
    final match = RegExp(
      r'Prêmio Total:\s+R\$\s+([\d.]+,\d{2})',
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