// Testes das regras de tarefas (Etapa 10).
// Rodar no Mac: flutter test test/tarefas_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/tarefas.dart';

final agora = DateTime(2026, 11, 8, 14, 0);

TarefaResumo tarefa({
  String status = 'Aberta',
  DateTime? prazo,
  DateTime? criadoEm,
  DateTime? concluidaEm,
  String id = '',
  String email = '',
}) =>
    TarefaResumo(
      status: status,
      prazo: prazo,
      criadoEm: criadoEm,
      concluidaEm: concluidaEm,
      responsavelId: id,
      responsavelEmail: email,
      descricao: 'Ligar para o cliente',
      numeroAtendimento: 'S-1',
      clienteNome: 'MAIS ALIMENTOS',
    );

const funcionarios = [
  Funcionario(id: 'u1', nome: 'Marcony', email: 'marcony@up.com'),
  Funcionario(id: 'u2', nome: 'Ana', email: 'ana@up.com'),
];

void main() {
  group('Situação do prazo', () {
    test('aberta com prazo hoje ainda está no prazo (vale até o fim do dia)', () {
      expect(Tarefas.situacaoPrazo(tarefa(prazo: DateTime(2026, 11, 8)), agora: agora), 'No prazo');
    });
    test('aberta com prazo ontem está fora do prazo', () {
      expect(Tarefas.situacaoPrazo(tarefa(prazo: DateTime(2026, 11, 7)), agora: agora), 'Fora do prazo');
    });
    test('concluída no dia do prazo = no prazo', () {
      final t = tarefa(status: 'Concluída', prazo: DateTime(2026, 11, 5), concluidaEm: DateTime(2026, 11, 5, 22));
      expect(Tarefas.situacaoPrazo(t, agora: agora), 'No prazo');
    });
    test('concluída depois do prazo = fora do prazo (mesmo que hoje já esteja concluída)', () {
      final t = tarefa(status: 'Concluída', prazo: DateTime(2026, 11, 5), concluidaEm: DateTime(2026, 11, 6, 9));
      expect(Tarefas.situacaoPrazo(t, agora: agora), 'Fora do prazo');
    });
    test('concluída antes da Etapa 10 (sem data de conclusão)', () {
      final t = tarefa(status: 'Concluída', prazo: DateTime(2026, 1, 5));
      expect(Tarefas.situacaoPrazo(t, agora: agora), 'Sem data de conclusão');
    });
    test('sem prazo', () => expect(Tarefas.situacaoPrazo(tarefa(), agora: agora), 'Sem prazo'));
  });

  group('Ordenação', () {
    final a = tarefa(criadoEm: DateTime(2026, 1, 1));
    final b = tarefa(criadoEm: DateTime(2026, 6, 1));
    final c = tarefa(prazo: DateTime(2026, 3, 1)); // sem criação: usa o prazo
    final d = tarefa(); // sem data nenhuma: fim
    test('mais antiga primeiro', () {
      expect(Tarefas.ordenar([b, d, c, a], maisRecentePrimeiro: false), [a, c, b, d]);
    });
    test('mais recente primeiro', () {
      expect(Tarefas.ordenar([a, d, c, b], maisRecentePrimeiro: true), [b, c, a, d]);
    });
  });

  group('Por funcionário', () {
    final tarefas = [
      tarefa(id: 'u1', status: 'Concluída', prazo: DateTime(2026, 11, 1), concluidaEm: DateTime(2026, 10, 30)),
      tarefa(id: 'u1', status: 'Concluída', prazo: DateTime(2026, 11, 1), concluidaEm: DateTime(2026, 11, 3)),
      tarefa(id: 'u1', status: 'Concluída', prazo: DateTime(2026, 11, 1)), // sem data
      tarefa(id: 'u1', status: 'Concluída', prazo: DateTime(2026, 11, 1), concluidaEm: DateTime(2026, 11, 1)),
      tarefa(email: 'MARCONY@up.com', status: 'Aberta', prazo: DateTime(2026, 11, 7)), // atrasada, casa pelo e-mail
      tarefa(id: 'u2', status: 'Pendente', prazo: DateTime(2026, 12, 1)),
      tarefa(email: 'ex@fora.com', status: 'Aberta', prazo: DateTime(2026, 12, 1)),
      tarefa(status: 'Aberta', prazo: DateTime(2026, 12, 1)),
    ];
    final grupos = Tarefas.porFuncionario(tarefas, funcionarios);

    test('agrupa por id ou e-mail; quem tem mais primeiro; sem responsável no fim', () {
      expect(grupos.map((g) => g.nome).toList(), ['Marcony', 'Ana', 'ex@fora.com', 'Sem responsável']);
    });

    test('Marcony: 5 tarefas, 1 aberta, 80% encerradas', () {
      final m = grupos.first;
      expect(m.total, 5);
      expect(m.abertas, 1);
      expect(m.concluidas, 4);
      expect(m.percentualConcluidas, closeTo(80, 0.001));
    });

    test('Marcony: no prazo 2, fora 2 (1 concluída atrasada + 1 aberta atrasada), 1 sem data', () {
      final m = grupos.first;
      expect(m.noPrazo(agora), 2);
      expect(m.foraDoPrazo(agora), 2);
      expect(m.semData(agora), 1);
      expect(m.percentualNoPrazo(agora), closeTo(50, 0.001));
    });
  });

  test('CSV agrupado com subtotal por funcionário', () {
    final grupos = Tarefas.porFuncionario([
      tarefa(id: 'u2', status: 'Concluída', prazo: DateTime(2026, 11, 1), concluidaEm: DateTime(2026, 10, 31), criadoEm: DateTime(2026, 10, 20)),
    ], funcionarios);
    final linhas = Tarefas.paraCsv(grupos, maisRecentePrimeiro: true, agora: agora).split('\r\n');
    expect(linhas[0].startsWith('﻿Funcionário;E-mail do funcionário;Atendimento;'), isTrue);
    expect(linhas[1], 'Ana;ana@up.com;S-1;MAIS ALIMENTOS;Ligar para o cliente;Concluída;20/10/2026;01/11/2026;31/10/2026;No prazo');
    expect(linhas[2].startsWith('SUBTOTAL Ana;;1 tarefas;0 abertas;1 concluídas (100%)'), isTrue);
  });
}
