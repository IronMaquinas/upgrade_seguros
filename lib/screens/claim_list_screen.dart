import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
//import 'package:upgrade_seguros/screens/new_claim_screen.dart';
import 'package:upgrade_seguros/screens/quick_claim_screen.dart';
import 'package:upgrade_seguros/screens/spreadsheet_claim_screen.dart';
import '../models/claim_model.dart';
import '../services/firestore_service.dart';
import '../screens/claim_detail_screen.dart';

class ClaimListScreen extends StatefulWidget {
  /// Filtro de status pré-aplicado ao abrir a tela.
  /// Passado pelo dashboard ao clicar nos cards de métricas.
  
  const ClaimListScreen({
    super.key,
    this.initialStatusFilter,
    this.initialRamoFilter,
    this.initialSlaFilter,
  });

  final String? initialStatusFilter;
  final String? initialRamoFilter;
  final String? initialSlaFilter;

  @override
  State<ClaimListScreen> createState() => _ClaimListScreenState();
}

class _ClaimListScreenState extends State<ClaimListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Claim> _claims = [];
  List<Claim> _filteredClaims = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatusFilter;
  String? _selectedRamoFilter;
  String _selectedSlaFilter = 'Todos';  // ← NOVO

  @override
  void initState() {
    super.initState();
    // Aplica filtro inicial se vier do dashboard
    if (widget.initialStatusFilter != null) {
      _selectedStatusFilter = widget.initialStatusFilter;
    }
    if (widget.initialRamoFilter != null) {
      _selectedRamoFilter = widget.initialRamoFilter;
    }
    _fetchClaims();
    _searchController.addListener(_filterClaims);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClaims);
    _searchController.dispose();
    super.dispose();
  }

  // Ícone por ramo
  IconData _getRamoIcon(String ramoSinistro) {
    switch (ramoSinistro) {
      case 'Frota':
        return Icons.directions_transit;
      case 'Transporte':
        return Icons.local_shipping;
      case 'Veículo Individual':
        return Icons.directions_car;
      case 'Residencial':
        return Icons.home;
      case 'Vidas':
        return Icons.person;
      case 'Máquinas':  // 🆕 NOVO
        return Icons.settings;
      default:
        return Icons.assignment;
    }
  }

  // Número formatado (com número da seguradora se disponível)
  String _formatNumeroSinistro(Claim claim) {
    if (claim.numeroSeguradora != null && claim.numeroSeguradora!.isNotEmpty) {
      return '${claim.numeroSinistro} | ${claim.numeroSeguradora!}';
    }
    return claim.numeroSinistro;
  }

  // Informação específica por ramo
  String _getRamoSpecificInfo(Claim claim) {
    switch (claim.ramoSinistro) {
      case 'Frota':
      case 'Veículo Individual':
        if (claim.veiculoSelecionado != null) {
          final veiculo = claim.veiculoSelecionado!;
          return '${veiculo.placa.isNotEmpty ? veiculo.placa : "Placa N/I"} | ${veiculo.marca} ${veiculo.modelo}';
        }
        return 'Veículo não informado';
      case 'Transporte':
        final transporte = claim.transporte;
        if (transporte != null) {
          return 'Cavalo: ${transporte.placaCavalo} | Carreta: ${transporte.placaCarreta ?? "N/I"}';
        }
        return 'Placas não informadas';
      case 'Máquinas':  // 🆕 NOVO
        final maquinaria = claim.maquinaria;
        if (maquinaria != null) {
          return '${maquinaria.modelo} | Série: ${maquinaria.numeroSerie}';
        }
        return 'Máquina não informada';
      default:
        return claim.ramoSinistro;
    }
  }

  // Placas para busca
  String _getPlacasForSearch(Claim claim) {
    switch (claim.ramoSinistro) {
      case 'Frota':
      case 'Veículo Individual':
        return claim.veiculoSelecionado?.placa ?? '';
      case 'Transporte':
        final t = claim.transporte;
        if (t != null) return '${t.placaCavalo} ${t.placaCarreta ?? ""}';
        return '';
      default:
        return '';
    }
  }

  Future<void> _fetchClaims() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final claims = await _firestoreService.getClaims();
      if (mounted) {
        setState(() {
          _claims = claims;
          _filterClaims(); // dentro de _filterClaims também tem setState, mas ele já verifica? não, mas pode usar mounted lá também
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

  // Picker de ramo
  Future<void> _showRamoPickerGlobal() async {
    const ramos = [
      _RamoOption(label: 'Veículo / Frota',    icon: Icons.directions_car_outlined,   ramo: 'Frota',              color: Color(0xFF1565C0)),
      _RamoOption(label: 'Veículo Individual', icon: Icons.car_rental_outlined,       ramo: 'Veículo Individual', color: Color.fromARGB(255, 225, 190, 15)),
      _RamoOption(label: 'Transporte',         icon: Icons.local_shipping_outlined,   ramo: 'Transporte',         color: Color(0xFF2E7D32)),
      _RamoOption(label: 'Máquinas e Equipamentos', icon: Icons.settings_outlined,    ramo: 'Máquinas',           color: Color(0xFFFF6F00)),
      _RamoOption(label: 'Residencial',        icon: Icons.home_outlined,             ramo: 'Residencial',        color: Color(0xFFBF360C)),
      _RamoOption(label: 'Vidas',              icon: Icons.favorite_outline,          ramo: 'Vidas',              color: Color(0xFF6A1B9A)),
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
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E))),
                const SizedBox(height: 4),
                Text('Selecione o ramo para personalizar os campos',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
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
                              border: Border.all(
                                  color: Colors.grey.shade200, width: 0.8),
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
                                  child: Icon(r.icon,
                                      color: r.color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(r.label,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1A1A2E))),
                                const Spacer(),
                                Icon(Icons.chevron_right,
                                    size: 16,
                                    color: Colors.grey.shade300),
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
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
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
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SpreadsheetClaimScreen(ramoSelecionado: ramo),
      ));
    }
  }

  void _filterClaims() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClaims = _claims.where((claim) {
        final placas = _getPlacasForSearch(claim).toLowerCase();

        final matchesSearch =
            claim.numeroSinistro.toLowerCase().contains(query) ||
                claim.numeroSeguradora.toLowerCase().contains(query) ||
                claim.clientNome.toLowerCase().contains(query) ||
                claim.clientCnpjCpf.toLowerCase().contains(query) ||
                placas.contains(query);

        final matchesStatus = _selectedStatusFilter == null ||
            _selectedStatusFilter == 'Todos' ||
            claim.statusAtual == _selectedStatusFilter;

        final matchesRamo = _selectedRamoFilter == null ||
            _selectedRamoFilter == 'Todos' ||
            claim.ramoSinistro == _selectedRamoFilter;

        // ← NOVO: Filtro de SLA
        bool matchesSla = true;
        if (_selectedSlaFilter == 'Em Risco' || _selectedSlaFilter == 'Vencidos') {
          // Só mostra sinistros abertos (não concluídos)
          if (claim.statusAtual == 'Concluído' || claim.slaPrevisto == null) {
            matchesSla = false;
          } else {
            final diasRestantes = claim.slaPrevisto!.difference(DateTime.now()).inDays;
            if (_selectedSlaFilter == 'Em Risco') {
              matchesSla = diasRestantes >= 1 && diasRestantes <= 3;
            } else if (_selectedSlaFilter == 'Vencidos') {
              matchesSla = diasRestantes < 0; // Já venceu
            }
          }
        }

        return matchesSearch && matchesStatus && matchesRamo && matchesSla;
      }).toList();
    });
  }

  // Cores por status — inclui 'Rascunho'
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
        return Colors.green.shade400;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCard(Claim claim) {
    final isRascunho = claim.statusAtual == 'Rascunho';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Rascunhos ficam visualmente distintos com borda tracejada
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClaimDetailScreen(claim: claim),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        _getStatusColor(claim.statusAtual).withOpacity(0.2),
                    child: Icon(
                      isRascunho
                          ? Icons.edit_note
                          : _getRamoIcon(claim.ramoSinistro),
                      size: 18,
                      color: _getStatusColor(claim.statusAtual),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatNumeroSinistro(claim),
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

              // Nome do cliente
              Text(
                claim.clientNome,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),

              // Informação específica do ramo (para rascunhos mostra aviso)
              Text(
                isRascunho
                    ? 'Pendente de preenchimento'
                    : _getRamoSpecificInfo(claim),
                style: TextStyle(
                  fontSize: 13,
                  color: isRascunho ? Colors.grey : Colors.black,
                  fontStyle:
                      isRascunho ? FontStyle.italic : FontStyle.normal,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 8),

              // Data
              Text(
                DateFormat('dd/MM/yyyy').format(claim.dataOcorrencia),
                style:
                    const TextStyle(fontSize: 12, color: Colors.black),
              ),

              const Spacer(),

              // Chip de status
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    claim.statusAtual,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor:
                      _getStatusColor(claim.statusAtual).withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: _getStatusColor(claim.statusAtual),
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
        title: const Text('Sinistros'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // ROW: SEARCH + BOTÕES SLA (responsivo)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // BOTÕES DE SLA — QUADRADOS
                    _buildSlaButton('Todos', Icons.list),
                    const SizedBox(width: 6),
                    _buildSlaButton('Em Risco', Icons.warning),
                    const SizedBox(width: 6),
                    _buildSlaButton('Vencidos', Icons.error),
                  ],
                ),
                const SizedBox(height: 12),
                
                // DROPDOWNS STATUS + RAMO
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatusFilter ?? 'Todos',
                        key: ValueKey(_selectedStatusFilter),
                        decoration: InputDecoration(
                          hintText: 'Status',
                          prefixIcon: const Icon(Icons.filter_list),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        items: [
                          'Todos',
                          'Rascunho',
                          'Aberto',
                          'Vistoria em Andamento',
                          'Aguardando Aprovação',
                          'Aguardando Peças',
                          'Reparo em Andamento',
                          'Concluído',
                        ]
                            .map((status) => DropdownMenuItem(
                                value: status, child: Text(status)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStatusFilter =
                                value == 'Todos' ? null : value;
                            _filterClaims();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedRamoFilter ?? 'Todos',
                        decoration: InputDecoration(
                          hintText: 'Ramo',
                          prefixIcon: const Icon(Icons.category),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        items: [
                          'Todos',
                          'Frota',
                          'Transporte',
                          'Veículo Individual',
                          'Residencial',
                          'Vidas',
                          'Máquinas',
                        ]
                            .map((ramo) => DropdownMenuItem(
                                value: ramo, child: Text(ramo)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRamoFilter =
                                value == 'Todos' ? null : value;
                            _filterClaims();
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
                itemCount: _filteredClaims.length,
                itemBuilder: (context, index) =>
                    _buildCard(_filteredClaims[index]),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _fetchClaims,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _filteredClaims.length,
              itemBuilder: (context, index) =>
                  _buildCard(_filteredClaims[index]),
            ),
          );
        },
      ),

      // ── FAB: Novo Sinistro (unificado) ──────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _showRamoPickerGlobal();
          if (mounted) _fetchClaims();
        },
        label: const Text('Novo Sinistro'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        heroTag: 'newClaimInList',
      ),
    );
  }

  Widget _buildSlaButton(String label, IconData icon) {
    final isSelected = _selectedSlaFilter == label;
    
    Color iconColor = Colors.grey.shade700;
    if (label == 'Em Risco') {
      iconColor = Colors.orange;
    } else if (label == 'Vencidos') {
      iconColor = Colors.red;
    }
    
    return SizedBox(
      height: 48,
      child: Tooltip(
        message: label,
        child: Material(
          color: isSelected ? Colors.blue : Colors.white,
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
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isSelected ? Colors.white : iconColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
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