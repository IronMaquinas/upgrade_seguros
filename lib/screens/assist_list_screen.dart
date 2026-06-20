// lib/screens/assist_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/claim_model.dart';
import '../services/firestore_service.dart';
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
  State<AssistListScreen> createState() => _AssistListScreenState();
}

class _AssistListScreenState extends State<AssistListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Claim> _assists = [];
  List<Claim> _filteredAssists = [];
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  List<String> _selectedStatusFilters = [];
  String? _selectedTipoFilter;

  final List<String> _statusOptions = [
    'Aberto',
    'Em Andamento',
    'Aguardando Cliente',
    'Concluído',
    'Cancelado',
  ];

  final List<String> _tipoOptions = [
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
    if (widget.initialStatusFilter != null) {
      _selectedStatusFilters = List.from(widget.initialStatusFilter!);
    }
    _fetchAssists();
    _searchController.addListener(_filterAssists);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAssists);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAssists() async {
    if (mounted) setState(() => _isLoading = true);
    setState(() => _isLoading = true);
    try {
      final all = await _firestoreService.getAllClaims();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAssists() {
    final query = _searchController.text.toLowerCase().trim();

    _filteredAssists = _assists.where((assist) {
      // Filtro por status
      if (_selectedStatusFilters.isNotEmpty &&
          !_selectedStatusFilters.contains(assist.statusAtual)) {
        return false;
      }

      // Filtro por tipo de assistência
      if (_selectedTipoFilter != null) {
        final tipoLabel = _getTipoLabel(assist.tipoAssistencia ?? 'outro');
        if (tipoLabel != _selectedTipoFilter) {
          return false;
        }
      }

      // Se não há texto na busca, retorna true (apenas filtros)
      if (query.isEmpty) return true;

      // Busca nos campos relevantes
      final nomeCliente = assist.clientNome.toLowerCase();
      final numeroSinistro = assist.numeroSinistro.toLowerCase();
      final tipoAssist = (assist.tipoAssistencia ?? '').toLowerCase();
      final cnpjCpf = assist.clientCnpjCpf.toLowerCase();
      final placa = assist.veiculoSelecionado?.placa?.toLowerCase() ?? '';

      return nomeCliente.contains(query) ||
          numeroSinistro.contains(query) ||
          tipoAssist.contains(query) ||
          cnpjCpf.contains(query) ||
          placa.contains(query);
    }).toList();

    // Atualiza a UI (se o widget ainda estiver montado)
    if (mounted) setState(() {});
  }

  // POP UP DO FAB - Nova Assistência
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
        tela = const SpreadsheetAssistScreen();
      } else {
        // tipo == 'residencial'
        tela = const SpreadsheetAssistResidencialScreen();
      }

      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => tela),
      );

      if (result == true && mounted) {
        _fetchAssists();
      }
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────

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
    if (assist.statusAtual == 'Concluído') return Colors.green;
    if (assist.statusAtual == 'Cancelado') return Colors.grey;

    // Usa slaAtendimento se disponível, senão slaPrevisto
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

    // Usa slaAtendimento se disponível, senão slaPrevisto
    final slaAtivo = assist.slaAtendimento ?? assist.slaPrevisto;
    if (slaAtivo == null) return 'SLA não definido';

    final agora = DateTime.now();
    final diferenca = slaAtivo.difference(agora);

    // Badge extra se for o SLA de atendimento
    final prefixo = assist.slaAtendimento != null ? '🚗 ' : '';

    if (diferenca.isNegative) {
      final minutos = agora.difference(slaAtivo).inMinutes;
      return '${prefixo}+${minutos}min atrasado';
    }

    final minutos = diferenca.inMinutes;
    return '${prefixo}${minutos}min restante';
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
        return Colors.green;
      case 'Cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ─── CARD (mesmo padrão do claim_list e client_list) ──────

  Widget _buildCard(Claim assist) {
    final slaColor = _getSlaColor(assist);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute(
                builder: (_) => AssistDetailScreen(assistId: assist.id),
              ))
              .then((_) => _fetchAssists());
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cabeçalho: Ícone + Número ──
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

              // ── Cliente ──
              Text(
                assist.clientNome,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),

              // ── Tipo de Assistência ──
              Text(
                _getTipoLabel(assist.tipoAssistencia),
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),

              // ── Data ──
              Text(
                DateFormat('dd/MM/yyyy').format(assist.dataAbertura),
                style: const TextStyle(fontSize: 12, color: Colors.black),
              ),

              const Spacer(),

              // ── SLA + Status ──
              Row(
                children: [
                  // SLA Chip
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                          Icon(Icons.timer_outlined,
                              size: 12, color: slaColor),
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

                  // Status Chip
                  Chip(
                    label: Text(
                      assist.statusAtual,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor:
                        _getStatusColor(assist.statusAtual).withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _getStatusColor(assist.statusAtual),
                      fontWeight: FontWeight.bold,
                    ),
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

  // ─── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Assistências'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    'Buscar por Nome, CPF, CNPJ, N° Assistência ou Placa',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _fetchAssists,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtros inline ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                // Filtro Status
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedStatusFilters.isEmpty ? null : _selectedStatusFilters.first,
                        hint: Row(
                          children: [
                            Icon(Icons.filter_list,
                                size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Text('Todos'),
                          ],
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ..._statusOptions.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() {
                              if (val == null) {
                                _selectedStatusFilters = [];
                              } else {
                                _selectedStatusFilters = [val];
                              }
                            });
                          _filterAssists();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Filtro Tipo
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedTipoFilter,
                        hint: Row(
                          children: [
                            Icon(Icons.category,
                                size: 18, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            const Text('Todos'),
                          ],
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos'),
                          ),
                          ..._tipoOptions.map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t),
                              )),
                        ],
                        onChanged: (val) {
                          setState(() => _selectedTipoFilter = val);
                          _filterAssists();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Grid / Lista ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_filteredAssists.isEmpty) {
                  return Center(
                    child: Text(
                      _searchController.text.isEmpty &&
                              _selectedStatusFilters.isEmpty &&
                              _selectedTipoFilter == null
                          ? 'Nenhuma assistência registrada.'
                          : 'Nenhuma assistência encontrada com os filtros aplicados.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  );
                }

                // Web: Grid
                if (constraints.maxWidth > 600) {
                  final crossAxisCount =
                      (constraints.maxWidth / 400).floor().clamp(2, 4);
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
                      itemBuilder: (context, index) =>
                          _buildCard(_filteredAssists[index]),
                    ),
                  );
                }

                // Mobile: Lista
                return RefreshIndicator(
                  onRefresh: _fetchAssists,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _filteredAssists.length,
                    itemBuilder: (context, index) =>
                        _buildCard(_filteredAssists[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // ── FAB ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarSeletorTipoAssist(),
        label: const Text('Nova Assistência'),
        icon: const Icon(Icons.add),
        backgroundColor: const Color(0xFFFFA500),  // amarelo pastel
        foregroundColor: Colors.white,
        heroTag: 'newAssistInList',
      ),
    );
  }
}