// Testes da sinistralidade mensal e acumulada (Etapa 11).
// Rodar no Mac: flutter test test/sinistralidade_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/sinistralidade.dart';

void main() {
  // Apólice anual de 2026 inteira (365 dias) de R$ 365.000 → R$ 1.000/dia.
  final anual = ApoliceSinistralidade(inicio: DateTime(2026, 1, 1), fim: DateTime(2026, 12, 31), valor: 365000);

  group('Prêmio ganho', () {
    test('janeiro = 31 dias de R\$ 1.000', () {
      expect(Sinistralidade.premioGanho(anual, DateTime(2026, 1, 1), DateTime(2026, 1, 31)), closeTo(31000, 0.01));
    });
    test('apólice que começa no meio do mês ganha só os dias vigentes', () {
      final a = ApoliceSinistralidade(inicio: DateTime(2026, 4, 19), fim: DateTime(2027, 4, 18), valor: 365000);
      expect(Sinistralidade.premioGanho(a, DateTime(2026, 4, 1), DateTime(2026, 4, 30)), closeTo(12000, 0.01));
    });
    test('fora da vigência não ganha nada; valor zero também não', () {
      expect(Sinistralidade.premioGanho(anual, DateTime(2027, 1, 1), DateTime(2027, 1, 31)), 0);
      final zero = ApoliceSinistralidade(inicio: DateTime(2026, 1, 1), fim: DateTime(2026, 12, 31), valor: 0);
      expect(Sinistralidade.premioGanho(zero, DateTime(2026, 1, 1), DateTime(2026, 1, 31)), 0);
    });
  });

  group('Mensal e acumulado', () {
    final meses = Sinistralidade.doAno(
      ano: 2026,
      hoje: DateTime(2026, 3, 15),
      apolices: [anual],
      sinistros: [
        SinistroSinistralidade(dataOcorrencia: DateTime(2026, 1, 10), status: 'Concluído', valor: 15500),
        SinistroSinistralidade(dataOcorrencia: DateTime(2026, 2, 5), status: 'Aberto', valor: 28000),
        SinistroSinistralidade(dataOcorrencia: DateTime(2026, 2, 6), status: 'Cancelado', valor: 99999),
        SinistroSinistralidade(dataOcorrencia: DateTime(2025, 12, 31), status: 'Aberto', valor: 99999),
      ],
    );

    test('só até o mês atual', () => expect(meses.length, 3));

    test('janeiro: 15.500 ÷ 31.000 = 50%', () {
      expect(meses[0].mensal, closeTo(50, 0.001));
      expect(meses[0].acumulado, closeTo(50, 0.001));
    });

    test('fevereiro: 28.000 ÷ 28.000 = 100%; cancelado não conta', () {
      expect(meses[1].mensal, closeTo(100, 0.001));
    });

    test('acumulado até fevereiro: 43.500 ÷ 59.000 ≈ 73,7%', () {
      expect(meses[1].acumulado, closeTo(43500 / 59000 * 100, 0.001));
    });

    test('março sem sinistro: mensal 0%, acumulado cai', () {
      expect(meses[2].mensal, 0);
      expect(meses[2].acumulado, closeTo(43500 / 90000 * 100, 0.001));
    });
  });

  test('sem apólice vigente no mês: sem valor (null), não 0', () {
    final meses = Sinistralidade.doAno(ano: 2026, hoje: DateTime(2026, 1, 20), apolices: const [], sinistros: const []);
    expect(meses.single.mensal, isNull);
  });

  test('ano passado mostra os 12 meses; ano futuro nenhum', () {
    expect(Sinistralidade.doAno(ano: 2025, hoje: DateTime(2026, 3, 1), apolices: [anual], sinistros: const []).length, 12);
    expect(Sinistralidade.doAno(ano: 2027, hoje: DateTime(2026, 3, 1), apolices: [anual], sinistros: const []), isEmpty);
  });
}
