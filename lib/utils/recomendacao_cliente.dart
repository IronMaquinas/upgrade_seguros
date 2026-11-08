// lib/utils/recomendacao_cliente.dart
//
// Etapa 09: regra ÚNICA da recomendação do cliente (Ótimo / Regular / Atenção /
// Não recomendado). Antes havia 4 contas diferentes (lista, detalhe, salvar
// cliente, encerrar sinistro), nenhuma usando o gatilho. Dart puro, testado em
// test/recomendacao_cliente_test.dart.
//
// Como calcula:
//  1. Só valem as apólices VIGENTES hoje (início ≤ hoje ≤ fim, dia final
//     inclusive). Nenhuma vigente → "Sem apólice vigente". Vigente, mas sem
//     valor da apólice e sem gatilho → "Apólice sem valor".
//  2. Para cada apólice vigente: gasto = soma dos sinistros que consomem o
//     gatilho dela (ocorridos na vigência, sem Cancelado/Negado — mesma regra do
//     Top 10 de risco, lib/utils/gatilho.dart).
//     Sinistro sem vínculo com apólice (aberto sem escolher, ou ligado a uma
//     apólice que não existe mais) entra na apólice do MESMO RAMO cuja vigência
//     cobre a data do sinistro. Isso é só para o cálculo; nada é gravado.
//  3. Uso = gasto ÷ gatilho efetivo (contrato, ou % padrão × valor da apólice).
//  4. Vale a PIOR apólice do cliente:
//       < 60%  Ótimo · < 80%  Regular · ≤ 100%  Atenção · > 100%  Não recomendado
//     Acima do gatilho e acima do próprio valor da apólice são ambos
//     "Não recomendado"; o resultado traz os dois percentuais para a tela
//     mostrar a diferença.

import 'gatilho.dart';

class ApoliceParaRecomendacao {
  final String id;
  final String numero;
  final String ramo;
  final DateTime inicio;
  final DateTime fim;
  final double valorApolice;
  final double valorGatilho;
  const ApoliceParaRecomendacao({
    required this.id,
    required this.numero,
    required this.ramo,
    required this.inicio,
    required this.fim,
    required this.valorApolice,
    required this.valorGatilho,
  });
}

class SinistroParaRecomendacao {
  final String? apoliceId;
  final String ramo;
  final DateTime dataOcorrencia;
  final String status;
  final double valor;
  const SinistroParaRecomendacao({
    required this.apoliceId,
    required this.ramo,
    required this.dataOcorrencia,
    required this.status,
    required this.valor,
  });
}

class ResultadoRecomendacao {
  final String rotulo;

  /// Dados da pior apólice (null quando não há apólice vigente com valor).
  final String? apoliceNumero;
  final String? apoliceRamo;
  final double gasto;
  final double gatilho;
  final double valorApolice;

  const ResultadoRecomendacao({
    required this.rotulo,
    this.apoliceNumero,
    this.apoliceRamo,
    this.gasto = 0,
    this.gatilho = 0,
    this.valorApolice = 0,
  });

  /// % do gatilho usado.
  double get usoGatilho => GatilhoApolice.usoPercentual(gasto, gatilho);

  /// % do valor da apólice usado.
  double get usoApolice => valorApolice > 0 ? gasto / valorApolice * 100 : 0;

  bool get acimaDoValorDaApolice => valorApolice > 0 && gasto > valorApolice;

  /// Linha explicativa para o Detalhes do Cliente.
  String get explicacao {
    switch (rotulo) {
      case RecomendacaoCliente.semApoliceVigente:
        return 'Nenhuma apólice vigente hoje: renovar ou cadastrar a apólice.';
      case RecomendacaoCliente.apoliceSemValor:
        return 'A apólice vigente está sem valor e sem gatilho: preencher no cadastro.';
    }
    final base = 'Uso do gatilho: ${usoGatilho.toStringAsFixed(0)}% · '
        '${usoApolice.toStringAsFixed(0)}% do valor da apólice';
    final onde = apoliceRamo == null ? '' : ' ($apoliceRamo ${apoliceNumero ?? ''})'.replaceAll(' )', ')');
    if (acimaDoValorDaApolice) return '$base$onde — acima do valor da apólice';
    if (usoGatilho > 100) return '$base$onde — acima do gatilho';
    return '$base$onde';
  }
}

class RecomendacaoCliente {
  static const otimo = 'Ótimo';
  static const regular = 'Regular';
  static const atencao = 'Atenção';
  static const naoRecomendado = 'Não recomendado';
  static const semApoliceVigente = 'Sem apólice vigente';
  static const apoliceSemValor = 'Apólice sem valor';

  static String rotuloPorUso(double usoGatilho) {
    if (usoGatilho < 60) return otimo;
    if (usoGatilho < 80) return regular;
    if (usoGatilho <= 100) return atencao;
    return naoRecomendado;
  }

  /// Sinistro grava "Vidas"; apólice grava "Vida".
  static String _ramo(String r) {
    final t = r.trim();
    return t == 'Vidas' ? 'Vida' : t;
  }

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool vigente(ApoliceParaRecomendacao a, DateTime hoje) {
    final h = _dia(hoje);
    return !h.isBefore(_dia(a.inicio)) && !h.isAfter(_dia(a.fim));
  }

  static ResultadoRecomendacao calcular({
    required List<ApoliceParaRecomendacao> apolices,
    required List<SinistroParaRecomendacao> sinistros,
    required double percentualGatilho,
    DateTime? hoje,
  }) {
    final agora = hoje ?? DateTime.now();
    final vigentes = apolices.where((a) => vigente(a, agora)).toList();
    if (vigentes.isEmpty) return const ResultadoRecomendacao(rotulo: semApoliceVigente);

    double gatilhoDe(ApoliceParaRecomendacao a) => GatilhoApolice.efetivo(
          valorApolice: a.valorApolice,
          valorGatilho: a.valorGatilho,
          percentual: percentualGatilho,
        );
    final comValor = vigentes.where((a) => gatilhoDe(a) > 0).toList();
    if (comValor.isEmpty) return const ResultadoRecomendacao(rotulo: apoliceSemValor);

    bool contaNa(ApoliceParaRecomendacao a, SinistroParaRecomendacao s) => GatilhoApolice.sinistroConta(
          dataOcorrencia: s.dataOcorrencia,
          status: s.status,
          inicioVigencia: a.inicio,
          fimVigencia: a.fim,
        );

    // Atribui cada sinistro a no máximo UMA apólice (sem contar em dobro).
    final idsDoCliente = apolices.map((a) => a.id).toSet();
    final gastoPorApolice = <String, double>{};
    for (final s in sinistros) {
      ApoliceParaRecomendacao? alvo;
      final id = s.apoliceId;
      if (id != null && id.isNotEmpty && idsDoCliente.contains(id)) {
        alvo = apolices.firstWhere((a) => a.id == id);
      } else {
        // Sem vínculo: mesmo ramo + vigência cobrindo a data (a mais recente primeiro).
        final candidatas = apolices
            .where((a) => _ramo(a.ramo) == _ramo(s.ramo) && contaNa(a, s))
            .toList()
          ..sort((x, y) => y.inicio.compareTo(x.inicio));
        if (candidatas.isNotEmpty) alvo = candidatas.first;
      }
      if (alvo == null || !contaNa(alvo, s)) continue;
      gastoPorApolice[alvo.id] = (gastoPorApolice[alvo.id] ?? 0) + s.valor;
    }

    ResultadoRecomendacao? pior;
    for (final a in comValor) {
      final r = ResultadoRecomendacao(
        rotulo: '',
        apoliceNumero: a.numero,
        apoliceRamo: a.ramo,
        gasto: gastoPorApolice[a.id] ?? 0,
        gatilho: gatilhoDe(a),
        valorApolice: a.valorApolice,
      );
      if (pior == null || r.usoGatilho > pior.usoGatilho) pior = r;
    }
    final p = pior!;
    return ResultadoRecomendacao(
      rotulo: rotuloPorUso(p.usoGatilho),
      apoliceNumero: p.apoliceNumero,
      apoliceRamo: p.apoliceRamo,
      gasto: p.gasto,
      gatilho: p.gatilho,
      valorApolice: p.valorApolice,
    );
  }
}
