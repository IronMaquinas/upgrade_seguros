// Testes da regra do gatilho da apólice (Etapa 07).
// Rodar no Mac: flutter test test/gatilho_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/gatilho.dart';

void main() {
  group('efetivo', () {
    test('usa o gatilho informado no contrato', () {
      expect(GatilhoApolice.efetivo(valorApolice: 120000.10, valorGatilho: 50000, percentual: 70), 50000.0);
    });

    test('sem gatilho (0 ou 0,01) usa o percentual da corretora', () {
      expect(GatilhoApolice.efetivo(valorApolice: 120000.10, valorGatilho: 0.01, percentual: 70), 84000.07);
      expect(GatilhoApolice.efetivo(valorApolice: 1837.05, valorGatilho: 0, percentual: 70), 1285.94);
      expect(GatilhoApolice.efetivo(valorApolice: 1000, valorGatilho: 0, percentual: 80), 800.0);
    });

    test('sem valor da apólice e sem gatilho = 0', () {
      expect(GatilhoApolice.efetivo(valorApolice: 0, valorGatilho: 0, percentual: 70), 0.0);
    });
  });

  test('percentual inválido volta para 70', () {
    expect(GatilhoApolice.normalizarPercentual(null), 70.0);
    expect(GatilhoApolice.normalizarPercentual(0), 70.0);
    expect(GatilhoApolice.normalizarPercentual(150), 70.0);
    expect(GatilhoApolice.normalizarPercentual(65), 65.0);
    expect(GatilhoApolice.sugerido(1000, 0), 700.0);
  });

  test('uso do gatilho em %', () {
    expect(GatilhoApolice.usoPercentual(42000, 84000), 50.0);
    expect(GatilhoApolice.usoPercentual(100, 0), 0.0);
  });

  group('sinistroConta', () {
    final inicio = DateTime(2026, 4, 18);
    final fim = DateTime(2027, 4, 18);

    test('dentro da vigência, inclusive o primeiro e o último dia', () {
      expect(GatilhoApolice.sinistroConta(dataOcorrencia: DateTime(2026, 4, 18), status: 'Aberto', inicioVigencia: inicio, fimVigencia: fim), true);
      expect(GatilhoApolice.sinistroConta(dataOcorrencia: DateTime(2027, 4, 18, 23, 59), status: 'Concluído', inicioVigencia: inicio, fimVigencia: fim), true);
    });

    test('fora da vigência não conta', () {
      expect(GatilhoApolice.sinistroConta(dataOcorrencia: DateTime(2026, 4, 17), status: 'Aberto', inicioVigencia: inicio, fimVigencia: fim), false);
      expect(GatilhoApolice.sinistroConta(dataOcorrencia: DateTime(2027, 4, 19), status: 'Aberto', inicioVigencia: inicio, fimVigencia: fim), false);
    });

    test('cancelado e negado não contam', () {
      expect(GatilhoApolice.sinistroConta(dataOcorrencia: DateTime(2026, 6, 1), status: 'Cancelado', inicioVigencia: inicio, fimVigencia: fim), false);
      expect(GatilhoApolice.sinistroConta(dataOcorrencia: DateTime(2026, 6, 1), status: 'Negado', inicioVigencia: inicio, fimVigencia: fim), false);
    });
  });

  test('lerMoeda entende o formato brasileiro', () {
    expect(GatilhoApolice.lerMoeda('R\$ 120.000,10'), 120000.10);
    expect(GatilhoApolice.lerMoeda('R\$ 1.837,05'), 1837.05);
    expect(GatilhoApolice.lerMoeda(''), 0.0);
  });

  test('formatarPercentual', () {
    expect(GatilhoApolice.formatarPercentual(70), '70');
    expect(GatilhoApolice.formatarPercentual(72.5), '72,5');
  });
}
