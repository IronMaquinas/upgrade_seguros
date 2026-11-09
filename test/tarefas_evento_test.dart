// Testes das tarefas ligadas a sinistro/assistência (Etapa 14).
// Rodar no Mac: flutter test test/tarefas_evento_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/tarefas.dart';
import 'package:upgrade_seguros/utils/tarefas_evento.dart';

TarefaDoEvento t(String id, String claimId,
        {String descricao = 'Ligar para a oficina', String status = 'Aberta', String tipo = '', DateTime? criadoEm}) =>
    TarefaDoEvento(id: id, claimId: claimId, descricao: descricao, status: status, tipo: tipo, criadoEm: criadoEm);

void main() {
  final agora = DateTime(2026, 11, 9, 11);

  group('Contato com o cliente', () {
    test('reconhece pelo tipo novo e pela descrição antiga', () {
      expect(TarefasEvento.ehContatoCliente(t('1', 'c', tipo: 'contato_cliente', descricao: 'qualquer')), true);
      expect(TarefasEvento.ehContatoCliente(t('2', 'c', descricao: 'Informar status ao cliente: Aguardando Peças')), true);
      expect(TarefasEvento.ehContatoCliente(t('3', 'c', descricao: 'Atualizar cliente: Aberto (nova previsão)')), true);
      expect(TarefasEvento.ehContatoCliente(t('4', 'c', descricao: 'Agendamento para Fulano')), false);
    });

    test('nova comunicação substitui só os contatos abertos', () {
      final lista = [
        t('a', 'c', descricao: 'Informar status ao cliente: Aguardando Peças'),
        t('b', 'c', descricao: 'Informar status ao cliente: Aberto', status: 'Concluída'),
        t('c', 'c', descricao: 'Pedir orçamento'),
      ];
      expect(TarefasEvento.contatosASubstituir(lista).map((x) => x.id).toList(), ['a']);
    });
  });

  group('Limpeza', () {
    test('separa encerrados, excluídos e contatos repetidos', () {
      final tarefas = [
        t('1', 'fechado'), // sinistro Concluído
        t('2', 'cancelada'), // assistência Cancelada
        t('3', 'sumiu'), // atendimento excluído
        t('4', ''), // sem vínculo
        t('5', 'ativo', descricao: 'Informar status ao cliente: Aberto', criadoEm: DateTime(2026, 11, 1)),
        t('6', 'ativo', descricao: 'Informar status ao cliente: Aguardando Peças', criadoEm: DateTime(2026, 11, 5)),
        t('7', 'ativo', descricao: 'Atualizar cliente: Aguardando Peças (nova previsão)', criadoEm: DateTime(2026, 11, 8)),
        t('8', 'ativo'), // manual, atendimento em curso → fica
        t('9', 'fechado', status: 'Concluída'), // já concluída → ignora
      ];
      final status = {'fechado': 'Concluído', 'cancelada': 'Cancelado', 'ativo': 'Aguardando Peças'};
      final plano = TarefasEvento.planoLimpeza(tarefas, status, agora: agora);
      final porId = {for (final i in plano) i.tarefa.id: i};

      expect(porId.keys.toList()..sort(), ['1', '2', '3', '4', '5', '6']);
      expect(porId['1']!.categoria, TarefasEvento.eventoFinalizado);
      expect(porId['1']!.motivo.contains('Concluído'), true);
      expect(porId['2']!.categoria, TarefasEvento.eventoFinalizado);
      expect(porId['3']!.categoria, TarefasEvento.eventoInexistente);
      expect(porId['4']!.categoria, TarefasEvento.eventoInexistente);
      expect(porId['5']!.categoria, TarefasEvento.contatoRepetido);
      expect(porId['6']!.categoria, TarefasEvento.contatoRepetido);
      expect(porId['1']!.motivo.contains('09/11/2026'), true);

      final contagem = TarefasEvento.contarPorCategoria(plano);
      expect(contagem[TarefasEvento.eventoFinalizado], 2);
      expect(contagem[TarefasEvento.eventoInexistente], 2);
      expect(contagem[TarefasEvento.contatoRepetido], 2);
    });

    test('um contato só, em atendimento em curso, não entra', () {
      final plano = TarefasEvento.planoLimpeza(
        [t('1', 'ativo', descricao: 'Informar status ao cliente: Aberto')],
        {'ativo': 'Aberto'},
        agora: agora,
      );
      expect(plano, isEmpty);
    });

    test('Rascunho conta como em curso', () {
      final plano = TarefasEvento.planoLimpeza([t('1', 'r')], {'r': 'Rascunho'}, agora: agora);
      expect(plano, isEmpty);
    });
  });

  group('Prazo do funcionário', () {
    test('concluída pelo sistema não conta como atraso', () {
      final atrasadaPeloSistema = TarefaResumo(
        status: 'Concluída',
        prazo: DateTime(2026, 10, 1),
        concluidaEm: DateTime(2026, 11, 9),
        encerradaPeloSistema: true,
        responsavelEmail: 'a@x.com',
      );
      final atrasadaPelaPessoa = TarefaResumo(
        status: 'Concluída',
        prazo: DateTime(2026, 10, 1),
        concluidaEm: DateTime(2026, 11, 9),
        responsavelEmail: 'a@x.com',
      );
      expect(Tarefas.situacaoPrazo(atrasadaPeloSistema, agora: agora), Tarefas.encerradaPeloSistema);
      expect(Tarefas.situacaoPrazo(atrasadaPelaPessoa, agora: agora), Tarefas.foraDoPrazo);

      final g = Tarefas.porFuncionario([atrasadaPeloSistema, atrasadaPelaPessoa], const []).single;
      expect(g.concluidas, 2);
      expect(g.foraDoPrazo(agora), 1);
      expect(g.encerradasPeloSistema, 1);
      expect(g.percentualNoPrazo(agora), 0.0);
    });
  });

  test('motivos com data', () {
    expect(TarefasEvento.motivoEncerramento('sinistro', 'encerrar', agora), 'Concluída ao encerrar o sinistro em 09/11/2026');
    expect(TarefasEvento.motivoExclusao(agora), 'Atendimento excluído em 09/11/2026');
    expect(TarefasEvento.motivoSubstituida('previsão', agora), 'Substituída pela atualização de previsão em 09/11/2026');
  });
}
