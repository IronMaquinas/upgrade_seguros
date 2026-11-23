// lib/services/marca_pdf.dart
//
// Etapa 17: cabeçalho e rodapé PADRÃO de todos os PDFs, com os dados da
// corretora do usuário (Configurações → 🏢 Dados da corretora) e a assinatura
// configurada (Configurações → 📝 Assinatura em PDF).
//
//   final marca = await MarcaPdf.carregar();
//   pw.MultiPage(
//     header: (ctx) => marca.cabecalho(titulo: 'Relatório de clientes'),
//     footer: (ctx) => marca.rodape(ctx),
//     ...
//
// A logo vem do cadastro da corretora. Enquanto a corretora que recebeu os
// dados antigos (a Upgrade) não envia a sua, usa a logo que já ia nos PDFs
// (lib/assets/logo_upgrade.png). Corretora nova sem logo: sem logo.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../helpers/signature_data_helper.dart';
import '../models/corretora_model.dart';
import '../models/pdf_signature_model.dart';
import '../utils/perfil_corretora.dart';
import 'empresa_atual.dart';
import 'employee_service.dart';

class MarcaPdf {
  static const azul = PdfColor.fromInt(0xFF1565C0);
  static const cinza = PdfColor.fromInt(0xFF546E7A);

  final Corretora? corretora;
  final Uint8List? logo;
  final Map<String, String?> assinatura;
  final DateTime geradoEm;

  MarcaPdf({this.corretora, this.logo, this.assinatura = const {}, DateTime? geradoEm})
      : geradoEm = geradoEm ?? DateTime.now();

  String get nome => PerfilCorretora.nome(corretora);

  /// Lê corretora, logo e assinatura. Nunca falha: o que não carregar fica de fora.
  static Future<MarcaPdf> carregar() async {
    Corretora? corretora;
    var legado = false;
    try {
      if (!EmpresaAtual.carregada) await EmpresaAtual.carregar();
      final s = await EmpresaAtual.doc.get();
      final d = s.data();
      if (d != null) {
        corretora = Corretora.fromMap(d, s.id);
        legado = d['migradoEm'] != null;
      }
    } catch (e) {
      debugPrint('MarcaPdf: cadastro da corretora não carregou: $e');
    }

    Uint8List? logo;
    final url = (corretora?.logo ?? '').trim();
    if (url.isNotEmpty) {
      try {
        final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
        if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) logo = r.bodyBytes;
      } catch (e) {
        debugPrint('MarcaPdf: logo não carregou: $e');
      }
    }
    if (logo == null && legado) {
      try {
        logo = (await rootBundle.load('lib/assets/logo_upgrade.png')).buffer.asUint8List();
      } catch (_) {}
    }

    var assinatura = <String, String?>{};
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final funcionario = uid == null ? null : await EmployeeService().getUserById(uid);
      var cfg = PdfSignatureConfig(seguradoraId: EmpresaAtual.id);
      final c = await EmpresaAtual.col('pdf_signatures').doc(EmpresaAtual.id).get();
      if (c.exists) cfg = PdfSignatureConfig.fromJson(c.data() as Map<String, dynamic>);
      assinatura = SignatureDataHelper.getSignatureData(
        nomeSource: cfg.nomeSource,
        telefoneSource: cfg.telefoneSource,
        emailSource: cfg.emailSource,
        currentEmployee: funcionario,
        corretora: corretora,
        nomeController: '',
        telefoneController: '',
        emailController: '',
      );
    } catch (e) {
      debugPrint('MarcaPdf: assinatura não carregou: $e');
    }

    return MarcaPdf(corretora: corretora, logo: logo, assinatura: assinatura);
  }

  /// Só o nome da corretora (ex.: assinatura da mensagem de WhatsApp).
  static Future<String> nomeDaCorretora() async {
    try {
      if (!EmpresaAtual.carregada) await EmpresaAtual.carregar();
      final s = await EmpresaAtual.doc.get();
      final d = s.data();
      return PerfilCorretora.nome(d == null ? null : Corretora.fromMap(d, s.id));
    } catch (_) {
      return PerfilCorretora.nome(null);
    }
  }

  /// Cabeçalho: logo + nome + dados da corretora à esquerda; título do
  /// documento (e o que mais vier em [direita]) à direita; linha embaixo.
  pw.Widget cabecalho({
    required String titulo,
    String? subtitulo,
    List<pw.Widget> direita = const [],
    PdfColor cor = azul,
  }) {
    final linhas = PerfilCorretora.linhasCabecalho(corretora);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: cor, width: 1))),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null) ...[
            pw.Container(
              constraints: const pw.BoxConstraints(maxHeight: 44, maxWidth: 110),
              child: pw.Image(pw.MemoryImage(logo!), fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(width: 12),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(nome, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: cor)),
                for (final l in linhas) pw.Text(l, style: const pw.TextStyle(fontSize: 7, color: cinza)),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(titulo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: cor)),
              if (subtitulo != null && subtitulo.isNotEmpty)
                pw.Text(subtitulo, style: const pw.TextStyle(fontSize: 8, color: cinza)),
              ...direita,
            ],
          ),
        ],
      ),
    );
  }

  /// Rodapé: observação (opcional) em cima; "Gerado por … · data" e a página.
  pw.Widget rodape(pw.Context ctx, {String? observacao}) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.only(top: 4),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (observacao != null && observacao.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(observacao, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600)),
            ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text('$nome · ${PerfilCorretora.linhaRodape(assinatura, geradoEm)}',
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ),
              pw.Text('Página ${ctx.pageNumber} de ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ],
      ),
    );
  }
}
