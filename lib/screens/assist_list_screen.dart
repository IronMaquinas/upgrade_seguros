// lib/screens/assist_list_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import '../models/claim_model.dart';
import '../services/firestore_service.dart';
import '../utils/filtro_status.dart';
import '../widgets/option_picker_dialog.dart';
import 'assist_detail_screen.dart';
import 'spreadsheet_assist_screen.dart';
import 'spreadsheet_assist_residencial_screen.dart';

class AssistListScreen extends StatefulWidget {
  final List<String>? initialStatusFilter;

  const AssistListScreen({
    super.key,
    this.initialStatusFilter,
  });

  @override
  State<AssistListScreen> createState() => AssistListScreenState();
}

class AssistListScreenState extends State<AssistListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<Claim> _assists = [];
  List<Claim> _filteredAssists = [];
  bool _isLoading = false;
  bool _hideConcluido = false;
  bool _isAdmin = false;
  final AuthService _authService = AuthService();
  bool _shouldReset = true;
  // Etapa 05: abre só com o que está em curso; o histórico (finalizados) é
  // baixado quando o filtro pede ("Todos" ou um status finalizado).
  bool _historicoCarregado = false;
  bool _carregandoHistorico = false;

  // Filtros (simplificados para dropdown único)
  String? _selectedStatusFilter;
  String? _selectedTipoFilter;

  // Filtros de Período
  String _selectedPeriodo = 'Todo período';
  DateTime? _periodoInicio;
  DateTime? _periodoFim;

  // Filtro de Oficina
  String _oficinaFilter = '';

  // Filtro de Funcionário
  String? _selectedFuncionarioId;
  List<Map<String, dynamic>> _funcionarios = [];

  final List<String> _statusOptions = [
    'Todos',
    'Aberto',
    'Em Andamento',
    'Aguardando Cliente',
    'Concluído',
    'Cancelado',
  ];

  final List<String> _tipoOptions = [
    'Todos',
    'Guincho',
    'Vidro Quebrado',
    'Combustível',
    'Pane Elétrica',
    'Carga de Bateria',
    'Falta de Peça',
    'Reboque',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null && widget.initialStatusFilter!.isNotEmpty) {
      final first = widget.initialStatusFilter!.first;
      if (first == 'Não concluído') {
        _selectedStatusFilter = null;
      } else {
        _selectedStatusFilter = first;
      }
    }
    _fetchAssists();
    _searchController.addListener(_filterAssists);
    _loadUserRole();
    _shouldReset = false;
    _carregarFuncionarios().then((_) {
      // Se for admin, não pré-seleciona funcionário
      if (_isAdmin) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final exists = _funcionarios.any((f) => f['id'] == currentUser.uid);
        if (exists) {
          setState(() {
            _selectedFuncionarioId = currentUser.uid;
            _filterAssists();
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
                _filterAssists();
              });
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAssists);
    _searchController.dispose();
    super.dispose();
  }

  void resetFilters() {
    setState(() {
      _selectedStatusFilter = null;
      _selectedTipoFilter = null;
      _selectedPeriodo = 'Todo período';
      _periodoInicio = null;
      _periodoFim = null;
      _oficinaFilter = '';
      _hideConcluido = false;
      _searchController.clear();
      _filterAssists();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shouldReset) {
      // Só reseta se não houver parâmetros iniciais
      if (widget.initialStatusFilter == null) {
        setState(() {
          _selectedStatusFilter = null;
          _selectedTipoFilter = null;
          _selectedPeriodo = 'Todo período';
          _periodoInicio = null;
          _periodoFim = null;
          _oficinaFilter = '';
          _searchController.clear();
          _filterAssists();
        });
      }
      _shouldReset = false;
    }
  }

  // --- FILTRO PARA ADMIN ---
  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    setState(() {
      _isAdmin = role == 'admin';
      if (_isAdmin) {
        // Se admin, não pré-seleciona funcionário
        _selectedFuncionarioId = null;
      } else {
        // Se não admin, pré-seleciona o próprio ID
        final userId = _authService.getUserId();
        if (userId != null) {
          _selectedFuncionarioId = userId;
        }
      }
      _filterAssists();
    });
  }

  // ─── Busca e Filtros ─────────────────────────────────────────────
  Future<void> _fetchAssists() async {
    if (!mounted) return;
    final completo = _historicoCarregado || FiltroStatus.precisaHistorico(_selectedStatusFilter);
    setState(() {
      _isLoading = true;
      _carregandoHistorico = completo && !_historicoCarregado;
    });
    try {
      final all = completo
          ? await _firestoreService.getAllClaims()
          : await _firestoreService.getAllClaimsEmCurso();
      _historicoCarregado = completo;
      _assists = all.where((c) => c.isAssistencia).toList();
      _assists.sort((a, b) => b.dataAbertura.compareTo(a.dataAbertura));
      _filterAssists();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao buscar assistências: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _carregandoHistorico = false;
        });
      }
    }
  }

  /// Baixa o histórico na primeira vez que o filtro precisar dele.
  void _carregarHistoricoSeNecessario() {
    if (!_historicoCarregado && FiltroStatus.precisaHistorico(_selectedStatusFilter)) {
      _fetchAssists();
    }
  }

  void _filterAssists() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredAssists = _assists.where((assist) {
        // ── Filtro Status ──
        // Etapa 05: null = "Em curso"; "Todos" = todos mesmo.
        final matchesStatus = FiltroStatus.corresponde(_selectedStatusFilter, assist.statusAtual);

        // ── Filtro Tipo ──
        final matchesTipo = _selectedTipoFilter == null ||
            _selectedTipoFilter == 'Filtrar por Tipo' ||
            _getTipoLabel(assist.tipoAssistencia ?? 'outro') == _selectedTipoFilter;

        // ── Busca textual ──
        final matchesSearch = query.isEmpty ||
            assist.clientNome.toLowerCase().contains(query) ||
            assist.numeroSinistro.toLowerCase().contains(query) ||
            (assist.tipoAssistencia ?? '').toLowerCase().contains(query) ||
            assist.clientCnpjCpf.toLowerCase().contains(query) ||
            (assist.veiculoSelecionado?.placa?.toLowerCase() ?? '').contains(query);
        
        // --- LÓGICA IS ADMIN ---
        bool matchesFuncionario = true;
          if (!_isAdmin && _selectedFuncionarioId != null) {
            matchesFuncionario = assist.responsavelId == _selectedFuncionarioId;
          }

        // ── Filtro por Período ──
        bool matchesPeriodo = true;
        final dataOcorrencia = assist.dataOcorrencia; // ou dataAbertura
        if (_selectedPeriodo == 'Mês atual') {
          final now = DateTime.now();
          matchesPeriodo = dataOcorrencia.year == now.year &&
              dataOcorrencia.month == now.month;
        } else if (_selectedPeriodo == 'Mês passado') {
          final now = DateTime.now();
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
          matchesPeriodo = dataOcorrencia.year == lastMonthYear &&
              dataOcorrencia.month == lastMonth;
        } else if (_selectedPeriodo == 'Por período') {
          if (_periodoInicio != null && _periodoFim != null) {
            matchesPeriodo = dataOcorrencia.isAfter(_periodoInicio!.subtract(const Duration(days: 1))) &&
                dataOcorrencia.isBefore(_periodoFim!.add(const Duration(days: 1)));
          }
          // Se não tiver datas, NÃO FILTRA (matchesPeriodo permanece true)
        }

        // ── Filtro por Oficina ──
        bool matchesOficina = true;
        if (_oficinaFilter.isNotEmpty) {
          final filterLower = _oficinaFilter.toLowerCase();
          final List<String> nomes = [];
          if (assist.nomeOficina != null && assist.nomeOficina!.isNotEmpty) {
            nomes.add(assist.nomeOficina!.toLowerCase());
          }
          if (assist.workshop != null && assist.workshop!.nome.isNotEmpty) {
            nomes.add(assist.workshop!.nome.toLowerCase());
          }
          for (var w in assist.oficinas) {
            if (w.nome.isNotEmpty) {
              nomes.add(w.nome.toLowerCase());
            }
          }
          matchesOficina = nomes.any((nome) => nome.contains(filterLower));
        }

        // ── Filtro por Funcionário ──
        if (_selectedFuncionarioId != null) {
          // Busca o funcionário selecionado
          Map<String, dynamic>? funcionario;
          try {
            funcionario = _funcionarios.firstWhere(
              (f) => f['id'] == _selectedFuncionarioId,
              orElse: () => {}, // retorna mapa vazio
            );
          } catch (_) {
            funcionario = {};
          }
          final emailFuncionario = funcionario?['email'] as String?;
          final matchId = assist.responsavelId == _selectedFuncionarioId;
          final matchEmail = emailFuncionario != null &&
              assist.responsavelEmail == emailFuncionario;
          matchesFuncionario = matchId || matchEmail;
        }

        return matchesSearch &&
            matchesStatus &&
            matchesTipo &&
            matchesPeriodo &&
            matchesOficina &&
            matchesFuncionario;
      }).toList();
    });
  }

  // ─── MÉTODO PARA CARREGAR FUNCIONÁRIOS ──────────────────────────────
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

  // --- Build Dropdown de Funcionário ---
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
        const DropdownMenuItem(value: null, child: Text('Filtrar por Funcionário')),
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
          _filterAssists();
        });
      },
    );
  }

  // ─── Helpers de UI ────────────────────────────────────────────────
  String _getTipoLabel(String? tipo) {
    const map = {
      'guincho': 'Guincho',
      'vidro': 'Vidro Quebrado',
      'vidro_quebrado': 'Vidro Quebrado',
      'combustivel': 'Combustível',
      'combustível': 'Combustível',
      'pane_eletrica': 'Pane Elétrica',
      'pane_elétrica': 'Pane Elétrica',
      'carga_bateria': 'Carga de Bateria',
      'falta': 'Falta de Peça',
      'falta_de_peça': 'Falta de Peça',
      'reboque': 'Reboque',
      'outro': 'Outro',
    };
    return map[tipo] ?? 'Outro';
  }

  IconData _getTipoIcon(String? tipo) {
    switch (tipo) {
      case 'guincho':
        return Icons.directions_car;
      case 'vidro':
      case 'vidro_quebrado':
        return Icons.broken_image;
      case 'combustivel':
      case 'combustível':
        return Icons.local_gas_station;
      case 'pane_eletrica':
      case 'pane_elétrica':
        return Icons.flash_on;
      case 'carga_bateria':
        return Icons.battery_charging_full;
      case 'falta':
      case 'falta_de_peça':
        return Icons.build;
      case 'reboque':
        return Icons.local_taxi;
      default:
        return Icons.support_agent;
    }
  }

  Color _getSlaColor(Claim assist) {
    if (assist.statusAtual == 'Concluído') return const Color(0xFF6366F1);
    if (assist.statusAtual == 'Cancelado') return Colors.grey;

    final slaAtivo = assist.slaAtendimento ?? assist.slaPrevisto;
    if (slaAtivo == null) return Colors.grey;

    final agora = DateTime.now();
    if (agora.isAfter(slaAtivo)) return Colors.red;

    final total = slaAtivo.difference(
      assist.slaAtendimento != null
          ? slaAtivo.subtract(Duration(minutes: assist.tempoSlaMinutos ?? 30))
          : assist.dataAbertura,
    ).inMinutes;
    final decorrido = agora.difference(
      assist.slaAtendimento != null
          ? slaAtivo.subtract(Duration(minutes: assist.tempoSlaMinutos ?? 30))
          : assist.dataAbertura,
    ).inMinutes;

    if (total > 0 && decorrido / total >= 0.8) return Colors.orange;
    return Colors.green;
  }

  String _getSlaText(Claim assist) {
    if (assist.statusAtual == 'Concluído') return 'Concluído ✓';
    if (assist.statusAtual == 'Cancelado') return 'Cancelado';

    // ✨ Considera agendamento se preenchido
    final dataLimite = assist.dataAgendamento ?? assist.slaAtendimento ?? assist.slaPrevisto;
    if (dataLimite == null) return 'SLA não definido';

    final agora = DateTime.now();
    final diferenca = dataLimite.difference(agora);

    // Define prefixo baseado na fonte de dados
    final prefixo = assist.dataAgendamento != null
        ? '📅 '  // Agendamento
        : assist.slaAtendimento != null
            ? '🚗 '  // SLA de Atendimento
            : '';   // SLA Previsto

    if (diferenca.isNegative) {
      // Atrasado
      final absoDiff = agora.difference(dataLimite);
      return '${prefixo}+${_formatarTempoInteligente(absoDiff)} atrasado';
    }

    // Dentro do prazo
    return '${prefixo}${_formatarTempoInteligente(diferenca)} restante';
  }

  /// Formata tempo de forma inteligente
  /// < 60min → minutos
  /// < 24h → horas
  /// >= 24h → dias
  String _formatarTempoInteligente(Duration duracao) {
    if (duracao.inHours < 1) {
      final minutos = duracao.inMinutes;
      return '${minutos}min';
    } else if (duracao.inHours < 24) {
      final horas = duracao.inHours;
      final minutos = duracao.inMinutes % 60;
      return minutos > 0 ? '${horas}h ${minutos}min' : '${horas}h';
    } else {
      final dias = duracao.inDays;
      final horas = (duracao.inHours % 24);
      return horas > 0 ? '${dias}d ${horas}h' : '${dias}d';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Aberto':
        return Colors.blue;
      case 'Em Andamento':
        return Colors.orange;
      case 'Aguardando Cliente':
        return Colors.purple;
      case 'Concluído':
        return const Color(0xFF6366F1);
      case 'Cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ─── Widgets de Card ─────────────────────────────────────────────
  Widget _buildCard(Claim assist) {
    final slaColor = _getSlaColor(assist);
    final statusColor = _getStatusColor(assist.statusAtual);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => AssistDetailScreen(assistId: assist.id),
                ),
              )
              .then((_) => _fetchAssists());
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
                    backgroundColor: const Color(0xFFFFA500).withOpacity(0.2),
                    child: Icon(
                      _getTipoIcon(assist.tipoAssistencia),
                      size: 18,
                      color: const Color(0xFFFFA500),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      assist.numeroSinistro,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
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
                assist.clientNome,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Text(
                _getTipoLabel(assist.tipoAssistencia),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(assist.dataAbertura),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: slaColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: slaColor.withOpacity(0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 12, color: slaColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getSlaText(assist),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: slaColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(assist.statusAtual, style: const TextStyle(fontSize: 12)),
                    backgroundColor: statusColor.withOpacity(0.2),
                    labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- FILTRO POR PERÍODO ---
  Widget _buildPeriodoDropdown() {
    final periodos = ['Todo período', 'Mês atual', 'Mês passado', 'Por período'];
    return DropdownButtonFormField<String>(
      value: _selectedPeriodo,
      isDense: true,
      decoration: InputDecoration(
        hintText: 'Período',
        prefixIcon: const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
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
      items: periodos.map((p) {
        return DropdownMenuItem(value: p, child: Text(p));
      }).toList(),
      onChanged: (val) {
        setState(() {
          _selectedPeriodo = val!;
          if (_selectedPeriodo != 'Por período') {
            _periodoInicio = null;
            _periodoFim = null;
          }
          _filterAssists();
        });
      },
    );
  }

  // --- FILTRO POR OFICNA ---
  Widget _buildOficinaTextField() {
    return TextFormField(
      initialValue: _oficinaFilter,
      decoration: InputDecoration(
        hintText: 'Filtrar por Oficina',
        prefixIcon: const Icon(Icons.build, size: 18, color: Colors.grey),
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
        suffixIcon: _oficinaFilter.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  setState(() {
                    _oficinaFilter = '';
                    _filterAssists();
                  });
                },
              )
            : null,
      ),
      onChanged: (value) {
        setState(() {
          _oficinaFilter = value;
          _filterAssists();
        });
      },
    );
  }

  // --- CAMPO DE SELEÇÃO DE DATA ---
  Widget _buildDatePickerField({
    required String label,
    required DateTime? selectedDate,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
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
          suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
        ),
        child: Text(
          selectedDate != null
              ? DateFormat('dd/MM/yyyy').format(selectedDate)
              : 'Selecione',
          style: TextStyle(color: selectedDate == null ? Colors.grey.shade600 : Colors.black),
        ),
      ),
    );
  }

  // ─── Widgets de Filtros ──────────────────────────────────────────
  Widget _buildFilterDropdown<T>({
    required T? value,
    required List<T> items,
    required String hint,
    required IconData icon,
    required void Function(T?) onChanged,
    String rotuloNulo = 'Todos',
  }) {
    return DropdownButtonFormField<T?>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        hintText: value == null ? hint : null,
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
      items: [
        DropdownMenuItem<T?>(value: null, child: Text(rotuloNulo)),
        ...items.map((item) => DropdownMenuItem<T?>(value: item, child: Text(item.toString()))),
      ],
      onChanged: onChanged,
    );
  }
  // ─── FAB para Nova Assistência ──────────────────────────────────

  Future<void> _mostrarSeletorTipoAssist() async {
    const options = [
      PickerOption(
        label: 'Assistência Veicular',
        value: 'veiculo',
        icon: Icons.directions_car_outlined,
        color: Color(0xFF1565C0),
        description: 'Guincho, vidro, combustível, pane...',
      ),
      PickerOption(
        label: 'Assistência Residencial',
        value: 'residencial',
        icon: Icons.home_outlined,
        color: Color(0xFF2E7D32),
        description: 'Eletricista, encanador, chaveiro...',
      ),
    ];

    final tipo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OptionPickerDialog(
        title: 'Nova Assistência',
        subtitle: 'Selecione o tipo de atendimento',
        options: options,
      ),
    );

    if (tipo != null && mounted) {
      late final Widget tela;
      if (tipo == 'veiculo') {
        tela = SpreadsheetAssistScreen(tipoAssistencia: tipo);
      } else {
        tela = SpreadsheetAssistScreen(tipoAssistencia: 'residencial');
      }

      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => tela),
      );
      if (result == true && mounted) {
        _fetchAssists();
      }
    }
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
          'Assistências',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _fetchAssists,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _selectedPeriodo == 'Por período' ? 170.0 : 130.0,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              children: [
                // ── Linha 1: Busca ──
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por Nome, CPF, CNPJ, N° Assistência ou Placa',
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
                const SizedBox(height: 4),

                // ── Linha 2: Status + Tipo ──
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _selectedStatusFilter,
                        // Etapa 05: "Em curso" (padrão) · "Todos" · cada status
                        items: [FiltroStatus.todos, ..._statusOptions.where((s) => s != 'Todos')],
                        rotuloNulo: FiltroStatus.emCurso,
                        hint: 'Filtrar por Status',
                        icon: Icons.filter_list,
                        onChanged: (val) {
                          setState(() {
                            _selectedStatusFilter = val;
                            _filterAssists();
                          });
                          _carregarHistoricoSeNecessario();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _selectedTipoFilter,
                        items: _tipoOptions.where((s) => s != 'Todos').toList(),
                        hint: 'Filtrar por Tipo',
                        icon: Icons.category,
                        onChanged: (val) {
                          setState(() {
                            _selectedTipoFilter = val;
                            _filterAssists();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Linha 3: Período + Oficina + Funcionário ──
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildPeriodoDropdown(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildOficinaTextField(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: _buildFuncionarioDropdown(),
                    ),
                  ],
                ),

                // ── Linha extra: datas para "Por período" ──
                if (_selectedPeriodo == 'Por período') ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerField(
                          label: 'Data Início',
                          selectedDate: _periodoInicio,
                          onChanged: (date) {
                            setState(() {
                              _periodoInicio = date;
                              _filterAssists();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDatePickerField(
                          label: 'Data Fim',
                          selectedDate: _periodoFim,
                          onChanged: (date) {
                            setState(() {
                              _periodoFim = date;
                              _filterAssists();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (_carregandoHistorico) ...[
                    const SizedBox(height: 12),
                    Text('Carregando histórico…', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ],
              ),
            );
          }

          if (_filteredAssists.isEmpty) {
            return Center(
              child: Text(
                _searchController.text.isEmpty &&
                        _selectedStatusFilter == null &&
                        _selectedTipoFilter == null
                    ? 'Nenhuma assistência registrada.'
                    : 'Nenhuma assistência encontrada com os filtros aplicados.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          if (constraints.maxWidth > 600) {
            final crossAxisCount = (constraints.maxWidth / 400).floor().clamp(2, 4);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 200,
                ),
                itemCount: _filteredAssists.length,
                itemBuilder: (context, index) => _buildCard(_filteredAssists[index]),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _fetchAssists,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _filteredAssists.length,
              itemBuilder: (context, index) => _buildCard(_filteredAssists[index]),
            ),
          );
        },
      ),
    );
  }
}