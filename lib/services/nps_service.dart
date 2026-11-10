// lib/services/nps_service.dart
// ignore_for_file: unused_import

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:upgrade_seguros/services/funcoes_nuvem.dart'; // Etapa 15
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
    // Etapa 15: o cliente responde sem login — quem grava é o servidor
    // (Function npsPublico), que confere o token. Antes o app gravava direto
    // no banco, o que exigia o banco aberto para qualquer pessoa.
    try {
      final r = await FuncoesNuvem.post(
        'npsPublico',
        {
          'acao': 'responder',
          'claimId': claimId,
          'token': token,
          'nota': nota,
          'pontosFortes': pontosFortes,
          'pontosFracos': pontosFracos,
          'reclamacoes': reclamacoes,
          'sugestoes': sugestoes,
        },
        comLogin: false,
      );
      if (r.statusCode != 200) debugPrint('NPS não salvo: ${FuncoesNuvem.erro(r)}');
      return r.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Erro ao salvar NPS: $e');
      return false;
    }
  }

  // (Etapa 15: o NPS médio do cliente agora é recalculado no servidor, na
  //  Function npsPublico — functions/seguranca.js.)

  // ─────────────────────────────────────────────────
  // Verificar pesquisa (pública - sem auth)
  // ✨ NOVO: Busca dados adicionais do cliente e OS
  // ─────────────────────────────────────────────────
  Future<Map<String, dynamic>?> verificarPesquisa({
    required String claimId,
    required String token,
  }) async {
    // Etapa 15: consulta pelo servidor (Function npsPublico), sem login.
    try {
      final r = await FuncoesNuvem.post(
        'npsPublico',
        {'acao': 'verificar', 'claimId': claimId, 'token': token},
        comLogin: false,
      );
      if (r.statusCode != 200) return null;
      return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } catch (e) {
      debugPrint('❌ Erro ao verificar pesquisa: $e');
      return null;
    }
  }

  String _formatarTelefone(String telefone) {
    final limpo = telefone.replaceAll(RegExp(r'[^\d]'), '');
    return limpo.startsWith('55') ? limpo : '55$limpo';
  }
}