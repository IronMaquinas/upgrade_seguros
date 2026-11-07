// Testes do filtro de status das listas (Etapa 05).
// Rodar no Mac: flutter test test/filtro_status_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/filtro_status.dart';

void main() {
  group('Em curso (padrão)', () {
    test('mostra os status de trabalho, inclusive Rascunho', () {
      for (final s in [
        'Rascunho',
        'Aberto',
        'Vistoria em Andamento',
        'Aguardando Aprovação',
        'Aguardando Peças',
        'Reparo em Andamento',
        'Em Andamento',
        'Aguardando Cliente',
      ]) {
        expect(FiltroStatus.corresponde(null, s), true);
        expect(FiltroStatus.corresponde(FiltroStatus.emCurso, s), true);
      }
    });

    test('esconde Concluído, Cancelado e Negado', () {
      for (final s in ['Concluído', 'Cancelado', 'Negado']) {
        expect(FiltroStatus.corresponde(null, s), false);
      }
    });
  });

  test('Todos mostra todos mesmo', () {
    for (final s in ['Rascunho', 'Aberto', 'Concluído', 'Cancelado', 'Negado', 'Qualquer']) {
      expect(FiltroStatus.corresponde(FiltroStatus.todos, s), true);
    }
  });

  test('status específico mostra só ele', () {
    expect(FiltroStatus.corresponde('Concluído', 'Concluído'), true);
    expect(FiltroStatus.corresponde('Concluído', 'Aberto'), false);
    expect(FiltroStatus.corresponde('Aberto', 'Aberto'), true);
  });

  test('histórico só é baixado quando o filtro pede', () {
    expect(FiltroStatus.precisaHistorico(null), false);
    expect(FiltroStatus.precisaHistorico(FiltroStatus.emCurso), false);
    expect(FiltroStatus.precisaHistorico('Aberto'), false);
    expect(FiltroStatus.precisaHistorico(FiltroStatus.todos), true);
    expect(FiltroStatus.precisaHistorico('Concluído'), true);
    expect(FiltroStatus.precisaHistorico('Cancelado'), true);
  });
}
