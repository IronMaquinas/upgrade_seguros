// lib/widgets/tarefas_evento_dialog.dart
//
// Etapa 14:
//  • confirmarTarefasAoEncerrar(...) → ao encerrar/cancelar um sinistro ou uma
//    assistência, mostra as tarefas abertas dele (todas marcadas) e conclui as
//    marcadas. Devolve false se o funcionário clicar em "Voltar".
//  • CartaoLimpezaTarefas → cartão de Configurações (só admin) que analisa e
//    conclui tarefas antigas esquecidas, mostrando antes o que vai concluir.

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/tarefas_evento_service.dart';
import '../utils/tarefas_evento.dart';

/// [rotulo] = 'sinistro' ou 'assistência'; [acao] = 'encerrar' ou 'cancelar'.
Future<bool> confirmarTarefasAoEncerrar(
  BuildContext context, {
  required String claimId,
  required String rotulo,
  String acao = 'encerrar',
}) async {
  final servico = TarefasEventoService();
  List<TarefaDoEvento> abertas;
  try {
    abertas = await servico.abertasDoEvento(claimId);
  } catch (e) {
    debugPrint('Não consegui ler as tarefas do atendimento $claimId: $e');
    return true; // não impede o encerramento
  }
  if (abertas.isEmpty || !context.mounted) return true;

  final marcadas = abertas.map((t) => t.id).toSet();
  final verbo = acao == 'cancelar' ? 'cancelar' : 'encerrar';
  final verboMaiusculo = verbo[0].toUpperCase() + verbo.substring(1);

  final seguir = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text('Tarefas abertas deste $rotulo'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                abertas.length == 1
                    ? 'Há 1 tarefa aberta. Ela será concluída junto com o $rotulo:'
                    : 'Há ${abertas.length} tarefas abertas. As marcadas serão concluídas junto com o $rotulo:',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in abertas)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: marcadas.contains(t.id),
                        onChanged: (v) => setS(() => v == true ? marcadas.add(t.id) : marcadas.remove(t.id)),
                        title: Text(t.descricao.isEmpty ? 'Tarefa sem descrição' : t.descricao,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: t.prazo == null
                            ? null
                            : Text('Prazo: ${TarefasEvento.data(t.prazo!)}', style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ficam registradas como "concluídas pelo sistema", com o motivo, e não contam '
                'como atraso do funcionário.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Voltar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(marcadas.isEmpty
                ? '$verboMaiusculo sem concluir tarefas'
                : 'Concluir ${marcadas.length} e $verbo'),
          ),
        ],
      ),
    ),
  );
  if (seguir != true) return false;

  if (marcadas.isNotEmpty) {
    try {
      await servico.concluir(marcadas, motivo: TarefasEvento.motivoEncerramento(rotulo, verbo, DateTime.now()));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('O $rotulo será salvo, mas as tarefas não foram concluídas: $e')),
        );
      }
    }
  }
  return true;
}

/// Cartão "🧹 Tarefas esquecidas" de Configurações. Só aparece para admin.
class CartaoLimpezaTarefas extends StatefulWidget {
  const CartaoLimpezaTarefas({super.key});

  @override
  State<CartaoLimpezaTarefas> createState() => _CartaoLimpezaTarefasState();
}

class _CartaoLimpezaTarefasState extends State<CartaoLimpezaTarefas> {
  final _servico = TarefasEventoService();
  bool? _admin;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    AuthService().isAdmin().then((admin) {
      if (mounted) setState(() => _admin = admin);
    }).catchError((_) {
      if (mounted) setState(() => _admin = false);
    });
  }

  Future<void> _analisar() async {
    setState(() => _ocupado = true);
    List<ItemLimpeza> itens;
    try {
      itens = await _servico.analisarLimpeza();
    } catch (e) {
      if (mounted) {
        setState(() => _ocupado = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao analisar as tarefas: $e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _ocupado = false);

    if (itens.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tudo em ordem'),
          content: const Text('Nenhuma tarefa aberta de atendimento encerrado, excluído ou com contato repetido.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
      return;
    }

    final contagem = TarefasEvento.contarPorCategoria(itens);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${itens.length} tarefa(s) para concluir'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in TarefasEvento.categorias)
                if ((contagem[c] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $c: ${contagem[c]}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final i in itens)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(i.tarefa.descricao.isEmpty ? 'Tarefa sem descrição' : i.tarefa.descricao,
                            style: const TextStyle(fontSize: 12)),
                        subtitle: Text(i.motivo, style: const TextStyle(fontSize: 11)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Elas não são apagadas: ficam concluídas, com o motivo, e não contam como atraso do funcionário.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Concluir ${itens.length}'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _ocupado = true);
    try {
      final n = await _servico.executarLimpeza(itens);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n tarefa(s) concluída(s).')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao concluir: $e')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_admin != true) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧹 Tarefas esquecidas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  'Procura tarefas abertas de atendimentos já encerrados ou excluídos, e contatos com o '
                  'cliente repetidos. Mostra a lista antes de concluir. Só administradores.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _ocupado ? null : _analisar,
            icon: _ocupado
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search, size: 18),
            label: const Text('Analisar'),
          ),
        ],
      ),
    );
  }
}
