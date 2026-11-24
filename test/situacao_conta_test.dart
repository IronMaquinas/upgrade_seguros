// test/situacao_conta_test.dart — Etapa 25: teste grátis e só leitura
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/situacao_conta.dart';

void main() {
  final agora = DateTime(2026, 11, 24, 15);

  test('teste vencido conta como encerrado', () {
    expect(SituacaoConta.efetiva('teste', DateTime(2026, 11, 24, 14), agora: agora), 'teste_encerrado');
    expect(SituacaoConta.efetiva('teste', DateTime(2026, 11, 30), agora: agora), 'teste');
    expect(SituacaoConta.efetiva('teste', null, agora: agora), 'teste');
    expect(SituacaoConta.efetiva('', null, agora: agora), 'ativa');
    expect(SituacaoConta.efetiva('suspensa', null, agora: agora), 'suspensa');
  });

  test('só leitura: encerrado, suspensa, cancelada (inadimplente ainda grava)', () {
    expect(SituacaoConta.somenteLeitura('teste_encerrado'), true);
    expect(SituacaoConta.somenteLeitura('suspensa'), true);
    expect(SituacaoConta.somenteLeitura('cancelada'), true);
    expect(SituacaoConta.somenteLeitura('inadimplente'), false);
    expect(SituacaoConta.somenteLeitura('teste'), false);
    expect(SituacaoConta.somenteLeitura('ativa'), false);
  });

  test('dias que faltam e avisos', () {
    expect(SituacaoConta.diasRestantes(DateTime(2026, 12, 8, 23, 59), agora: agora), 14); // aprovado hoje com 14 dias
    expect(SituacaoConta.diasRestantes(DateTime(2026, 11, 24, 23, 59), agora: agora), 0);
    expect(SituacaoConta.diasRestantes(DateTime(2026, 11, 24, 10), agora: agora), 0);
    expect(SituacaoConta.aviso('teste', DateTime(2026, 11, 26, 23, 59), agora: agora), 'Teste grátis: faltam 2 dias.');
    expect(SituacaoConta.aviso('teste', DateTime(2026, 11, 25, 23, 59), agora: agora), 'Teste grátis: termina amanhã.');
    expect(SituacaoConta.aviso('teste', DateTime(2026, 11, 24, 23, 59), agora: agora), 'Teste grátis: hoje é o último dia.');
    expect(SituacaoConta.aviso('teste_encerrado', null, agora: agora).contains('só leitura'), true);
    expect(SituacaoConta.aviso('ativa', null, agora: agora), '');
  });
}
