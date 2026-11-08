// lib/services/relatorio_clientes_pdf.dart
//
// Etapa 08: PDF do relatório de clientes (auditoria). Os números vêm de
// lib/utils/relatorio_clientes.dart, os mesmos do CSV.
// Usa a fonte padrão do PDF (Helvetica): só caracteres latinos, sem emoji.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/relatorio_clientes.dart';

class RelatorioClientesPdf {
  static const _azul = PdfColor.fromInt(0xFF1565C0);
  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
  static final _pct = NumberFormat.decimalPatternDigits(locale: 'pt_BR', decimalDigits: 1);

  static String _p(double? v) => v == null ? '-' : '${_pct.format(v)}%';

  static Future<Uint8List> gerar(RelatorioClientes r, {DateTime? geradoEm}) async {
    final quando = DateFormat('dd/MM/yyyy HH:mm').format(geradoEm ?? DateTime.now());
    final doc = pw.Document(title: 'Relatório de clientes', author: 'Upgrade Seguros');

    const titulos = [
      'Cliente',
      'Valor total das apólices',
      'Apólices',
      'Maior apólice',
      'Sinistros',
      'Valor utilizado',
      '% usada',
      'Assist.',
    ];
    const larguras = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(3.2),
      1: pw.FlexColumnWidth(1.6),
      2: pw.FlexColumnWidth(0.8),
      3: pw.FlexColumnWidth(2.0),
      4: pw.FlexColumnWidth(0.8),
      5: pw.FlexColumnWidth(1.6),
      6: pw.FlexColumnWidth(0.9),
      7: pw.FlexColumnWidth(0.8),
    };
    const direita = {1, 2, 4, 5, 6, 7};

    pw.Widget celula(String t, int col, {bool negrito = false, PdfColor? cor}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(
            t,
            textAlign: direita.contains(col) ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: cor,
            ),
          ),
        );

    pw.TableRow linha(List<String> valores,
            {bool negrito = false, PdfColor? fundo, PdfColor? cor, bool repetir = false}) =>
        pw.TableRow(
          repeat: repetir, // cabeçalho repete em todas as páginas
          decoration: fundo == null ? null : pw.BoxDecoration(color: fundo),
          children: [for (var i = 0; i < valores.length; i++) celula(valores[i], i, negrito: negrito, cor: cor)],
        );

    final linhas = <pw.TableRow>[
      linha(titulos, negrito: true, fundo: _azul, cor: PdfColors.white, repetir: true),
      for (var i = 0; i < r.linhas.length; i++)
        () {
          final l = r.linhas[i];
          return linha(
            [
              l.documento.isEmpty ? l.nome : '${l.nome}\n${l.documento}',
              _moeda.format(l.valorApolices),
              '${l.qtdApolices}',
              l.qtdApolices == 0 ? '-' : '${l.maiorApoliceNumero}\n${_moeda.format(l.maiorApoliceValor)}',
              '${l.qtdSinistros}',
              _moeda.format(l.valorUtilizado),
              _p(l.percentualUsado),
              '${l.qtdAssistencias}',
            ],
            fundo: i.isOdd ? PdfColors.grey100 : null,
          );
        }(),
      linha(
        [
          'TOTAL (${r.linhas.length} clientes)',
          _moeda.format(r.totalApolices),
          '${r.totalQtdApolices}',
          '',
          '${r.totalSinistros}',
          _moeda.format(r.totalUtilizado),
          _p(r.percentualTotal),
          '${r.totalAssistencias}',
        ],
        negrito: true,
        fundo: PdfColors.grey300,
      ),
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Relatório de clientes',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _azul)),
            pw.Text('Gerado em $quando - ordenado pelo valor total das apólices',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Valor utilizado = soma dos sinistros sem Cancelado/Negado. % usada = valor utilizado / valor total das apólices.',
              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
            ),
            pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
        build: (ctx) => [
          pw.Table(
            columnWidths: larguras,
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
            children: linhas,
          ),
        ],
      ),
    );
    return doc.save();
  }
}
