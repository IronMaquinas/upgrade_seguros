// lib/services/tarefas_evento_service.dart
//
// Etapa 14: gravações das tarefas ligadas a um sinistro/assistência. Regras em
// lib/utils/tarefas_evento.dart. Toda conclusão feita pelo sistema grava:
//   status = 'Concluída', concluida_em, motivoConclusao, conclusao_automatica = true
// (`conclusao_automatica` tira a tarefa do "no prazo / fora do prazo" do
// funcionário — ver lib/utils/tarefas.dart).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../utils/tarefas_evento.dart';

class TarefasEventoService {
  final FirebaseFirestore _db;
  TarefasEventoService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasks => _db.collection('tasks');

  /// Tarefas abertas do sinistro/assistência [claimId], da mais antiga para a mais nova.
  Future<List<TarefaDoEvento>> abertasDoEvento(String claimId) async {
    if (claimId.isEmpty) return const [];
    final snap = await _tasks.where('claimId', isEqualTo: claimId).get();
    final lista = snap.docs
        .map((d) => TarefaDoEvento.fromMap(d.id, d.data()))
        .where((t) => t.aberta)
        .toList()
      ..sort((a, b) => (a.criadoEm ?? a.prazo ?? DateTime(0)).compareTo(b.criadoEm ?? b.prazo ?? DateTime(0)));
    return lista;
  }

  /// Conclui as tarefas [ids] com o [motivo]. [automatica] = concluída pelo
  /// sistema (fora da conta de prazo). Grava em lotes de 400.
  Future<int> concluir(Iterable<String> ids, {required String motivo, bool automatica = true}) async {
    final lista = ids.where((id) => id.isNotEmpty).toSet().toList();
    for (var i = 0; i < lista.length; i += 400) {
      final lote = _db.batch();
      for (final id in lista.skip(i).take(400)) {
        lote.update(_tasks.doc(id), {
          'status': TarefasEvento.concluida,
          'concluida_em': FieldValue.serverTimestamp(),
          'motivoConclusao': motivo,
          'conclusao_automatica': automatica,
        });
      }
      await lote.commit();
    }
    return lista.length;
  }

  /// Excluir o atendimento: conclui todas as tarefas abertas dele.
  /// Nunca impede a exclusão (erro só vai para o log).
  Future<int> concluirTodasDoEvento(String claimId, {required String motivo}) async {
    try {
      final abertas = await abertasDoEvento(claimId);
      return await concluir(abertas.map((t) => t.id), motivo: motivo);
    } catch (e) {
      debugPrint('Tarefas do atendimento $claimId não foram concluídas: $e');
      return 0;
    }
  }

  /// Nova comunicação de status/previsão: conclui as tarefas de contato
  /// anteriores do sinistro. Nunca impede a atualização.
  Future<int> concluirContatosAnteriores(String claimId, {required String motivo}) async {
    try {
      final abertas = await abertasDoEvento(claimId);
      return await concluir(TarefasEvento.contatosASubstituir(abertas).map((t) => t.id), motivo: motivo);
    } catch (e) {
      debugPrint('Contatos anteriores do sinistro $claimId não foram concluídos: $e');
      return 0;
    }
  }

  // ── Limpeza (Configurações, admin) ────────────────────────────────────

  /// Lê todas as tarefas e o status atual dos atendimentos ligados a elas e
  /// devolve o que a limpeza concluiria. Não grava nada.
  Future<List<ItemLimpeza>> analisarLimpeza() async {
    final snap = await _tasks.get();
    final tarefas = snap.docs.map((d) => TarefaDoEvento.fromMap(d.id, d.data())).toList();
    final ids = tarefas.where((t) => t.aberta && t.claimId.isNotEmpty).map((t) => t.claimId).toSet().toList();

    final status = <String, String>{};
    for (var i = 0; i < ids.length; i += 30) {
      final parte = ids.skip(i).take(30).toList();
      final resultados = await Future.wait([
        _db.collection('sinistros').where(FieldPath.documentId, whereIn: parte).get(),
        _db.collection('assistencias').where(FieldPath.documentId, whereIn: parte).get(),
      ]);
      for (final r in resultados) {
        for (final d in r.docs) {
          status[d.id] = (d.data()['status_atual'] as String?) ?? '';
        }
      }
    }
    return TarefasEvento.planoLimpeza(tarefas, status, agora: DateTime.now());
  }

  /// Conclui o que [analisarLimpeza] encontrou, cada uma com o seu motivo.
  Future<int> executarLimpeza(List<ItemLimpeza> itens) async {
    var total = 0;
    final porMotivo = <String, List<String>>{};
    for (final i in itens) {
      porMotivo.putIfAbsent(i.motivo, () => []).add(i.tarefa.id);
    }
    for (final e in porMotivo.entries) {
      total += await concluir(e.value, motivo: e.key);
    }
    return total;
  }
}
