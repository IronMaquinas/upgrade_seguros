import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart'; // Importe para usar debugPrint
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../models/third_party_model.dart';

class PdfService {
  Future<Uint8List> loadLogo() async {
    // Carrega a logo a partir dos assets locais.
    final data = await rootBundle.load('lib/assets/logo_upgrade.png');
    return data.buffer.asUint8List();
  }

  Future<Uint8List> generateClaimPdf(
    Claim claim,
    Client? client,
    List<ThirdParty> terceiros,
    Uint8List? logoBytes,
    [param4]
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');

    // ✅ Chama a função corrigida para construir o grid de imagens do sinistro
    final fotosDoSinistroGrid = await _buildImageGrid(claim.fotosUrls);
    
    final terceirosSections = await Future.wait(
      claim.terceiros.map((tp) => _buildTerceiroSection(tp))
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ),
        build: (context) => [
          // Cabeçalho
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoBytes != null)
                pw.Image(pw.MemoryImage(logoBytes), height: 60),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text('Upgrade Seguros',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Relatório do Sinistro',
                        style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Número do Sinistro: ${claim.numeroSinistro}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 8),
          pw.Text('Ramo: ${claim.ramoSinistro}'),
          pw.Text('Tipo: ${claim.tipoOcorrencia}'),
          pw.Text('Data da Ocorrência: ${dateFormat.format(claim.dataOcorrencia)}'),
          pw.Text('Local: ${claim.localOcorrencia}'),
          pw.Text('Número de Controle da Seguradora: ${claim.numeroSeguradora}'),
          pw.Text('Nome da Seguradora: ${claim.seguradora}'),
          pw.SizedBox(height: 12),
          pw.Text('Valor Total do Sinistro: R\$ ${claim.valorTotalSinistro.toStringAsFixed(2)}'),
          pw.SizedBox(height: 12),
          pw.Text('Relato do Evento:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(claim.relatoEvento),
          pw.SizedBox(height: 16),
          if (client != null) ...[
            pw.Text('Informações do Cliente:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Nome: ${client.nome}'),
            pw.Text('Contato: ${client.contato}'),
            pw.Text('Email: ${client.email}'),
            pw.SizedBox(height: 16),
          ],
          _buildSinistroInfoSection(claim),
          pw.SizedBox(height: 16),
          pw.Text('Histórico de Status:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ...claim.historicoStatus.map((entry) {
            final status = entry['status'] as String;
            final dataField = entry['data'];
            final date = dataField is DateTime
                ? dataField
                : dataField is Timestamp
                    ? dataField.toDate()
                    : DateTime.now();
            final responsavel = entry['responsavelEmail'] ?? entry['responsavel'] ?? 'N/A';
            return pw.Text('- $status em ${dateFormat.format(date)} (Responsável: $responsavel)',
                style: pw.TextStyle(fontSize: 12));
          }),
          pw.SizedBox(height: 16),
          if (claim.fotosUrls.isNotEmpty) ...[
            pw.Text('Fotos do Sinistro:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            // ✅ Usa o grid de fotos gerado
            fotosDoSinistroGrid,
            pw.SizedBox(height: 16),
          ],
          if (claim.terceiros.isNotEmpty) ...[
            pw.Text('Terceiros Envolvidos:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            ...terceirosSections,
          ],
          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('Este relatório é confidencial e não pode ser divulgado sem o consentimento da Upgrade Seguros.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text('Emitido em: ${dateTimeFormat.format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Contato:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Nome: Nathália'),
                pw.Text('Telefone: (11) 98765-4321'),
                pw.Text('Email: contato@upgradeseguros.com.br'),
              ],
            ),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildSinistroInfoSection(Claim claim) {
    if (claim.ramoSinistro == 'Transporte' && claim.transporte != null) {
      final t = claim.transporte!;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Informações do Transporte:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Motorista: ${t.nomeMotorista}'),
          pw.Text('CPF: ${t.cpfMotorista}'),
          pw.Text('Placa Cavalo: ${t.placaCavalo}'),
          pw.Text('Placa Carreta: ${t.placaCarreta}'),
          pw.Text('Número Averbação: ${t.numeroAverbacao}'),
          pw.Text('Reguladora: ${t.reguladora}'),
          pw.Text('NFE: ${t.nfe}'),
          pw.Text('Chassi: ${t.chassi}'),
          pw.Text('Chassi da Carreta: ${t.chassiCarreta}'),
          pw.Text('CTE: ${t.cte}'),
          pw.Text('Marca da Carreta: ${t.marcaCarreta}'),
          pw.Text('Modelo da Carreta: ${t.modeloCarreta}'),
          pw.Text('RCTRC: ${t.rctrc}'),
          pw.Text('VPO: ${t.vpo}'),
          pw.Text('Marca: ${t.marca}'),
          pw.Text('Modelo: ${t.modelo}'),
          pw.Text('Cor: ${t.cor}'),
        ],
      );
    } else if ((claim.ramoSinistro == 'Frota' || claim.ramoSinistro == 'Veículo Individual') && claim.veiculoSelecionado != null) {
      final v = claim.veiculoSelecionado!;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Informações do Veículo:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('Placa: ${v.placa}'),
          pw.Text('Chassi: ${v.chassi}'),
          pw.Text('Marca: ${v.marca}'),
          pw.Text('Modelo: ${v.modelo}'),
          pw.Text('Ano: ${v.ano} / ${v.anomodelo}'),
        ],
      );
    } else {
      return pw.Text('Sem informações detalhadas do transporte ou veículo.');
    }
  }

  Future<pw.Widget> _buildTerceiroSection(ThirdParty tp) async {
    pw.Widget? fotos;
    if (tp.fotosUrls != null && tp.fotosUrls!.isNotEmpty) {
      fotos = await _buildImageGrid(tp.fotosUrls!);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Divider(),
        pw.Text('Nome: ${tp.nome}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        if (tp.contato.isNotEmpty) pw.Text('Contato: ${tp.contato}'),
        if (tp.veiculo != null)
          pw.Text('Veículo: ${tp.veiculo.marca} ${tp.veiculo.modelo}'
              '${tp.veiculo.placa.isNotEmpty ? " - ${tp.veiculo.placa}" : ""}'),
        if (fotos != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('Fotos do terceiro:'),
          fotos,
        ],
      ],
    );
  }

  // ✅ VERSÃO CORRIGIDA: Usa a URL diretamente, sem manipulação
  Future<pw.Widget> _buildImageGrid(List<String> urls) async {
    final imageWidgets = <pw.Widget>[];
    for (final url in urls) {
      try {
        debugPrint('🔍 Tentando buscar imagem da URL: $url');
        // ✅ Remove a lógica de sanitização e cache busting.
        // O Uri.parse já é capaz de lidar com URLs com caracteres especiais codificados.
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          imageWidgets.add(
            pw.Container(
              width: 160,
              height: 160,
              child: pw.Image(pw.MemoryImage(response.bodyBytes), fit: pw.BoxFit.cover),
            ),
          );
        } else {
          // Adiciona a URL com o erro para facilitar a depuração
          debugPrint('❌ HTTP Error: ${response.statusCode} - ${response.body} - URL: $url');
          imageWidgets.add(
            pw.Container(
              width: 160,
              height: 160,
              color: PdfColors.grey300,
              alignment: pw.Alignment.center,
              child: pw.Text('Erro ao carregar imagem'),
            ),
          );
        }
      } catch (e) {
        // Loga o erro específico
        debugPrint('❌ Exception ao buscar imagem da URL: $url - Erro: $e');
        imageWidgets.add(
          pw.Container(
            width: 160,
            height: 160,
            color: PdfColors.grey300,
            alignment: pw.Alignment.center,
            child: pw.Text('Erro'),
          ),
        );
      }
    }
    return pw.Wrap(
      spacing: 4,
      runSpacing: 4,
      children: imageWidgets,
    );
  }
}
