// lib/screens/settings_screen.dart
// ignore_for_file: use_build_context_synchronously
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/helpers/signature_data_helper.dart';
import 'package:upgrade_seguros/models/config_model.dart';
import 'package:upgrade_seguros/models/corretora_model.dart';
import 'package:upgrade_seguros/models/employee_model.dart';
import 'package:upgrade_seguros/screens/user_management_screen.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:upgrade_seguros/services/corretora_service.dart';
import 'package:upgrade_seguros/services/employee_service.dart';
import 'package:upgrade_seguros/services/firestore_service.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:upgrade_seguros/utils/gatilho.dart';
import '../models/seguradora_model.dart';
import '../services/seguradora_service.dart';
import 'package:upgrade_seguros/models/pdf_signature_model.dart';
import 'package:upgrade_seguros/services/pdf_signature_service.dart';
import 'package:upgrade_seguros/models/workshop_model.dart';
import 'package:upgrade_seguros/services/workshop_service.dart';

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

  final _pdfSignatureService = PdfSignatureService();
  late PdfSignatureConfig _pdfConfig;
  bool _loadingPdfConfig = true;

  final _workshopService = WorkshopService();
  String _buscaOfficina = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPdfSignatureConfig();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Função para gerar assinatura do pdf ---
  Future<void> _loadPdfSignatureConfig() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingPdfConfig = false);
        return;
      }

      // 🔥 Busca o empresaId do usuário logado
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final empresaId = userDoc.data()?['empresaId'] as String?;

      if (empresaId == null || empresaId.isEmpty) {
        setState(() => _loadingPdfConfig = false);
        return;
      }

      // 🔥 Carrega a configuração usando o empresaId real
      final config = await _pdfSignatureService.getSignatureConfig(empresaId);
      
      setState(() {
        _pdfConfig = config;
        _loadingPdfConfig = false;
      });
    } catch (e) {
      print('Erro ao carregar config de PDF: $e');
      setState(() => _loadingPdfConfig = false);
    }
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

  Future<void> _abrirFormOfficina({Workshop? workshop}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FormularioOfficina(
        workshop: workshop,  // ← AQUI! Dentro do builder, como parâmetro de _FormularioOfficina
        onSave: (novaOfficina) async {
          try {
            if (workshop == null) {
              await _workshopService.criarOfficina(novaOfficina);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Oficina adicionada com sucesso!')),
              );
            } else {
              await _workshopService.atualizarOfficina(workshop.id, novaOfficina);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Oficina atualizada com sucesso!')),
              );
            }
            Navigator.pop(ctx);
            setState(() {});
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Erro: $e')),
            );
          }
        },
      ),
    );
  }
  
  Future<void> _toggleOficinaAtiva(Workshop workshop) async {
    try {
      await _workshopService.atualizarOfficina(
        workshop.id,
        workshop.copyWith(ativo: !(workshop.ativo ?? true)),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro: $e')),
      );
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
                Tab(text: 'Oficinas'),
                Tab(text: 'Usuários'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _AbaAjustes(),
  
                // ─── ABA SEGURADORAS ───
                _AbaSeguradoras(
                  service: _service,
                  busca: _busca,
                  onBuscaChanged: (v) => setState(() => _busca = v),
                  onAdicionar: () => _abrirForm(),
                  onEditar: (s) => _abrirForm(seguradora: s),
                  onToggle: _toggleAtiva,
                ),
                
                // ─── ABA OFICINAS (NOVA) ───
                _AbaOfficinas(
                  service: _workshopService,
                  busca: _buscaOfficina,
                  onBuscaChanged: (v) => setState(() => _buscaOfficina = v),
                  onAdicionar: () => _abrirFormOfficina(),
                  onEditar: (w) => _abrirFormOfficina(workshop: w),
                  onToggle: _toggleOficinaAtiva,
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

  final _pdfSignatureService = PdfSignatureService();
  late PdfSignatureConfig _pdfConfig;
  bool _loadingPdfConfig = true;

  final TextEditingController _seguradoraNomeController = TextEditingController();
  final TextEditingController _seguradoraTelefoneController = TextEditingController();
  final TextEditingController _seguradoraEmailController = TextEditingController();
  // Etapa 07: % padrão do gatilho da apólice
  final TextEditingController _percentualGatilhoController = TextEditingController();
  bool _salvandoPercentualGatilho = false;

  final _corretoraService = CorretoraService();
  Corretora? _corretora;
  bool _loadingCorretora = true;

  final _firestoreService = FirestoreService();
  final _employeeService = EmployeeService();
  Employee? _currentEmployee;
 
  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadPdfSignatureConfig();
    _loadCorretora();
    _loadCurrentEmployee();
  }

  @override
  void dispose() {
    _seguradoraNomeController.dispose();
    _seguradoraTelefoneController.dispose();
    _seguradoraEmailController.dispose();
    _percentualGatilhoController.dispose();
    super.dispose();
  }  

  // --- Método para carregar Corretora cliente do SaaS ---
  Future<void> _loadCorretora() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingCorretora = false);
        return;
      }
  
      // Busca o documento do usuário para pegar empresaId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
  
      final empresaId = userDoc.data()?['empresaId'] as String?;
  
      if (empresaId == null || empresaId.isEmpty) {
        setState(() => _loadingCorretora = false);
        return;
      }
  
      // Busca a corretora (retorna Map)
      final corretoraMap = await _firestoreService.getCorretoraById(empresaId);
  
      if (corretoraMap != null) {
        setState(() {
          _corretora = Corretora.fromMap(corretoraMap, empresaId);
          
          _seguradoraNomeController.text = _corretora?.nome ?? '';
          _seguradoraTelefoneController.text = _corretora?.telefone ?? '';
          _seguradoraEmailController.text = _corretora?.email ?? '';
          _loadingCorretora = false;
        });
      } else {
        setState(() => _loadingCorretora = false);
      }
    } catch (e) {
      debugPrint('Erro ao carregar corretora: $e');
      setState(() => _loadingCorretora = false);
    }
  }
  
  // --- Método para carregar Funcionário logado ---
  Future<void> _loadCurrentEmployee() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
  
      final employee = await _employeeService.getUserById(user.uid);
      
      setState(() {
        _currentEmployee = employee;
      });
    } catch (e) {
      debugPrint('Erro ao carregar employee logado: $e');
    }
  }

  Future<void> _loadPdfSignatureConfig() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _loadingPdfConfig = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final empresaId = userDoc.data()?['empresaId'] as String?;

      if (empresaId == null || empresaId.isEmpty) {
        setState(() => _loadingPdfConfig = false);
        return;
      }

      final config = await _pdfSignatureService.getSignatureConfig(empresaId);
      
      setState(() {
        _pdfConfig = config;
        _loadingPdfConfig = false;
      });
    } catch (e) {
      print('Erro ao carregar config de PDF: $e');
      setState(() => _loadingPdfConfig = false);
    }
  }

  // ─── Seção de Assinaturas de PDF (VERSÃO FINAL COM CONTAINER + SEGURADORA) ─
  Widget _buildPdfSignatureSection() {
    if (_loadingPdfConfig) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),

        // ─── TÍTULO ────────────────────────────────────────────────────────────
        const Text(
          '📝 Assinatura em PDF',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Configure como os documentos serão assinados ao cliente',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // ═══════════════════════════════════════════════════════════════════════
        // CONTAINER BRANCO - SEÇÃO PRINCIPAL
        // ═══════════════════════════════════════════════════════════════════════
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── CADASTRO DADOS DA SEGURADORA ──────────────────────────────
              const Text(
                '🏢 Dados da Seguradora/Corretora',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),

              // Nome
              TextField(
                controller: _seguradoraNomeController,
                decoration: InputDecoration(
                  labelText: 'Nome da Seguradora',
                  hintText: 'Ex: Seguradora XYZ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  // Salva em tempo real (você pode debounce se quiser)
                  _saveSeguradoraData();
                },
              ),
              const SizedBox(height: 12),

              // Telefone
              TextField(
                controller: _seguradoraTelefoneController,
                decoration: InputDecoration(
                  labelText: 'Telefone de Contato',
                  hintText: 'Ex: (11) 3000-0000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  _saveSeguradoraData();
                },
              ),
              const SizedBox(height: 12),

              // Email
              TextField(
                controller: _seguradoraEmailController,
                decoration: InputDecoration(
                  labelText: 'Email de Contato',
                  hintText: 'Ex: contato@seguradora.com.br',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  _saveSeguradoraData();
                },
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // ─── SELEÇÃO DE FONTES PARA ASSINATURA ─────────────────────────
              const Text(
                '📋 Usar na Assinatura:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // ─── NOME ──────────────────────────────────────────────────────
              const Text(
                'Assinar nome no PDF como:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Funcionário',
                      isSelected: _pdfConfig.nomeSource == SignatureSource.funcionario,
                      onPressed: () => _updatePdfConfigField('nomeSource', SignatureSource.funcionario),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Corretora',
                      isSelected: _pdfConfig.nomeSource == SignatureSource.corretora,
                      onPressed: () => _updatePdfConfigField('nomeSource', SignatureSource.corretora),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── TELEFONE ──────────────────────────────────────────────────
              const Text(
                'Telefone de contato no PDF como:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Funcionário',
                      isSelected: _pdfConfig.telefoneSource == SignatureSource.funcionario,
                      onPressed: () => _updatePdfConfigField('telefoneSource', SignatureSource.funcionario),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Corretora',
                      isSelected: _pdfConfig.telefoneSource == SignatureSource.corretora,
                      onPressed: () => _updatePdfConfigField('telefoneSource', SignatureSource.corretora),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ─── EMAIL ────────────────────────────────────────────────────
              const Text(
                'Email de contato no PDF como:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Funcionário',
                      isSelected: _pdfConfig.emailSource == SignatureSource.funcionario,
                      onPressed: () => _updatePdfConfigField('emailSource', SignatureSource.funcionario),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildToggleButton(
                      label: 'Corretora',
                      isSelected: _pdfConfig.emailSource == SignatureSource.corretora,
                      onPressed: () => _updatePdfConfigField('emailSource', SignatureSource.corretora),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── PREVIEW ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PREVIEW DO PDF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _generatePreviewSignature(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ─── Widget para botão de toggle (Funcionário / Corretora) ──────────────────
  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Material(
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade600 : Colors.white,
            border: Border.all(
              color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Atualiza um campo da configuração ───────────────────────────────────────
  Future<void> _updatePdfConfigField(String field, SignatureSource value) async {
    try {
      PdfSignatureConfig newConfig;

      if (field == 'nomeSource') {
        newConfig = _pdfConfig.copyWith(nomeSource: value);
      } else if (field == 'telefoneSource') {
        newConfig = _pdfConfig.copyWith(telefoneSource: value);
      } else if (field == 'emailSource') {
        newConfig = _pdfConfig.copyWith(emailSource: value);
      } else {
        return;
      }

      await _pdfSignatureService.saveSignatureConfig(newConfig);

      setState(() {
        _pdfConfig = newConfig;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Configuração atualizada'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  // ─── Salva dados da seguradora ───────────────────────────────────────────────
  Future<void> _saveSeguradoraData() async {
    if (_corretora == null) return;  // ← ADICIONE ISTO
    
    try {
      await _firestoreService.updateCorretoraContactInfo(
        corretoraId: _corretora!.id,
        nome: _seguradoraNomeController.text,
        telefone: _seguradoraTelefoneController.text,
        email: _seguradoraEmailController.text,
      );

      setState(() {
        _corretora = _corretora!.copyWith(
          nome: _seguradoraNomeController.text,
          telefone: _seguradoraTelefoneController.text,
          email: _seguradoraEmailController.text,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Dados da corretora atualizados')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  // ─── Gera preview da assinatura ────────────────────────────────────────────
  String _generatePreviewSignature() {
    if (_loadingCorretora || _corretora == null) {
      return 'Carregando dados da corretora...';
    }

    final data = SignatureDataHelper.getSignatureData(
      nomeSource: _pdfConfig.nomeSource,
      telefoneSource: _pdfConfig.telefoneSource,
      emailSource: _pdfConfig.emailSource,
      currentEmployee: _currentEmployee,
      corretora: _corretora,
      nomeController: _seguradoraNomeController.text,
      telefoneController: _seguradoraTelefoneController.text,
      emailController: _seguradoraEmailController.text,
    );

    final buffer = StringBuffer();
    buffer.writeln('Atenciosamente,');
    buffer.writeln('');
    buffer.writeln(data['nome'] ?? 'Sem nome');
    
    if (data['telefone'] != null && data['telefone']!.isNotEmpty) {
      buffer.writeln('📞 ${BRFormatters.formatarTelefone(data['telefone']!)}');
    }
    
    if (data['email'] != null && data['email']!.isNotEmpty) {
      buffer.write('📧 ${data['email']}');
    }

    return buffer.toString();
  }

  Future<void> _loadConfig() async {
    final config = await _configService.getConfig();
    setState(() {
      _config = config;
      _percentualGatilhoController.text = GatilhoApolice.formatarPercentual(config.percentualGatilhoPadrao);
      _loading = false;
    });
  }

  // Etapa 07: salva o % padrão do gatilho (1 a 100).
  Future<void> _salvarPercentualGatilho() async {
    final texto = _percentualGatilhoController.text.replaceAll(',', '.').replaceAll('%', '').trim();
    final valor = double.tryParse(texto);
    if (valor == null || valor < 1 || valor > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um percentual entre 1 e 100.')),
      );
      return;
    }
    setState(() => _salvandoPercentualGatilho = true);
    try {
      await _configService.updatePercentualGatilho(valor);
      final config = await _configService.getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _percentualGatilhoController.text = GatilhoApolice.formatarPercentual(config.percentualGatilhoPadrao);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Gatilho padrão: ${GatilhoApolice.formatarPercentual(valor)}% do valor da apólice')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      if (mounted) setState(() => _salvandoPercentualGatilho = false);
    }
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

          // ─── Etapa 07: GATILHO PADRÃO DA APÓLICE ───────────────────────────────
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gatilho padrão da apólice',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Quando o contrato não informa o valor do gatilho, o sistema usa este percentual '
                        'do valor da apólice. Também é a sugestão ao cadastrar uma apólice.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _percentualGatilhoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      isDense: true,
                      suffixText: '%',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onSubmitted: (_) => _salvarPercentualGatilho(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Salvar',
                  icon: _salvandoPercentualGatilho
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                  onPressed: _salvandoPercentualGatilho ? null : _salvarPercentualGatilho,
                ),
              ],
            ),
          ),

          // ─── SEÇÃO: NOTIFICAÇÕES ───────────────────────────────────────────────
          const SizedBox(height: 32),
          const Text(
            '🔔 Notificações Telegram',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle Ativar/Desativar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ativar notificações',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    Switch(
                      value: _config.notificacoesAtivas,
                      onChanged: (value) async {
                        await _configService.updateNotificacaoConfig(
                          ativas: value,
                          horarioInicio: _config.notificacaoHorarioInicio,
                          horarioFim: _config.notificacaoHorarioFim,
                          intervaloMinutos: _config.notificacaoIntervaloMinutos,
                          atrasoMinimo: _config.notificacaoAtrasoMinimo,
                          chatIds: _config.notificacaoTelegramChatIds,
                        );
                        final config = await _configService.getConfig();
                        setState(() => _config = config);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Horário de silêncio
                Row(
                  children: [
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Início do silêncio',
                        value: _config.notificacaoHorarioInicio,
                        onChanged: (time) async {
                          final novoInicio = time.format(context);
                          await _configService.updateNotificacaoConfig(
                            ativas: _config.notificacoesAtivas,
                            horarioInicio: novoInicio,
                            horarioFim: _config.notificacaoHorarioFim,
                            intervaloMinutos: _config.notificacaoIntervaloMinutos,
                            atrasoMinimo: _config.notificacaoAtrasoMinimo,
                            chatIds: _config.notificacaoTelegramChatIds,
                          );
                          final config = await _configService.getConfig();
                          setState(() => _config = config);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTimePickerField(
                        label: 'Fim do silêncio',
                        value: _config.notificacaoHorarioFim,
                        onChanged: (time) async {
                          final novoFim = time.format(context);
                          await _configService.updateNotificacaoConfig(
                            ativas: _config.notificacoesAtivas,
                            horarioInicio: _config.notificacaoHorarioInicio,
                            horarioFim: novoFim,
                            intervaloMinutos: _config.notificacaoIntervaloMinutos,
                            atrasoMinimo: _config.notificacaoAtrasoMinimo,
                            chatIds: _config.notificacaoTelegramChatIds,
                          );
                          final config = await _configService.getConfig();
                          setState(() => _config = config);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Intervalo de reenvio (minutos)
                _buildNumberField(
                  label: 'Reenviar a cada (minutos)',
                  value: _config.notificacaoIntervaloMinutos,
                  onChanged: (value) async {
                    await _configService.updateNotificacaoConfig(
                      ativas: _config.notificacoesAtivas,
                      horarioInicio: _config.notificacaoHorarioInicio,
                      horarioFim: _config.notificacaoHorarioFim,
                      intervaloMinutos: value,
                      atrasoMinimo: _config.notificacaoAtrasoMinimo,
                      chatIds: _config.notificacaoTelegramChatIds,
                    );
                    final config = await _configService.getConfig();
                    setState(() => _config = config);
                  },
                ),
                const SizedBox(height: 12),

                // Atraso mínimo para disparar
                _buildNumberField(
                  label: 'Atraso mínimo para notificar (minutos)',
                  value: _config.notificacaoAtrasoMinimo,
                  onChanged: (value) async {
                    await _configService.updateNotificacaoConfig(
                      ativas: _config.notificacoesAtivas,
                      horarioInicio: _config.notificacaoHorarioInicio,
                      horarioFim: _config.notificacaoHorarioFim,
                      intervaloMinutos: _config.notificacaoIntervaloMinutos,
                      atrasoMinimo: value,
                      chatIds: _config.notificacaoTelegramChatIds,
                    );
                    final config = await _configService.getConfig();
                    setState(() => _config = config);
                  },
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Lista de chat_ids
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Destinatários (Chat IDs)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.blue),
                      onPressed: () => _adicionarChatId(),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _config.notificacaoTelegramChatIds.map((chatId) {
                    return Chip(
                      label: Text(chatId),
                      onDeleted: () => _removerChatId(chatId),
                    );
                  }).toList(),
                ),
                if (_config.notificacaoTelegramChatIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Nenhum destinatário configurado. Adicione o chat_id do Telegram.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
              ],
            ),
          ),

          _buildPdfSignatureSection(),
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
    'Civil Ônibus (RCO)': '🚌', // Etapa 08
    'Empresarial': '🏢',       // Etapa 08
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

  // Método para escolher horário
  Widget _buildTimePickerField({
    required String label,
    required String value,
    required Function(TimeOfDay) onChanged,
  }) {
    final time = TimeOfDay.fromDateTime(DateTime.parse('2000-01-01 $value:00'));
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          isDense: true,
        ),
        child: Text(value),
      ),
    );
  }

  // Método para campo numérico
  Widget _buildNumberField({
    required String label,
    required int value,
    required Function(int) onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        SizedBox(
          width: 80,
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixText: 'min',
            ),
            onFieldSubmitted: (text) {
              final intValue = int.tryParse(text) ?? value;
              onChanged(intValue);
            },
          ),
        ),
      ],
    );
  }

  // Método para adicionar chat_id
  Future<void> _adicionarChatId() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Chat ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Digite o chat_id do Telegram',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final novosChatIds = List<String>.from(_config.notificacaoTelegramChatIds)
        ..add(result);
      await _configService.updateNotificacaoConfig(
        ativas: _config.notificacoesAtivas,
        horarioInicio: _config.notificacaoHorarioInicio,
        horarioFim: _config.notificacaoHorarioFim,
        intervaloMinutos: _config.notificacaoIntervaloMinutos,
        atrasoMinimo: _config.notificacaoAtrasoMinimo,
        chatIds: novosChatIds,
      );
      final config = await _configService.getConfig();
      setState(() => _config = config);
    }
  }

  // Método para remover chat_id
  Future<void> _removerChatId(String chatId) async {
    final novosChatIds = List<String>.from(_config.notificacaoTelegramChatIds)
      ..remove(chatId);
    await _configService.updateNotificacaoConfig(
      ativas: _config.notificacoesAtivas,
      horarioInicio: _config.notificacaoHorarioInicio,
      horarioFim: _config.notificacaoHorarioFim,
      intervaloMinutos: _config.notificacaoIntervaloMinutos,
      atrasoMinimo: _config.notificacaoAtrasoMinimo,
      chatIds: novosChatIds,
    );
    final config = await _configService.getConfig();
    setState(() => _config = config);
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

 
// ✅ _AbaOfficinas COM DESIGN ALINHADO ÀS SEGURADORAS
// Mesmo padrão visual: TextField busca + FilledButton + Card + Avatar

class _AbaOfficinas extends StatelessWidget {
  const _AbaOfficinas({
    required this.service,
    required this.busca,
    required this.onBuscaChanged,
    required this.onAdicionar,
    required this.onEditar,
    required this.onToggle,
  });

  final WorkshopService service;
  final String busca;
  final ValueChanged<String> onBuscaChanged;
  final VoidCallback onAdicionar;
  final ValueChanged<Workshop> onEditar;
  final ValueChanged<Workshop> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ─── Barra superior: busca + botão adicionar ───────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: onBuscaChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar oficina...',
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

        // ─── Lista em tempo real via Stream ────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Workshop>>(
            stream: service.obterOfficinas(),
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
                      .where((o) =>
                          o.nome
                              .toLowerCase()
                              .contains(busca.toLowerCase()) ||
                          (o.endereco?.toLowerCase().contains(busca.toLowerCase()) ??
                              false))
                      .toList();

              if (filtradas.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.build_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        busca.isEmpty
                            ? 'Nenhuma oficina cadastrada ainda.'
                            : 'Nenhum resultado para "$busca".',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }

              // Contador de ativas/inativas
              final nAtivas = filtradas.where((o) => o.ativo ?? true).length;
              final nInativas = filtradas.where((o) => !(o.ativo ?? true)).length;

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '$nAtivas ativas · $nInativas inativas',
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
                      itemBuilder: (_, i) => _OficinaCard(
                        oficina: filtradas[i],
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

// ─── Card individual de oficina ───────────────────────────────────────────────
class _OficinaCard extends StatelessWidget {
  const _OficinaCard({
    required this.oficina,
    required this.onEdit,
    required this.onToggle,
  });

  final Workshop oficina;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  String get _iniciais {
    final parts = oficina.nome.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return oficina.nome
        .substring(0, oficina.nome.length.clamp(0, 2))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final ativa = oficina.ativo ?? true;
    final endereco = oficina.endereco ?? '';
    final telefone = oficina.telefone ?? '';
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

              // ─── Dados da oficina ─────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome + Status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            oficina.nome,
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
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ativa ? 'Ativa' : 'Inativa',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ativa ? _kGreen : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Endereço (se houver)
                    if (endereco.isNotEmpty)
                      Text(
                        endereco,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    // Telefone (se houver)
                    if (telefone.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          telefone,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ─── Ações: Toggle + Edit ─────────────────────────────────────────
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      ativa ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: ativa ? _kGreen : Colors.grey.shade400,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: _kBlue,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
 
// ─── Card da Oficina ───────────────────────────────────────────────────────
class _CardOfficina extends StatelessWidget {
  final Workshop oficina;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
 
  const _CardOfficina({
    required this.oficina,
    required this.onEdit,
    required this.onToggle,
  });
 
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Status ativo/inativo
            Checkbox(
              value: oficina.ativo ?? true,
              onChanged: (_) => onToggle(),
              activeColor: _kGreen,
            ),
            const SizedBox(width: 12),
 
            // Info da oficina
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    oficina.nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (oficina.endereco != null && oficina.endereco!.isNotEmpty)
                    Text(
                      oficina.endereco!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (oficina.telefone != null && oficina.telefone!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        oficina.telefone!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
 
            // Botão editar
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: _kBlue),
              onPressed: onEdit,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          ],
        ),
      ),
    );
  }
}
 
// ─── Formulário Modal de Oficina ───────────────────────────────────────────
class _FormularioOfficina extends StatefulWidget {
  final Workshop? workshop;
  final Function(Workshop) onSave;
 
  const _FormularioOfficina({
    this.workshop,
    required this.onSave,
  });
 
  @override
  State<_FormularioOfficina> createState() => _FormularioOficinaState();
}
 
class _FormularioOficinaState extends State<_FormularioOfficina> {
  late TextEditingController _nomeCtrl;
  late TextEditingController _enderecoCtrl;
  late TextEditingController _telefoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _contatoCtrl;
  late TextEditingController _cnpjCtrl;
 
  String _tipoSelecionado = 'segurado';
 
  @override
  void initState() {
    super.initState();
    final w = widget.workshop;
_nomeCtrl = TextEditingController(text: w?.nome.toUpperCase() ?? '');    _enderecoCtrl = TextEditingController(text: w?.endereco ?? '');
    _telefoneCtrl = TextEditingController(text: w?.telefone ?? '');
    _emailCtrl = TextEditingController(text: w?.email ?? '');
    _contatoCtrl = TextEditingController(text: w?.contato ?? '');
    _cnpjCtrl = TextEditingController(text: w?.cnpjEmpresa ?? '');
    _tipoSelecionado = w?.tipo ?? 'segurado';
  }
 
  @override
  void dispose() {
    _nomeCtrl.dispose();
    _enderecoCtrl.dispose();
    _telefoneCtrl.dispose();
    _emailCtrl.dispose();
    _contatoCtrl.dispose();
    _cnpjCtrl.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.workshop != null;
    final padding = MediaQuery.of(context).viewInsets.bottom;
 
    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Editar Oficina' : 'Adicionar Oficina',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _kBlue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
 
              // Nome (obrigatório)
              TextField(
                controller: _nomeCtrl,
                onChanged: (value) {
                  // Converter para caixa alta enquanto digita
                  _nomeCtrl.value = _nomeCtrl.value.copyWith(
                    text: value.toUpperCase(),
                    selection: TextSelection.fromPosition(
                      TextPosition(offset: value.toUpperCase().length),
                    ),
                  );
                },
                decoration: InputDecoration(
                  labelText: 'Nome da Oficina *',
                  hintText: 'Ex: CARGLASS, OFICINA SILVA',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
 
              // Endereço (obrigatório)
              TextField(
                controller: _enderecoCtrl,
                decoration: InputDecoration(
                  labelText: 'Endereço *',
                  hintText: 'Rua, número, bairro',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
 
              // Telefone e Email lado a lado
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _telefoneCtrl,
                      decoration: InputDecoration(
                        labelText: 'Telefone (opcional)',
                        hintText: '(11) 9999-9999',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email (opcional)',
                        hintText: 'oficina@email.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
 
              // Contato e Tipo lado a lado
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _contatoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Contato (opcional)',
                        hintText: 'Ex: João Silva',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _tipoSelecionado,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'segurado',
                          child: Text('Segurado'),
                        ),
                        DropdownMenuItem(
                          value: 'terceiro',
                          child: Text('Terceiro'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _tipoSelecionado = value ?? 'segurado');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
 
              // CNPJ
              TextField(
                controller: _cnpjCtrl,
                decoration: InputDecoration(
                  labelText: 'CNPJ (opcional)',
                  hintText: '00.000.000/0000-00',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
 
              // Botões
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _salvar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
 
  void _salvar() {
    if (_nomeCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Preencha o nome da oficina para salvar!'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }
 
    final oficina = Workshop(
      id: widget.workshop?.id ?? DateTime.now().toString(),
      nome: _nomeCtrl.text,
      endereco: _enderecoCtrl.text,
      telefone: _telefoneCtrl.text.isEmpty ? null : _telefoneCtrl.text,
      email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text,
      contato: _contatoCtrl.text.isEmpty ? null : _contatoCtrl.text,
      tipo: _tipoSelecionado,
      cnpjEmpresa: _cnpjCtrl.text.isEmpty ? null : _cnpjCtrl.text,
      dataCriacao: widget.workshop?.dataCriacao ?? DateTime.now(),
      documentosUrls: widget.workshop?.documentosUrls ?? [],
    );
 
    widget.onSave(oficina);
  }
}