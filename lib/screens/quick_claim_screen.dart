// lib/screens/quick_claim_screen.dart
//
// TELA DE ABERTURA RÁPIDA DE SINISTRO
// ------------------------------------
// Objetivo: permitir abrir um sinistro com o mínimo de informação (≤ 1 minuto),
// salvando imediatamente com status "Rascunho". Os campos detalhados são
// preenchidos depois, na ClaimDetailScreen que já existe.
//
// Campos obrigatórios aqui:
//   • Cliente (busca existente ou nome livre p/ novo)
//   • Ramo do sinistro
//   • Tipo de ocorrência
//   • Data da ocorrência  (default = hoje)
//
// Campos opcionais que ficam para depois:
//   • Seguradora / número da seguradora
//   • Local da ocorrência
//   • Veículo / placa / chassi
//   • Relato completo
//   • Fotos, laudos, terceiros, etc.
//
// Como integrar:
//   Substitua (ou adicione ao lado) o botão "Abrir Novo Sinistro" no
//   DashboardScreen e no FAB do ClaimListScreen por esta tela.
//   O formulário completo (NewClaimScreen) continua disponível para
//   quem quiser preencher tudo de uma vez.

// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/client_search_dialog.dart';

class QuickClaimScreen extends StatefulWidget {
  const QuickClaimScreen({super.key});

  @override
  State<QuickClaimScreen> createState() => _QuickClaimScreenState();
}

class _QuickClaimScreenState extends State<QuickClaimScreen> {
  // ─── Serviços ────────────────────────────────────────────────────────────
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // ─── Estado ──────────────────────────────────────────────────────────────
  bool _isLoading = false;

  // Cliente
  Client? _clienteSelecionado;
  bool _isNovoCliente = false;
  final _buscaController = TextEditingController();
  final _nomeNovoClienteController = TextEditingController();
  final _cpfCnpjNovoClienteController = TextEditingController();

  // Sinistro
  String _tipoOcorrencia = 'Sinistro';
  String? _ramoSinistro;
  DateTime _dataOcorrencia = DateTime.now();
  DateTime _dataAviso = DateTime.now();

  // Observação rápida (opcional)
  final _observacaoController = TextEditingController();

  // ─── Ramos disponíveis ───────────────────────────────────────────────────
  static const _ramos = [
    'Frota',
    'Veículo Individual',
    'Transporte',
    'Residencial',
    'Vidas',
  ];

  // ─── Dispose ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _buscaController.dispose();
    _nomeNovoClienteController.dispose();
    _cpfCnpjNovoClienteController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  // ─── Salvar ──────────────────────────────────────────────────────────────
  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = _authService.getUserId();
    final userEmail = _authService.getUserEmail();

    if (userId == 'anonymous_user') {
      _showSnack('Usuário não autenticado. Faça login.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── 1. Garante que o cliente existe no Firestore ──────────────────────
      if (_isNovoCliente) {
        // Cria um cliente mínimo; o restante pode ser completado depois
        _clienteSelecionado = Client(
          nome: _nomeNovoClienteController.text.trim(),
          cnpjCpf: _cpfCnpjNovoClienteController.text.trim(),
          contato: '',
          email: '',
          dataCadastro: DateTime.now(),
          veiculosSegurados: [],
          apolices: [],
        );
        await _firestoreService.addClient(_clienteSelecionado!, userId);
      }

      // ── 2. Gera número de sinistro ────────────────────────────────────────
      final numeroSinistro =
          'SN${DateFormat('yyyyMMddHHmmss').format(DateTime.now())}';

      // ── 3. Cria o sinistro com status "Rascunho" ─────────────────────────
      //
      // Todos os campos não-obrigatórios ficam vazios/nulos.
      // O ClaimDetailScreen existente já suporta edição desses campos depois.
      final novoClaim = Claim(
        idCliente: _clienteSelecionado!.id ?? '',
        numeroSinistro: numeroSinistro,
        tipoOcorrencia: _tipoOcorrencia,
        ramoSinistro: _ramoSinistro!,
        dataOcorrencia: _dataOcorrencia,
        dataAviso: _dataAviso,
        localOcorrencia: '',
        enderecoTerceiro: '',
        relatoEvento: _observacaoController.text.trim(),
        requerAprovacaoGerencial: false,
        aprovadoPorGerente: true,
        dataAbertura: DateTime.now(),
        dataUltimaAtualizacao: DateTime.now(),
        historicoStatus: [
          {
            'status': 'Rascunho',
            'data': Timestamp.now(),
            'responsavel': userId,
            'responsavelEmail': userEmail,
          }
        ],
        terceiros: [],
        veiculoSelecionado: null,
        transporte: null,
        fotosUrls: [],
        arquivosLaudosUrls: [],
        numeroSeguradora: '',
        seguradora: '',
        clientNome: _clienteSelecionado!.nome,
        clientCnpjCpf: _clienteSelecionado!.cnpjCpf,
        valorTotalSinistro: 0.0,
        anotacoes: [],
        status: 'Rascunho',
        house: null,
        life: null,
      );

      await _firestoreService.addClaim(novoClaim);

      if (mounted) {
        // ── Feedback visual ─────────────────────────────────────────────────
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sinistro aberto com sucesso!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Nº $numeroSinistro — complete os detalhes quando quiser.',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.of(context).pop(true); // retorna true → lista pode atualizar
      }
    } catch (e) {
      _showSnack('Erro ao salvar: $e');
      debugPrint('[QuickClaimScreen] erro: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _abrirBuscaCliente() async {
    final result = await showDialog<ClientSearchResult>(
      context: context,
      builder: (_) => ClientSearchDialog(
        initialQuery: _buscaController.text,
        onClientSelected: (c) =>
            c != null ? ClientSearchResult.client(c) : null,
      ),
    );

    if (result == null) return;

    if (result.client != null) {
      setState(() {
        _clienteSelecionado = result.client;
        _isNovoCliente = false;
        _buscaController.text = result.client!.nome;
      });
    } else if (result.searchText != null &&
        result.searchText!.isNotEmpty) {
      setState(() {
        _clienteSelecionado = null;
        _isNovoCliente = true;
        _buscaController.text = result.searchText!;
        // Pré-preenche o campo certo (nome ou CPF/CNPJ)
        final texto = result.searchText!;
        if (RegExp(r'^\d+$').hasMatch(texto)) {
          _cpfCnpjNovoClienteController.text = texto;
          _nomeNovoClienteController.clear();
        } else {
          _nomeNovoClienteController.text = texto;
          _cpfCnpjNovoClienteController.clear();
        }
      });
    }
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataOcorrencia,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (data == null) return;

    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dataOcorrencia),
    );
    if (!mounted) return;

    setState(() {
      _dataOcorrencia = DateTime(
        data.year, data.month, data.day,
        hora?.hour ?? _dataOcorrencia.hour,
        hora?.minute ?? _dataOcorrencia.minute,
      );
    });
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Abrir Sinistro'),
        // Sem botão de voltar customizado — o padrão é suficiente aqui
        // porque o formulário é curto e o usuário não perde dados críticos.
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 560 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Cabeçalho informativo ──────────────────────────────
                    _InfoBanner(
                      icon: Icons.flash_on_rounded,
                      text:
                          'Preencha apenas o essencial agora. '
                          'Fotos, seguradora, veículo e relato completo '
                          'podem ser adicionados depois.',
                    ),
                    const SizedBox(height: 24),

                    // ── Seção: Cliente ─────────────────────────────────────
                    _SectionLabel(label: 'Cliente', icon: Icons.person),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _buscaController,
                      readOnly: true,
                      onTap: _abrirBuscaCliente,
                      decoration: InputDecoration(
                        labelText: 'Buscar cliente (nome, CPF ou CNPJ)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _clienteSelecionado != null
                            ? const Icon(Icons.check_circle,
                                color: Colors.green)
                            : null,
                      ),
                      validator: (_) {
                        if (_clienteSelecionado == null && !_isNovoCliente) {
                          return 'Selecione ou cadastre um cliente';
                        }
                        return null;
                      },
                    ),

                    // Cliente encontrado — chip de confirmação
                    if (_clienteSelecionado != null) ...[
                      const SizedBox(height: 8),
                      _ClienteConfirmado(cliente: _clienteSelecionado!),
                    ],

                    // Novo cliente — campos mínimos
                    if (_isNovoCliente) ...[
                      const SizedBox(height: 12),
                      _NovoClienteFields(
                        nomeController: _nomeNovoClienteController,
                        cpfCnpjController: _cpfCnpjNovoClienteController,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // ── Seção: Tipo e Ramo ─────────────────────────────────
                    _SectionLabel(
                        label: 'Tipo e Ramo', icon: Icons.category),
                    const SizedBox(height: 8),

                    // Tipo — Sempre Sinistro (QuickClaim é apenas para sinistros)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sinistro Resumido — complete os dados depois',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Ramo
                    DropdownButtonFormField<String>(
                      value: _ramoSinistro,
                      hint: const Text('Selecione o ramo'),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.policy_outlined),
                      ),
                      items: _ramos
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _ramoSinistro = v),
                      validator: (v) =>
                          v == null ? 'Selecione o ramo' : null,
                    ),

                    const SizedBox(height: 24),

                    // ── Seção: Data ────────────────────────────────────────
                    _SectionLabel(
                        label: 'Data da ocorrência',
                        icon: Icons.calendar_today),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _selecionarData,
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                          suffixIcon: Icon(Icons.edit_calendar),
                        ),
                        child: Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(_dataOcorrencia),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Seção: Observação rápida (opcional) ────────────────
                    _SectionLabel(
                      label: 'Observação rápida (opcional)',
                      icon: Icons.notes,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _observacaoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Ex: colisão traseira, carga avariada... '
                            'O relato completo pode ser adicionado depois.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Botão principal ────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _salvar,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_alt_rounded),
                        label: Text(
                          _isLoading ? 'Salvando...' : 'Abrir Sinistro',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Link para o formulário completo (para quem quer preencher tudo)
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit_note, size: 18),
                        label: const Text(
                          'Prefiro preencher todos os campos agora',
                          style: TextStyle(fontSize: 13),
                        ),
                        onPressed: () {
                          // Substitua NewClaimScreen pelo import correto se necessário
                          // Navigator.of(context).pushReplacement(
                          //   MaterialPageRoute(builder: (_) => const NewClaimScreen()),
                          // );
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Use o botão "Formulário Completo" no menu principal.',
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Widgets auxiliares (privados ao arquivo) ─────────────────────────────────

/// Faixa informativa no topo do formulário.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de seção com ícone.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Chip de confirmação de cliente encontrado.
class _ClienteConfirmado extends StatelessWidget {
  const _ClienteConfirmado({required this.cliente});
  final Client cliente;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.person_pin, color: Colors.green.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente.nome,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  cliente.cnpjCpf,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Campos mínimos para cadastro de novo cliente durante a abertura rápida.
class _NovoClienteFields extends StatelessWidget {
  const _NovoClienteFields({
    required this.nomeController,
    required this.cpfCnpjController,
  });
  final TextEditingController nomeController;
  final TextEditingController cpfCnpjController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add, color: Colors.orange.shade700, size: 16),
              const SizedBox(width: 6),
              Text(
                'Novo cliente — dados básicos',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: nomeController,
            decoration: const InputDecoration(
              labelText: 'Nome / Razão Social',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: cpfCnpjController,
            decoration: const InputDecoration(
              labelText: 'CPF / CNPJ',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
          ),
          const SizedBox(height: 8),
          Text(
            'Contato, e-mail e demais dados podem ser completados depois.',
            style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
          ),
        ],
      ),
    );
  }
}
