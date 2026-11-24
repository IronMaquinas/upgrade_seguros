// lib/services/receita_cnpj.dart — Etapa 22.1
//
// Consulta do CNPJ na Receita (BrasilAPI) feita NO NAVEGADOR — o mesmo jeito da
// Etapa 17.1 (Dados da corretora), que funciona. Na 22 a consulta foi para o
// servidor, mas a BrasilAPI recusa (403) as chamadas que saem dos servidores do
// Google; o servidor agora só tenta e, se não conseguir, usa o que o navegador
// trouxe.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:upgrade_seguros/utils/perfil_corretora.dart';

class ErroReceita implements Exception {
  final String mensagem;
  const ErroReceita(this.mensagem);
  @override
  String toString() => mensagem;
}

/// Dados da Receita para o CNPJ (só dígitos ou formatado). Lança [ErroReceita].
Future<DadosReceita> consultarReceitaCnpj(String cnpj) async {
  final c = cnpj.replaceAll(RegExp(r'\D'), '');
  if (!PerfilCorretora.cnpjValido(c)) throw const ErroReceita('CNPJ inválido — confira os 14 dígitos.');
  final http.Response r;
  try {
    r = await http.get(Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$c')).timeout(const Duration(seconds: 15));
  } catch (_) {
    throw const ErroReceita('A consulta à Receita não respondeu agora. Tente de novo.');
  }
  if (r.statusCode == 404) throw const ErroReceita('CNPJ não encontrado na Receita Federal.');
  if (r.statusCode != 200) throw ErroReceita('A consulta à Receita não respondeu agora (${r.statusCode}). Tente de novo.');
  return PerfilCorretora.lerReceita(Map<String, dynamic>.from(jsonDecode(r.body) as Map));
}
