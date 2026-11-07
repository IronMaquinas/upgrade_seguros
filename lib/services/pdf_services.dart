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
      bool isAdmin = false,
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

          // ═══════════════════════════════════════════════════════════════
          // SEÇÃO: ANOTAÇÕES
          // ═══════════════════════════════════════════════════════════════
          if (claim.anotacoes.isNotEmpty) ...[
            pw.Text('Anotações',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _colorBlue)),
            pw.SizedBox(height: 8),
            ...claim.anotacoes.map((a) {
              final autor = a['autor'] as String? ?? '';
              final conteudo = a['conteudo'] as String? ?? '';
              final data = a['data'] as String? ?? '';
              DateTime? dataObj;
              try { dataObj = DateTime.parse(data); } catch (_) {}
              return pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  border: pw.Border.all(color: _colorGrayBorder),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                padding: const pw.EdgeInsets.all(10),
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(autor, style: pw.TextStyle(fontSize: 8, color: _colorGray, fontWeight: pw.FontWeight.bold)),
                        if (dataObj != null)
                          pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(dataObj),
                              style: pw.TextStyle(fontSize: 8, color: _colorGray)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(conteudo, style: pw.TextStyle(fontSize: 10, color: const PdfColor.fromInt(0xFF424242))),
                  ],
                ),
              );
            }),
            pw.SizedBox(height: 16),
          ],

          // ═══════════════════════════════════════════════════════════════
          // SEÇÃO: HISTÓRICO (somente admin)
          // ═══════════════════════════════════════════════════════════════
          if (isAdmin && claim.historicoStatus.isNotEmpty) ...[
            pw.Container(
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFF9C4),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFF9A825)),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('HISTÓRICO DE MOVIMENTAÇÕES — USO INTERNO',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFFE65100))),
                  pw.SizedBox(height: 8),
                  ...claim.historicoStatus.map((h) {
                    final status = h['status'] as String? ?? '';
                    final data = h['data'] as String? ?? '';
                    DateTime? dataObj;
                    try { dataObj = DateTime.parse(data); } catch (_) {}
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(
                        children: [
                          pw.Container(width: 6, height: 6,
                              decoration: const pw.BoxDecoration(
                                  color: PdfColor.fromInt(0xFFE65100),
                                  shape: pw.BoxShape.circle)),
                          pw.SizedBox(width: 6),
                          pw.Expanded(child: pw.Text(status,
                              style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF1A1A2E)))),
                          if (dataObj != null)
                            pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(dataObj),
                                style: pw.TextStyle(fontSize: 8, color: _colorGray)),
                        ],
                      ),
                    );
                  }),
                  pw.SizedBox(height: 4),
                  pw.Text('Abertura: ${dateTimeFormat.format(claim.dataAbertura)}',
                      style: pw.TextStyle(fontSize: 8, color: _colorGray)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],

          // ─ Linha Decorativa ──────────────────────────────────────────────
          pw.Divider(color: _colorGrayBorder, height: 1),

          pw.SizedBox(height: 16),

          // ═════════════════════════════════════════════════════════════════
          // RODAPÉ / ASSINATURA
          // ═════════════════════════════════════════════════════════════════
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
                pw.Text('Assinatura e Contato',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _colorBlue)),
                pw.SizedBox(height: 6),
                
                // Nome (já vem correto do _generateAndSharePdf)
                pw.Text(
                  'Nome: ${usuarioNome ?? 'Sem assinatura'}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF1A1A2E)),
                ),

                if ((usuarioEmail ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Email: $usuarioEmail', style: pw.TextStyle(fontSize: 9, color: _colorGray)),
                ],

                if ((usuarioTelefone ?? '').isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Telefone: $usuarioTelefone', style: pw.TextStyle(fontSize: 9, color: _colorGray)),
                ],
                
                pw.SizedBox(height: 8),
                pw.Text(
                  isAdmin
                      ? 'Documento interno — não distribuir sem autorização da Upgrade Seguros.'
                      : 'Este relatório é confidencial e não pode ser divulgado sem o consentimento da Upgrade Seguros.',
                  style: pw.TextStyle(fontSize: 8, color: _colorGray, fontStyle: pw.FontStyle.italic),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Emitido em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}${isAdmin ? ' — VERSÃO ADMIN' : ''}',
                  style: pw.TextStyle(fontSize: 8, color: _colorGray),
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
    final ramo = claim.ramoSinistro;

    // ── Transporte ─────────────────────────────────────────────────────────
    if (ramo == 'Transporte' && claim.transporte != null) {
      return _buildInfoSectionWrapper('Informações do Transporte', _buildTransportRows(claim.transporte!));
    }

    // ── Veículo Individual / Frota / Civil Ônibus (RCO) ───────────────────
    if ((ramo == 'Frota' || ramo == 'Veículo Individual' || ramo == 'Civil Ônibus (RCO)') &&
        claim.veiculoSelecionado != null) {
      final v = claim.veiculoSelecionado!;
      final titulo = ramo == 'Civil Ônibus (RCO)' ? 'Dados do Veículo (RCO)' : 'Informações do Veículo';
      return _buildInfoSectionWrapper(titulo, _buildVehicleRows(v));
    }

    // ── Máquinas ───────────────────────────────────────────────────────────
    if (ramo == 'Máquinas' && claim.maquinaria != null) {
      final m = claim.maquinaria!;
      return _buildInfoSectionWrapper('Informações da Máquina / Equipamento', [
        _buildTableRow('Descrição', m.descricao),
        _buildTableRow('Modelo', m.modelo),
        _buildTableRow('Número de Série', m.numeroSerie),
        _buildTableRow('Descrição do Sinistro', m.descricaoSinistro),
      ]);
    }

    // ── Residencial ────────────────────────────────────────────────────────
    if (ramo == 'Residencial' && claim.house != null) {
      final h = claim.house!;
      return _buildInfoSectionWrapper('Informações do Imóvel', [
        _buildTableRow('Endereço / Local', h.localHouse),
        _buildTableRow('Tipo de Imóvel', h.tipoImovel ?? ''),
        _buildTableRow('Valor do Imóvel', h.valorImovel != null
            ? 'R\$ ${h.valorImovel!.toStringAsFixed(2)}' : ''),
      ]);
    }

    // ── Vidas ──────────────────────────────────────────────────────────────
    if (ramo == 'Vidas' && claim.life != null) {
      final l = claim.life!;
      return _buildInfoSectionWrapper('Informações da Vida Segurada', [
        _buildTableRow('Nome do Segurado', l.nomeSegurado),
        _buildTableRow('CPF', l.cpfSegurado),
        _buildTableRow('Idade', l.idadeSegurado.toString()),
        _buildTableRow('Causa', l.causaMorte),
        _buildTableRow('Parentesco', l.parentesco ?? ''),
        _buildTableRow('Telefone', l.telefone ?? ''),
        _buildTableRow('Email', l.email ?? ''),
        _buildTableRow('Local', l.localLife),
      ]);
    }
    return pw.SizedBox();
  }

  pw.Widget _buildInfoSectionWrapper(String titulo, List<pw.TableRow> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(titulo,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _colorBlue)),
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
            children: rows,
          ),
        ),
      ],
    );
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label, style: _labelStyle()),
          pw.SizedBox(height: 2),
          pw.Text(value.isNotEmpty ? value : '—', style: _valueStyle()),
          pw.SizedBox(height: 8),
        ]),
        pw.SizedBox(),
      ],
    );
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
      ('Cor', v.cor ?? ''),
      ('Ano Fab. / Modelo', '${v.ano ?? ""} / ${v.anomodelo ?? ""}'),
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