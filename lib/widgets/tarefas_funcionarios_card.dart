// lib/widgets/tarefas_funcionarios_card.dart
//
// Etapa 10: Relatórios → FUNCIONÁRIOS → "Tarefas por Funcionário (período)".
// Por funcionário: total, abertas, concluídas, % encerradas, no prazo × fora do
// prazo (regras em lib/utils/tarefas.dart). Período = data de criação da tarefa
// (ou o prazo, se a tarefa antiga não tiver data de criação).

import 'package:flutter/material.dart';

import '../utils/tarefas.dart';

class TarefasFuncionariosCard extends StatelessWidget {
  final List<ResumoFuncionario> grupos;
  final DateTime agora;
  const TarefasFuncionariosCard({super.key, required this.grupos, required this.agora});

  static const _roxo = Color(0xFF6A1B9A);

  Color _corPercentual(double? p) {
    if (p == null) return Colors.grey;
    if (p >= 80) return const Color(0xFF2E7D32);
    if (p >= 60) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final total = grupos.fold<int>(0, (s, g) => s + g.total);
    final semData = grupos.fold<int>(0, (s, g) => s + g.semData(agora));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _roxo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.task_alt_rounded, color: _roxo, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('✅ Tarefas por Funcionário (período)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _roxo.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _roxo)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (grupos.isEmpty)
            Text('Nenhuma tarefa criada no período.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          else
            ...grupos.map((g) {
              final pNoPrazo = g.percentualNoPrazo(agora);
              final semResp = g.chave == '__sem__';
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: semResp ? Colors.orange.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: semResp ? Colors.orange.shade300 : Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(semResp ? '⚠️ ${g.nome}' : g.nome,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                        Text('${g.total} tarefas', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Barra: % encerradas
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: g.total == 0 ? 0 : g.concluidas / g.total,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(_corPercentual(g.percentualConcluidas)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 14,
                      runSpacing: 4,
                      children: [
                        _info('Abertas', '${g.abertas}', Colors.blue.shade700),
                        _info('Concluídas', '${g.concluidas} (${g.percentualConcluidas.toStringAsFixed(0)}%)',
                            _corPercentual(g.percentualConcluidas)),
                        _info('No prazo', '${g.noPrazo(agora)}', const Color(0xFF2E7D32)),
                        _info('Fora do prazo', '${g.foraDoPrazo(agora)}', const Color(0xFFC62828)),
                        // Etapa 14: concluídas pelo sistema (evento encerrado/excluído, contato substituído).
                        if (g.encerradasPeloSistema > 0)
                          _info('Pelo sistema', '${g.encerradasPeloSistema}', Colors.grey.shade700),
                        if (pNoPrazo != null)
                          _info('Cumprimento do prazo', '${pNoPrazo.toStringAsFixed(0)}%', _corPercentual(pNoPrazo)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          if (semData > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$semData tarefa(s) concluída(s) antes de o app registrar a data de conclusão (ou sem prazo) '
                'não entram em "no prazo / fora do prazo".',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(String rotulo, String valor, Color cor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rotulo, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
        ],
      );
}
