// lib/services/relatorio_atendimentos_pdf.dart
//
// Etapa 19b: PDF do relatório montado por modelo, na folha A4 deitada, com o
// cabeçalho e o rodapé da corretora (MarcaPdf, Etapa 17).
//   • tabela          — o modelo cabe na largura da folha;
//   • tabela compacta — apertado: letra menor;
//   • ficha           — não cabe: um bloco por ocorrência, campos em 3 colunas.
// O formato sai de OcupacaoPdf (lib/utils/relatorio_modelo.dart), o mesmo
// medidor que aparece no editor do modelo.

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/relatorio_modelo.dart';
import 'marca_pdf.dart';

class RelatorioAtendimentosPdf {
  static const _azul = PdfColor.fromInt(0xFF1565C0);

  static Future<Uint8List> gerar(
    RelatorioMontado r, {
    required MarcaPdf marca,
    String filtro = '',
  }) async {
    final layout = OcupacaoPdf.de(r.colunas).layout;
    final fonte = layout == LayoutPdf.tabela ? 7.0 : 6.0;
    final tipoNome = r.modelo.tipo == 'assistencia' ? 'Assistências' : 'Sinistros';
    final doc = pw.Document(title: r.modelo.nome, author: marca.nome);

    pw.Widget celula(String t, {bool negrito = false, bool direita = false, PdfColor? cor}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
          child: pw.Text(
            t,
            textAlign: direita ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: fonte, fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal, color: cor),
          ),
        );

    final conteudo = <pw.Widget>[];
    if (r.quantidade == 0) {
      conteudo.add(pw.Padding(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Text('Nenhuma ocorrência com estes filtros.', style: const pw.TextStyle(fontSize: 10)),
      ));
    } else if (layout != LayoutPdf.ficha) {
      final larguras = <int, pw.TableColumnWidth>{
        for (var i = 0; i < r.colunas.length; i++) i: pw.FlexColumnWidth(r.colunas[i].largura),
      };
      final temTotal = r.colunas.any((c) => c.soma);
      conteudo.add(pw.Table(
        columnWidths: larguras,
        border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
        ),
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _azul),
            children: [
              for (final c in r.colunas) celula(c.rotulo, negrito: true, direita: c.alinharDireita, cor: PdfColors.white),
            ],
          ),
          for (var i = 0; i < r.linhas.length; i++)
            pw.TableRow(
              decoration: i.isOdd ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
              children: [
                for (var j = 0; j < r.colunas.length; j++) celula(r.linhas[i][j], direita: r.colunas[j].alinharDireita),
              ],
            ),
          if (temTotal)
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                for (var j = 0; j < r.colunas.length; j++)
                  celula(r.linhaTotal[j], negrito: true, direita: r.colunas[j].alinharDireita),
              ],
            ),
        ],
      ));
      if (!temTotal) {
        conteudo.add(pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Text('Total: ${r.quantidade} ocorrência(s)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ));
      }
    } else {
      // Ficha: um bloco por ocorrência, 3 campos por linha.
      for (var i = 0; i < r.linhas.length; i++) {
        final pares = <pw.Widget>[
          for (var j = 0; j < r.colunas.length; j++)
            pw.Container(
              width: 250,
              padding: const pw.EdgeInsets.only(bottom: 3, right: 6),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: '${r.colunas[j].rotulo}: ', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.TextSpan(text: r.linhas[i][j].isEmpty ? '-' : r.linhas[i][j], style: const pw.TextStyle(fontSize: 7.5)),
                ]),
              ),
            ),
        ];
        conteudo.add(pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            color: i.isOdd ? PdfColors.grey100 : null,
          ),
          child: pw.Wrap(children: pares),
        ));
      }
      final totais = [
        for (final c in r.colunas)
          if (c.soma) '${c.rotulo}: ${RelatorioMontado.formatar(c, r.totais[c.id])}',
      ];
      conteudo.add(pw.Container(
        padding: const pw.EdgeInsets.all(6),
        color: PdfColors.grey300,
        child: pw.Text('TOTAL: ${r.quantidade} ocorrência(s)${totais.isEmpty ? '' : ' · ${totais.join(' · ')}'}',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      ));
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (ctx) => marca.cabecalho(
        titulo: r.modelo.nome,
        subtitulo: [
          '$tipoNome: ${r.quantidade}',
          if (filtro.isNotEmpty) filtro,
        ].join(' · '),
      ),
      footer: (ctx) => marca.rodape(ctx),
      build: (ctx) => conteudo,
    ));
    return doc.save();
  }
}
