// lib/utils/gatilho.dart
//
// Regra única do GATILHO da apólice (Etapa 07). Dart puro, testado em
// test/gatilho_test.dart.
//
// O gatilho é o valor de sinistros, dentro da vigência da apólice, a partir do
// qual o uso do seguro fica crítico (a corretora pode recomendar não acionar).
//
// • Se o contrato traz o valor, ele é informado na apólice ("informado").
// • Se não traz, vale o PERCENTUAL PADRÃO da corretora (Configurações,
//   70% se nada foi configurado) aplicado sobre o valor da apólice ("calculado").
// • Valores até R$ 0,01 contam como "não informado" (apólices antigas foram
//   gravadas com 0,00 ou 0,01 quando o campo ficava vazio).

class GatilhoApolice {
  /// Percentual usado quando a corretora ainda não configurou o dela.
  static const double percentualPadraoInicial = 70.0;

  /// Gatilho até este valor = não informado.
  static const double _minimoInformado = 0.01;

  /// Status de sinistro que NÃO consomem o gatilho.
  static const statusQueNaoContam = <String>{'Cancelado', 'Negado'};

  static double _arredondar(double v) => (v * 100).roundToDouble() / 100;

  /// Percentual válido (entre 1 e 100). Fora disso, volta ao padrão inicial.
  static double normalizarPercentual(num? p) {
    if (p == null || p.isNaN || p < 1 || p > 100) return percentualPadraoInicial;
    return p.toDouble();
  }

  static bool informado(double valorGatilho) => valorGatilho > _minimoInformado;

  /// Gatilho sugerido = percentual × valor da apólice.
  static double sugerido(double valorApolice, double percentual) {
    if (valorApolice <= 0) return 0.0;
    return _arredondar(valorApolice * normalizarPercentual(percentual) / 100);
  }

  /// Gatilho que vale para os cálculos: o informado ou, se não houver, o sugerido.
  static double efetivo({
    required double valorApolice,
    required double valorGatilho,
    required double percentual,
  }) {
    return informado(valorGatilho) ? valorGatilho : sugerido(valorApolice, percentual);
  }

  /// Quanto do gatilho já foi usado, em % (0 se não há gatilho).
  static double usoPercentual(double gasto, double gatilho) {
    if (gatilho <= 0) return 0.0;
    return gasto / gatilho * 100;
  }

  /// O sinistro consome o gatilho desta apólice? Precisa ter ocorrido dentro da
  /// vigência (dia final inclusive) e não estar cancelado/negado.
  static bool sinistroConta({
    required DateTime dataOcorrencia,
    required String status,
    required DateTime inicioVigencia,
    required DateTime fimVigencia,
  }) {
    if (statusQueNaoContam.contains(status.trim())) return false;
    final inicio = DateTime(inicioVigencia.year, inicioVigencia.month, inicioVigencia.day);
    final fimExclusivo = DateTime(fimVigencia.year, fimVigencia.month, fimVigencia.day).add(const Duration(days: 1));
    return !dataOcorrencia.isBefore(inicio) && dataOcorrencia.isBefore(fimExclusivo);
  }

  /// Lê um valor digitado em moeda ("R$ 1.234,56", com ou sem espaço especial).
  static double lerMoeda(String texto) {
    final limpo = texto.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
    return double.tryParse(limpo) ?? 0.0;
  }

  /// "70", "72,5" — para exibir o percentual.
  static String formatarPercentual(double p) {
    final s = p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
    return s.replaceAll('.', ',');
  }
}
