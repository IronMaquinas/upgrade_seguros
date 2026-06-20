// lib/screens/settings_screen.dart
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/models/config_model.dart';
import 'package:upgrade_seguros/screens/user_management_screen.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import '../models/seguradora_model.dart';
import '../services/seguradora_service.dart';

// ─── Paleta ──────────────────────────────────────────────────────────────────
const _kBlue  = Color(0xFF1565C0);
const _kGreen = Color(0xFF2E7D32);
const _kRed   = Color(0xFFC62828);
const _kBg    = Color(0xFFF4F6F9);
const _kGray  = Color(0xFF546E7A);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = SeguradoraService();
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Abre o bottom sheet de cadastro / edição ──────────────────────────────
  Future<void> _abrirForm({Seguradora? seguradora}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SeguradoraForm(
        seguradora: seguradora,
        service: _service,
      ),
    );
  }

  // ── Suspender / Reativar ──────────────────────────────────────────────────
  Future<void> _toggleAtiva(Seguradora s) async {
    final acao = s.ativa ? 'suspender' : 'reativar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${s.ativa ? "Suspender" : "Reativar"} seguradora?'),
        content: Text('Deseja $acao "${s.nome}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                s.ativa ? 'Suspender' : 'Reativar',
                style: TextStyle(color: s.ativa ? _kRed : _kGreen),
              )),
        ],
      ),
    );
    if (confirm == true) {
      try {
        if (s.ativa) {
          await _service.desativar(s.id);
        } else {
          await _service.reativar(s.id);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: _kRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: true,
        title: const Text(
          'Configurações',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ),
      body: Column(
        children: [
          // Abas
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: _kBlue,
              labelColor: _kBlue,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Ajustes'),
                Tab(text: 'Seguradoras'),
                Tab(text: 'Usuários'),                
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _AbaAjustes(),
                _AbaSeguradoras(
                  service: _service,
                  busca: _busca,
                  onBuscaChanged: (v) => setState(() => _busca = v),
                  onAdicionar: () => _abrirForm(),
                  onEditar: (s) => _abrirForm(seguradora: s),
                  onToggle: _toggleAtiva,
                ),
                const _AbaUsuarios(),                
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aba Seguradoras ──────────────────────────────────────────────────────────
class _AbaSeguradoras extends StatelessWidget {
  const _AbaSeguradoras({
    required this.service,
    required this.busca,
    required this.onBuscaChanged,
    required this.onAdicionar,
    required this.onEditar,
    required this.onToggle,
  });

  final SeguradoraService service;
  final String busca;
  final ValueChanged<String> onBuscaChanged;
  final VoidCallback onAdicionar;
  final ValueChanged<Seguradora> onEditar;
  final ValueChanged<Seguradora> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra superior: busca + botão adicionar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onBuscaChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar seguradora...',
                    prefixIcon:
                        const Icon(Icons.search, color: _kBlue, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.grey.shade300, width: 0.8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: Colors.grey.shade300, width: 0.8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: _kBlue, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: onAdicionar,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nova'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 13),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
              ),
            ],
          ),
        ),

        // Lista em tempo real via Stream
        Expanded(
          child: StreamBuilder<List<Seguradora>>(
            stream: service.streamTodas(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kBlue));
              }
              if (snap.hasError) {
                return Center(child: Text('Erro: ${snap.error}'));
              }

              final todas = snap.data ?? [];
              final filtradas = busca.isEmpty
                  ? todas
                  : todas
                      .where((s) =>
                          s.nome
                              .toLowerCase()
                              .contains(busca.toLowerCase()) ||
                          s.contato
                              .toLowerCase()
                              .contains(busca.toLowerCase()))
                      .toList();

              if (filtradas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        busca.isEmpty
                            ? 'Nenhuma seguradora cadastrada ainda.'
                            : 'Nenhum resultado para "$busca".',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // Contador de ativas/suspensas
              final nAtivas = filtradas.where((s) => s.ativa).length;
              final nSuspensas = filtradas.where((s) => !s.ativa).length;

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '$nAtivas ativas · $nSuspensas suspensas',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtradas.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _SeguradoraCard(
                        seguradora: filtradas[i],
                        onEdit: () => onEditar(filtradas[i]),
                        onToggle: () => onToggle(filtradas[i]),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Card individual de seguradora ────────────────────────────────────────────
class _SeguradoraCard extends StatelessWidget {
  const _SeguradoraCard({
    required this.seguradora,
    required this.onEdit,
    required this.onToggle,
  });

  final Seguradora seguradora;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  String get _iniciais {
    final parts = seguradora.nome.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return seguradora.nome
        .substring(0, seguradora.nome.length.clamp(0, 2))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ativa = seguradora.ativa;
    final contato = seguradora.contato ?? '';
    final telefone = seguradora.telefone ?? '';
    final email = seguradora.email ?? '';
    final accent = ativa ? _kBlue : Colors.grey.shade400;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade200,
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar com iniciais
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _iniciais,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // ─── Dados da seguradora ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome + Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            seguradora.nome,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ativa
                                  ? const Color(0xFF1A1A2E)
                                  : Colors.grey.shade400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: ativa
                                ? _kGreen.withOpacity(0.1)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            ativa ? 'Ativa' : 'Suspensa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: ativa ? _kGreen : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ✅ CONTATO - Mostrar sempre
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            contato.isEmpty ? '(sem contato)' : contato,
                            style: TextStyle(
                              fontSize: 12,
                              color: seguradora.contato.isEmpty 
                                  ? Colors.grey.shade400 
                                  : Colors.grey.shade600,
                              fontStyle: seguradora.contato.isEmpty 
                                  ? FontStyle.italic 
                                  : FontStyle.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // ✅ TELEFONE + EMAIL - Mostrar sempre
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Telefone
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                telefone.isEmpty 
                                  ? '(sem telefone)' 
                                  : telefone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: seguradora.telefone.isEmpty 
                                      ? Colors.grey.shade400 
                                      : Colors.grey.shade600,
                                  fontStyle: seguradora.telefone.isEmpty 
                                      ? FontStyle.italic 
                                      : FontStyle.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        // Email
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.email_outlined,
                                size: 12, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email.isEmpty 
                                  ? '(sem email)' 
                                  : email,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: seguradora.email.isEmpty 
                                      ? Colors.grey.shade400 
                                      : Colors.grey.shade600,
                                  fontStyle: seguradora.email.isEmpty 
                                      ? FontStyle.italic 
                                      : FontStyle.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Botões de ação
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: _kBlue,
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: Icon(
                      ativa
                          ? Icons.pause_circle_outlined
                          : Icons.play_circle_outlined,
                      size: 18,
                    ),
                    color: ativa ? Colors.orange.shade600 : _kGreen,
                    tooltip: ativa ? 'Suspender' : 'Reativar',
                    onPressed: onToggle,
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
}

// ─── Bottom sheet de formulário ────────────────────────────────────────────────
class _SeguradoraForm extends StatefulWidget {
  const _SeguradoraForm({this.seguradora, required this.service});
  final Seguradora? seguradora;
  final SeguradoraService service;

  @override
  State<_SeguradoraForm> createState() => _SeguradoraFormState();
}

class _SeguradoraFormState extends State<_SeguradoraForm> {
  final _formKey   = GlobalKey<FormState>();
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _contatoCtrl;
  late final TextEditingController _telefoneCtrl;
  late final TextEditingController _emailCtrl;
  bool _isSaving = false;
  bool _ativa    = true;

  bool get _isEdit => widget.seguradora != null;

  @override
  void initState() {
    super.initState();
    final s = widget.seguradora;
    _nomeCtrl     = TextEditingController(text: s?.nome ?? '');
    _contatoCtrl  = TextEditingController(text: s?.contato ?? '');
    _telefoneCtrl = TextEditingController(text: s?.telefone ?? '');
    _emailCtrl    = TextEditingController(text: s?.email ?? '');
    _ativa        = s?.ativa ?? true;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _contatoCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final s = Seguradora(
        id:       widget.seguradora?.id ?? '',
        nome:     _nomeCtrl.text.trim().toUpperCase(),
        contato:  _contatoCtrl.text.trim(),
        telefone: _telefoneCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        ativa:    _ativa,
      );

      if (_isEdit) {
        await widget.service.editar(s.id, s);
      } else {
        await widget.service.criar(s);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              _isEdit ? 'Seguradora atualizada.' : 'Seguradora adicionada.'),
          backgroundColor: _kGreen,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: _kRed));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: _kGray)
            : null,
        isDense: true,
        filled: true,
        fillColor: _kBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.grey.shade300, width: 0.8)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: Colors.grey.shade300, width: 0.8)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kRed, width: 1.2)),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Text(
              _isEdit ? 'Editar Seguradora' : 'Nova Seguradora',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 18),

            // Nome
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('Nome da Seguradora *',
                  hint: 'Ex: PORTO SEGURO',
                  icon: Icons.business_outlined),
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Nome obrigatório' : null,
            ),
            const SizedBox(height: 12),

            // Contato
            TextFormField(
              controller: _contatoCtrl,
              decoration: _dec('Nome do Contato',
                  hint: 'Pessoa responsável',
                  icon: Icons.person_outline),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Telefone + Email
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _dec('Telefone',
                        hint: '(00) 00000-0000',
                        icon: Icons.phone_outlined),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _dec('E-mail',
                        hint: 'contato@seguradora.com',
                        icon: Icons.email_outlined),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Toggle ativa (só em edição)
            if (_isEdit)
              Row(
                children: [
                  Switch(
                    value: _ativa,
                    activeColor: _kGreen,
                    onChanged: (v) => setState(() => _ativa = v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ativa ? 'Seguradora ativa' : 'Seguradora suspensa',
                    style: TextStyle(
                      fontSize: 13,
                      color: _ativa ? _kGreen : Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 18),

            // Botão salvar
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _salvar,
                style: FilledButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(
                        _isEdit
                            ? 'Salvar alterações'
                            : 'Adicionar seguradora',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Aba SLAs ─────────────────────────────────────────────────────────────────
class _AbaAjustes extends StatefulWidget {
  const _AbaAjustes();

  @override
  State<_AbaAjustes> createState() => _AbaAjustesState();
}

class _AbaAjustesState extends State<_AbaAjustes> {
  final _configService = ConfigService();
  late AppConfig _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _configService.getConfig();
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── SLA ASSISTÊNCIAS ─────────────────────────────────────────────
        const Text(
          '🚗 Tempo Padrão para Atendimento Inicial de Assistências (SLA)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._config.slaAsistenciasPorTipo.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSlaField(
              label: entry.key,
              valor: entry.value.toString(),
              unidade: 'min',
              onChanged: (newValue) async {
                final minutos = int.tryParse(newValue) ?? entry.value;
                await _configService.updateSlaAssistencia(entry.key, minutos);
                final config = await _configService.getConfig();
                setState(() => _config = config);
              },
            ),
          );
        }),
        const SizedBox(height: 24),

        // ─── SLA SINISTROS ────────────────────────────────────────────────
        const Text(
          '📋 Tempo Padrão para Resolução de Sinistros (SLA)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ..._config.slaSinistrosPorRamo.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildSlaField(
              label: entry.key,
              valor: entry.value.toString(),
              unidade: 'dias',
              onChanged: (newValue) async {
                final dias = int.tryParse(newValue) ?? entry.value;
                await _configService.updateSlaSinistro(entry.key, dias);
                final config = await _configService.getConfig();
                setState(() => _config = config);
              },
            ),
          );
        }),
        const SizedBox(height: 32),

          // ─── SEÇÃO: FUNCIONALIDADES ───────────────────────────────────────
          const Text(
            '🎛️ Funcionalidades',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Toggle NPS
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pesquisa NPS',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Habilitar botão "Enviar Pesquisa de Satisfação" ao concluir uma Assistência ou Sinistro',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _config.enableNpsSurvey,
                        onChanged: (value) async {
                          await _configService.updateNpsEnabled(value);
                          
                          final config = await _configService.getConfig();
                          setState(() => _config = config);
                          setModalState(() {}); // ← Atualiza o modal
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value ? '✅ NPS habilitado' : '❌ NPS desabilitado',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSlaCard({
    required String titulo,
    required String valor,
    required String unidade,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: valor,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tempo',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixText: unidade,
              ),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  // Mapa de ícones por ramo/tipo
  final _icones = {
    // Assistências
    'Veicular': '🚗',
    'Residencial': '🏠',
    // Sinistros
    'Veículo Individual': '🚗',
    'Frota': '🚚',
    'Transporte': '📦',
    'Máquinas': '⚙️',
    'Residencial': '🏠',
    'Vida': '💓',
  };

  Widget _buildSlaField({
    required String label,
    required String valor,
    required String unidade,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(_icones[label] ?? '📋', style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: valor,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                suffixText: unidade,
                suffixStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

}
// ─── Aba Usuários ─────────────────────────────────────────────────────────────

class _AbaUsuarios extends StatelessWidget {
  const _AbaUsuarios();

  @override
  Widget build(BuildContext context) {
    return const UserManagementScreen();
  }
}