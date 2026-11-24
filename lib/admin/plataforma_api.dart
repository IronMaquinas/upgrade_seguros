// lib/admin/plataforma_api.dart — Etapa 21
//
// Chamadas do portal à Function "plataforma" (functions/plataforma.js) e os
// dados que ela devolve. O portal não lê o Firestore direto: tudo passa pela
// Function, que confere o admin e registra a auditoria.

import 'dart:convert';

import 'package:upgrade_seguros/services/funcoes_nuvem.dart';
import 'package:upgrade_seguros/utils/planos.dart';

import 'modelos_plataforma.dart';
export 'modelos_plataforma.dart';
export 'package:upgrade_seguros/utils/planos.dart';

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

  // ── Etapa 23: módulos ──
  /// [modulos] null = tudo ligado.
  static Future<void> contaDefinirModulos(String empresaId, List<String>? modulos) => _chamar({
        'acao': 'contaDefinirModulos',
        'empresaId': empresaId,
        'tipo': modulos == null ? 'tudo_ligado' : 'personalizado',
        if (modulos != null) 'modulos': modulos,
      });

  // ── Etapa 24: planos ──
  static Future<List<PlanoModelo>> planos() async {
    final j = await _chamar({'acao': 'planos'});
    return [for (final p in (j['planos'] as List)) PlanoModelo.deJson(Map<String, dynamic>.from(p as Map))];
  }

  /// Devolve quantas corretoras foram atualizadas (edição de um plano em uso).
  static Future<int> planoSalvar({
    String? id,
    required String nome,
    String descricao = '',
    bool ativo = true,
    required List<String> modulos,
    required int precoCentavos,
    required Map<String, Franquia> franquias,
  }) async {
    final j = await _chamar({
      'acao': 'planoSalvar',
      if (id != null && id.isNotEmpty) 'id': id,
      'nome': nome,
      'descricao': descricao,
      'ativo': ativo,
      'modulos': modulos,
      'precoCentavos': precoCentavos,
      'franquias': Planos.franquiasParaMapa(franquias),
    });
    return (j['contas'] as num?)?.toInt() ?? 0;
  }

  static Future<void> planoExcluir(String id) => _chamar({'acao': 'planoExcluir', 'id': id});

  /// [tipo]: 'tudo_ligado' · 'modelo' (com [planoId]) · 'personalizado' (módulos, preço, franquias).
  /// [cortesiaAte]: 'AAAA-MM-DD' ou null (sem validade).
  static Future<void> contaDefinirPlano(
    String empresaId, {
    required String tipo,
    String? planoId,
    List<String>? modulos,
    int? precoCentavos,
    Map<String, Franquia>? franquias,
    required bool cortesia,
    String? cortesiaAte,
    String motivo = '',
  }) =>
      _chamar({
        'acao': 'contaDefinirPlano',
        'empresaId': empresaId,
        'tipo': tipo,
        if (planoId != null) 'planoId': planoId,
        if (modulos != null) 'modulos': modulos,
        if (precoCentavos != null) 'precoCentavos': precoCentavos,
        if (franquias != null) 'franquias': Planos.franquiasParaMapa(franquias),
        'cortesia': cortesia,
        'cortesiaAte': cortesiaAte,
        'motivo': motivo,
      });

  // ── Etapa 25: pedidos e situação ──
  static Future<List<PedidoPlataforma>> pedidos() async {
    final j = await _chamar({'acao': 'pedidos'});
    return [for (final p in (j['pedidos'] as List)) PedidoPlataforma.deJson(Map<String, dynamic>.from(p as Map))];
  }

  /// [planoId] null = Tudo ligado durante o teste. Devolve o e-mail do gestor criado.
  static Future<String> pedidoAprovar(String id, {String? planoId, int diasTeste = 14}) async {
    final j = await _chamar({'acao': 'pedidoAprovar', 'id': id, if (planoId != null) 'planoId': planoId, 'diasTeste': diasTeste});
    return (j['email'] ?? '') as String;
  }

  static Future<void> pedidoRecusar(String id, String motivo) => _chamar({'acao': 'pedidoRecusar', 'id': id, 'motivo': motivo});

  static Future<void> pedidoAtendido(String id, String nota) => _chamar({'acao': 'pedidoAtendido', 'id': id, 'nota': nota});

  /// [testeAte] 'AAAA-MM-DD' (só para situação 'teste').
  static Future<void> contaDefinirSituacao(String empresaId, String situacao, {String? testeAte, String motivo = ''}) => _chamar({
        'acao': 'contaDefinirSituacao',
        'empresaId': empresaId,
        'situacao': situacao,
        if (testeAte != null) 'testeAte': testeAte,
        'motivo': motivo,
      });

  // ── Etapa 22: catálogo de seguradoras ──
  static Future<List<SeguradoraCatalogo>> catalogo() async {
    final j = await _chamar({'acao': 'catalogo'});
    return [for (final x in (j['seguradoras'] as List)) SeguradoraCatalogo.deJson(Map<String, dynamic>.from(x as Map))];
  }

  static Future<Map<String, dynamic>> catalogoImportar() => _chamar({'acao': 'catalogoImportar'});

  static Future<Map<String, dynamic>> catalogoUso(String id) => _chamar({'acao': 'catalogoUso', 'id': id});

  static Future<void> catalogoAprovar(String id, {String? nome}) => _chamar({'acao': 'catalogoAprovar', 'id': id, if (nome != null) 'nome': nome});

  static Future<void> catalogoCriar({required String cnpj, required String nome, String razaoSocial = '', String susep = ''}) =>
      _chamar({'acao': 'catalogoCriar', 'cnpj': cnpj, 'nome': nome, 'razaoSocial': razaoSocial, 'susep': susep});

  static Future<void> catalogoEditar(String id,
          {String? nome, String? cnpj, String? susep, List<String>? apelidos, bool? ativa, String? razaoSocial}) =>
      _chamar({
        'acao': 'catalogoEditar',
        'id': id,
        if (nome != null) 'nome': nome,
        if (cnpj != null) 'cnpj': cnpj,
        if (susep != null) 'susep': susep,
        if (apelidos != null) 'apelidos': apelidos,
        if (ativa != null) 'ativa': ativa,
        if (razaoSocial != null) 'razaoSocial': razaoSocial,
      });

  static Future<void> catalogoJuntar(String de, String para) => _chamar({'acao': 'catalogoJuntar', 'de': de, 'para': para});

  static Future<void> catalogoRecusar(String id, String motivo) => _chamar({'acao': 'catalogoRecusar', 'id': id, 'motivo': motivo});

  static Future<List<String>> criarContasQueFaltam() async {
    final j = await _chamar({'acao': 'criarContasQueFaltam'});
    return [for (final x in (j['criadas'] as List)) x as String];
  }
}
