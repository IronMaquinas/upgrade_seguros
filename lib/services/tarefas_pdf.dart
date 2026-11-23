// lib/services/tarefas_pdf.dart
//
// Etapa 10: PDF das tarefas agrupadas por funcionário (lista de Tarefas →
// "Exportar"). Regras e números de lib/utils/tarefas.dart, os mesmos do CSV.
// Fonte padrão do PDF (Helvetica): só caracteres latinos, sem emoji.

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/tarefas.dart';
import 'marca_pdf.dart'; // Etapa 17: cabeçalho e rodapé da corretora

class TarefasPdf {
  static const _roxo = PdfColor.fromInt(0xFF6A1B9A);
  static final _data = DateFormat('dd/MM/yyyy');

  static String _d(DateTime? d) => d == null ? '-' : _data.format(d);

  static PdfColor _corSituacao(String s) {
    switch (s) {
      case Tarefas.noPrazo:
        return const PdfColor.fromInt(0xFF2E7D32);
      case Tarefas.foraDoPrazo:
        return const PdfColor.fromInt(0xFFC62828);
      default:
        return PdfColors.grey700;
    }
  }

  static Future<Uint8List> gerar(
    List<ResumoFuncionario> grupos, {
    required bool maisRecentePrimeiro,
    String? filtro,
    DateTime? agora,
    MarcaPdf? marca, // Etapa 17
  }) async {
    final hoje = agora ?? DateTime.now();
    final m = marca ?? MarcaPdf(geradoEm: hoje);
    final doc = pw.Document(title: 'Tarefas por funcionário', author: m.nome);
    final total = grupos.fold<int>(0, (s, g) => s + g.total);

    const titulos = ['Atendimento', 'Cliente', 'Descrição', 'Status', 'Criada em', 'Prazo', 'Concluída em', 'Prazo cumprido?'];
    const larguras = <int, pw.TableColumnWidth>{
      0: pw.FlexColumnWidth(1.3),
      1: pw.FlexColumnWidth(2.2),
      2: pw.FlexColumnWidth(4.0),
      3: pw.FlexColumnWidth(1.1),
      4: pw.FlexColumnWidth(1.1),
      5: pw.FlexColumnWidth(1.1),
      6: pw.FlexColumnWidth(1.1),
      7: pw.FlexColumnWidth(1.5),
    };

    pw.Widget celula(String t, {bool negrito = false, PdfColor? cor}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: pw.Text(t,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: negrito ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: cor,
              )),
        );

    final conteudo = <pw.Widget>[];
    for (final g in grupos) {
      final pNoPrazo = g.percentualNoPrazo(hoje);
      conteudo.add(pw.Container(
        margin: const pw.EdgeInsets.only(top: 10, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        color: PdfColors.grey200,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${g.nome}${g.email.isNotEmpty && g.email != g.nome ? '  (${g.email})' : ''}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _roxo)),
            pw.Text(
              '${g.total} tarefas - ${g.abertas} abertas - ${g.concluidas} concluídas '
              '(${g.percentualConcluidas.toStringAsFixed(0)}%) - '
              '${g.noPrazo(hoje)} no prazo / ${g.foraDoPrazo(hoje)} fora'
              '${pNoPrazo == null ? '' : ' (${pNoPrazo.toStringAsFixed(0)}% no prazo)'}',
              style: const pw.TextStyle(fontSize: 7.5),
            ),
          ],
        ),
      ));
      final linhas = <pw.TableRow>[
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _roxo),
          children: [for (final t in titulos) celula(t, negrito: true, cor: PdfColors.white)],
        ),
      ];
      final ordenadas = Tarefas.ordenar(g.tarefas, maisRecentePrimeiro: maisRecentePrimeiro);
      for (var i = 0; i < ordenadas.length; i++) {
        final t = ordenadas[i];
        final situacao = Tarefas.situacaoPrazo(t, agora: hoje);
        linhas.add(pw.TableRow(
          decoration: i.isOdd ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
          children: [
            celula(t.numeroAtendimento),
            celula(t.clienteNome),
            celula(t.descricao),
            celula(t.status),
            celula(_d(t.criadoEm)),
            celula(_d(t.prazo)),
            celula(_d(t.concluidaEm)),
            celula(situacao, cor: _corSituacao(situacao), negrito: situacao == Tarefas.foraDoPrazo),
          ],
        ));
      }
      conteudo.add(pw.Table(
        columnWidths: larguras,
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
        children: linhas,
      ));
    }

    final quando = DateFormat('dd/MM/yyyy HH:mm').format(hoje);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => m.cabecalho(
          titulo: 'Tarefas por funcionário',
          subtitulo: 'Gerado em $quando - $total tarefas - ${maisRecentePrimeiro ? 'mais recentes' : 'mais antigas'} primeiro'
              '${filtro == null || filtro.isEmpty ? '' : ' - $filtro'}',
          cor: _roxo,
        ),
        footer: (ctx) => m.rodape(
          ctx,
          observacao:
              'Prazo vale até o fim do dia. Concluídas antes da data de conclusão ser registrada aparecem como "Sem data de conclusão".',
        ),
        build: (ctx) => conteudo,
      ),
    );
    return doc.save();
  }
}
