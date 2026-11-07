// lib/utils/filtro_status.dart
//
// Regra única do filtro de status das listas de Sinistros e Assistências
// (Etapa 05). Dart puro, para ser testado (test/filtro_status_test.dart).
//
// • "Em curso" (padrão, valor null no filtro): tudo que ainda dá trabalho no
//   dia a dia — qualquer status que NÃO seja finalizado. Inclui Rascunho.
// • "Todos": todos mesmo, inclusive Concluído e Cancelado.
// • Um status específico: só ele.
//
// A tela abre buscando no banco só o que está em curso. O histórico
// (finalizados) só é baixado quando o filtro pede: "Todos" ou um status
// finalizado.

class FiltroStatus {
  static const emCurso = 'Em curso';
  static const todos = 'Todos';

  /// Status que encerram o atendimento (não aparecem em "Em curso").
  /// Firestore: no máximo 10 valores num filtro `whereNotIn`.
  static const finalizados = <String>['Concluído', 'Cancelado', 'Negado'];

  static bool estaEmCurso(String status) => !finalizados.contains(status.trim());

  /// [filtro] null ou "Em curso" = em curso; "Todos" = tudo; senão, o status exato.
  static bool corresponde(String? filtro, String status) {
    if (filtro == null || filtro == emCurso) return estaEmCurso(status);
    if (filtro == todos) return true;
    return status == filtro;
  }

  /// O filtro precisa dos registros finalizados (histórico)?
  static bool precisaHistorico(String? filtro) =>
      filtro == todos || (filtro != null && finalizados.contains(filtro));
}
