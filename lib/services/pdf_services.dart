import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../models/third_party_model.dart';

class PdfService {
  // ── Paleta de Cores (conforme projeto) ──────────────────────────────────
  static const PdfColor _colorBlue = PdfColor.fromInt(0xFF1565C0);
  static const PdfColor _colorGreen = PdfColor.fromInt(0xFF2E7D32);
  static const PdfColor _colorRed = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _colorAmber = PdfColor.fromInt(0xFFE65100);
  static const PdfColor _colorGray = PdfColor.fromInt(0xFF546E7A);
  static const PdfColor _colorGrayLight = PdfColor.fromInt(0xFFF4F6F9);
  static const PdfColor _colorGrayBorder = PdfColor.fromInt(0xFFE0E0E0);

  Future<Uint8List> loadLogo() async {
    final data = await rootBundle.load('lib/assets/logo_upgrade.png');
    return data.buffer.asUint8List();
  }

  Future<Uint8List> generateClaimPdf(
    Claim claim,
    Client? client,
    List<ThirdParty> terceiros,
    Uint8List? logoBytes,
    {
      String? usuarioNome,
      String? usuarioEmail,
      String? usuarioTelefone,
    }
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    final fotosDoSinistroGrid = await _buildImageGrid(claim.fotosUrls);
    
    final terceirosSections = await Future.wait(
      claim.terceiros.map((tp) => _buildTerceiroSection(tp))
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Upgrade Corretora de Seguros',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _colorGray,
                  fontWeight: pw.FontWeight.normal,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(
                  fontSize: 8,
                  color: _colorGray,
                  fontWeight: pw.FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          // ═════════════════════════════════════════════════════════════════════════
          // CABEÇALHO PREMIUM
          // ═════════════════════════════════════════════════════════════════════════
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Image(
                  pw.MemoryImage(logoBytes),
                  height: 50,
                  width: 50,
                ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Upgrade Corretora de Seguros',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: _colorBlue,
                      ),
                    ),
                    pw.Text(
                      'Relatório de Sinistro',
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: _colorGray,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'ID: ${claim.numeroSinistro}',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _colorBlue,
                    ),
                  ),
                  pw.Text(
                    dateFormat.format(claim.dataOcorrencia),
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _colorGray,
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ─ Linha Decorativa ─────────────────────────────────────────────────────
          pw.Container(
            height: 2,
            color: _colorBlue,
          ),

          pw.SizedBox(height: 20),

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 1: INFORMAÇÕES PRINCIPAIS (Cards)
          // ═════════════════════════════════════════════════════════════════════════
          pw.Text(
            'Informações do Sinistro',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlue,
            ),
          ),

          pw.SizedBox(height: 12),

          // Grid 2x2 de informações principais
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                children: [
                  _buildInfoBox('Número do Sinistro', claim.numeroSinistro, _colorBlue),
                  _buildInfoBox('Ramo', claim.ramoSinistro, _colorBlue),
                ],
              ),
              pw.TableRow(children: [pw.SizedBox(), pw.SizedBox()]),
              pw.TableRow(
                children: [
                  _buildInfoBox('Tipo de Ocorrência', claim.tipoOcorrencia, _colorBlue),
                  _buildInfoBox('Status', claim.statusAtual, _getStatusColor(claim.statusAtual)),
                ],
              ),
              pw.TableRow(children: [pw.SizedBox(), pw.SizedBox()]),
              pw.TableRow(
                children: [
                  _buildInfoBox(
                    'Data da Ocorrência',
                    dateFormat.format(claim.dataOcorrencia),
                    _colorBlue,
                  ),
                  _buildInfoBox(
                    'Data do Aviso',
                    dateFormat.format(claim.dataAviso),
                    _colorBlue,
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ─ Linha Decorativa ─────────────────────────────────────────────────────
          pw.Divider(color: _colorGrayBorder, height: 1),

          pw.SizedBox(height: 20),

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 2: DETALHES DO SINISTRO
          // ═════════════════════════════════════════════════════════════════════════
          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 60,
                color: _colorBlue,
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Local da Ocorrência',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _colorGray,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      claim.localOcorrencia,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: const PdfColor.fromInt(0xFF1A1A2E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          pw.Row(
            children: [
              pw.Container(
                width: 3,
                height: 60,
                color: _colorBlue,
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relato do Evento',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: _colorGray,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      claim.relatoEvento,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: const PdfColor.fromInt(0xFF424242),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // ─ Linha Decorativa ─────────────────────────────────────────────────────
          pw.Divider(color: _colorGrayBorder, height: 1),

          pw.SizedBox(height: 20),

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 3: INFORMAÇÕES FINANCEIRAS
          // ═════════════════════════════════════════════════════════════════════════
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _colorGrayLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _colorGrayBorder, width: 1),
            ),
            padding: const pw.EdgeInsets.all(16),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Número de Controle',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: _colorGray,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          claim.numeroSeguradora,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorBlue,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Valor Total',
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: _colorGray,
                            fontWeight: pw.FontWeight.normal,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'R\$ ${claim.valorTotalSinistro.toStringAsFixed(2)}',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: _colorGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 4: INFORMAÇÕES DO CLIENTE
          // ═════════════════════════════════════════════════════════════════════════
          if (client != null) ...[
            pw.Text(
              'Informações do Cliente',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _colorBlue,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: _colorGrayBorder, width: 1),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Table(
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Nome', style: _labelStyle()),
                          pw.SizedBox(height: 2),
                          pw.Text(client.nome, style: _valueStyle()),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CNPJ/CPF', style: _labelStyle()),
                          pw.SizedBox(height: 2),
                          pw.Text(client.cnpjCpf, style: _valueStyle()),
                        ],
                      ),
                    ],
                  ),
                  pw.TableRow(children: [pw.SizedBox(height: 8), pw.SizedBox(height: 8)]),
                  pw.TableRow(
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Email', style: _labelStyle()),
                          pw.SizedBox(height: 2),
                          pw.Text(client.email, style: _valueStyle()),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Contato', style: _labelStyle()),
                          pw.SizedBox(height: 2),
                          pw.Text(client.contato, style: _valueStyle()),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 5: INFORMAÇÕES ESPECÍFICAS DO RAMO
          // ═════════════════════════════════════════════════════════════════════════
          _buildSinistroInfoSection(claim),

          pw.SizedBox(height: 20),

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 6: FOTOS DO SINISTRO
          // ═════════════════════════════════════════════════════════════════════════
          if (claim.fotosUrls.isNotEmpty) ...[
            pw.Text(
              'Fotos do Sinistro',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _colorBlue,
              ),
            ),
            pw.SizedBox(height: 12),
            fotosDoSinistroGrid,
            pw.SizedBox(height: 20),
          ],

          // ═════════════════════════════════════════════════════════════════════════
          // SEÇÃO 7: TERCEIROS ENVOLVIDOS
          // ═════════════════════════════════════════════════════════════════════════
          if (claim.terceiros.isNotEmpty) ...[
            pw.Text(
              'Terceiros Envolvidos',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _colorBlue,
              ),
            ),
            pw.SizedBox(height: 12),
            ...terceirosSections,
            pw.SizedBox(height: 20),
          ],

          // ─ Linha Decorativa ─────────────────────────────────────────────────────
          pw.Divider(color: _colorGrayBorder, height: 1),

          pw.SizedBox(height: 16),

          // ═════════════════════════════════════════════════════════════════════════
          // RODAPÉ
          // ═════════════════════════════════════════════════════════════════════════
          pw.Container(
            decoration: pw.BoxDecoration(
              color: _colorGrayLight,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _colorGrayBorder, width: 1),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Assinatura e Contato',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: _colorBlue,
                  ),
                ),
                pw.SizedBox(height: 6),
                // Nome do responsável (com fallback)
                pw.Text(
                  'Nome: ${usuarioNome ?? 'Upgrade Seguros'}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF1A1A2E),
                  ),
                ),
                pw.SizedBox(height: 3),
                // Email do responsável
                if (usuarioEmail != null && usuarioEmail.isNotEmpty) ...[
                  pw.Text(
                    'Email: $usuarioEmail',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _colorGray,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                ],
                // Telefone do responsável
                if (usuarioTelefone != null && usuarioTelefone.isNotEmpty) ...[
                  pw.Text(
                    'Telefone: $usuarioTelefone',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _colorGray,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                ],
                pw.SizedBox(height: 8),
                pw.Text(
                  'Este relatório é confidencial e não pode ser divulgado sem o consentimento da Upgrade Seguros.',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: _colorGray,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Emitido em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: _colorGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HELPER FUNCTIONS
  // ════════════════════════════════════════════════════════════════════════════

  pw.Widget _buildInfoBox(String label, String value, PdfColor color) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _colorGrayBorder, width: 1),
      ),
      padding: const pw.EdgeInsets.all(10),
      margin: const pw.EdgeInsets.symmetric(horizontal: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8,
              color: _colorGray,
              fontWeight: pw.FontWeight.normal,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  pw.TextStyle _labelStyle() {
    return pw.TextStyle(
      fontSize: 8,
      color: _colorGray,
      fontWeight: pw.FontWeight.normal,
    );
  }

  pw.TextStyle _valueStyle() {
    return pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      color: const PdfColor.fromInt(0xFF1A1A2E),
    );
  }

  PdfColor _getStatusColor(String status) {
    switch (status) {
      case 'Concluído':
        return _colorGreen;
      case 'Aberto':
        return _colorRed;
      case 'Aguardando Aprovação':
        return _colorAmber;
      default:
        return _colorGray;
    }
  }

  pw.Widget _buildSinistroInfoSection(Claim claim) {
    if (claim.ramoSinistro == 'Transporte' && claim.transporte != null) {
      final t = claim.transporte!;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informações do Transporte',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlue,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _colorGrayBorder, width: 1),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: _buildTransportRows(t),
            ),
          ),
        ],
      );
    } else if ((claim.ramoSinistro == 'Frota' || claim.ramoSinistro == 'Veículo Individual') &&
        claim.veiculoSelecionado != null) {
      final v = claim.veiculoSelecionado!;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informações do Veículo',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlue,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _colorGrayBorder, width: 1),
            ),
            padding: const pw.EdgeInsets.all(12),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
              },
              children: _buildVehicleRows(v),
            ),
          ),
        ],
      );
    } else {
      return pw.SizedBox();
    }
  }

  List<pw.TableRow> _buildTransportRows(dynamic t) {
    final rows = <pw.TableRow>[];
    final fields = [
      ('Motorista', t.nomeMotorista ?? ''),
      ('CPF', t.cpfMotorista ?? ''),
      ('Placa Cavalo', t.placaCavalo ?? ''),
      ('Placa Carreta', t.placaCarreta ?? ''),
      ('Reguladora', t.reguladora ?? ''),
      ('NFE', t.nfe ?? ''),
      ('Chassi', t.chassi ?? ''),
      ('CTE', t.cte ?? ''),
      ('Marca', t.marca ?? ''),
      ('Modelo', t.modelo ?? ''),
      ('Cor', t.cor ?? ''),
    ];

    for (int i = 0; i < fields.length; i += 2) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(fields[i].$1, style: _labelStyle()),
                pw.SizedBox(height: 2),
                pw.Text(fields[i].$2, style: _valueStyle()),
              ],
            ),
            if (i + 1 < fields.length)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(fields[i + 1].$1, style: _labelStyle()),
                  pw.SizedBox(height: 2),
                  pw.Text(fields[i + 1].$2, style: _valueStyle()),
                ],
              )
            else
              pw.SizedBox(),
          ],
        ),
      );
      if (i + 1 < fields.length) {
        rows.add(pw.TableRow(children: [pw.SizedBox(height: 8), pw.SizedBox(height: 8)]));
      }
    }

    return rows;
  }

  List<pw.TableRow> _buildVehicleRows(dynamic v) {
    final rows = <pw.TableRow>[];
    final fields = [
      ('Placa', v.placa ?? ''),
      ('Chassi', v.chassi ?? ''),
      ('Marca', v.marca ?? ''),
      ('Modelo', v.modelo ?? ''),
      ('Ano', '${v.ano ?? ""} / ${v.anomodelo ?? ""}'),
    ];

    for (int i = 0; i < fields.length; i += 2) {
      rows.add(
        pw.TableRow(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(fields[i].$1, style: _labelStyle()),
                pw.SizedBox(height: 2),
                pw.Text(fields[i].$2, style: _valueStyle()),
              ],
            ),
            if (i + 1 < fields.length)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(fields[i + 1].$1, style: _labelStyle()),
                  pw.SizedBox(height: 2),
                  pw.Text(fields[i + 1].$2, style: _valueStyle()),
                ],
              )
            else
              pw.SizedBox(),
          ],
        ),
      );
      if (i + 1 < fields.length) {
        rows.add(pw.TableRow(children: [pw.SizedBox(height: 8), pw.SizedBox(height: 8)]));
      }
    }

    return rows;
  }

  Future<pw.Widget> _buildTerceiroSection(ThirdParty tp) async {
    pw.Widget? fotos;
    if (tp.fotosUrls != null && tp.fotosUrls!.isNotEmpty) {
      fotos = await _buildImageGrid(tp.fotosUrls!);
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _colorGrayBorder, width: 1),
      ),
      padding: const pw.EdgeInsets.all(12),
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            tp.nome,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: _colorBlue,
            ),
          ),
          if (tp.contato.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Contato: ${tp.contato}',
              style: pw.TextStyle(fontSize: 9, color: _colorGray),
            ),
          ],
          if (tp.veiculo != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Veículo: ${tp.veiculo!.marca} ${tp.veiculo!.modelo}${tp.veiculo!.placa.isNotEmpty ? " - ${tp.veiculo!.placa}" : ""}',
              style: pw.TextStyle(fontSize: 9, color: _colorGray),
            ),
          ],
          if (fotos != null) ...[
            pw.SizedBox(height: 8),
            fotos,
          ],
        ],
      ),
    );
  }

  Future<pw.Widget> _buildImageGrid(List<String> urls) async {
    final imageWidgets = <pw.Widget>[];
    for (final url in urls) {
      try {
        debugPrint('🔍 Buscando imagem: $url');
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          imageWidgets.add(
            pw.Container(
              width: 140,
              height: 140,
              decoration: pw.BoxDecoration(
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _colorGrayBorder, width: 1),
              ),
              child: pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(
                  pw.MemoryImage(response.bodyBytes),
                  fit: pw.BoxFit.cover,
                ),
              ),
            ),
          );
        } else {
          debugPrint('❌ Erro HTTP: ${response.statusCode}');
          imageWidgets.add(_buildErrorImage());
        }
      } catch (e) {
        debugPrint('❌ Erro: $e');
        imageWidgets.add(_buildErrorImage());
      }
    }

    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: imageWidgets,
    );
  }

  pw.Widget _buildErrorImage() {
    return pw.Container(
      width: 140,
      height: 140,
      decoration: pw.BoxDecoration(
        color: _colorGrayLight,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: _colorGrayBorder, width: 1),
      ),
      alignment: pw.Alignment.center,
      child: pw.Text(
        'Erro ao\ncarregar',
        style: pw.TextStyle(fontSize: 9, color: _colorGray),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}