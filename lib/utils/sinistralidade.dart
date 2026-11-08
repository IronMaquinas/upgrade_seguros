// lib/utils/sinistralidade.dart
//
// Etapa 11: sinistralidade mensal e acumulada do ano (Relatórios → gráfico
// "Sinistralidade Mensal"). Dart puro, testado em test/sinistralidade_test.dart.
//
// Antes: sinistros do mês ÷ SOMA ANUAL das apólices vigentes HOJE. Comparava um
// mês de sinistros com um ano inteiro de apólice (dá ~1/12 do real) e o
// denominador ainda carregava os valores inflados (ex.: R$ 10 bi) — por isso o
// gráfico ficava colado no zero.
//
// Agora (o padrão de mercado, "sinistralidade = sinistros ÷ prêmio ganho"):
//  • Prêmio ganho no mês = para cada apólice, valor da apólice × (dias de
//    vigência dentro do mês ÷ dias totais da vigência). Uma apólice anual de
//    R$ 120.000 "ganha" ~R$ 10.000 por mês enquanto está vigente.
//  • Sinistros do mês = valor total dos sinistros OCORRIDOS no mês, sem
//    Cancelado/Negado (mesma regra do gatilho).
//  • Mensal = sinistros do mês ÷ prêmio ganho no mês.
//  • Acumulado no ano = sinistros de janeiro até o mês ÷ prêmio ganho de
//    janeiro até o mês. É o número comparável ao gatilho (70%).
//  • Meses futuros ficam sem valor (não aparecem no gráfico).

class ApoliceSinistralidade {
  final DateTime inicio;
  final DateTime fim;
  final double valor;
  const ApoliceSinistralidade({required this.inicio, required this.fim, required this.valor});
}

class SinistroSinistralidade {
  final DateTime dataOcorrencia;
  final String status;
  final double valor;
  const SinistroSinistralidade({required this.dataOcorrencia, required this.status, required this.valor});
}

class MesSinistralidade {
  final int mes;
  final double sinistros;
  final double premioGanho;
  final double sinistrosAcumulados;
  final double premioAcumulado;
  const MesSinistralidade({
    required this.mes,
    required this.sinistros,
    required this.premioGanho,
    required this.sinistrosAcumulados,
    required this.premioAcumulado,
  });

  double? get mensal => premioGanho > 0 ? sinistros / premioGanho * 100 : null;
  double? get acumulado => premioAcumulado > 0 ? sinistrosAcumulados / premioAcumulado * 100 : null;
}

class Sinistralidade {
  static const statusQueNaoContam = {'Cancelado', 'Negado'};

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Dias entre [a] e [b], contando os dois (datas sem hora; usa UTC para não
  /// errar na troca de horário de verão).
  static int _dias(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays + 1;

  /// Parte do valor da apólice "ganha" entre [de] e [ate] (inclusive).
  static double premioGanho(ApoliceSinistralidade a, DateTime de, DateTime ate) {
    if (a.valor <= 0) return 0;
    final ini = _dia(a.inicio), fim = _dia(a.fim);
    if (fim.isBefore(ini)) return 0;
    final x = _dia(de).isAfter(ini) ? _dia(de) : ini;
    final y = _dia(ate).isBefore(fim) ? _dia(ate) : fim;
    if (y.isBefore(x)) return 0;
    return a.valor * _dias(x, y) / _dias(ini, fim);
  }

  /// Os meses de [ano] até o mês de [hoje] (ou os 12, se o ano já passou).
  static List<MesSinistralidade> doAno({
    required int ano,
    required List<ApoliceSinistralidade> apolices,
    required List<SinistroSinistralidade> sinistros,
    DateTime? hoje,
  }) {
    final agora = hoje ?? DateTime.now();
    if (ano > agora.year) return const [];
    final ultimoMes = ano < agora.year ? 12 : agora.month;

    final resultado = <MesSinistralidade>[];
    double accSin = 0, accPremio = 0;
    for (var m = 1; m <= ultimoMes; m++) {
      final de = DateTime(ano, m, 1);
      final ate = DateTime(ano, m + 1, 0); // último dia do mês
      final premio = apolices.fold<double>(0, (s, a) => s + premioGanho(a, de, ate));
      final sin = sinistros
          .where((s) =>
              !statusQueNaoContam.contains(s.status) &&
              s.dataOcorrencia.year == ano &&
              s.dataOcorrencia.month == m)
          .fold<double>(0, (t, s) => t + s.valor);
      accSin += sin;
      accPremio += premio;
      resultado.add(MesSinistralidade(
        mes: m,
        sinistros: sin,
        premioGanho: premio,
        sinistrosAcumulados: accSin,
        premioAcumulado: accPremio,
      ));
    }
    return resultado;
  }
}
