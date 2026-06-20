// lib/services/nps_service.dart
// ignore_for_file: unused_import

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class NpsService {
  final _db = FirebaseFirestore.instance;

  // ── URL base do app web (mudar para produção)
  static const String _baseUrl = 'https://upgrade-seguros.web.app/nps';

  // ─────────────────────────────────────────────────
  // Gerar link único de pesquisa
  // ─────────────────────────────────────────────────
  Future<String> gerarLinkNps({
    required String claimId,
    required String numeroSinistro,
    required String clienteId,
    required String clienteNome,
    required String tipo, // 'sinistro' ou 'assistencia'
  }) async {
    final token = '${claimId}_${DateTime.now().millisecondsSinceEpoch}';

    await _db.collection('nps_pesquisas').doc(claimId).set({
      'claimId': claimId,
      'numeroSinistro': numeroSinistro,
      'clienteId': clienteId,
      'clienteNome': clienteNome,
      'tipo': tipo,
      'token': token,
      'status': 'enviada',
      'criadoEm': FieldValue.serverTimestamp(),
      'respondidoEm': null,
    });

    return '$_baseUrl?claim=$claimId&token=$token';
  }

  // COTAÇÕES VENCIDAS
  Future<void> verificarCotacoesVencidas() async {
    final seiseDiasAtras = DateTime.now().subtract(Duration(days: 7));
    
    final cotacoes = await _db
        .collection('cotacoes')
        .where('status', isEqualTo: 'enviada')
        .where('dataCriacao', isLessThan: seiseDiasAtras)
        .get();

    for (var doc in cotacoes.docs) {
      await doc.reference.update({'status': 'vencida'});
    }
  }

  // ─────────────────────────────────────────────────
  // Enviar via WhatsApp
  // ─────────────────────────────────────────────────
  Future<void> enviarViaWhatsApp({
    required String telefone,
    required String nomeCliente,
    required String numeroSinistro,
    required String link,
  }) async {
    final mensagem = 'Olá $nomeCliente! 👋\n\n'
        'Seu atendimento *$numeroSinistro* foi concluído com sucesso!\n\n'
        'Gostaríamos de saber sua opinião sobre o nosso serviço. Leva menos de 1 minuto:\n\n'
        '🔗 $link\n\n'
        'Sua avaliação é muito importante para continuarmos melhorando!\n\n'
        'Obrigada pela confiança. 🙏';

    final telefoneFormatado = _formatarTelefone(telefone);
    final uri = Uri.parse(
      'https://wa.me/$telefoneFormatado?text=${Uri.encodeComponent(mensagem)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> enviarViaEmail({
    required String email,
    required String nomeCliente,
    required String numeroSinistro,
    required String link,
  }) async {
    final assunto = 'A Upgrade Seguros quer ouvir você — Atendimento $numeroSinistro';
    final corpo = 'Olá $nomeCliente,\n\n'
        'Seu atendimento $numeroSinistro foi concluído!\n\n'
        'Clique no link abaixo para avaliar nosso serviço (menos de 1 minuto):\n\n'
        '$link\n\n'
        'Sua opinião é fundamental para melhorarmos continuamente.\n\n'
        'Obrigada pela confiança!';

    final uri = Uri(
      scheme: 'https',
      host: 'mail.google.com',
      path: '/mail/u/0/',
      queryParameters: {
        'view': 'cm',
        'to': email,
        'subject': assunto,
        'body': corpo,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ─────────────────────────────────────────────────
  // Salvar resposta do cliente
  // ✨ NOVO: Atualiza a OS com a avaliação
  // ─────────────────────────────────────────────────
  Future<bool> salvarResposta({
    required String claimId,
    required String token,
    required int nota,
    required List<String> pontosFortes,
    required List<String> pontosFracos,
    required String reclamacoes,
    required String sugestoes,
  }) async {
    try {
      final pesquisa = await _db.collection('nps_pesquisas').doc(claimId).get();
      if (!pesquisa.exists) return false;

      final data = pesquisa.data()!;
      if (data['token'] != token) return false;
      if (data['status'] == 'respondida') return false;

      final categoria = nota >= 9 ? 'promotor' : nota >= 7 ? 'neutro' : 'detrator';

      await _db.collection('avaliacoes').doc(claimId).set({
        'claimId': claimId,
        'numeroSinistro': data['numeroSinistro'],
        'clienteId': data['clienteId'],
        'clienteNome': data['clienteNome'],
        'tipo': data['tipo'],
        'nota': nota,
        'categoria': categoria,
        'pontosFortes': pontosFortes,
        'pontosFracos': pontosFracos,
        'reclamacoes': reclamacoes,
        'sugestoes': sugestoes,
        'respondidoEm': FieldValue.serverTimestamp(),
      });

      await _db.collection('nps_pesquisas').doc(claimId).update({
        'status': 'respondida',
        'respondidoEm': FieldValue.serverTimestamp(),
        'nota': nota,
        'categoria': categoria,
      });

      // Atualiza na coleção correta (sinistros ou assistencias)
      final colecao = data['tipo'] == 'assistencia' ? 'assistencias' : 'sinistros';
      await _db.collection(colecao).doc(claimId).update({
        'nps_avaliada': true,
        'nps_satisfacao': nota.toDouble(),
        'nps_categoria': categoria,
        'npsDataAvaliacao': FieldValue.serverTimestamp(),
      });

      await _atualizarNpsCliente(data['clienteId']);
      return true;
    } catch (e) {
      print('❌ Erro ao salvar NPS: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────
  // Atualizar NPS médio do cliente
  // ─────────────────────────────────────────────────
  Future<void> _atualizarNpsCliente(String clienteId) async {
    try {
      final avaliacoes = await _db
          .collection('avaliacoes')
          .where('clienteId', isEqualTo: clienteId)
          .get();

      if (avaliacoes.docs.isEmpty) return;

      final notas = avaliacoes.docs
          .map((d) => (d.data()['nota'] as num?)?.toDouble() ?? 0.0)
          .toList();

      final media = notas.reduce((a, b) => a + b) / notas.length;

      // Contar promotores e detratores
      final promotores = notas.where((n) => n >= 9).length;
      final detratores = notas.where((n) => n <= 6).length;
      final total      = notas.length;
      final score      = ((promotores - detratores) / total * 100).round();

      await _db.collection('clientes').doc(clienteId).update({
        'nps':        media,        // Média das notas
        'npsScore':   score,        // Score NPS real (-100 a 100)
        'npsTotal':   total,        // Total de respostas
        'npsAtualizado': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Erro ao atualizar NPS do cliente: $e');
    }
  }

  // ─────────────────────────────────────────────────
  // Verificar pesquisa (pública - sem auth)
  // ✨ NOVO: Busca dados adicionais do cliente e OS
  // ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> verificarPesquisa({
    required String claimId,
    required String token,
  }) async {
    try {
      final doc = await _db.collection('nps_pesquisas').doc(claimId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      if (data['token'] != token) return null;
      if (data['status'] == 'respondida') return {'jaRespondida': true};

      Map<String, dynamic> clienteData = {};
      if (data['clienteId'] != null && (data['clienteId'] as String).isNotEmpty) {
        try {
          final clienteDoc = await _db.collection('clientes').doc(data['clienteId']).get();
          clienteData = clienteDoc.data() ?? {};
        } catch (e) {
          print('⚠️ Erro ao buscar cliente: $e');
        }
      }

      return {
        'jaRespondida': false,
        'clienteNome': data['clienteNome'],
        'numeroSinistro': data['numeroSinistro'],
        'tipo': data['tipo'] ?? 'sinistro',
        'clienteLogoUrl': clienteData['logoUrl'] ?? '',
        'clienteEmpresa': clienteData['nomeEmpresa'] ?? data['clienteNome'],
      };
    } catch (e) {
      print('❌ Erro ao verificar pesquisa: $e');
      return null;
    }
  }

  String _formatarTelefone(String telefone) {
    final limpo = telefone.replaceAll(RegExp(r'[^\d]'), '');
    return limpo.startsWith('55') ? limpo : '55$limpo';
  }
}