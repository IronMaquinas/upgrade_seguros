// lib/services/catalogo_seguradoras_service.dart — Etapa 22
//
// O lado do app do catálogo único de seguradoras (functions/catalogo.js):
//   • consultarCnpj / sugerir — seguradora nova entra pelo CNPJ; quem consulta a
//     Receita é o servidor, então o nome é o oficial;
//   • streamParaConfiguracoes — a lista de Configurações → Seguradoras: o
//     catálogo + o que é desta corretora (telefone, e-mail, contato, ativa).

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:upgrade_seguros/models/seguradora_model.dart';
import 'package:upgrade_seguros/services/empresa_atual.dart';
import 'package:upgrade_seguros/services/funcoes_nuvem.dart';
import 'package:upgrade_seguros/services/receita_cnpj.dart';
import 'package:upgrade_seguros/utils/perfil_corretora.dart';
import 'package:upgrade_seguros/services/seguradoras_cadastradas.dart';

class ResultadoCnpj {
  /// Já está no catálogo (visível para esta corretora).
  final String? existenteNome;
  final String cnpj;
  final String razaoSocial;
  final String nomeFantasia;
  final String situacaoReceita;

  const ResultadoCnpj({this.existenteNome, this.cnpj = '', this.razaoSocial = '', this.nomeFantasia = '', this.situacaoReceita = ''});

  bool get ativaNaReceita => situacaoReceita.isEmpty || situacaoReceita.toUpperCase() == 'ATIVA';
}

class CatalogoSeguradorasService {
  CatalogoSeguradorasService._();

  static Future<Map<String, dynamic>> _chamar(Map<String, dynamic> corpo) async {
    final r = await FuncoesNuvem.post('catalogoSeguradoras', corpo);
    final j = (() {
      try {
        return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      } catch (_) {
        return <String, dynamic>{};
      }
    })();
    if (r.statusCode != 200) throw Exception(j['erro'] ?? 'Erro ${r.statusCode}');
    return j;
  }

  /// Já está na lista? Se não, os dados da Receita: do servidor, ou — se o
  /// servidor não conseguir consultar (22.1) — do navegador, como na 17.1.
  static Future<ResultadoCnpj> consultarCnpj(String cnpj) async {
    final j = await _chamar({'acao': 'consultarCnpj', 'cnpj': cnpj});
    if (j['existente'] is Map) return ResultadoCnpj(existenteNome: (j['existente'] as Map)['nome'] as String?);
    if (j['receita'] is! Map) {
      final d = await consultarReceitaCnpj(cnpj);
      return ResultadoCnpj(
        cnpj: PerfilCorretora.formatarCnpj(cnpj.replaceAll(RegExp(r'\D'), '')),
        razaoSocial: d.razaoSocial,
        nomeFantasia: d.nomeFantasia,
        situacaoReceita: d.situacao,
      );
    }
    final r = Map<String, dynamic>.from(j['receita'] as Map);
    return ResultadoCnpj(
      cnpj: (r['cnpj'] ?? '') as String,
      razaoSocial: (r['razaoSocial'] ?? '') as String,
      nomeFantasia: (r['nomeFantasia'] ?? '') as String,
      situacaoReceita: (r['situacao'] ?? '') as String,
    );
  }

  /// Devolve o nome que ficou no catálogo (o existente ou o novo, pendente).
  /// [receita]: o que a consulta trouxe (o servidor usa se ele mesmo não conseguir consultar).
  static Future<({String nome, bool pendente, bool existente})> sugerir(String cnpj, String nome, {ResultadoCnpj? receita}) async {
    final j = await _chamar({
      'acao': 'sugerir',
      'cnpj': cnpj,
      'nome': nome,
      if (receita != null)
        'receita': {'razaoSocial': receita.razaoSocial, 'nomeFantasia': receita.nomeFantasia, 'situacao': receita.situacaoReceita},
    });
    final s = Map<String, dynamic>.from(j['seguradora'] as Map);
    SeguradorasCadastradas.invalidar();
    return (nome: (s['nome'] ?? '') as String, pendente: s['situacao'] == 'pendente', existente: j['existente'] == true);
  }

  /// Configurações → Seguradoras: catálogo (aprovadas + pendentes desta corretora)
  /// juntado com o cadastro desta corretora. Catálogo vazio → só o cadastro
  /// (como antes da Etapa 22).
  static Stream<List<Seguradora>> streamParaConfiguracoes() {
    final col = FirebaseFirestore.instance.collection('catalogo_seguradoras');
    final fontes = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
      col.where('situacao', isEqualTo: 'aprovada').snapshots(),
      col.where('criadaPor.empresaId', isEqualTo: EmpresaAtual.id).where('situacao', isEqualTo: 'pendente').snapshots(),
      EmpresaAtual.col('seguradoras').snapshots(),
    ];
    final ultimos = List<QuerySnapshot<Map<String, dynamic>>?>.filled(3, null);
    final subs = <StreamSubscription>[];
    late final StreamController<List<Seguradora>> ctrl;

    void emitir() {
      final cadastro = ultimos[2];
      if (cadastro == null) return;
      final docsCadastro = cadastro.docs;
      final catalogo = [
        for (final s in [ultimos[0], ultimos[1]])
          if (s != null)
            for (final d in s.docs) (d.id, d.data()),
      ];
      final temAprovada = (ultimos[0]?.docs.isNotEmpty ?? false);
      if (!temAprovada) {
        ctrl.add([for (final d in docsCadastro) Seguradora.fromFirestore(d)]..sort((a, b) => a.nome.compareTo(b.nome)));
        return;
      }
      final porCatalogoId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      final porNome = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final d in docsCadastro) {
        final cid = (d.data()['catalogoId'] ?? '') as String;
        if (cid.isNotEmpty) porCatalogoId[cid] = d;
        porNome[((d.data()['nome'] ?? '') as String).trim()] = d;
      }
      final usados = <String>{};
      final lista = <Seguradora>[];
      for (final (id, m) in catalogo) {
        final nome = ((m['nome'] ?? '') as String).trim();
        final doc = porCatalogoId[id] ?? porNome[nome];
        if (doc != null) usados.add(doc.id);
        final dados = doc?.data() ?? const <String, dynamic>{};
        lista.add(Seguradora(
          id: doc?.id ?? '',
          nome: nome,
          telefone: (dados['telefone'] ?? '') as String,
          email: (dados['email'] ?? '') as String,
          contato: (dados['contato'] ?? '') as String,
          ativa: (dados['ativa'] ?? true) as bool,
          catalogoId: id,
          pendente: m['situacao'] == 'pendente',
          cnpj: (m['cnpj'] ?? '') as String,
        ));
      }
      // do cadastro da corretora, mas fora do catálogo (antes da importação, ou nome antigo)
      for (final d in docsCadastro) {
        if (!usados.contains(d.id)) lista.add(Seguradora.fromFirestore(d)..foraDoCatalogo = true);
      }
      lista.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
      ctrl.add(lista);
    }

    // broadcast: a aba pode ser recriada (TabBarView) e escutar de novo; ao
    // voltar a ter ouvinte, as consultas são refeitas e mandam o estado atual.
    ctrl = StreamController<List<Seguradora>>.broadcast(
      onListen: () {
        for (var i = 0; i < fontes.length; i++) {
          subs.add(fontes[i].listen(
            (s) {
              ultimos[i] = s;
              emitir();
            },
            // catálogo fora do ar (ex.: regras ainda não publicadas): segue só com o cadastro
            onError: (Object e) {
              if (i == 2) ctrl.addError(e);
            },
          ));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
        subs.clear();
        ultimos.fillRange(0, ultimos.length, null);
      },
    );
    return ctrl.stream;
  }
}
