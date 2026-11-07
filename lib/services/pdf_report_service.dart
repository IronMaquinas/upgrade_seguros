// lib/services/pdf_report_service.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/report_data.dart';

class _CardData {
  final String label;
  final String value;
  final PdfColor color;

  _CardData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class PdfReportService {
  final _fmtCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _fmtDate = DateFormat('dd/MM/yyyy');

  static const _corBlue = PdfColor.fromInt(0xFF1565C0);
  static const _corGreen = PdfColor.fromInt(0xFF2E7D32);
  static const _corRed = PdfColor.fromInt(0xFFC62828);
  static const _corAmber = PdfColor.fromInt(0xFFE65100);
  static const _corGray = PdfColor.fromInt(0xFF546E7A);
  static const _corBg = PdfColor.fromInt(0xFFF4F6F9);
  static const _corTeal = PdfColor.fromInt(0xFF00695C);
  static const _corPurple = PdfColor.fromInt(0xFF6A1B9A);
  static const _corOrange = PdfColor.fromInt(0xFFE65100);

    // Campo da fonte emoji
  late final pw.Font _emojiFont;

  // Método de carga
  Future<void> _loadEmojiFont() async {
    final fontData = await rootBundle.load('assets/fonts/NotoColorEmoji.ttf');
    _emojiFont = pw.Font.ttf(fontData.buffer.asByteData());
  }

  // Função auxiliar para cores com opacidade
  static PdfColor _colorWithOpacity(PdfColor color, double opacity) {
    return PdfColor(
      color.red,
      color.green,
      color.blue,
      opacity.toDouble(),
    );
  }

  pw.Widget _buildGraficoSection(String titulo, Uint8List imagem) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 16),
        pw.Text(titulo,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _corBlue)),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Image(pw.MemoryImage(imagem), width: 500),
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: _colorWithOpacity(_corGray, 0.3)),
      ],
    );
  }

  Future<pw.Document> generateReport({
    required ReportData data,
    required DateTime? dataInicio,
    required DateTime? dataFim,
    required String periodoLabel,
    required int totalClientes,
    required double slaGeral,
    Uint8List? imagemPizza,
    required double slaSinistros,
    required double slaAssistencias,
  }) async {
    await _loadEmojiFont();
    final pdf = pw.Document();
    final periodo = dataInicio != null && dataFim != null
        ? '${_fmtDate.format(dataInicio)} a ${_fmtDate.format(dataFim)}'
        : periodoLabel;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context ctx) => [
          _buildHeader(periodo),
          _buildKpiGrid(data, totalClientes, slaGeral),

          if (imagemPizza != null) _buildGraficoSection('Sinistros vs Assistências', imagemPizza),
          
          _buildSinistrosSection(data, slaSinistros),
          _buildAssistenciasSection(data, slaAssistencias),
          _buildDistribuicaoStatus(data),
          if (data.emAtraso.isNotEmpty) _buildSinistrosAtraso(data),
          if (data.tempoMedioEtapa.isNotEmpty) _buildTempoMedioEtapa(data),
          if (data.clientesAltoRisco.isNotEmpty) _buildClientesRisco(data),
          if (data.aprovacoesParadas.isNotEmpty) _buildAprovacoesParadas(data),
          if (data.reparosProlongados.isNotEmpty) _buildReparosProlongados(data),
          if (data.contratosProximos.isNotEmpty) _buildContratosProximos(data),
          _buildNPS(data),
          _buildTempoMedio(data),
          _buildEvolucaoMensal(data),
          _buildFooter(),
        ],
      ),
    );

    return pdf;
  }

  // ─── Seções (mesmo código, apenas substitua as referências de _ReportData por ReportData) ───

  // --- SEÇÃO 1 ---
  pw.Widget _buildHeader(String periodo) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Relatório Executivo',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _corBlue),
                ),
                pw.Text(
                  'Upgrade Corretora de Seguros',
                  style: pw.TextStyle(fontSize: 12, color: _corGray),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Período: $periodo',
                  style: pw.TextStyle(fontSize: 9, color: _corGray),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Gerado em ${_fmtDate.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: _corGray),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(color: _corBlue, height: 20, thickness: 2),
      ],
    );
  }


  pw.Widget _buildKpiGrid(ReportData d, int totalClientes, double slaGeral) {
    // Ticket Médio: apenas sinistros
    final ticketMedio = d.totalSinistros > 0 ? d.valorTotalSinistros / d.totalSinistros : 0.0;
    
    // Total de assistências (apenas contagem)
    final totalAssistencias = d.assistenciasPorRamo.values.fold<int>(0, (sum, v) => sum + v);

    String slaEmoji;
    PdfColor slaColor;

    if (slaGeral >= 80) {
      slaEmoji = '✅';
      slaColor = _corGreen;
    } else if (slaGeral >= 60) {
      slaEmoji = '⚠️';
      slaColor = _corAmber;
    } else {
      slaEmoji = '🔴';
      slaColor = _corRed;
    }

    final items = <_KpiItem>[
      _KpiItem(label: 'Clientes', value: totalClientes.toString(), emoji: '👥', color: _corGreen),
      _KpiItem(label: 'Ticket Médio', value: _fmtCurrency.format(ticketMedio), emoji: '🎫', color: _corAmber),
      _KpiItem(label: 'Valor Total das Apólices (VGV)', value: _fmtCurrency.format(d.valorTotalApolices), emoji: '📈', color: _corBlue),
      _KpiItem(label: 'Sinistros', value: d.totalSinistros.toString(), emoji: '⚠', color: _corRed),
      _KpiItem(label: 'Assistências', value: totalAssistencias.toString(), emoji: '🆘', color: _corTeal),
      _KpiItem(
        label: 'SLA Geral',
        value: '${slaGeral.toStringAsFixed(0)}%',
        emoji: slaEmoji,
        color: slaColor,
      ),
      _KpiItem(label: 'NPS Score', value: d.npsMedia.toStringAsFixed(1), emoji: '⭐', color: _corPurple),
    ];

    final linha1 = items.sublist(0, 3); // Clientes, Ticket Médio, VGV
    final linha2 = items.sublist(3);    // Sinistros, Assistências, SLA Geral, NPS Score

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Visão Geral do Negócio',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _corBlue)),
        pw.SizedBox(height: 8),
        pw.Row(children: linha1.map((item) => _kpiCard(item)).toList()),
        pw.SizedBox(height: 6),
        pw.Row(children: linha2.map((item) => _kpiCard(item)).toList()),
        pw.SizedBox(height: 12),
        pw.Divider(color: _colorWithOpacity(_corGray, 0.3)),
      ],
    );
  }

pw.Widget _kpiCard(_KpiItem item) {
  return pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.all(4),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white, // 🟢 FUNDO BRANCO
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: _colorWithOpacity(item.color, 0.40), // borda mais visível
          width: 1.5,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                item.emoji,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontFallback: [_emojiFont],
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                item.label,
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _corGray, // cinza escuro – legível
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            item.value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: item.color, // valor com a cor do card
            ),
          ),
        ],
      ),
    ),
  );
}

  pw.Widget _metricBox(String label, String value, {PdfColor color = _corBlue}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _corBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _corGray)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // --- CABEÇALHO DE SINISTROS ---
  pw.Widget _buildSinistrosSection(ReportData d, double slaSinistros) {
    final totalSinistros = d.totalSinistros;
    final concluidos = d.porStatus['Concluído'] ?? 0;
    final abertos = totalSinistros - concluidos;

    // Usando uma classe auxiliar (definida fora)
    final cards = <_CardData>[
      _CardData(label: 'Total Sinistros', value: totalSinistros.toString(), color: _corRed),
      _CardData(label: 'Concluídos', value: concluidos.toString(), color: _corGreen),
      _CardData(label: 'Abertos', value: abertos.toString(), color: _corBlue),
      _CardData(
        label: 'SLA Cumprido',
        value: '${slaSinistros.toStringAsFixed(0)}%',
        color: slaSinistros >= 80 ? _corGreen : (slaSinistros >= 60 ? _corAmber : _corRed),
      ),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Visão Geral dos Sinistros',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _corRed)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: cards.map((c) => _buildCard(c)).toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _colorWithOpacity(_corGray, 0.3)),
      ],
    );
  }

  pw.Widget _buildCard(_CardData card) { // ou _SinistroCardData
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.all(4),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: _colorWithOpacity(card.color, 0.4), width: 1.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              card.label,
              style: pw.TextStyle(
                fontSize: 8,
                color: _corGray,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              card.value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: card.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildDistribuicaoStatus(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Distribuição por status', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _corBg),
              children: ['Status', 'Quantidade', '% do total']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...d.porStatus.entries.map((e) {
              final pct = d.totalSinistros > 0 ? (e.value / d.totalSinistros * 100).toStringAsFixed(1) : '0';
              return pw.TableRow(
                children: [e.key, '${e.value}', '$pct%']
                    .map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                        ))
                    .toList(),
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildSinistrosAtraso(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Sinistros em atraso (sem movimentação ≥ 7 dias)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _corRed)),
        pw.SizedBox(height: 6),
        _buildTableFromClaimAtraso(
          d.emAtraso.take(15).toList(),
          columns: ['Nº Sinistro', 'Cliente', 'Status', 'Dias parado'],
          rowBuilder: (a) => [
            a.claim.numeroSinistro,
            a.claim.clientNome,
            a.claim.statusAtual,
            '${a.diasSemMovimentacao} dias',
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildTempoMedioEtapa(ReportData d) {
    final sorted = d.tempoMedioEtapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Tempo médio por etapa do processo', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _corBg),
              children: ['Transição', 'Média (dias)']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...sorted.map((e) => pw.TableRow(
                  children: [e.key, e.value.toStringAsFixed(1)]
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                          ))
                      .toList(),
                )),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildClientesRisco(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Clientes com sinistralidade elevada (≥ 60%)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _corAmber)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _corBg),
              children: ['Cliente', 'Sinistralidade', 'Total sinistros', 'Vencimento apólice']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...d.clientesAltoRisco.map((r) => pw.TableRow(
                  children: [
                    r.client.nome,
                    '${r.sinistralidade.toStringAsFixed(1)}%',
                    _fmtCurrency.format(r.totalSinistros),
                    _fmtDate.format(
                      r.client.apolices.reduce((a, b) => a.dataFim.isBefore(b.dataFim) ? a : b).dataFim,
                    ),
                  ]
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                          ))
                      .toList(),
                )),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildAprovacoesParadas(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Aprovações travadas (> 3 dias)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _corAmber)),
        pw.SizedBox(height: 6),
        _buildTableFromClaimAtraso(
          d.aprovacoesParadas,
          columns: ['Nº Sinistro', 'Cliente', 'Seguradora', 'Dias parado'],
          rowBuilder: (a) => [
            a.claim.numeroSinistro,
            a.claim.clientNome,
            a.claim.seguradora.isNotEmpty ? a.claim.seguradora : '—',
            '${a.diasSemMovimentacao} dias',
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildReparosProlongados(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Veículos em manutenção prolongada (> 7 dias)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _corBlue)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _corBg),
              children: ['Nº Sinistro', 'Cliente', 'Veículo / Placa', 'Dias em reparo']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...d.reparosProlongados.map((a) {
              String veiculo = '—';
              if (a.claim.veiculoSelecionado != null) {
                final v = a.claim.veiculoSelecionado!;
                veiculo = '${v.placa.isNotEmpty ? v.placa : "N/I"} · ${v.marca}';
              } else if (a.claim.transporte != null) {
                veiculo = 'Cavalo: ${a.claim.transporte!.placaCavalo}';
              }
              return pw.TableRow(
                children: [
                  a.claim.numeroSinistro,
                  a.claim.clientNome,
                  veiculo,
                  '${a.diasSemMovimentacao} dias${a.diasSemMovimentacao > 14 ? " ⚠" : ""}',
                ]
                    .map((cell) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                        ))
                    .toList(),
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildContratosProximos(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Contratos próximos do vencimento (30 dias)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _corBg),
              children: ['Cliente', 'Vencimento', 'Valor apólice']
                  .map((h) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      ))
                  .toList(),
            ),
            ...d.contratosProximos.map((c) => pw.TableRow(
                  children: [
                    c.nome,
                    _fmtDate.format(
                      c.apolices.isNotEmpty
                          ? c.apolices.reduce((a, b) => a.dataFim.isBefore(b.dataFim) ? a : b).dataFim
                          : DateTime.now(),
                    ),
                    _fmtCurrency.format(c.valorTotalApolicesAtivas),
                  ]
                      .map((cell) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
                          ))
                      .toList(),
                )),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildNPS(ReportData d) {
    final total = d.totalPesquisasRespondidas;
    final promotores = d.npsCategoria['promotor'] ?? 0;
    final neutros = d.npsCategoria['neutro'] ?? 0;
    final detratores = d.npsCategoria['detrator'] ?? 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('⭐ NPS (Net Promoter Score)', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _colorWithOpacity(_corGreen, 0.1),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                children: [
                  pw.Text(d.npsMedia.toStringAsFixed(1), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text('Nota Média', style: pw.TextStyle(fontSize: 8, color: _corGray)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              child: pw.Column(
                children: [
                  _buildNpsBar('Promotores (9-10)', promotores, total, PdfColors.green),
                  pw.SizedBox(height: 4),
                  _buildNpsBar('Neutros (7-8)', neutros, total, PdfColors.orange),
                  pw.SizedBox(height: 4),
                  _buildNpsBar('Detratores (0-6)', detratores, total, PdfColors.red),
                  pw.SizedBox(height: 4),
                  pw.Text('${total} respostas de ${d.totalPesquisasEnviadas} pesquisas', style: pw.TextStyle(fontSize: 7, color: _corGray)),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildNpsBar(String label, int count, int total, PdfColor color) {
    final pct = total > 0 ? count / total : 0.0;
    return pw.Row(
      children: [
        pw.SizedBox(width: 80, child: pw.Text(label, style: pw.TextStyle(fontSize: 8))),
        pw.Expanded(
          child: pw.Container(
            height: 10,
            color: _colorWithOpacity(color, 0.2),
            child: pw.Container(
              width: pct * 100,
              color: color,
            ),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text('$count (${(pct * 100).toStringAsFixed(0)}%)', style: pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildTempoMedio(ReportData d) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('⏱️ Tempo Médio de Resolução', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            _metricBox('Sinistros', '${d.tempoMedioSinistros.toStringAsFixed(1)} dias', color: _corBlue),
            pw.SizedBox(width: 8),
            _metricBox('Assistências', '${d.tempoMedioAssistencias.toStringAsFixed(1)} dias', color: _corGreen),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildEvolucaoMensal(ReportData d) {
    final meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    final headers = ['Mês', 'Sinistros', 'Assist.', 'Sinistralidade %', 'Ticket Médio (R\$)', 'SLA Sinistros %', 'SLA Assist. %', 'Retenção %'];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('📈 Evolução Mensal - ${DateTime.now().year}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _corBg),
              children: headers.map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              )).toList(),
            ),
            ...List.generate(12, (i) {
              final mes = i + 1;
              final sin = d.sinistrosPoMes[mes] ?? 0;
              final ass = d.assistenciasPoMes[mes] ?? 0;
              final sinistralidade = d.sinistralidadePoMes[mes] ?? 0.0;
              final ticket = d.ticketMedioPoMes[mes] ?? 0.0;
              final slaSin = d.slaComplianceSinistrosPoMes[mes] ?? 0.0;
              final slaAss = d.slaComplianceAssistenciasPoMes[mes] ?? 0.0;
              final retencao = d.taxaRetencaoPoMes[mes] ?? 0.0;
              return pw.TableRow(
                children: [
                  meses[i],
                  sin.toString(),
                  ass.toString(),
                  sinistralidade.toStringAsFixed(1),
                  _fmtCurrency.format(ticket),
                  slaSin.toStringAsFixed(0),
                  slaAss >= 0 ? slaAss.toStringAsFixed(0) : '-',
                  retencao.toStringAsFixed(0),
                ].map((cell) => pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(cell, style: const pw.TextStyle(fontSize: 8)),
                )).toList(),
              );
            }),
          ],
        ),
        pw.SizedBox(height: 16),
      ],
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Text(
          'Upgrade Corretora de Seguros · Relatório gerado automaticamente pelo sistema de gestão',
          style: pw.TextStyle(fontSize: 7, color: _corGray),
        ),
      ],
    );
  }

  pw.Widget _buildTableFromClaimAtraso(
    List<ClaimAtraso> items, {
    required List<String> columns,
    required List<String> Function(ClaimAtraso) rowBuilder,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _corBg),
          children: columns.map((h) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(h, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          )).toList(),
        ),
        ...items.map((a) => pw.TableRow(
          children: rowBuilder(a).map((cell) => pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(cell, style: const pw.TextStyle(fontSize: 9)),
          )).toList(),
        )),
      ],
    );
  }

  // --- SEÇÃO DE ASSISTÊNCIAS ---
  pw.Widget _buildAssistenciasSection(ReportData d, double slaAssistencias) {
    // 1. Calcular total de assistências (soma dos ramos)
    final total = d.assistenciasPorRamo.values.fold<int>(0, (sum, v) => sum + v);

    // 2. Separar veiculares vs residenciais (usando assistenciasPorTipo)
    int veiculares = 0;
    int residenciais = 0;
    for (var entry in d.assistenciasPorTipo.entries) {
      if (entry.key == 'residencial') {
        residenciais += entry.value;
      } else {
        veiculares += entry.value;
      }
    }

    // 3. Criar a lista de cards usando a classe _CardData
    final cards = <_CardData>[
      _CardData(label: 'Total Assistências', value: total.toString(), color: _corTeal),
      _CardData(label: 'Veiculares', value: veiculares.toString(), color: _corBlue),
      _CardData(label: 'Residenciais', value: residenciais.toString(), color: _corGreen),
      _CardData(
        label: 'SLA Cumprido',
        value: '${slaAssistencias.toStringAsFixed(0)}%',
        color: slaAssistencias >= 80 ? _corGreen : (slaAssistencias >= 60 ? _corAmber : _corRed),
      ),
    ];

    // 4. Renderizar com o widget _buildCard (genérico)
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Visão Geral das Assistências',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _corTeal)),
        pw.SizedBox(height: 8),
        pw.Row(
          children: cards.map((c) => _buildCard(c)).toList(), // ✅ agora passa o objeto _CardData
        ),
        pw.SizedBox(height: 12),
        pw.Divider(color: _colorWithOpacity(_corGray, 0.3)),
      ],
    );
  }

}

class _KpiItem {
  final String label;
  final String value;
  final String emoji;
  final PdfColor color;

  _KpiItem({
    required this.label,
    required this.value,
    required this.emoji,
    required this.color,
  });
}