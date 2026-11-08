// screens/task_list_screen.dart
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import '../services/firestore_service.dart';
import '../screens/assist_detail_screen.dart';
import '../screens/claim_detail_screen.dart';
import '../services/tarefas_pdf.dart';
import '../utils/tarefas.dart';
import '../widgets/botao_com_texto.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

  List<Map<String, dynamic>> _allTasks = [];
  List<Map<String, dynamic>> _filteredTasks = [];
  bool _isLoading = true;

  // Filtros
  String? _selectedStatus;
  String? _selectedPrazoFilter; // null=Todos, 'No prazo', 'Fora do prazo'

  final List<String> _statusOptions = ['Todas', 'Aberta', 'Pendente', 'Concluída'];
  final List<String> _prazoOptions = ['Todos', 'No prazo', 'Fora do prazo'];

  // Etapa 10: ordenação e exportação
  static const _ordemOptions = ['Mais recente', 'Mais antiga'];
  bool _maisRecentePrimeiro = true;
  bool _exportando = false;

  // Filtro de Funcionário
  String? _selectedFuncionarioId;
  List<Map<String, dynamic>> _funcionarios = [];
  bool _isAdmin = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_filterTasks);
    _loadUserRole(); // <-- ADICIONADO
    _carregarFuncionarios().then((_) {
      // Se for admin, NÃO pré-seleciona funcionário
      if (_isAdmin) {
        return;
      }
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final exists = _funcionarios.any((f) => f['id'] == currentUser.uid);
        if (exists) {
          setState(() {
            _selectedFuncionarioId = currentUser.uid;
            _filterTasks();
          });
        } else {
          final userEmail = currentUser.email;
          if (userEmail != null) {
            final funcionarioPorEmail = _funcionarios.firstWhere(
              (f) => f['email'] == userEmail,
              orElse: () => {},
            );
            if (funcionarioPorEmail.isNotEmpty) {
              setState(() {
                _selectedFuncionarioId = funcionarioPorEmail['id'] as String;
                _filterTasks();
              });
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTasks);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    setState(() {
      _isAdmin = role == 'admin';
    });
  }

  // --- MÉTODO PARA CARREGAR FUNCIONÁRIOS ---
  Future<void> _carregarFuncionarios() async {
    try {
      final users = await _firestoreService.getFuncionarios();
      setState(() {
        _funcionarios = users.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nome = data['nome'] as String? ?? 'Sem nome';
          final email = data['email'] as String? ?? '';
          return {
            'id': doc.id,
            'nome': nome,
            'email': email,
          };
        }).toList();
      });
      print('Funcionários carregados: ${_funcionarios.length}');
    } catch (e) {
      print('Erro ao carregar funcionários: $e');
    }
  }

  // ─── Busca e Filtros ─────────────────────────────────────────────
  Future<void> _loadTasks() async {
    try {
      final tasks = await _firestoreService.getAllTasksWithClaims();
      setState(() {
        _allTasks = tasks;
        _filterTasks();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar tarefas: $e')),
        );
      }
    }
  }

  void _filterTasks() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredTasks = _allTasks.where((task) {
        // Busca textual (mantido)
        final matchesSearch = query.isEmpty ||
            (task['numeroSinistro'] ?? '').toString().toLowerCase().contains(query) ||
            (task['clientNome'] ?? '').toString().toLowerCase().contains(query) ||
            (task['clientCnpjCpf'] ?? '').toString().toLowerCase().contains(query) ||
            (task['responsavelEmail'] ?? '').toString().toLowerCase().contains(query) ||
            (task['descricao'] ?? '').toString().toLowerCase().contains(query);

        // Filtro status (mantido)
        final matchesStatus = _selectedStatus == null ||
            _selectedStatus == 'Todas' ||
            task['status'] == _selectedStatus;

        // Filtro prazo — Etapa 10: regra única (lib/utils/tarefas.dart). Concluída
        // conta pela data de conclusão; antes, toda tarefa com prazo vencido
        // (inclusive as concluídas no prazo) caía em "Fora do prazo".
        final situacao = Tarefas.situacaoPrazo(_resumo(task));
        final matchesPrazo = _selectedPrazoFilter == null ||
            _selectedPrazoFilter == 'Todos' ||
            situacao == _selectedPrazoFilter;

        // ── Filtro por Funcionário ──
        bool matchesFuncionario = true;
        if (_selectedFuncionarioId != null) {
          // Busca o funcionário de forma segura sem firstWhere com orElse problemático
          Map<String, dynamic>? funcionario;
          for (var f in _funcionarios) {
            if (f['id'] == _selectedFuncionarioId) {
              funcionario = f;
              break;
            }
          }
          
          // Se não encontrou, tenta por email (fallback)
          if (funcionario == null) {
            // Busca pelo email do funcionário
            final userEmail = FirebaseAuth.instance.currentUser?.email;
            for (var f in _funcionarios) {
              if (f['email'] == userEmail) {
                funcionario = f;
                break;
              }
            }
          }

          if (funcionario != null) {
            final emailFuncionario = funcionario['email'] as String?;
            // Usa o email da task (responsavelEmail) ou ID (se tiver)
            final responsavelEmail = task['responsavelEmail'] as String?;
            final responsavelId = task['responsavelId'] as String?;
            matchesFuncionario = responsavelId == _selectedFuncionarioId ||
                (emailFuncionario != null && responsavelEmail == emailFuncionario);
          } else {
            matchesFuncionario = false; // funcionário não encontrado, não filtra
          }
        }

        return matchesSearch && matchesStatus && matchesPrazo && matchesFuncionario;
      }).toList();

      // Etapa 10: "Mais recente" / "Mais antiga" pela data de criação (ou prazo).
      _filteredTasks.sort((a, b) {
        final da = (a['criadoEm'] as DateTime?) ?? (a['prazo'] as DateTime?);
        final db = (b['criadoEm'] as DateTime?) ?? (b['prazo'] as DateTime?);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return _maisRecentePrimeiro ? db.compareTo(da) : da.compareTo(db);
      });
    });
  }

  // ─── Etapa 10: exportar agrupado por funcionário ──────────────────

  TarefaResumo _resumo(Map<String, dynamic> task) => TarefaResumo(
        id: task['taskId'] as String? ?? '',
        descricao: task['descricao'] as String? ?? '',
        status: task['status'] as String? ?? 'Pendente',
        prazo: task['prazo'] as DateTime?,
        criadoEm: task['criadoEm'] as DateTime?,
        concluidaEm: task['concluidaEm'] as DateTime?,
        responsavelId: task['responsavelId'] as String? ?? '',
        responsavelEmail: task['responsavelEmail'] as String? ?? '',
        numeroAtendimento: task['numeroSinistro'] as String? ?? '',
        clienteNome: task['clientNome'] as String? ?? '',
      );

  Future<void> _exportar(String formato) async {
    if (_filteredTasks.isEmpty) return;
    setState(() => _exportando = true);
    try {
      final funcionarios = [
        for (final f in _funcionarios)
          Funcionario(id: f['id'] as String? ?? '', nome: f['nome'] as String? ?? '', email: f['email'] as String? ?? ''),
      ];
      final grupos = Tarefas.porFuncionario(_filteredTasks.map(_resumo).toList(), funcionarios);
      String? nomeFuncionario;
      for (final f in _funcionarios) {
        if (f['id'] == _selectedFuncionarioId) nomeFuncionario = f['nome'] as String?;
      }
      final filtros = [
        if (_selectedStatus != null) 'Status: $_selectedStatus',
        if (_selectedPrazoFilter != null) 'Prazo: $_selectedPrazoFilter',
        if (nomeFuncionario != null) 'Funcionário: $nomeFuncionario',
        if (_searchController.text.trim().isNotEmpty) 'Busca: "${_searchController.text.trim()}"',
      ].join(' · ');
      final data = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (formato == 'pdf') {
        await Printing.sharePdf(
          bytes: await TarefasPdf.gerar(grupos, maisRecentePrimeiro: _maisRecentePrimeiro, filtro: filtros),
          filename: 'tarefas_por_funcionario_$data.pdf',
        );
      } else {
        await Printing.sharePdf(
          bytes: utf8.encode(Tarefas.paraCsv(grupos, maisRecentePrimeiro: _maisRecentePrimeiro)),
          filename: 'tarefas_por_funcionario_$data.csv',
        );
      }
      if (mounted && filtros.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportadas ${_filteredTasks.length} tarefa(s) — $filtros.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  // ─── Helpers de UI ────────────────────────────────────────────────

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

  Color _getPrazoColor(DateTime? prazo, String status, {String? situacao}) {
    if (prazo == null) return Colors.grey;
    if (status == 'Concluída') {
      // Etapa 10: concluída fora do prazo fica vermelha; sem data, cinza.
      if (situacao == Tarefas.foraDoPrazo) return Colors.red.shade400;
      if (situacao == Tarefas.semDataConclusao) return Colors.grey;
      return Colors.green.shade400;
    }

    final agora = DateTime.now();
    final diferenca = prazo.difference(agora);

    if (prazo.isBefore(agora)) {
      return Colors.red.shade400;
    } else if (diferenca.inDays <= 2) {
      return Colors.orange.shade400;
    } else {
      return Colors.green.shade400;
    }
  }

  // ─── Widgets de Filtros ──────────────────────────────────────────
  Widget _buildFilterDropdown<T>({
    required T? value,
    required List<T> items,
    required String hint,
    required IconData icon,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // --- WIDGET DE FUNCIONÁRIOS ---
  Widget _buildFuncionarioDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedFuncionarioId,
      isDense: true,
      decoration: InputDecoration(
        hintText: 'Funcionário',
        prefixIcon: const Icon(Icons.person, size: 18, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ..._funcionarios.map<DropdownMenuItem<String?>>((f) {
          final nome = f['nome'] as String? ?? 'Sem nome';
          final email = f['email'] as String?;
          return DropdownMenuItem(
            value: f['id'] as String?,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome, style: const TextStyle(fontWeight: FontWeight.w500)),
                if (email != null && email.isNotEmpty)
                  Text(email, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          );
        }).toList(),
      ],
      onChanged: (val) {
        setState(() {
          _selectedFuncionarioId = val;
          _filterTasks();
        });
      },
    );
  }

  // ─── Widgets de Card ─────────────────────────────────────────────

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final prazo = task['prazo'] as DateTime?;
    final status = task['status'] as String? ?? 'Pendente';
    final numeroSinistro = task['numeroSinistro'] as String?;
    final descricao = task['descricao'] as String? ?? 'Sem descrição';
    final clientNome = task['clientNome'] as String? ?? 'Cliente não informado';
    final concluidaEm = task['concluidaEm'] as DateTime?;
    final situacao = Tarefas.situacaoPrazo(_resumo(task));

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
                    builder: (_) => AssistDetailScreen(assistId: claim.id),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClaimDetailScreen(claim: claim),
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
              Text(
                descricao,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                clientNome,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Text(
                (prazo != null ? 'Prazo: ${_dateFormat.format(prazo)}' : 'Prazo não definido') +
                    (concluidaEm != null ? '  ·  Concluída em ${_dateFormat.format(concluidaEm)}' : ''),
                style: TextStyle(
                  fontSize: 12,
                  color: _getPrazoColor(prazo, status, situacao: situacao),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(
                    label: Text(status, style: const TextStyle(fontSize: 12)),
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (situacao == Tarefas.foraDoPrazo)
                    Tooltip(
                      message: status == 'Concluída' ? 'Concluída fora do prazo' : 'Atrasada',
                      child: const Icon(Icons.warning, color: Colors.red, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Tarefas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          if (_exportando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Exportar as tarefas da lista, agrupadas por funcionário',
              enabled: _filteredTasks.isNotEmpty,
              onSelected: _exportar,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined, color: Color(0xFF2E7D32)),
                    title: Text('Planilha (CSV / Excel)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFC62828)),
                    title: Text('PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
              child: BotaoComTexto(
                icone: Icons.file_download_outlined,
                texto: MediaQuery.of(context).size.width < 600 ? 'Exportar' : 'Exportar por funcionário',
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadTasks,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120.0), // Aumente para caber a nova linha
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              children: [
                // Linha 1: Busca (mantido)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por Sinistro, Cliente, Responsável ou Descrição',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Linha 2: Status + Prazo (mantido)
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _selectedStatus ?? 'Todas',
                        items: _statusOptions,
                        hint: 'Status',
                        icon: Icons.filter_list,
                        onChanged: (val) {
                          setState(() {
                            _selectedStatus = val == 'Todas' ? null : val;
                            _filterTasks();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _selectedPrazoFilter ?? 'Todos',
                        items: _prazoOptions,
                        hint: 'Prazo',
                        icon: Icons.calendar_today,
                        onChanged: (val) {
                          setState(() {
                            _selectedPrazoFilter = val == 'Todos' ? null : val;
                            _filterTasks();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFuncionarioDropdown(),
                    ),
                    const SizedBox(width: 8),
                    // Etapa 10: ordenação
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _maisRecentePrimeiro ? 'Mais recente' : 'Mais antiga',
                        items: _ordemOptions,
                        hint: 'Ordenar',
                        icon: Icons.sort,
                        onChanged: (val) {
                          _maisRecentePrimeiro = val != 'Mais antiga';
                          _filterTasks();
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
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_filteredTasks.isEmpty) {
            return Center(
              child: Text(
                _searchController.text.isEmpty &&
                        _selectedStatus == null &&
                        _selectedPrazoFilter == null
                    ? 'Nenhuma tarefa registrada.'
                    : 'Nenhuma tarefa encontrada com os filtros aplicados.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          if (constraints.maxWidth > 600) {
            final availableWidth = constraints.maxWidth;
            final crossAxisCount = (availableWidth / 400).floor().clamp(2, 4);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
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