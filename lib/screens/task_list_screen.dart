// screens/task_list_screen.dart
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/screens/assist_detail_screen.dart';
import 'package:upgrade_seguros/screens/claim_detail_screen.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _firestoreService = FirestoreService();
  final _dateFormat = DateFormat('dd/MM/yyyy');
  bool? _selectedPrazoFilter; // null=Todos, true=No prazo, false=Fora do prazo

  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];

  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_filterTasks);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTasks);
    _searchController.dispose();
    super.dispose();
  }

  // ✅ Função para obter ícone baseado no status
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Concluída':
        return Icons.check_circle;
      case 'Aberta':
        return Icons.autorenew;
      case 'Pendente':
        return Icons.access_time;
      default:
        return Icons.assignment;
    }
  }

  // ✅ Função para obter cor baseada no status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Concluída':
        return Colors.green.shade400;
      case 'Aberta':
        return Colors.blue.shade400;
      case 'Pendente':
        return Colors.orange.shade400;
      default:
        return Colors.grey;
    }
  }

  // ✅ Função para obter cor baseada no prazo (CORRIGIDA)
  Color _getPrazoColor(DateTime? prazo, String status) {
    if (prazo == null) return Colors.grey;
    
    // Se a tarefa está concluída, mostra em verde independente do prazo
    if (status == 'Concluída') {
      return Colors.green.shade400;
    }
    
    final agora = DateTime.now();
    final diferenca = prazo.difference(agora);
    
    if (prazo.isBefore(agora)) {
      return Colors.red.shade400; // Fora do prazo (não concluída)
    } else if (diferenca.inDays <= 2) {
      return Colors.orange.shade400; // Próximo do prazo (2 dias ou menos)
    } else {
      return Colors.green.shade400; // No prazo
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _firestoreService.getAllTasksWithClaims();
      setState(() {
        _allTasks = tasks;
        _filterTasks();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar tarefas: $e')),
      );
    }
  }

  void _filterTasks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTasks = _allTasks.where((task) {
        final matchesSearch = query.isEmpty ||
            (task['numeroSinistro'] ?? '').toString().toLowerCase().contains(query) ||
            (task['clientNome'] ?? '').toString().toLowerCase().contains(query) ||
            (task['clientCnpjCpf'] ?? '').toString().toLowerCase().contains(query) ||
            (task['responsavelEmail'] ?? '').toString().toLowerCase().contains(query) ||
            (task['descricao'] ?? '').toString().toLowerCase().contains(query);

        final matchesStatus = _selectedStatus == null || task['status'] == _selectedStatus;

        final prazo = task['prazo'] as DateTime?;
        final atrasada = prazo?.isBefore(DateTime.now()) ?? false;
        final matchesPrazo = _selectedPrazoFilter == null ||
            (_selectedPrazoFilter == true && !atrasada) ||
            (_selectedPrazoFilter == false && atrasada);

        return matchesSearch && matchesStatus && matchesPrazo;
      }).toList();
    });
  }

  // ✅ Card atualizado no mesmo estilo dos sinistros
  Widget _buildTaskCard(Map<String, dynamic> task) {
    final prazo = task['prazo'] as DateTime?;
    final status = task['status'] as String? ?? 'Pendente';
    final numeroSinistro = task['numeroSinistro'] as String?;
    final descricao = task['descricao'] as String? ?? 'Sem descrição';
    final clientNome = task['clientNome'] as String? ?? 'Cliente não informado';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (numeroSinistro == null || numeroSinistro.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Número do atendimento não encontrado.')),
            );
            return;
          }

          try {
            final claim = await _firestoreService.getClaimByNumeroSinistro(numeroSinistro);
            if (claim != null) {
              if (claim.tipo == 'assistencia') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AssistDetailScreen(assistId: claim.id),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClaimDetailScreen(claim: claim),
                  ),
                );
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Atendimento não encontrado.')),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar atendimento: $e')),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ CABEÇALHO COM ÍCONE DE STATUS
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    child: Icon(
                      _getStatusIcon(status),
                      size: 18, 
                      color: _getStatusColor(status),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      numeroSinistro ?? 'N/I',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // ✅ DESCRIÇÃO DA TAREFA
              Text(
                descricao,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              
              // ✅ NOME DO CLIENTE
              Text(
                clientNome,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              
              // ✅ PRAZO (CORRIGIDO)
              Text(
                prazo != null ? _dateFormat.format(prazo) : 'Prazo não definido',
                style: TextStyle(
                  fontSize: 12,
                  color: prazo != null ? _getPrazoColor(prazo, status) : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 10),
              
              // ✅ CHIP DE STATUS
              Row(
                children: [
                  Chip(
                    label: Text(
                      status,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  // ✅ Ícone de warning só aparece se estiver atrasada E não concluída
                  if (prazo != null && prazo.isBefore(DateTime.now()) && status != 'Concluída')
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Todas as Tarefas'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(160.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por Sinistro, Cliente, Responsável ou Descrição',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus ?? 'Todas',
                        decoration: InputDecoration(
                          hintText: 'Status',
                          prefixIcon: const Icon(Icons.filter_list),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: ['Todas', 'Aberta', 'Pendente', 'Concluída']
                            .map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatus = value == 'Todas' ? null : value;
                            _filterTasks();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPrazoFilter == null
                            ? 'Todos'
                            : _selectedPrazoFilter == true
                                ? 'No prazo'
                                : 'Fora do prazo',
                        decoration: InputDecoration(
                          hintText: 'Prazo',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: ['Todos', 'No prazo', 'Fora do prazo']
                            .map((prazo) => DropdownMenuItem(
                                  value: prazo,
                                  child: Text(prazo),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            if (value == 'Todos') {
                              _selectedPrazoFilter = null;
                            } else if (value == 'No prazo') {
                              _selectedPrazoFilter = true;
                            } else {
                              _selectedPrazoFilter = false;
                            }
                            _filterTasks();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) return const Center(child: CircularProgressIndicator());

          if (_filteredTasks.isEmpty) {
            return Center(
              child: Text(
                _searchController.text.isEmpty && _selectedStatus == null && _selectedPrazoFilter == null
                    ? 'Nenhuma tarefa registrada.'
                    : 'Nenhuma tarefa encontrada com os filtros aplicados.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          if (constraints.maxWidth > 600) {
            final availableWidth = constraints.maxWidth;
            final crossAxisCount = (availableWidth / 400).floor();
            final effectiveCount = crossAxisCount.clamp(2, 4);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: effectiveCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  mainAxisExtent: 225,
                ),
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) => _buildTaskCard(_filteredTasks[index]),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadTasks,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _filteredTasks.length,
              itemBuilder: (context, index) => _buildTaskCard(_filteredTasks[index]),
            ),
          );
        },
      ),
    );
  }
}