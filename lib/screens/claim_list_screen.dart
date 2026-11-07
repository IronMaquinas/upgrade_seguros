import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import '../models/claim_model.dart';
import '../services/firestore_service.dart';
import '../screens/claim_detail_screen.dart';
import '../screens/spreadsheet_claim_screen.dart';

class ClaimListScreen extends StatefulWidget {
  const ClaimListScreen({
    super.key,
    this.initialStatusFilter,
    this.initialRamoFilter,
    this.initialSlaFilter,
    this.showAppBar = true,
  });

  final String? initialStatusFilter;
  final String? initialRamoFilter;
  final String? initialSlaFilter;
  final bool showAppBar;

  @override
  State<ClaimListScreen> createState() => ClaimListScreenState();
}

class ClaimListScreenState extends State<ClaimListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<Claim> _claims = [];
  List<Claim> _filteredClaims = [];
  bool _isLoading = false;
  bool _hideConcluido = false;
  bool _isAdmin = false;
  final AuthService _authService = AuthService();
  bool _shouldReset = true;

  String? _selectedStatusFilter;
  String? _selectedRamoFilter;
  String _selectedSlaFilter = 'Todos';

  String _selectedPeriodo = 'Todo período';
  DateTime? _periodoInicio;
  DateTime? _periodoFim;
  String _oficinaFilter = '';

  // Filtro por Funcionário
  String? _selectedFuncionarioId;
  List<Map<String, dynamic>> _funcionarios = [];

  final List<String> _statusOptions = [
    'Todos',
    'Rascunho',
    'Aberto',
    'Vistoria em Andamento',
    'Aguardando Aprovação',
    'Aguardando Peças',
    'Reparo em Andamento',
    'Concluído',
  ];

  final List<String> _ramoOptions = [
    'Todos',
    'Frota',
    'Civil Ônibus (RCO)',
    'Transporte',
    'Veículo Individual',
    'Residencial',
    'Empresarial',
    'Vidas',
    'Máquinas',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatusFilter = widget.initialStatusFilter;
    if (_selectedStatusFilter == 'Não concluído') {
      _selectedStatusFilter = null;
    }
    _selectedRamoFilter = widget.initialRamoFilter;
    _selectedSlaFilter = widget.initialSlaFilter ?? 'Todos';
    _shouldReset = false;
    _fetchClaims();
    _searchController.addListener(_filterClaims);
    _loadUserRole();
    _carregarFuncionarios().then((_) {
      if (_isAdmin) return;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final exists = _funcionarios.any((f) => f['id'] == currentUser.uid);
        if (exists) {
          setState(() {
            _selectedFuncionarioId = currentUser.uid;
            _filterClaims();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClaims);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shouldReset) {
      if (widget.initialRamoFilter == null && widget.initialStatusFilter == null) {
        setState(() {
          _selectedRamoFilter = null;
          _selectedStatusFilter = null;
          _selectedSlaFilter = 'Todos';
          _selectedPeriodo = 'Todo período';
          _periodoInicio = null;
          _periodoFim = null;
          _oficinaFilter = '';
          _searchController.clear();
          _filterClaims();
        });
      }
      _shouldReset = false;
    }
  }

  @override
  void didUpdateWidget(covariant ClaimListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se os novos parâmetros forem null, queremos resetar na próxima reativação
    if (widget.initialRamoFilter == null && widget.initialStatusFilter == null) {
      _shouldReset = true;
    }
  }

  void resetFilters() {
    setState(() {
      _shouldReset = false;
      _selectedStatusFilter = null;
      _selectedRamoFilter = null;
      _selectedSlaFilter = 'Todos';
      _selectedPeriodo = 'Todo período';
      _periodoInicio = null;
      _periodoFim = null;
      _oficinaFilter = '';
      _hideConcluido = false;
      _searchController.clear();
      _filterClaims();
    });
  }

  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    setState(() {
      _isAdmin = role == 'admin';
      if (_isAdmin) {
        _selectedFuncionarioId = null;
      } else {
        final userId = _authService.getUserId();
        if (userId != null) {
          _selectedFuncionarioId = userId;
        }
      }
      _filterClaims();
    });
  }

  // ─── Busca e Filtros ─────────────────────────────────────────────
  Future<void> _fetchClaims() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final claims = await _firestoreService.getClaims();
      if (mounted) {
        setState(() {
          _claims = claims;
          _filterClaims();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar sinistros: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            'email': email, // mantemos para exibição, mas não usamos no filtro
          };
        }).toList();
      });
      print('Funcionários carregados: ${_funcionarios.length}');
    } catch (e) {
      print('Erro ao carregar funcionários: $e');
    }
  }

  void _filterClaims() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredClaims = _claims.where((claim) {
        // ── Busca textual ──
        final matchesSearch = query.isEmpty ||
            claim.numeroSinistro.toLowerCase().contains(query) ||
            claim.numeroSeguradora.toLowerCase().contains(query) ||
            claim.clientNome.toLowerCase().contains(query) ||
            claim.clientCnpjCpf.toLowerCase().contains(query) ||
            _getPlacasParaBusca(claim).toLowerCase().contains(query);

        // ── Filtro Status ──
        final matchesStatus = _selectedStatusFilter == null ||
            _selectedStatusFilter == 'Todos' ||
            claim.statusAtual == _selectedStatusFilter;

        // ── Filtro Ramo ──
        final matchesRamo = _selectedRamoFilter == null ||
            _selectedRamoFilter == 'Todos' ||
            claim.ramoSinistro == _selectedRamoFilter;
        
        // --- FILTRO VINDO DA DASHBOARD_CONTENT ---
        // ── Filtro de ocultar concluídos (quando não há filtro de status específico) ──
        final bool ocultarConcluidos = (_selectedStatusFilter == null);
        final bool matchesStatusConcluido = ocultarConcluidos ? claim.statusAtual != 'Concluído' : true;

        // ── Filtro SLA ──
        bool matchesSla = true;
        if (_selectedSlaFilter == 'Em Risco' || _selectedSlaFilter == 'Vencidos') {
          if (claim.statusAtual == 'Concluído' || claim.slaPrevisto == null) {
            matchesSla = false;
          } else {
            final diasRestantes = claim.slaPrevisto!.difference(DateTime.now()).inDays;
            if (_selectedSlaFilter == 'Em Risco') {
              matchesSla = diasRestantes >= 1 && diasRestantes <= 3;
            } else if (_selectedSlaFilter == 'Vencidos') {
              matchesSla = diasRestantes < 0;
            }
          }
        }

        // ── Filtro Período (AGORA USANDO dataAbertura) ──
        bool matchesPeriodo = true;
        final dataAbertura = claim.dataAbertura; // <-- TROCADO de dataOcorrencia para dataAbertura
        if (_selectedPeriodo == 'Mês atual') {
          final now = DateTime.now();
          matchesPeriodo = dataAbertura.year == now.year &&
              dataAbertura.month == now.month;
          if (!matchesPeriodo) {
          }
        } else if (_selectedPeriodo == 'Mês passado') {
          final now = DateTime.now();
          final lastMonth = now.month == 1 ? 12 : now.month - 1;
          final lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
          matchesPeriodo = dataAbertura.year == lastMonthYear &&
              dataAbertura.month == lastMonth;
        } else if (_selectedPeriodo == 'Por período') {
          if (_periodoInicio != null && _periodoFim != null) {
            matchesPeriodo = dataAbertura.isAfter(_periodoInicio!.subtract(const Duration(days: 1))) &&
                dataAbertura.isBefore(_periodoFim!.add(const Duration(days: 1)));
          }
          // Se não tiver datas, não filtra
        }

        // ── Filtro Oficina ──
        bool matchesOficina = true;
        if (_oficinaFilter.isNotEmpty) {
          final filterLower = _oficinaFilter.toLowerCase();
          final List<String> nomes = [];
          if (claim.nomeOficina != null && claim.nomeOficina!.isNotEmpty) {
            nomes.add(claim.nomeOficina!.toLowerCase());
          }
          if (claim.workshop != null && claim.workshop!.nome.isNotEmpty) {
            nomes.add(claim.workshop!.nome.toLowerCase());
          }
          for (var w in claim.oficinas) {
            if (w.nome.isNotEmpty) {
              nomes.add(w.nome.toLowerCase());
            }
          }
          matchesOficina = nomes.any((nome) => nome.contains(filterLower));
        }

        // ── Filtro Funcionário ──
        bool matchesFuncionario = true;
        if (!_isAdmin && _selectedFuncionarioId != null) {
          matchesFuncionario = claim.responsavelId == _selectedFuncionarioId;
        }

        return matchesSearch &&
            matchesStatus &&
            matchesRamo &&
            matchesSla &&
            matchesPeriodo &&
            matchesOficina &&
            matchesFuncionario &&
            matchesStatusConcluido;
      }).toList();
    });
  }

  // ─── Novos widgets de filtro ─────────────────────────────────────
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
          _filterClaims();
        });
      },
    );
  }

  Widget _buildOficinaTextField() {
    return TextFormField(
      initialValue: _oficinaFilter,
      decoration: InputDecoration(
        hintText: 'Filtrar por Oficina',
        prefixIcon: const Icon(Icons.business, size: 18, color: Colors.grey),
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
                    _filterClaims();
                  });
                },
              )
            : null,
      ),
      onChanged: (value) {
        setState(() {
          _oficinaFilter = value;
          _filterClaims();
        });
      },
    );
  }

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

  Widget _buildFuncionarioDropdown() {
    return DropdownButtonFormField<String>(
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
        ..._funcionarios.map((f) {
          final nome = f['nome'] as String;
          final email = f['email'] as String?;
          return DropdownMenuItem(
            value: f['id'] as String,
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
          _filterClaims();
        });
      },
    );
  }

  String _getPlacasParaBusca(Claim claim) {
    switch (claim.ramoSinistro) {
      case 'Frota':
      case 'Veículo Individual':
      case 'Civil Ônibus (RCO)':
        return claim.veiculoSelecionado?.placa ?? '';
      case 'Transporte':
        final t = claim.transporte;
        if (t != null) return '${t.placaCavalo} ${t.placaCarreta ?? ""}';
        return '';
      default:
        return '';
    }
  }

  // ─── Helpers de UI ────────────────────────────────────────────────
  IconData _getRamoIcon(String ramo) {
    switch (ramo) {
      case 'Frota':
        return Icons.directions_transit;
      case 'Transporte':
        return Icons.local_shipping;
      case 'Civil Ônibus (RCO)':
        return Icons.directions_bus;
      case 'Veículo Individual':
        return Icons.directions_car;
      case 'Residencial':
        return Icons.home;
      case 'Vidas':
        return Icons.person;
      case 'Máquinas':
        return Icons.settings;
      case 'Empresarial':
        return Icons.business;
      default:
        return Icons.assignment;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Rascunho':
        return Colors.grey.shade500;
      case 'Aberto':
        return Colors.red.shade400;
      case 'Vistoria em Andamento':
        return Colors.orange.shade400;
      case 'Aguardando Aprovação':
        return Colors.yellow.shade700;
      case 'Aguardando Peças':
        return Colors.blueGrey.shade400;
      case 'Reparo em Andamento':
        return Colors.blue.shade400;
      case 'Concluído':
        return const Color(0xFF6366F1);
      default:
        return Colors.grey;
    }
  }

  String _formatNumeroSinistro(Claim claim) {
    if (claim.numeroSeguradora.isNotEmpty) {
      return '${claim.numeroSinistro} | ${claim.numeroSeguradora}';
    }
    return claim.numeroSinistro;
  }

  String _getRamoSpecificInfo(Claim claim) {
    switch (claim.ramoSinistro) {
      case 'Frota':
      case 'Veículo Individual':
      case 'Civil Ônibus (RCO)':  
        if (claim.veiculoSelecionado != null) {
          final v = claim.veiculoSelecionado!;
          return '${v.placa.isNotEmpty ? v.placa : "Placa N/I"} | ${v.marca} ${v.modelo}';
        }
        return 'Veículo não informado';
      case 'Transporte':
        final t = claim.transporte;
        if (t != null) {
          return 'Cavalo: ${t.placaCavalo} | Carreta: ${t.placaCarreta ?? "N/I"}';
        }
        return 'Placas não informadas';
      case 'Máquinas':
        final m = claim.maquinaria;
        if (m != null) {
          return '${m.modelo} | Série: ${m.numeroSerie}';
        }
        return 'Máquina não informada';
      default:
        return claim.ramoSinistro;
    }
  }

  // ─── Widgets de Card ─────────────────────────────────────────────

  Widget _buildCard(Claim claim) {
    final isRascunho = claim.statusAtual == 'Rascunho';
    final statusColor = _getStatusColor(claim.statusAtual);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClaimDetailScreen(claim: claim)),
          );
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
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(
                      isRascunho ? Icons.edit_note : _getRamoIcon(claim.ramoSinistro),
                      size: 18,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatNumeroSinistro(claim),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                claim.clientNome,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Text(
                isRascunho ? 'Pendente de preenchimento' : _getRamoSpecificInfo(claim),
                style: TextStyle(
                  fontSize: 13,
                  color: isRascunho ? Colors.grey : Colors.black87,
                  fontStyle: isRascunho ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd/MM/yyyy').format(claim.dataOcorrencia),
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(claim.statusAtual, style: const TextStyle(fontSize: 12)),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Widgets de Filtros ──────────────────────────────────────────

  Widget _buildSlaButton(String label, IconData icon) {
    final isSelected = _selectedSlaFilter == label;
    final iconColor = label == 'Em Risco'
        ? Colors.orange
        : label == 'Vencidos'
            ? Colors.red
            : Colors.grey.shade700;

    return SizedBox(
      height: 38, // 🔥 Reduzido para caber na linha da busca
      child: Tooltip(
        message: label,
        child: Material(
          color: isSelected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          elevation: isSelected ? 0 : 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              setState(() {
                _selectedSlaFilter = label;
                _filterClaims();
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: isSelected ? Colors.white : iconColor, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T? value,
    required List<T?> items,
    required String hint,
    required IconData icon,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T?>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        hintText: value == null ? hint : null, // só mostra hint se não tiver valor
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
        return DropdownMenuItem<T?>(
          value: item,
          child: Text(item == null ? 'Todos' : item.toString()),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  // ─── FAB para Novo Sinistro ──────────────────────────────────────

  Future<void> _showRamoPickerGlobal() async {
    const ramos = [
      _RamoOption(label: 'Veículo / Frota',          icon: Icons.directions_car_outlined,  ramo: 'Frota',               color: Color(0xFF1565C0)),
      _RamoOption(label: 'Veículo Individual',       icon: Icons.car_rental_outlined,      ramo: 'Veículo Individual',  color: Color(0xFFD4A017)),
      _RamoOption(label: 'Civil Ônibus (RCO)',       icon: Icons.directions_bus_outlined,  ramo: 'Civil Ônibus (RCO)',  color: Color(0xFF00838F)),
      _RamoOption(label: 'Transporte',               icon: Icons.local_shipping_outlined,  ramo: 'Transporte',          color: Color(0xFF2E7D32)),
      _RamoOption(label: 'Máquinas e Equipamentos',  icon: Icons.settings_outlined,        ramo: 'Máquinas',            color: Color(0xFFFF6F00)),
      _RamoOption(label: 'Residencial',              icon: Icons.home_outlined,            ramo: 'Residencial',         color: Color(0xFFBF360C)),
      _RamoOption(label: 'Empresarial',              icon: Icons.business_outlined,        ramo: 'Empresarial',         color: Color(0xFF424242)),
      _RamoOption(label: 'Vidas',                    icon: Icons.favorite_outline,         ramo: 'Vidas',               color: Color(0xFF6A1B9A)),
    ];
    final ramo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tipo de sinistro',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 4),
                Text('Selecione o ramo para personalizar os campos',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                const SizedBox(height: 18),
                ...ramos.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(ctx).pop(r.ramo),
                          child: Container(
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade200, width: 0.8),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: r.color.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(r.icon, color: r.color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(r.label,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E))),
                                const Spacer(),
                                Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (ramo != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SpreadsheetClaimScreen(ramoSelecionado: ramo)),
      );
      _fetchClaims();
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
          'Sinistros',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _fetchClaims,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(
            _selectedPeriodo == 'Por período' ? 190.0 : 150.0,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              children: [
                // ── Linha 1: Busca + Botões SLA ──
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por Nome, CPF, CNPJ, N° Sinistro ou Placa',
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
                    const SizedBox(width: 8),
                    _buildSlaButton('Todos', Icons.list),
                    const SizedBox(width: 4),
                    _buildSlaButton('Em Risco', Icons.warning),
                    const SizedBox(width: 4),
                    _buildSlaButton('Vencidos', Icons.error),
                  ],
                ),
                const SizedBox(height: 6),

                // ── Linha 2: Status + Ramo ──
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _selectedStatusFilter,
                        items: [
                          null,
                          'Todos',
                          ..._statusOptions.where((s) => s != 'Todos').toList(),
                        ],
                        hint: 'Filtrar por Status',
                        icon: Icons.filter_list,
                        onChanged: (val) {
                          setState(() {
                            //_hideConcluido = false;
                            _selectedStatusFilter = val;
                            _filterClaims();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildFilterDropdown<String>(
                        value: _selectedRamoFilter,
                        items: [null, ..._ramoOptions.where((s) => s != 'Todos').toList()],
                        hint: 'Filtrar por Ramo',
                        icon: Icons.category,
                        onChanged: (val) {
                          setState(() {
                            _hideConcluido = false;
                            _selectedRamoFilter = val;
                            _filterClaims();
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatePickerField(
                          label: 'Data Início',
                          selectedDate: _periodoInicio,
                          onChanged: (date) {
                            setState(() {
                              _periodoInicio = date;
                              _filterClaims();
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
                              _filterClaims();
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
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredClaims.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.isEmpty &&
                              _selectedStatusFilter == null &&
                              _selectedRamoFilter == null
                          ? 'Nenhum sinistro registrado.'
                          : 'Nenhum sinistro encontrado com os filtros aplicados.',
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
                      itemCount: _filteredClaims.length,
                      itemBuilder: (context, index) => _buildCard(_filteredClaims[index]),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _fetchClaims,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _filteredClaims.length,
                    itemBuilder: (context, index) => _buildCard(_filteredClaims[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRamoPickerGlobal,
        label: const Text('Novo Sinistro'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        heroTag: 'newClaimInList',
      ),
    );
  }
}

class _RamoOption {
  final String label;
  final IconData icon;
  final String ramo;
  final Color color;
  const _RamoOption({
    required this.label,
    required this.icon,
    required this.ramo,
    required this.color,
  });
}