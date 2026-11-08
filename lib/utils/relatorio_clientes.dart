// lib/utils/relatorio_clientes.dart
//
// Etapa 08: relatório de clientes para auditoria (exportado da lista de clientes).
// Regra única, em Dart puro (sem Firebase), testada em test/relatorio_clientes_test.dart.
//
// Uma linha por cliente, ordenada pelo valor total das apólices (maior primeiro):
//   • Valor total das apólices = soma do "Valor da Apólice" de TODAS as apólices
//     cadastradas (vigentes ou não) — o mesmo "Total das Apólices" do Detalhes do Cliente.
//   • Maior apólice = número e valor da apólice de maior valor (para achar valor
//     digitado errado, ex.: R$ 1.200.001,00 no lugar de R$ 120.000,10).
//   • Qtd. sinistros / assistências = todos os registros ligados ao cliente.
//   • Valor utilizado = soma do valor total dos sinistros, SEM Cancelado/Negado
//     (mesma regra do gatilho, Etapa 07).
//   • % usada = valor utilizado ÷ valor total das apólices.

class ApoliceResumo {
  final String numero;
  final double valor;
  const ApoliceResumo({required this.numero, required this.valor});
}

class AtendimentoResumo {
  /// 'sinistro' ou 'assistencia'
  final String tipo;
  final String status;
  final double valor;
  const AtendimentoResumo({required this.tipo, required this.status, required this.valor});
}

class ClienteEntrada {
  final String nome;
  final String documento;
  final List<ApoliceResumo> apolices;
  final List<AtendimentoResumo> atendimentos;
  const ClienteEntrada({
    required this.nome,
    required this.documento,
    required this.apolices,
    required this.atendimentos,
  });
}

class LinhaRelatorioCliente {
  final String nome;
  final String documento;
  final double valorApolices;
  final int qtdApolices;
  final String maiorApoliceNumero;
  final double maiorApoliceValor;
  final int qtdSinistros;
  final double valorUtilizado;
  final int qtdAssistencias;

  const LinhaRelatorioCliente({
    required this.nome,
    required this.documento,
    required this.valorApolices,
    required this.qtdApolices,
    required this.maiorApoliceNumero,
    required this.maiorApoliceValor,
    required this.qtdSinistros,
    required this.valorUtilizado,
    required this.qtdAssistencias,
  });

  /// null quando o cliente não tem valor de apólice (não dá para calcular).
  double? get percentualUsado => valorApolices > 0 ? valorUtilizado / valorApolices * 100 : null;
}

class RelatorioClientes {
  static const statusQueNaoContam = {'Cancelado', 'Negado'};

  final List<LinhaRelatorioCliente> linhas;
  RelatorioClientes._(this.linhas);

  factory RelatorioClientes.montar(List<ClienteEntrada> clientes) {
    final linhas = clientes.map((c) {
      ApoliceResumo? maior;
      for (final a in c.apolices) {
        if (maior == null || a.valor > maior.valor) maior = a;
      }
      final sinistros = c.atendimentos.where((a) => a.tipo == 'sinistro');
      return LinhaRelatorioCliente(
        nome: c.nome.trim(),
        documento: c.documento.trim(),
        valorApolices: c.apolices.fold(0.0, (s, a) => s + a.valor),
        qtdApolices: c.apolices.length,
        maiorApoliceNumero: maior?.numero ?? '',
        maiorApoliceValor: maior?.valor ?? 0,
        qtdSinistros: sinistros.length,
        valorUtilizado: sinistros
            .where((s) => !statusQueNaoContam.contains(s.status))
            .fold(0.0, (s, a) => s + a.valor),
        qtdAssistencias: c.atendimentos.where((a) => a.tipo == 'assistencia').length,
      );
    }).toList()
      ..sort((a, b) {
        final v = b.valorApolices.compareTo(a.valorApolices);
        return v != 0 ? v : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });
    return RelatorioClientes._(linhas);
  }

  double get totalApolices => linhas.fold(0.0, (s, l) => s + l.valorApolices);
  int get totalQtdApolices => linhas.fold(0, (s, l) => s + l.qtdApolices);
  int get totalSinistros => linhas.fold(0, (s, l) => s + l.qtdSinistros);
  double get totalUtilizado => linhas.fold(0.0, (s, l) => s + l.valorUtilizado);
  int get totalAssistencias => linhas.fold(0, (s, l) => s + l.qtdAssistencias);
  double? get percentualTotal => totalApolices > 0 ? totalUtilizado / totalApolices * 100 : null;

  // ── CSV (abre direto no Excel em português) ────────────────────────────────
  // Separador ";" e vírgula decimal, sem separador de milhar (o Excel lê como
  // número e dá para somar). Começa com BOM para os acentos aparecerem certos.

  static const cabecalho = [
    'Cliente',
    'CNPJ/CPF',
    'Valor total das apólices (R\$)',
    'Qtd. apólices',
    'Maior apólice (nº)',
    'Maior apólice (R\$)',
    'Qtd. sinistros',
    'Valor total utilizado (R\$)',
    '% da apólice usada',
    'Qtd. assistências',
  ];

  String paraCsv() {
    final b = StringBuffer('﻿');
    void linha(List<String> celulas) => b.write('${celulas.map(_celula).join(';')}\r\n');

    linha(cabecalho);
    for (final l in linhas) {
      linha([
        l.nome,
        l.documento,
        numeroCsv(l.valorApolices),
        '${l.qtdApolices}',
        l.maiorApoliceNumero,
        l.qtdApolices > 0 ? numeroCsv(l.maiorApoliceValor) : '',
        '${l.qtdSinistros}',
        numeroCsv(l.valorUtilizado),
        l.percentualUsado == null ? '' : numeroCsv(l.percentualUsado!),
        '${l.qtdAssistencias}',
      ]);
    }
    linha([
      'TOTAL (${linhas.length} clientes)',
      '',
      numeroCsv(totalApolices),
      '$totalQtdApolices',
      '',
      '',
      '$totalSinistros',
      numeroCsv(totalUtilizado),
      percentualTotal == null ? '' : numeroCsv(percentualTotal!),
      '$totalAssistencias',
    ]);
    return b.toString();
  }

  /// 1234567.891 → "1234567,89"
  static String numeroCsv(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// Aspas quando precisa; e um apóstrofo antes de = + - @ para o Excel não
  /// executar o texto como fórmula (nome de cliente vem de digitação).
  static String _celula(String v) {
    var s = v;
    if (s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
    if (s.contains(';') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
