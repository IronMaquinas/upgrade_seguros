// lib/utils/tarefas.dart
//
// Etapa 10: regras das TAREFAS em um lugar só (Dart puro, testado em
// test/tarefas_test.dart): prazo (no prazo / fora do prazo), ordenação, resumo
// por funcionário (lista de tarefas e Relatórios) e CSV agrupado por funcionário.
//
// Prazo:
//  • O prazo vale até o FIM do dia marcado (prazo 10/11 = pode concluir até 23:59 do dia 10).
//  • Aberta/Pendente: depois do fim do dia do prazo → "Fora do prazo" (atrasada).
//  • Concluída: compara a data de conclusão (`concluida_em`) com o prazo.
//    `concluida_em` só passou a ser gravado na Etapa 10 — tarefa concluída antes
//    disso fica "Sem data de conclusão" (não dá para saber se foi no prazo).

class TarefaResumo {
  final String id;
  final String descricao;
  final String status; // 'Aberta', 'Pendente', 'Concluída'
  final DateTime? prazo;
  final DateTime? criadoEm;
  final DateTime? concluidaEm;
  final String responsavelId;
  final String responsavelEmail;
  final String numeroAtendimento;
  final String clienteNome;

  const TarefaResumo({
    this.id = '',
    this.descricao = '',
    required this.status,
    this.prazo,
    this.criadoEm,
    this.concluidaEm,
    this.responsavelId = '',
    this.responsavelEmail = '',
    this.numeroAtendimento = '',
    this.clienteNome = '',
  });

  bool get concluida => status == Tarefas.concluida;

  /// Data usada para "Mais antiga / Mais recente": criação (ou o prazo, se a
  /// tarefa antiga não tiver data de criação).
  DateTime? get dataReferencia => criadoEm ?? prazo;
}

class Funcionario {
  final String id;
  final String nome;
  final String email;
  const Funcionario({required this.id, required this.nome, required this.email});
}

class ResumoFuncionario {
  final String chave;
  final String nome;
  final String email;
  final List<TarefaResumo> tarefas;
  ResumoFuncionario(this.chave, this.nome, this.email, this.tarefas);

  int get total => tarefas.length;
  int get concluidas => tarefas.where((t) => t.concluida).length;
  int get abertas => total - concluidas;

  /// % de tarefas encerradas (concluídas ÷ total).
  double get percentualConcluidas => total == 0 ? 0 : concluidas / total * 100;

  int _conta(String situacao, DateTime agora) =>
      tarefas.where((t) => Tarefas.situacaoPrazo(t, agora: agora) == situacao).length;
  int noPrazo(DateTime agora) => _conta(Tarefas.noPrazo, agora);
  int foraDoPrazo(DateTime agora) => _conta(Tarefas.foraDoPrazo, agora);
  int semData(DateTime agora) => _conta(Tarefas.semDataConclusao, agora) + _conta(Tarefas.semPrazo, agora);

  /// % no prazo entre as tarefas em que dá para saber (no prazo + fora do prazo).
  double? percentualNoPrazo(DateTime agora) {
    final n = noPrazo(agora), f = foraDoPrazo(agora);
    return n + f == 0 ? null : n / (n + f) * 100;
  }
}

class Tarefas {
  static const concluida = 'Concluída';
  static const noPrazo = 'No prazo';
  static const foraDoPrazo = 'Fora do prazo';
  static const semDataConclusao = 'Sem data de conclusão';
  static const semPrazo = 'Sem prazo';
  static const semResponsavel = 'Sem responsável';

  static DateTime fimDoDia(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static String situacaoPrazo(TarefaResumo t, {DateTime? agora}) {
    final prazo = t.prazo;
    if (prazo == null) return semPrazo;
    final limite = fimDoDia(prazo);
    if (t.concluida) {
      final c = t.concluidaEm;
      if (c == null) return semDataConclusao;
      return c.isAfter(limite) ? foraDoPrazo : noPrazo;
    }
    return (agora ?? DateTime.now()).isAfter(limite) ? foraDoPrazo : noPrazo;
  }

  /// Ordena pela data de criação. Sem data nenhuma vai para o fim.
  static List<TarefaResumo> ordenar(List<TarefaResumo> tarefas, {required bool maisRecentePrimeiro}) {
    final lista = List<TarefaResumo>.from(tarefas);
    lista.sort((a, b) {
      final da = a.dataReferencia, db = b.dataReferencia;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return maisRecentePrimeiro ? db.compareTo(da) : da.compareTo(db);
    });
    return lista;
  }

  /// Agrupa por funcionário (pelo id do responsável; se não casar, pelo e-mail).
  /// Ordem: quem tem mais tarefas primeiro; "Sem responsável" no fim.
  static List<ResumoFuncionario> porFuncionario(List<TarefaResumo> tarefas, List<Funcionario> funcionarios) {
    final porId = {for (final f in funcionarios) f.id: f};
    final porEmail = {for (final f in funcionarios) if (f.email.isNotEmpty) f.email.toLowerCase(): f};
    final grupos = <String, ResumoFuncionario>{};
    for (final t in tarefas) {
      final f = porId[t.responsavelId] ?? porEmail[t.responsavelEmail.toLowerCase()];
      final String chave, nome, email;
      if (f != null) {
        chave = f.id;
        nome = f.nome;
        email = f.email;
      } else if (t.responsavelEmail.isNotEmpty) {
        chave = 'email:${t.responsavelEmail.toLowerCase()}';
        nome = t.responsavelEmail;
        email = t.responsavelEmail;
      } else {
        chave = '__sem__';
        nome = semResponsavel;
        email = '';
      }
      grupos.putIfAbsent(chave, () => ResumoFuncionario(chave, nome, email, [])).tarefas.add(t);
    }
    final lista = grupos.values.toList()
      ..sort((a, b) {
        if (a.chave == '__sem__') return 1;
        if (b.chave == '__sem__') return -1;
        final c = b.total.compareTo(a.total);
        return c != 0 ? c : a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      });
    return lista;
  }

  // ── CSV agrupado por funcionário (abre no Excel em português) ─────────────

  static const cabecalhoCsv = [
    'Funcionário',
    'E-mail do funcionário',
    'Atendimento',
    'Cliente',
    'Descrição',
    'Status',
    'Criada em',
    'Prazo',
    'Concluída em',
    'Situação do prazo',
  ];

  static String _data(DateTime? d) => d == null
      ? ''
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String paraCsv(List<ResumoFuncionario> grupos, {required bool maisRecentePrimeiro, DateTime? agora}) {
    final hoje = agora ?? DateTime.now();
    final b = StringBuffer('﻿');
    void linha(List<String> celulas) => b.write('${celulas.map(_celula).join(';')}\r\n');
    linha(cabecalhoCsv);
    for (final g in grupos) {
      for (final t in ordenar(g.tarefas, maisRecentePrimeiro: maisRecentePrimeiro)) {
        linha([
          g.nome,
          g.email,
          t.numeroAtendimento,
          t.clienteNome,
          t.descricao,
          t.status,
          _data(t.criadoEm),
          _data(t.prazo),
          _data(t.concluidaEm),
          situacaoPrazo(t, agora: hoje),
        ]);
      }
      final pNoPrazo = g.percentualNoPrazo(hoje);
      linha([
        'SUBTOTAL ${g.nome}',
        '',
        '${g.total} tarefas',
        '${g.abertas} abertas',
        '${g.concluidas} concluídas (${g.percentualConcluidas.toStringAsFixed(0)}%)',
        '',
        '',
        '',
        '',
        '${g.noPrazo(hoje)} no prazo · ${g.foraDoPrazo(hoje)} fora'
            '${pNoPrazo == null ? '' : ' (${pNoPrazo.toStringAsFixed(0)}% no prazo)'}',
      ]);
    }
    return b.toString();
  }

  static String _celula(String v) {
    var s = v;
    if (s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
    if (s.contains(';') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      s = '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
