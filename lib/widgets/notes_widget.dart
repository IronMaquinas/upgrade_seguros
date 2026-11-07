import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotesWidget extends StatefulWidget {
  final String claimId;
  final List<Map<String, dynamic>> anotacoes;
  final bool isAdmin;

  const NotesWidget({
    super.key,
    required this.claimId,
    required this.anotacoes,
    required this.isAdmin,
  });

  @override
  State<NotesWidget> createState() => _NotesWidgetState();
}

class _NotesWidgetState extends State<NotesWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isAdding = false;

  Future<void> _addAnotacao() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;

    setState(() => _isAdding = true);

    try {
      final authService = AuthService();
      final nomeUsuario = await authService.getUserName(); // ✨ PEGA NOME!
      await FirestoreService().addAnotacao(widget.claimId, texto, nomeUsuario); // ✨ PASSA NOME!
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar anotação: $e')),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteAnotacao(Map<String, dynamic> anotacao) async {
    try {
      await FirestoreService().deleteAnotacao(widget.claimId, anotacao);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir anotação: $e')),
      );
    }
  }

  void _showAddNoteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nova Anotação'),
          content: SizedBox(
            width: 400, // ocupa mais horizontal
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Digite sua anotação...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
              autofocus: true,
              maxLines: null,
              minLines: 5,
              keyboardType: TextInputType.multiline,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
              onPressed: _isAdding ? null : () async {
                Navigator.of(context).pop();
                await _addAnotacao();
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Anotações',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Adicionar anotação',
                  onPressed: _showAddNoteDialog,
                ),
              ],
            ),
            const SizedBox(height: 8),
            widget.anotacoes.isEmpty
              ? const SelectableText('Nenhuma anotação adicionada ainda.')
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.anotacoes.length,
                  itemBuilder: (context, index) {
                    final nota = widget.anotacoes.reversed.toList()[index];
                    final data = (nota['data'] is Timestamp)
                        ? (nota['data'] as Timestamp).toDate()
                        : DateTime.now();
                    final autor = nota['autor'] ?? nota['responsavelEmail'] ?? 'N/A';
                    final texto = nota['texto'] ?? '';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      color: Colors.grey[50],
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    '$autor - ${dateFormat.format(data)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                if (widget.isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                                    tooltip: 'Excluir anotação',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Confirmar exclusão'),
                                          content: const Text('Tem certeza que deseja excluir esta anotação?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await _deleteAnotacao(nota);
                                      }
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SelectableText(texto),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}