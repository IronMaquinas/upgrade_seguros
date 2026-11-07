// lib/parsers/ezze_parser.dart
import 'package:intl/intl.dart';
import '../models/contrato_dto.dart';

class EzzeParser {
  static ContratoDTO parse(String texto) {
    print('📄 [EZZE] Analisando texto completo para extrair dados...');

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

    print('📋 [EZZE] Dados extraídos:');
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
      seguradora: 'EZZE Seguros',
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
  // 🔧 MÉTODOS DE EXTRAÇÃO ESPECÍFICOS PARA EZZE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extrai nome do segurado
  /// Padrão EZZE: "Nome\nM V DE OLIVEIRA LOCACAO DE VEICULOS DE TRANSP DE CARGA LTDA"
  static String? _extractNomeFromTexto(String texto) {
    // Procura por "Nome" seguido de quebra de linha e o nome
    final match = RegExp(
      r'Nome\s+([A-Z][A-Z0-9\s]+?)(?:\nTipo Pessoa|\nDocumento)',
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
  /// Padrão EZZE: "97.525.959/0001-82"
  static String? _extractCpfFromTexto(String texto) {
    // Procura por CNPJ formatado: XX.XXX.XXX/XXXX-XX
    final match = RegExp(
      r'(\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})',
    ).firstMatch(texto);

    if (match != null) {
      final cpf = match.group(1)?.trim();
      print('✅ CNPJ/CPF encontrado: $cpf');
      return cpf;
    }

    return null;
  }

  /// Extrai celular/telefone
  /// Padrão EZZE: "(27) 99919-5502"
  static String? _extractCelularFromTexto(String texto) {
    // Procura por Telefone label
    var match = RegExp(
      r'Telefone\s+\((\d{2})\)\s+(\d{4,5})-(\d{4})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final ddd = match.group(1);
      final parte1 = match.group(2);
      final parte2 = match.group(3);
      final celular = '($ddd) $parte1-$parte2';
      print('✅ Telefone encontrado: $celular');
      return celular;
    }

    // Fallback: padrão genérico de telefone
    match = RegExp(r'\((\d{2})\)\s*(\d{4,5})-?(\d{4})').firstMatch(texto);
    if (match != null) {
      final ddd = match.group(1);
      final parte1 = match.group(2);
      final parte2 = match.group(3);
      final celular = '($ddd) $parte1-$parte2';
      print('✅ Telefone encontrado (fallback): $celular');
      return celular;
    }

    return null;
  }

  /// Extrai email do cliente
  /// Nota: EZZE geralmente não tem email do cliente na apólice
  /// Preferir deixar vazio a pegar email da seguradora/corretor
  static String? _extractEmailFromTexto(String texto) {
    // Por enquanto, retorna null para não pegar email errado
    // EZZE não tem email do cliente no PDF
    print('⚠️ Email do cliente não encontrado na apólice EZZE');
    return null;
  }

  /// Extrai endereço
  /// Padrão EZZE: "Endereço\nR CECILIA PENA GOMES, 56"
  static String? _extractEnderecoFromTexto(String texto) {
    // Procura por "Endereço" seguido do endereço
    final match = RegExp(
      r'Endereço\s+([A-Z][\w\s\.,\-]+?)(?:\nBairro)',
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
  /// Padrão EZZE: "Placa\nFYZ5569"
  static String? _extractPlacaFromTexto(String texto) {
    // Procura por "Placa" seguido da placa
    final match = RegExp(
      r'Placa\s+([A-Z]{3}\d[A-Z0-9]\d{2})',
      caseSensitive: false,
    ).firstMatch(texto);

    if (match != null) {
      final placa = match.group(1)?.trim();
      print('✅ Placa encontrada: $placa');
      return placa;
    }

    return null;
  }

  /// Extrai chassi do veículo
  /// Padrão EZZE: "Chassi\n8AJBA3CD4J1606157"
  static String? _extractChassiFromTexto(String texto) {
    // Procura por "Chassi" seguido do chassi (17 caracteres VIN)
    final match = RegExp(
      r'Chassi\s+([A-HJ-NPR-Z0-9]{17})',
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
  /// Padrão EZZE: "Marca/Modelo\nTOYOTA | Hilux..."
  static String? _extractMarcaFromTexto(String texto) {
    // Procura por "Marca/Modelo" seguido da marca
    final match = RegExp(
      r'Marca/Modelo\s+([A-Z][A-Z0-9\s]+?)\s*\|',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final marca = match.group(1)?.trim();
      print('✅ Marca encontrada: $marca');
      return marca;
    }

    // Fallback: procura por marcas conhecidas
    final marcas = [
      'TOYOTA', 'FORD', 'CHEVROLET', 'VOLKSWAGEN', 'FIAT', 'SCANIA',
      'RENAULT', 'MERCEDES BENZ', 'HONDA', 'BMW', 'AUDI', 'RAM'
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
  /// Padrão EZZE: "Marca/Modelo\nTOYOTA | Hilux Cd Srx 4X4 2.8 Tdi 16V"
  static String? _extractModeloFromTexto(String texto) {
    // Procura por modelo após o pipe (|)
    final match = RegExp(
      r'\|\s*([A-Za-z0-9\s\.]+?)(?:\nAno Modelo)',
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
  /// Padrão EZZE: "Ano Modelo\n2018"
  static int? _extractAnoFromTexto(String texto) {
    // Procura por "Ano Modelo" seguido do ano
    final match = RegExp(
      r'Ano Modelo\s+(\d{4})',
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
  /// Padrão EZZE: "Nº Apólice\n1003100122598"
  static String? _extractApoliceFromTexto(String texto) {
    // Procura por "Nº Apólice" seguido do número
    final match = RegExp(
      r'Nº\s+Apólice\s+(\d+)',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      final apolice = match.group(1)?.trim();
      print('✅ Apólice encontrada: $apolice');
      return apolice;
    }

    return null;
  }

  /// Extrai data de início da vigência
  /// Padrão EZZE: "Vigência\ndas 00:00 do dia 09/05/2026 até 23:59 do dia 09/05/2027"
  static DateTime? _extractDataInicioFromTexto(String texto) {
    // Procura por "Vigência" e extrai a primeira data
    final match = RegExp(
      r'Vigência\s+das\s+\d{2}:\d{2}\s+do\s+dia\s+(\d{2})/(\d{2})/(\d{4})',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data início vigência encontrada: $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data início: $e');
      }
    }

    return null;
  }

  /// Extrai data de fim da vigência
  /// Padrão EZZE: "Vigência\ndas 00:00 do dia 09/05/2026 até 23:59 do dia 09/05/2027"
  static DateTime? _extractDataFimFromTexto(String texto) {
    // Procura por "até 23:59 do dia" e extrai a data
    final match = RegExp(
      r'até\s+\d{2}:\d{2}\s+do\s+dia\s+(\d{2})/(\d{2})/(\d{4})',
      multiLine: true,
    ).firstMatch(texto);

    if (match != null) {
      try {
        final dia = int.parse(match.group(1) ?? '0');
        final mes = int.parse(match.group(2) ?? '0');
        final ano = int.parse(match.group(3) ?? '0');
        final data = DateTime(ano, mes, dia);
        print('✅ Data fim vigência encontrada: $data');
        return data;
      } catch (e) {
        print('⚠️ Erro ao processar data fim: $e');
      }
    }

    return null;
  }

  /// Extrai valor do prêmio
  /// Padrão EZZE: "Prêmio Líquido Total    R$ 76.271,19"
  static double? _extractValorPremioFromTexto(String texto) {
    // Procura por "Prêmio Líquido Total" seguido do valor
    final match = RegExp(
      r'Prêmio\s+Líquido\s+Total\s+R\$\s*([\d.]+,\d{2})',
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