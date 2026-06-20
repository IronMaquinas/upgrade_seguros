// ignore_for_file: unused_element, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TaskListWidget extends StatefulWidget {
  final String numeroSinistro;         // ID do sinistro
  final String clientId;
  final String clientNome;
  final String clientCnpjCpf;
  final String sinistroId;     // novo campo: id real do documento no Firestore

  const TaskListWidget({
    super.key,
    required this.numeroSinistro,
    required this.clientId,
    required this.clientNome,
    required this.clientCnpjCpf,
    required this.sinistroId,
  });

  @override
  State<TaskListWidget> createState() => _TaskListWidgetState();
}

class _TaskListWidgetState extends State<TaskListWidget> {
  final _firestore = FirebaseFirestore.instance;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  // ✅ Mudança: Agora a coleção é de nível superior, para que seja visível em todas as telas
  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
    _firestore.collection('tasks');

  // Adiciona ou edita tarefa
  Future<void> _showTaskDialog({DocumentSnapshot? taskDoc}) async {
    final isEditing = taskDoc != null;
    final descricaoController = TextEditingController(text: taskDoc?['descricao'] ?? '');
    final List<String> statusOptions = ['Aberta', 'Pendente', 'Concluída'];
    String? rawStatus = taskDoc != null ? taskDoc['status'] as String? : null;
    String statusValue = statusOptions.contains(rawStatus) ? rawStatus! : 'Aberta';
    DateTime prazo = taskDoc != null
        ? (taskDoc['prazo'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 3));
    DateTime criadoEm = taskDoc != null && taskDoc.data().toString().contains('criado_em')
        ? (taskDoc['criado_em'] as Timestamp).toDate()
        : DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
          content: SizedBox(
            width: 400, // popup maior
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: statusValue,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: statusOptions
                        .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          statusValue = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Prazo:'),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy').format(prazo)),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: prazo,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              prazo = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Data de abertura: '),
                      const SizedBox(width: 8),
                      Text(DateFormat('dd/MM/yyyy HH:mm').format(criadoEm)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: Text(isEditing ? 'Salvar' : 'Adicionar'),
              onPressed: () async {
                final currentUser = FirebaseAuth.instance.currentUser;
                final responsavelEmail = currentUser?.email ?? '';

                final data = {
                  'descricao': descricaoController.text,
                  'status': statusValue,
                  'prazo': Timestamp.fromDate(prazo),
                  // ✅ Adiciona o sinistroId ao documento da tarefa
                  'claimId': widget.sinistroId,
                  if (!isEditing) ...{
                    'criado_em': FieldValue.serverTimestamp(),
                    'numeroSinistro': widget.numeroSinistro,
                    'clientId': widget.clientId,
                    'clientNome': widget.clientNome,
                    'clientCnpjCpf': widget.clientCnpjCpf,
                    'responsavelEmail': responsavelEmail,
                  },
                };

                if (isEditing) {
                  await _tasksCollection.doc(taskDoc!.id).update(data);
                } else {
                  await _tasksCollection.add(data);
                }
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTask(DocumentSnapshot taskDoc) async {
    await _tasksCollection.doc(taskDoc.id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lista de Tarefas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showTaskDialog(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ✅ Mudança: o StreamBuilder agora filtra as tarefas por claimId
            StreamBuilder<QuerySnapshot>(
              stream: _tasksCollection.where('claimId', isEqualTo: widget.sinistroId).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('Nenhuma tarefa adicionada ainda.');
                }

                final tasks = snapshot.data!.docs.toList();

                tasks.sort((a, b) {
                  final agora = DateTime.now();

                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aStatus = aData['status'] ?? '';
                  final bStatus = bData['status'] ?? '';

                  final aPrazo = (aData['prazo'] as Timestamp).toDate();
                  final bPrazo = (bData['prazo'] as Timestamp).toDate();

                  final aConcluida = aStatus == 'Concluída';
                  final bConcluida = bStatus == 'Concluída';

                  final aAtrasada = !aConcluida && aPrazo.isBefore(agora);
                  final bAtrasada = !bConcluida && bPrazo.isBefore(agora);

                  // 🔴 atrasadas primeiro
                  if (aAtrasada != bAtrasada) return aAtrasada ? -1 : 1;

                  // 🟠 abertas depois
                  if (aConcluida != bConcluida) return aConcluida ? 1 : -1;

                  // ⏱ prazo mais próximo
                  return aPrazo.compareTo(bPrazo);
                });

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final descricao = task['descricao'] ?? '';
                    final status = task['status'] ?? '';
                    final prazo = (task['prazo'] as Timestamp).toDate();
                    final agora = DateTime.now();

                    final isConcluida = status == 'Concluída';
                    final isAtrasada = !isConcluida && prazo.isBefore(agora);

                    final criadoEmTimestamp = task.data().toString().contains('criado_em')
                        ? task['criado_em'] as Timestamp?
                        : null;
                    final criadoEm = criadoEmTimestamp?.toDate();

                    final diasRestantes = prazo.difference(agora).inDays;

                    IconData icone;
                    Color cor;

                    if (isConcluida) {
                      icone = Icons.check_circle;
                      cor = Colors.green;
                    } else if (isAtrasada) {
                      icone = Icons.warning;
                      cor = Colors.red;
                    } else {
                      icone = Icons.schedule;
                      cor = Colors.orange;
                    }

                    return ListTile(
                      // 🔥 COR DO CARD (AGORA FUNCIONA)
                      tileColor: isConcluida
                          ? Colors.grey.shade50
                          : (isAtrasada
                              ? Colors.red.shade50
                              : Colors.orange.shade50),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),

                      title: Text(
                        descricao,
                        style: TextStyle(
                          fontWeight: isAtrasada ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: $status'),
                          Text('Prazo: ${_dateFormat.format(prazo)}'),

                          if (criadoEm != null)
                            Text(
                              'Criada em: ${DateFormat('dd/MM/yyyy HH:mm').format(criadoEm)}',
                            ),

                          // 🔥 feedback de prazo
                          if (!isConcluida)
                            Text(
                              isAtrasada
                                  ? 'Atrasada há ${diasRestantes.abs()} dias'
                                  : 'Prazo em $diasRestantes dias',
                              style: TextStyle(
                                color: isAtrasada ? Colors.red : Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icone, color: cor, size: 20),

                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _showTaskDialog(taskDoc: task),
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(task),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
