// Testes do histórico de valores do sinistro (Etapa 02).
// Rodar no Mac: flutter test test/lancamento_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/models/lancamento_model.dart';

LancamentoSinistro _l({
  required String id,
  required double valor,
  String beneficiario = BeneficiarioLancamento.segurado,
  String? terceiroId,
  DateTime? data,
  DateTime? registradoEm,
}) {
  return LancamentoSinistro(
    id: id,
    data: data ?? DateTime(2026, 10, 10),
    tipo: TiposLancamento.reparo,
    valor: valor,
    beneficiario: beneficiario,
    terceiroId: terceiroId,
    terceiroNome: terceiroId == null ? null : 'Fulano',
    registradoPor: 'Ana',
    registradoEm: registradoEm ?? DateTime(2026, 10, 11),
  );
}

void main() {
  group('ResumoValores', () {
    test('soma segurado e terceiros e ignora cancelados', () {
      final lista = [
        _l(id: 'a', valor: 1000.10),
        _l(id: 'b', valor: 250.20, beneficiario: BeneficiarioLancamento.terceiro, terceiroId: 't1'),
        _l(id: 'c', valor: 99.99, beneficiario: BeneficiarioLancamento.terceiro, terceiroId: 't2'),
        _l(id: 'd', valor: 500).cancelar(motivo: 'valor errado', por: 'Ana'),
        _l(id: 'e', valor: 0.70, beneficiario: BeneficiarioLancamento.terceiro, terceiroId: 't1'),
      ];
      final r = ResumoValores.calcular(lista);
      expect(r.segurado, 1000.10);
      expect(r.terceiros, 350.89);
      expect(r.total, 1350.99);
      expect(r.porTerceiro['t1'], 250.90);
      expect(r.porTerceiro['t2'], 99.99);
      expect(r.ativos, 4);
      expect(r.cancelados, 1);
    });

    test('lista vazia dá zero', () {
      final r = ResumoValores.calcular(const []);
      expect(r.total, 0.0);
      expect(r.ativos, 0);
    });

    test('arredonda centavos (0,1 + 0,2)', () {
      final r = ResumoValores.calcular([_l(id: 'a', valor: 0.1), _l(id: 'b', valor: 0.2)]);
      expect(r.total, 0.3);
    });
  });

  group('cancelar', () {
    test('marca como cancelado sem alterar o original', () {
      final original = _l(id: 'a', valor: 10);
      final cancelado = original.cancelar(motivo: '  digitado duas vezes ', por: 'Bia', porEmail: 'bia@x.com');
      expect(original.cancelado, false);
      expect(cancelado.cancelado, true);
      expect(cancelado.motivoCancelamento, 'digitado duas vezes');
      expect(cancelado.canceladoPor, 'Bia');
      expect(cancelado.valor, 10.0);
      expect(cancelado.id, 'a');
      expect(cancelado.canceladoEm != null, true);
    });
  });

  group('toMap / fromMap', () {
    test('ida e volta preserva os dados', () {
      final l = LancamentoSinistro(
        id: 'x1',
        data: DateTime(2026, 10, 15),
        tipo: TiposLancamento.pecas,
        descricao: 'Para-choque',
        valor: 1200.5,
        beneficiario: BeneficiarioLancamento.terceiro,
        terceiroId: 't9',
        terceiroNome: 'Maria',
        anexos: const [AnexoLancamento(nome: 'nf-123.pdf', url: 'https://x/nf-123.pdf')],
        registradoPor: 'Ana',
        registradoPorEmail: 'ana@x.com',
        registradoEm: DateTime(2026, 10, 16, 9, 30),
      ).cancelar(motivo: 'NF errada', por: 'Ana', em: DateTime(2026, 10, 17));
      final volta = LancamentoSinistro.fromMap(l.toMap());
      expect(volta.id, 'x1');
      expect(volta.data, DateTime(2026, 10, 15));
      expect(volta.tipo, TiposLancamento.pecas);
      expect(volta.descricao, 'Para-choque');
      expect(volta.valor, 1200.5);
      expect(volta.isTerceiro, true);
      expect(volta.terceiroId, 't9');
      expect(volta.beneficiarioLabel, 'Terceiro — Maria');
      expect(volta.anexos.length, 1);
      expect(volta.anexos.first.nome, 'nf-123.pdf');
      expect(volta.registradoEm, DateTime(2026, 10, 16, 9, 30));
      expect(volta.cancelado, true);
      expect(volta.motivoCancelamento, 'NF errada');
      expect(volta.canceladoEm, DateTime(2026, 10, 17));
    });

    test('codificarData é aplicado a todas as datas', () {
      final m = _l(id: 'a', valor: 1).cancelar(motivo: 'm', por: 'p').toMap(codificarData: (d) => 'D:${d.year}');
      expect(m['data'], 'D:2026');
      expect(m['registrado_em'], 'D:2026');
      expect(m['cancelado_em'].toString().startsWith('D:'), true);
    });

    test('lê dados incompletos ou antigos sem quebrar', () {
      final l = LancamentoSinistro.fromMap({
        'valor': '35,90',
        'anexos': ['https://firebasestorage.googleapis.com/v0/b/x/o/sinistros%2FS1%2Fnota%20fiscal.pdf?alt=media'],
        'data': 1760054400000,
      });
      expect(l.valor, 35.90);
      expect(l.isTerceiro, false);
      expect(l.tipo, TiposLancamento.outro);
      expect(l.anexos.first.nome, 'nota fiscal.pdf');
      expect(l.data, DateTime.fromMillisecondsSinceEpoch(1760054400000));
      expect(l.cancelado, false);
    });

    test('listaDoMapa ignora o que não é mapa', () {
      final lista = LancamentoSinistro.listaDoMapa([
        {'id': 'a', 'valor': 1},
        'lixo',
        null,
        {'id': 'b', 'valor': 2},
      ]);
      expect(lista.length, 2);
      expect(LancamentoSinistro.listaDoMapa(null).length, 0);
    });
  });

  group('validar', () {
    test('exige valor, tipo, data e terceiro', () {
      final hoje = DateTime(2026, 11, 7);
      expect(LancamentoSinistro.validar(valor: 0, tipo: 'Reparo', beneficiario: 'segurado', data: hoje),
          'Informe um valor maior que zero.');
      expect(LancamentoSinistro.validar(valor: 10, tipo: '', beneficiario: 'segurado', data: hoje),
          'Escolha o tipo do lançamento.');
      expect(LancamentoSinistro.validar(valor: 10, tipo: 'Reparo', beneficiario: 'segurado'), 'Informe a data.');
      expect(LancamentoSinistro.validar(valor: 10, tipo: 'Reparo', beneficiario: 'terceiro', data: hoje),
          'Escolha o terceiro.');
      expect(LancamentoSinistro.validar(valor: 10, tipo: 'Reparo', beneficiario: 'terceiro', terceiroId: 't', data: hoje),
          null);
    });
  });

  group('ordenar', () {
    test('por data do evento e depois por registro', () {
      final lista = LancamentoSinistro.ordenar([
        _l(id: 'c', valor: 1, data: DateTime(2026, 10, 20)),
        _l(id: 'b', valor: 1, data: DateTime(2026, 10, 10), registradoEm: DateTime(2026, 10, 12)),
        _l(id: 'a', valor: 1, data: DateTime(2026, 10, 10), registradoEm: DateTime(2026, 10, 11)),
      ]);
      expect(lista.map((l) => l.id).join(), 'abc');
    });
  });

  test('novoId gera ids diferentes', () {
    final ids = List.generate(50, (_) => LancamentoSinistro.novoId()).toSet();
    expect(ids.length, 50);
  });
}
