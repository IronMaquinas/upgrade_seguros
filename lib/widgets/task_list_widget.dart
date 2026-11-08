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
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
    _firestore.collection('tasks');

  // Adiciona ou edita tarefa
  Future<void> _showTaskDialog({DocumentSnapshot? taskDoc}) async {
    final isEditing = taskDoc != null;
    final descricaoController = TextEditingController(text: taskDoc?['descricao'] ?? '');
    final List<String> statusOptions = ['Aberta', 'Pendente', 'Concluída'];
    String? rawStatus = taskDoc != null ? taskDoc['status'] as String? : null;
    String statusValue = statusOptions.contains(rawStatus) ? rawStatus! : 'Aberta';
    
    // ✅ AJUSTE 1: Campo prazo começa vazio para novas tarefas (sem pré-definição)
    DateTime? prazo = taskDoc != null
        ? (taskDoc['prazo'] as Timestamp).toDate()
        : null; // ← Agora começa null em vez de +3 dias
    
    DateTime criadoEm = taskDoc != null && taskDoc.data().toString().contains('criado_em')
        ? (taskDoc['criado_em'] as Timestamp).toDate()
        : DateTime.now();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CABEÇALHO
                      Text(
                        isEditing ? 'Editar Tarefa' : 'Nova Tarefa',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // CAMPO DESCRIÇÃO
                      TextField(
                        controller: descricaoController,
                        decoration: const InputDecoration(
                          labelText: 'Descrição*',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        maxLines: null,
                        minLines: 3,
                        keyboardType: TextInputType.multiline,
                      ),
                      const SizedBox(height: 16),

                      // CAMPO STATUS
                      DropdownButtonFormField<String>(
                        value: statusValue,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: statusOptions
                            .map((status) => DropdownMenuItem(value: status, child: Text(status)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setModalState(() {
                              statusValue = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // CAMPO PRAZO COM DATA E HORA
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Prazo*',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // ✅ ATALHOS RÁPIDOS: HOJE E AMANHÃ
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final hoje = DateTime.now();
                                    setModalState(() {
                                      prazo = DateTime(
                                        hoje.year,
                                        hoje.month,
                                        hoje.day,
                                        prazo?.hour ?? 09,
                                        prazo?.minute ?? 0,
                                      );
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: prazo != null && 
                                             prazo!.day == DateTime.now().day &&
                                             prazo!.month == DateTime.now().month &&
                                             prazo!.year == DateTime.now().year
                                        ? const Color(0xFF2563EB).withOpacity(0.1)
                                        : Colors.grey.shade100,
                                      border: Border.all(
                                        color: prazo != null && 
                                               prazo!.day == DateTime.now().day &&
                                               prazo!.month == DateTime.now().month &&
                                               prazo!.year == DateTime.now().year
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Hoje',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: prazo != null && 
                                                 prazo!.day == DateTime.now().day &&
                                                 prazo!.month == DateTime.now().month &&
                                                 prazo!.year == DateTime.now().year
                                            ? const Color(0xFF2563EB)
                                            : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final amanha = DateTime.now().add(const Duration(days: 1));
                                    setModalState(() {
                                      prazo = DateTime(
                                        amanha.year,
                                        amanha.month,
                                        amanha.day,
                                        prazo?.hour ?? 09,
                                        prazo?.minute ?? 0,
                                      );
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: prazo != null && 
                                             prazo!.day == DateTime.now().add(const Duration(days: 1)).day &&
                                             prazo!.month == DateTime.now().add(const Duration(days: 1)).month &&
                                             prazo!.year == DateTime.now().add(const Duration(days: 1)).year
                                        ? const Color(0xFF2563EB).withOpacity(0.1)
                                        : Colors.grey.shade100,
                                      border: Border.all(
                                        color: prazo != null && 
                                               prazo!.day == DateTime.now().add(const Duration(days: 1)).day &&
                                               prazo!.month == DateTime.now().add(const Duration(days: 1)).month &&
                                               prazo!.year == DateTime.now().add(const Duration(days: 1)).year
                                          ? const Color(0xFF2563EB)
                                          : Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Amanhã',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: prazo != null && 
                                                 prazo!.day == DateTime.now().add(const Duration(days: 1)).day &&
                                                 prazo!.month == DateTime.now().add(const Duration(days: 1)).month &&
                                                 prazo!.year == DateTime.now().add(const Duration(days: 1)).year
                                            ? const Color(0xFF2563EB)
                                            : Colors.grey.shade600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: prazo ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        prazo = DateTime(
                                          picked.year,
                                          picked.month,
                                          picked.day,
                                          prazo?.hour ?? 09,
                                          prazo?.minute ?? 0,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          prazo != null 
                                            ? DateFormat('dd/MM/yyyy').format(prazo!)
                                            : 'Selecione uma data',
                                          style: TextStyle(
                                            color: prazo != null ? Colors.black : Colors.grey.shade600,
                                          ),
                                        ),
                                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // CAMPO HORA
                              SizedBox(
                                width: 100,
                                child: GestureDetector(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(prazo ?? DateTime.now()),
                                    );
                                    if (picked != null && prazo != null) {
                                      setModalState(() {
                                        prazo = prazo!.copyWith(
                                          hour: picked.hour,
                                          minute: picked.minute,
                                        );
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          prazo != null 
                                            ? DateFormat('HH:mm').format(prazo!)
                                            : '--:--',
                                          style: TextStyle(
                                            color: prazo != null ? Colors.black : Colors.grey.shade600,
                                          ),
                                        ),
                                        const Icon(Icons.access_time, size: 18, color: Colors.grey),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      if (isEditing) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text(
                              'Data de abertura: ',
                              style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(criadoEm),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // BOTÕES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(color: Color(0xFF666666)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            onPressed: () async {
                              // ✅ Validar se prazo foi preenchido
                              if (prazo == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor, defina uma data e hora para o prazo')),
                                );
                                return;
                              }
                            
                              if (descricaoController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Por favor, preencha a descrição')),
                                );
                                return;
                              }

                              final currentUser = FirebaseAuth.instance.currentUser;
                              // Etapa 10: ao EDITAR, o responsável continua o mesmo (antes
                              // passava para quem editou — distorcia "tarefas por funcionário").
                              final dadosAtuais = (taskDoc?.data() as Map<String, dynamic>?) ?? const {};
                              final emailAtual = (dadosAtuais['responsavelEmail'] as String?) ?? '';
                              final idAtual = (dadosAtuais['responsavelId'] as String?) ?? '';
                              final manterResponsavel = isEditing && (emailAtual.isNotEmpty || idAtual.isNotEmpty);
                              final responsavelEmail = manterResponsavel ? emailAtual : (currentUser?.email ?? '');
                              final responsavelId = manterResponsavel ? idAtual : (currentUser?.uid ?? '');

                              final data = {
                                'descricao': descricaoController.text,
                                'status': statusValue,
                                'prazo': Timestamp.fromDate(prazo!),
                                'claimId': widget.sinistroId,
                                'responsavelEmail': responsavelEmail,
                                'responsavelId': responsavelId,
                                // Etapa 10: data de conclusão (no prazo / fora do prazo)
                                if (statusValue == 'Concluída' && rawStatus != 'Concluída')
                                  'concluida_em': FieldValue.serverTimestamp(),
                                if (isEditing && statusValue != 'Concluída' && rawStatus == 'Concluída')
                                  'concluida_em': FieldValue.delete(),
                                if (!isEditing) ...{
                                  'criado_em': FieldValue.serverTimestamp(),
                                  'numeroSinistro': widget.numeroSinistro,
                                  'clientId': widget.clientId,
                                  'clientNome': widget.clientNome,
                                  'clientCnpjCpf': widget.clientCnpjCpf,
                                },
                              };

                              if (isEditing) {
                                await _tasksCollection.doc(taskDoc!.id).update(data);
                              } else {
                                await _tasksCollection.add(data);
                              }
                              Navigator.pop(context);
                            },
                            child: Text(  // ← AQUI! Adicione o child
                              isEditing ? 'Salvar' : 'Adicionar',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
                  return const SelectableText('Nenhuma tarefa adicionada ainda.');
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

                      title: SelectableText(
                        descricao,
                        style: TextStyle(
                          fontWeight: isAtrasada ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText('Status: $status'),
                          SelectableText('Prazo: ${_dateFormat.format(prazo)}'),

                          if (criadoEm != null)
                            SelectableText(
                              'Criada em: ${DateFormat('dd/MM/yyyy HH:mm').format(criadoEm)}',
                            ),

                          // 🔥 feedback de prazo
                          if (!isConcluida)
                            SelectableText(
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