// lib/services/plano_atual.dart — Etapa 23
//
// O plano da corretora logada (plataforma_contas/{empresaId}): situação,
// nome do plano e quais módulos estão ligados. Lido uma vez no PortaoEmpresa;
// as telas perguntam PlanoAtual.tem('tarefas') etc.
//
// Sem conta (ou se a leitura falhar) = tudo ligado: o app nunca trava por um
// problema de leitura; a trava de verdade fica nas regras do servidor.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:upgrade_seguros/services/empresa_atual.dart';
import 'package:upgrade_seguros/utils/modulos.dart';
import 'package:upgrade_seguros/utils/planos.dart';
import 'package:upgrade_seguros/utils/situacao_conta.dart';

class PlanoAtual {
  PlanoAtual._();

  static Set<String>? _ligados; // null = tudo ligado
  static Map<String, dynamic>? _conta;

  /// Avisa as telas quando o plano é (re)carregado.
  static final ValueNotifier<int> versao = ValueNotifier(0);

  static Future<void> carregar() async {
    try {
      final d = await FirebaseFirestore.instance.collection('plataforma_contas').doc(EmpresaAtual.id).get();
      _conta = d.exists ? d.data() : null;
      _ligados = Modulos.ligadosDaConta(_conta);
    } catch (_) {
      _conta = null;
      _ligados = null;
    }
    versao.value++;
  }

  static void limpar() {
    _conta = null;
    _ligados = null;
  }

  /// O módulo [id] está ligado no plano desta corretora?
  static bool tem(String id) => _ligados == null || _ligados!.contains(id);

  static bool get tudoLigado => _ligados == null;

  static String get nomePlano {
    final p = _conta?['plano'];
    if (p is Map && (p['nome'] ?? '').toString().isNotEmpty) return p['nome'].toString();
    return _ligados == null ? 'Tudo ligado' : 'Personalizado';
  }

  /// '' = sem conta na plataforma (corretora anterior aos planos).
  static String get situacao => (_conta?['situacao'] ?? '') as String;

  static bool get cortesia => _conta?['cortesia'] == true;

  // ── Etapa 24: tipo, preço, franquias e cortesia com validade ──
  static Map<String, dynamic> get _plano =>
      _conta?['plano'] is Map ? Map<String, dynamic>.from(_conta!['plano'] as Map) : const <String, dynamic>{};

  /// 'tudo_ligado' · 'modelo' · 'personalizado'
  static String get tipo => (_plano['tipo'] ?? 'tudo_ligado') as String;

  static String get planoId => (_plano['planoId'] ?? '') as String;

  static String get descricao => (_plano['descricao'] ?? '') as String;

  static int get precoCentavos => tipo == 'tudo_ligado' ? 0 : (_plano['precoCentavos'] as num?)?.toInt() ?? 0;

  static Map<String, Franquia> get franquias => Planos.franquiasDe(_plano['franquias']);

  /// Etapa 27: uso medido pela plataforma (null = ainda não medido).
  static UsoConta? get uso => UsoConta.deMapa(_conta?['uso']);

  static DateTime? get cortesiaAte {
    final v = _conta?['cortesiaAte'];
    return v is Timestamp ? v.toDate() : null;
  }

  static DateTime? get testeAte {
    final v = _conta?['testeAte'];
    return v is Timestamp ? v.toDate() : null;
  }

  // ── Etapa 25 ──
  /// Teste vencido = 'teste_encerrado' (sem conta = 'ativa').
  static String get situacaoEfetiva => SituacaoConta.efetiva(situacao, testeAte);

  /// Teste encerrado, suspensa, cancelada: o servidor só deixa ler.
  static bool get somenteLeitura => SituacaoConta.somenteLeitura(situacaoEfetiva);
}
