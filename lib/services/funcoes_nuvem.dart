// lib/services/funcoes_nuvem.dart
//
// Etapa 15: endereço e cabeçalhos das Cloud Functions chamadas por HTTP.
// Desde a Etapa 15 as Functions de arquivo (uploadFile, deleteFiles) e a de
// criar usuário exigem login: o app manda o "ID token" do Firebase Auth no
// cabeçalho Authorization, e o servidor confere se o usuário está ativo.
// As públicas (npsPublico, apoioLogin) são chamadas sem login.

import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class FuncoesNuvem {
  // Etapa 15.1: as Functions são de 2ª geração (Cloud Run). O endereço
  // "us-central1-upgrade-seguros.cloudfunctions.net/<nome>" responde 404 para
  // elas neste projeto; o que funciona é o do Cloud Run:
  //   https://<nome em minúsculas>-hwtlk2s4qq-uc.a.run.app
  // ("hwtlk2s4qq" é fixo do projeto; "uc" = us-central1). É o mesmo formato
  // que o uploadFile já usava.
  static const _sufixo = '-hwtlk2s4qq-uc.a.run.app';

  static Uri url(String nome) => Uri.parse('https://${nome.toLowerCase()}$_sufixo');

  /// Content-Type JSON + Authorization com o ID token de quem está logado.
  static Future<Map<String, String>> cabecalhos() async {
    final h = <String, String>{'Content-Type': 'application/json'};
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  /// POST com JSON. [comLogin] = manda o ID token. Devolve a resposta crua.
  static Future<http.Response> post(String nome, Map<String, dynamic> corpo, {bool comLogin = true}) async {
    return http.post(
      url(nome),
      headers: comLogin ? await cabecalhos() : const {'Content-Type': 'application/json'},
      body: jsonEncode(corpo),
    );
  }

  /// Lê a mensagem de erro que as Functions da Etapa 15 devolvem ({erro: …}).
  static String erro(http.Response r) {
    try {
      final b = jsonDecode(r.body);
      if (b is Map && b['erro'] is String) return b['erro'] as String;
    } catch (_) {}
    return 'Erro ${r.statusCode}';
  }
}
