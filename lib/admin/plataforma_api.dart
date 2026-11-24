// lib/admin/plataforma_api.dart — Etapa 21
//
// Chamadas do portal à Function "plataforma" (functions/plataforma.js) e os
// dados que ela devolve. O portal não lê o Firestore direto: tudo passa pela
// Function, que confere o admin e registra a auditoria.

import 'dart:convert';

import 'package:upgrade_seguros/services/funcoes_nuvem.dart';

import 'modelos_plataforma.dart';
export 'modelos_plataforma.dart';

class AcessoNegado implements Exception {
  final String mensagem;
  const AcessoNegado(this.mensagem);
  @override
  String toString() => mensagem;
}

class PlataformaApi {
  static Future<Map<String, dynamic>> _chamar(Map<String, dynamic> corpo) async {
    final r = await FuncoesNuvem.post('plataforma', corpo);
    if (r.statusCode == 403) throw AcessoNegado(FuncoesNuvem.erro(r));
    if (r.statusCode != 200) throw Exception(FuncoesNuvem.erro(r));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  /// Confere se quem está logado é admin. [entrada]: registra o login.
  static Future<String> eu({bool entrada = false}) async =>
      (await _chamar({'acao': 'eu', 'entrada': entrada}))['email'] as String? ?? '';

  static Future<List<CorretoraPlataforma>> corretoras() async {
    final j = await _chamar({'acao': 'corretoras'});
    return [for (final c in (j['corretoras'] as List)) CorretoraPlataforma.deJson(Map<String, dynamic>.from(c as Map))];
  }

  static Future<List<AcaoAuditoria>> auditoria() async {
    final j = await _chamar({'acao': 'auditoria'});
    return [for (final a in (j['acoes'] as List)) AcaoAuditoria.deJson(Map<String, dynamic>.from(a as Map))];
  }

  static Future<List<String>> criarContasQueFaltam() async {
    final j = await _chamar({'acao': 'criarContasQueFaltam'});
    return [for (final x in (j['criadas'] as List)) x as String];
  }
}
