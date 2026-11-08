// Testes da recomendação do cliente (Etapa 09).
// Rodar no Mac: flutter test test/recomendacao_cliente_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/recomendacao_cliente.dart';

final hoje = DateTime(2026, 11, 8);

ApoliceParaRecomendacao apolice({
  String id = 'A1',
  String ramo = 'Frota',
  DateTime? inicio,
  DateTime? fim,
  double valor = 100000,
  double gatilho = 0,
}) =>
    ApoliceParaRecomendacao(
      id: id,
      numero: 'N-$id',
      ramo: ramo,
      inicio: inicio ?? DateTime(2026, 4, 19),
      fim: fim ?? DateTime(2027, 4, 19),
      valorApolice: valor,
      valorGatilho: gatilho,
    );

SinistroParaRecomendacao sinistro(
  double valor, {
  String? apoliceId = 'A1',
  String ramo = 'Frota',
  DateTime? data,
  String status = 'Aberto',
}) =>
    SinistroParaRecomendacao(
      apoliceId: apoliceId,
      ramo: ramo,
      dataOcorrencia: data ?? DateTime(2026, 6, 1),
      status: status,
      valor: valor,
    );

ResultadoRecomendacao calc(List<ApoliceParaRecomendacao> a, List<SinistroParaRecomendacao> s) =>
    RecomendacaoCliente.calcular(apolices: a, sinistros: s, percentualGatilho: 70, hoje: hoje);

void main() {
  group('Sem apólice', () {
    test('apólice vencida → Sem apólice vigente (mesmo com 0 sinistros)', () {
      final r = calc([apolice(inicio: DateTime(2025, 9, 24), fim: DateTime(2026, 9, 24))], []);
      expect(r.rotulo, RecomendacaoCliente.semApoliceVigente);
    });

    test('apólice que começa no futuro também não vale', () {
      final r = calc([apolice(inicio: DateTime(2026, 11, 27), fim: DateTime(2027, 11, 27))], []);
      expect(r.rotulo, RecomendacaoCliente.semApoliceVigente);
    });

    test('vigente sem valor e sem gatilho → Apólice sem valor', () {
      final r = calc([apolice(valor: 0, gatilho: 0.01)], []);
      expect(r.rotulo, RecomendacaoCliente.apoliceSemValor);
    });

    test('último dia da vigência ainda vale', () {
      final r = calc([apolice(fim: hoje)], []);
      expect(r.rotulo, RecomendacaoCliente.otimo);
    });
  });

  group('Faixas pelo uso do gatilho (70% de R\$ 100.000 = R\$ 70.000)', () {
    test('< 60% Ótimo', () => expect(calc([apolice()], [sinistro(41000)]).rotulo, 'Ótimo'));
    test('60% Regular', () => expect(calc([apolice()], [sinistro(42000)]).rotulo, 'Regular'));
    test('80% Atenção', () => expect(calc([apolice()], [sinistro(56000)]).rotulo, 'Atenção'));
    test('100% ainda Atenção', () => expect(calc([apolice()], [sinistro(70000)]).rotulo, 'Atenção'));
    test('> 100% Não recomendado', () => expect(calc([apolice()], [sinistro(70001)]).rotulo, 'Não recomendado'));

    test('gatilho do contrato vale no lugar do %', () {
      final r = calc([apolice(gatilho: 20000)], [sinistro(15000)]);
      expect(r.usoGatilho, closeTo(75, 0.001));
      expect(r.rotulo, 'Regular');
    });
  });

  group('Acima do gatilho × acima da apólice', () {
    test('passou do gatilho, não da apólice', () {
      final r = calc([apolice()], [sinistro(90000)]);
      expect(r.rotulo, 'Não recomendado');
      expect(r.acimaDoValorDaApolice, false);
      expect(r.explicacao.endsWith('acima do gatilho'), true);
    });

    test('passou do valor da apólice', () {
      final r = calc([apolice()], [sinistro(198000)]);
      expect(r.rotulo, 'Não recomendado');
      expect(r.acimaDoValorDaApolice, true);
      expect(r.usoApolice, closeTo(198, 0.001));
      expect(r.explicacao.endsWith('acima do valor da apólice'), true);
    });
  });

  group('Quais sinistros contam', () {
    test('cancelado, negado e fora da vigência não contam', () {
      final r = calc([apolice()], [
        sinistro(10000),
        sinistro(99999, status: 'Cancelado'),
        sinistro(99999, status: 'Negado'),
        sinistro(99999, data: DateTime(2025, 1, 1)),
      ]);
      expect(r.gasto, 10000);
    });

    test('sem vínculo entra pela apólice do mesmo ramo e vigência', () {
      final r = calc([apolice()], [sinistro(50000, apoliceId: null)]);
      expect(r.gasto, 50000);
    });

    test('sem vínculo de outro ramo não entra', () {
      final r = calc([apolice()], [sinistro(50000, apoliceId: '', ramo: 'Residencial')]);
      expect(r.gasto, 0);
    });

    test('vínculo com apólice que não existe mais cai na regra do ramo', () {
      final r = calc([apolice()], [sinistro(50000, apoliceId: 'APAGADA')]);
      expect(r.gasto, 50000);
    });

    test('"Vidas" do sinistro casa com "Vida" da apólice', () {
      final r = calc([apolice(ramo: 'Vida')], [sinistro(1000, apoliceId: null, ramo: 'Vidas')]);
      expect(r.gasto, 1000);
    });

    test('renovação: sinistro sem vínculo vai só para a apólice cuja vigência cobre a data', () {
      final antiga = apolice(id: 'OLD', inicio: DateTime(2025, 4, 19), fim: DateTime(2026, 4, 18));
      final atual = apolice(id: 'NEW');
      final r = calc([antiga, atual], [
        sinistro(30000, apoliceId: null, data: DateTime(2026, 1, 10)), // da antiga (vencida)
        sinistro(5000, apoliceId: null, data: DateTime(2026, 8, 10)),
      ]);
      expect(r.gasto, 5000);
      expect(r.apoliceNumero, 'N-NEW');
    });
  });

  test('vale a pior apólice do cliente', () {
    final r = calc([
      apolice(id: 'F', ramo: 'Frota'),
      apolice(id: 'R', ramo: 'Residencial', valor: 10000),
    ], [
      sinistro(10000, apoliceId: 'F'), // 14%
      sinistro(6000, apoliceId: 'R'), // 86%
    ]);
    expect(r.rotulo, 'Atenção');
    expect(r.apoliceRamo, 'Residencial');
  });
}
