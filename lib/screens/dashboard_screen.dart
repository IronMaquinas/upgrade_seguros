// screens/dashboard_screen.dart
// ignore_for_file: unnecessary_null_comparison
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:upgrade_seguros/screens/assist_detail_screen.dart';
import 'package:upgrade_seguros/screens/spreadsheet_assist_residencial_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/quick_claim_screen.dart';
import '../screens/spreadsheet_claim_screen.dart';
import '../screens/claim_list_screen.dart';
import '../screens/client_list_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/spreadsheet_assist_screen.dart';
import '../screens/task_list_screen.dart';
import '../screens/assist_list_screen.dart';
import '../widgets/dashboard_content.dart';
import '../widgets/option_picker_dialog.dart';
import '../widgets/assist_tipo_picker.dart';
import '../services/firestore_service.dart';
import '../models/client_model.dart';
import '../screens/claim_list_screen.dart';
import '../screens/assist_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _hasClientsNearExpiry = false;
  final _firestoreService = FirestoreService();

  late final List<Widget> _widgetOptions;
  String? _ramoSelecionado;
  String _ramoSelecionadoLabel = 'Novo Sinistro';

  Map<String, dynamic>? _claimListParams;
  Map<String, dynamic>? _assistListParams;

  // ── Definição dos grupos e campos ─────────────────────────────────────────
  List<_Group> _groups = [];

  @override
  void initState() {
    super.initState();
    _checkClientsNearExpiry();
  }

  void _onNavigateFromDashboard(Widget screen) {
    if (screen is ClaimListScreen) {
      _claimListParams = {
        'initialRamoFilter': screen.initialRamoFilter,
        'initialStatusFilter': screen.initialStatusFilter,
        'initialSlaFilter': screen.initialSlaFilter,
        //'hideConcluido': screen.hideConcluido,
      };
      setState(() {
        _selectedIndex = 1;
      });
    } else if (screen is AssistListScreen) {
      _assistListParams = {
        'initialStatusFilter': screen.initialStatusFilter,
      };
      setState(() {
        _selectedIndex = 2;
      });
    } else {
      // Para detalhes (ClaimDetailScreen, AssistDetailScreen), use push
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => screen),
      );
    }
  }

  Widget _buildCurrentScreen() {
      switch (_selectedIndex) {
    case 0:
      return DashboardContent(
        onNavigate: _onNavigateFromDashboard,
      );
    case 1:
      return ClaimListScreen(
        key: ValueKey('claim_${DateTime.now().millisecondsSinceEpoch}'),
        initialRamoFilter: _claimListParams?['initialRamoFilter'],
        initialStatusFilter: _claimListParams?['initialStatusFilter'],
        initialSlaFilter: _claimListParams?['initialSlaFilter'] ?? 'Todos',
      );
    case 2:
      return AssistListScreen(
        key: ValueKey('assist_${DateTime.now().millisecondsSinceEpoch}'),
        initialStatusFilter: _assistListParams?['initialStatusFilter'],
      );
      case 3:
        return ClientListScreen(
          onNavigate: (screen) {
            setState(() {
              _selectedIndex = 3;
            });
          },
        );
      case 4:
        return TaskListScreen();
      case 5:
        return ReportsScreen();
      case 6:
        return const SettingsScreen();
      default:
        return const SizedBox();
    }
  }

  Future<void> _checkClientsNearExpiry() async {
    try {
      final List<Client> clients = await _firestoreService.getAllClients();
      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(const Duration(days: 30));
      
      final hasNearExpiry = clients.any((client) {
        // Verifica se alguma apólice vence nos próximos 30 dias
        return client.apolices.any((apolice) {
          return apolice.dataFim.isAfter(now) &&
                apolice.dataFim.isBefore(thirtyDaysFromNow);
        });
      });
      
      if (mounted) setState(() => _hasClientsNearExpiry = hasNearExpiry);
    } catch (e) {
      debugPrint('Erro ao verificar apólices vencendo: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // Resetar parâmetros se não for a tela correspondente
      if (index != 1) _claimListParams = null;
      if (index != 2) _assistListParams = null;
    });
  }

  String _ramoToLabel(String ramo) {
    switch (ramo) {
      case 'Frota':              return 'Veículo / Frota';
      case 'Veículo Individual': return 'Veículo Individual';
      case 'Civil Ônibus (RCO)': return 'Veículo Individual';
      case 'Transporte':         return 'Transporte';
      case 'Máquinas':           return 'Máquinas e Equipamentos';
      case 'Residencial':        return 'Residencial';
      case 'Vidas':              return 'Vidas';
      default:                   return ramo;
    }
  }

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
              // Botão Voltar + Cancelar
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showNewItemDialog();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Voltar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ),
  );

  // ✅ NOVO: Apenas abre SpreadsheetClaimScreen com o ramo
  if (ramo != null && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SpreadsheetClaimScreen(ramoSelecionado: ramo),
      ));
    }
  }

  Widget _clientesIcon() => Stack(
        children: [
          const Icon(Icons.people),
          if (_hasClientsNearExpiry)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                constraints:
                    const BoxConstraints(minWidth: 8, minHeight: 8),
              ),
            ),
        ],
      );

  // 🆕 NOVO MODAL PARA SINISTRO (o modal anterior, renomeado)
  void _showOpenSinistroModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Como deseja abrir o sinistro?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha o modo mais adequado ao momento.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
 
            _OpenModeOption(
              icon: Icons.flash_on_rounded,
              color: const Color(0xFF1565C0),
              title: 'Abertura rápida',
              subtitle:
                  'Campos mínimos. Salva como rascunho para completar depois.',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const QuickClaimScreen()));
              },
            ),
            const SizedBox(height: 10),
 
            _OpenModeOption(
              icon: Icons.table_rows_outlined,
              color: const Color(0xFF2E7D32),
              title: 'Abrir registro completo',
              subtitle:
                  'Formulário estruturado em grupos. Melhor para desktop.',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SpreadsheetClaimScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Modal de seleção de modo ──────────────────────────────────────────────
    void _showOpenClaimModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'O que deseja abrir?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha entre Sinistro ou Assistência.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
 
            // 🔴 OPÇÃO 1: SINISTRO
            _OpenModeOption(
              icon: Icons.assignment_outlined,
              color: const Color(0xFF1565C0),
              title: 'Sinistro',
              subtitle: 'Abrir um novo sinistro. Claim complexo com documentação.',
              onTap: () {
                Navigator.pop(ctx);
                _showOpenSinistroModal();
              },
            ),
            const SizedBox(height: 16),
 
            // 🟠 OPÇÃO 2: ASSISTÊNCIA
            _OpenModeOption(
              icon: Icons.emergency_share_outlined,
              color: Colors.orange.shade600,
              title: 'Assistência',
              subtitle:
                  'Guincho, vidro, combustível, pane. Atendimento rápido com SLA.',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SpreadsheetAssistScreen(tipoAssistencia: 'veiculo'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MODAL COM NOVO REGISTRO + CANCELAR
  Widget _buildNewItemDialog() {
      const options = [
    PickerOption(
      label: 'Sinistro Completo',
      value: 'sinistro_completo',
      icon: Icons.assignment_outlined,
      color: Color(0xFF1565C0),
      description: 'Registro completo com ramo e dados',
    ),
    PickerOption(
      label: 'Sinistro Resumido',
      value: 'sinistro_resumido',
      icon: Icons.flash_on_rounded,
      color: Color.fromARGB(255, 233, 102, 108),
      description: 'Abertura rápida - preencha depois',
    ),
    PickerOption(
      label: 'Assistência',
      value: 'assistencia',
      icon: Icons.emergency_outlined,
      color: Color(0xFF2E7D32),
      description: 'Novo atendimento assistencial',
    ),
  ];

    return Dialog(
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
              const Text(
                'Novo Documento',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecione o tipo de registro',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 18),
              // Opções
              ...options.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      if (opt.value == 'sinistro_completo') {
                        Navigator.of(context).pop();
                        _showRamoPickerGlobal();
                      } else if (opt.value == 'sinistro_resumido') {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const QuickClaimScreen(),
                        ));
                      } else if (opt.value == 'assistencia') {
                        Navigator.of(context).pop();
                        _showAssistTipoPickerGlobal();
                      }
                    },
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
                              color: opt.color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(opt.icon, color: opt.color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  opt.label,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  opt.description ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 16),
              // Botão Voltar + Cancelar
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MODAL PARA ASSISTÊNCIA
  // Etapa 06: modal padrão compartilhado com a lista de Assistências.
  Future<void> _showAssistTipoPickerGlobal() async {
    final tipo = await mostrarSeletorTipoAssistencia(
      context,
      onVoltar: _showNewItemDialog, // reabre "Novo Registro"
    );

    if (tipo == 'veiculo' && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const SpreadsheetAssistScreen(tipoAssistencia: 'veiculo'),
      ));
    } else if (tipo == 'residencial' && mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const SpreadsheetAssistScreen(tipoAssistencia: 'residencial'),
      ));
    }
  }

  // Dialog unificado: Sinistro ou Assistência
  Future<void> _showNewItemDialog() async {
    const options = [
      PickerOption(
        label: 'Sinistro',
        value: 'sinistro',
        icon: Icons.assignment_outlined,
        color: Color(0xFF1565C0),
        description: 'Novo registro de sinistro',
      ),
      PickerOption(
        label: 'Assistência',
        value: 'assistencia',
        icon: Icons.emergency_outlined,
        color: Color(0xFF2E7D32),
        description: 'Novo atendimento assistencial',
      ),
    ];

    final tipo = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _buildNewItemDialog(),
    );

    if (tipo == 'sinistro' && mounted) {
        await _showRamoPickerGlobal();
      } else if (tipo == 'assistencia' && mounted) {
        await _showAssistTipoPickerGlobal();
      }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobileDevice =
        !kIsWeb || (kIsWeb && MediaQuery.of(context).size.width < 600);
    final bool isDesktop =
        kIsWeb && MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
 appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'UP',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Upgrade Corretora',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
            ),
          ],
        ),
        actions: [
          // 🆕 SETTINGS - Só em mobile
          if (isMobileDevice)
            IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: Color(0xFF1565C0), size: 20),
              tooltip: 'Configurações',
              onPressed: () {
                setState(() => _selectedIndex = 5);
              },
            ),
          // BOTÃO LOGOUT (EXISTENTE)
          IconButton(
            icon: const Icon(Icons.logout_outlined,
                color: Color(0xFF1A1A2E), size: 20),
            tooltip: 'Sair',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja encerrar a sessão?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sair')),
                  ],
                ),
              );
              if (shouldLogout == true) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  backgroundColor: Colors.white,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  selectedIconTheme:
                      const IconThemeData(color: Color(0xFF1565C0)),
                  selectedLabelTextStyle: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  unselectedLabelTextStyle: TextStyle(
                      color: Colors.grey.shade600, fontSize: 12),
                  destinations: [
                    const NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard),
                      label: Text('Início'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.assignment_outlined),
                      selectedIcon: Icon(Icons.assignment),
                      label: Text('Sinistros'),
                    ),

                    // ASSISTÊNCIAS
                    const NavigationRailDestination(
                      icon: Icon(Icons.emergency_share_outlined),
                      selectedIcon: Icon(Icons.emergency_share),
                      label: Text('Assistências'),
                    ),

                    NavigationRailDestination(
                      icon: _clientesIcon(),
                      label: const Text('Clientes'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.checklist_outlined),
                      selectedIcon: Icon(Icons.checklist),
                      label: Text('Tarefas'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.bar_chart_outlined),
                      selectedIcon: Icon(Icons.bar_chart),
                      label: Text('Relatórios'),
                    ),
                    const NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('Configurações'),
                    ),
                  ],
                ),
                Container(width: 0.5, color: Colors.grey.shade200),
                Expanded(child: _buildCurrentScreen()),
              ],
            )
          : _buildCurrentScreen(),

      bottomNavigationBar: isMobileDevice
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              selectedItemColor: const Color(0xFF1565C0),
              unselectedItemColor: Colors.grey.shade500,
              backgroundColor: Colors.white,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              onTap: _onItemTapped,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'Início',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_outlined),
                  activeIcon: Icon(Icons.assignment),
                  label: 'Sinistros',
                ),

                // ASSISTÊNCIAS
                const BottomNavigationBarItem(
                  icon: Icon(Icons.emergency_share_outlined),
                  activeIcon: Icon(Icons.emergency_share),
                  label: 'Assistências',
                ),

                BottomNavigationBarItem(
                    icon: _clientesIcon(), label: 'Clientes'),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.checklist_outlined),
                  activeIcon: Icon(Icons.checklist),
                  label: 'Tarefas',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_outlined),
                  activeIcon: Icon(Icons.bar_chart),
                  label: 'Relatórios',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Configurações',
                ),
              ],
            )
          : null,

      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _showNewItemDialog,
              label: const Text('Novo Registro',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              icon: const Icon(Icons.add_rounded),
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 2,
              heroTag: 'mainFab',
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

  // ─── Modelo de opção de ramo ──────────────────────────────────────────────────
  class _RamoOption {
    const _RamoOption({
      required this.label,
      required this.icon,
      required this.ramo,
      required this.color,
    });
    final String label;
    final IconData icon;
    final String ramo;
    final Color color;
  }

  // ─── Grupos de campos (hierarquia visual) ────────────────────────────────────
class _Group {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<List<_Field>> rows; // cada lista interna = uma linha horizontal

  const _Group({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });
}

// ─── Modelo de campo de uma linha de entrada ─────────────────────────────────
class _Field {
  final String id;
  final String label;

  const _Field({
    required this.id,
    required this.label,
  });
}

// ─── Widget de opção do modal ─────────────────────────────────────────────────
class _OpenModeOption extends StatelessWidget {
  const _OpenModeOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted ? color.withOpacity(0.04) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted
                  ? color.withOpacity(0.4)
                  : Colors.grey.shade200,
              width: highlighted ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: highlighted
                                ? color
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                        if (highlighted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'recomendado',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade300, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
