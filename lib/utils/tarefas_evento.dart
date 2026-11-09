// lib/utils/tarefas_evento.dart
//
// Etapa 14: tarefas ligadas a um sinistro/assistência ("evento") — regras em
// Dart puro (testadas em test/tarefas_evento_test.dart). As gravações ficam em
// lib/services/tarefas_evento_service.dart.
//
// O que o sistema conclui sozinho (sempre com motivo e `conclusao_automatica`):
//  • Encerrar/cancelar o evento → o funcionário escolhe quais tarefas abertas
//    concluir (todas marcadas por padrão).
//  • Excluir o evento → todas as tarefas abertas dele ("Evento excluído").
//  • Nova comunicação de status/previsão do sinistro → as tarefas de contato
//    anteriores daquele sinistro ("Substituída…").
//  • Limpeza (Configurações, admin) → tarefas abertas de eventos já
//    finalizados, de eventos que não existem mais e contatos repetidos.

import 'filtro_status.dart';

/// Tarefa como vem do Firestore, só com o que as regras usam.
class TarefaDoEvento {
  final String id;
  final String claimId;
  final String descricao;
  final String status;
  final String tipo;
  final DateTime? prazo;
  final DateTime? criadoEm;

  const TarefaDoEvento({
    required this.id,
    required this.claimId,
    this.descricao = '',
    this.status = 'Aberta',
    this.tipo = '',
    this.prazo,
    this.criadoEm,
  });

  bool get aberta => status != TarefasEvento.concluida;

  factory TarefaDoEvento.fromMap(String id, Map<String, dynamic> m) {
    DateTime? data(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return (v as dynamic).toDate() as DateTime; // Timestamp do Firestore
      } catch (_) {
        return null;
      }
    }

    return TarefaDoEvento(
      id: id,
      claimId: (m['claimId'] as String?) ?? '',
      descricao: (m['descricao'] as String?) ?? '',
      status: (m['status'] as String?) ?? 'Pendente',
      tipo: (m['tipo'] as String?) ?? '',
      prazo: data(m['prazo']),
      criadoEm: data(m['criado_em']),
    );
  }
}

/// Uma tarefa que a limpeza vai concluir, com o motivo.
class ItemLimpeza {
  final TarefaDoEvento tarefa;
  final String categoria;
  final String motivo;
  const ItemLimpeza(this.tarefa, this.categoria, this.motivo);
}

class TarefasEvento {
  static const concluida = 'Concluída';

  /// Valor de `tipo` das tarefas de comunicação com o cliente (desde a Etapa 14).
  static const tipoContato = 'contato_cliente';

  // Categorias da limpeza
  static const eventoFinalizado = 'De atendimentos já encerrados';
  static const eventoInexistente = 'De atendimentos excluídos';
  static const contatoRepetido = 'Contatos repetidos (há um mais novo)';
  static const categorias = [eventoFinalizado, eventoInexistente, contatoRepetido];

  static String data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Tarefa de "informar o cliente". As antigas não têm `tipo`: reconhece pela
  /// descrição que o sistema sempre gravou.
  static bool ehContatoCliente(TarefaDoEvento t) =>
      t.tipo == tipoContato ||
      t.descricao.startsWith('Informar status ao cliente:') ||
      t.descricao.startsWith('Atualizar cliente:');

  static String motivoEncerramento(String rotulo, String acao, DateTime quando) =>
      'Concluída ao $acao o $rotulo em ${data(quando)}';

  static String motivoExclusao(DateTime quando) => 'Atendimento excluído em ${data(quando)}';

  static String motivoSubstituida(String oQue, DateTime quando) =>
      'Substituída pela atualização de $oQue em ${data(quando)}';

  static const motivoOutroMeio = 'Cliente informado por outro meio (telefone, presencial…)';

  /// Tarefas de contato abertas que uma nova comunicação substitui.
  static List<TarefaDoEvento> contatosASubstituir(List<TarefaDoEvento> doEvento) =>
      doEvento.where((t) => t.aberta && ehContatoCliente(t)).toList();

  /// Plano da limpeza. [statusDoEvento]: id do sinistro/assistência → status
  /// atual; id que não está no mapa = o evento não existe mais.
  static List<ItemLimpeza> planoLimpeza(
    List<TarefaDoEvento> tarefas,
    Map<String, String> statusDoEvento, {
    required DateTime agora,
  }) {
    final itens = <ItemLimpeza>[];
    final contatosAtivos = <String, List<TarefaDoEvento>>{};
    final hoje = data(agora);

    for (final t in tarefas.where((t) => t.aberta)) {
      final status = statusDoEvento[t.claimId];
      if (t.claimId.isEmpty || status == null) {
        itens.add(ItemLimpeza(t, eventoInexistente, 'Atendimento excluído (limpeza de $hoje)'));
      } else if (!FiltroStatus.estaEmCurso(status)) {
        itens.add(ItemLimpeza(t, eventoFinalizado, 'Atendimento $status (limpeza de $hoje)'));
      } else if (ehContatoCliente(t)) {
        contatosAtivos.putIfAbsent(t.claimId, () => []).add(t);
      }
    }

    // Em atendimento em curso, fica só o contato mais novo.
    for (final lista in contatosAtivos.values) {
      if (lista.length < 2) continue;
      lista.sort((a, b) => _ref(b).compareTo(_ref(a)));
      for (final t in lista.skip(1)) {
        itens.add(ItemLimpeza(t, contatoRepetido, 'Substituída por um contato mais novo (limpeza de $hoje)'));
      }
    }
    return itens;
  }

  static DateTime _ref(TarefaDoEvento t) =>
      t.criadoEm ?? t.prazo ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Quantas por categoria (na ordem de [categorias]).
  static Map<String, int> contarPorCategoria(List<ItemLimpeza> itens) => {
        for (final c in categorias) c: itens.where((i) => i.categoria == c).length,
      };
}
