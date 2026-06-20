// lib/screens/spreadsheet_assist_residencial_screen.dart
import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' hide LatLng;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/image_services.dart';
import '../services/place_search_delegate.dart';
import '../utils/formatters.dart';
import 'assist_detail_screen.dart';
import '../widgets/client_search_dialog.dart';

class SpreadsheetAssistResidencialScreen extends StatefulWidget {
  const SpreadsheetAssistResidencialScreen({super.key});

  @override
  State<SpreadsheetAssistResidencialScreen> createState() =>
      _SpreadsheetAssistResidencialScreenState();
}

class _SpreadsheetAssistResidencialScreenState
    extends State<SpreadsheetAssistResidencialScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _picker = ImagePicker();
  late FlutterGooglePlacesSdk _places;

  // Controllers
  final _clienteBuscaCtrl = TextEditingController();
  final _tipoServicoCtrl = TextEditingController();
  final _outroServicoCtrl = TextEditingController();
  final _enderecoCtrl = TextEditingController();
  final _nomeContatoCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  final _relatoCtrl = TextEditingController();
  final _anotacoesCtrl = TextEditingController();

  // Campos de assistência (Seguradora, Protocolo, Franquia, SLA)
  final _seguradoraCtrl = TextEditingController();
  final _protocoloSeguradoraCtrl = TextEditingController();
  final _franquiaCtrl = TextEditingController();
  final _tempoSlaCtrl = TextEditingController(text: '30');

  // Contato que realizará o serviço (agendamento)
  final _nomeContatoServicoCtrl = TextEditingController();
  final _telefoneContatoServicoCtrl = TextEditingController();

  // Agendamento
  DateTime? _dataAgendamento;
  TimeOfDay? _horaAgendamento;

  // Tarefas
  final List<Map<String, dynamic>> _tarefasLocais = [];

  // Google Places - lat/lng
  LatLng? _enderecoLatLng;

  // Anexos
  final Map<String, List<XFile>> _anexos = {
    'Fotos da Ocorrência': [],
    'Documentos': [],
  };
  final Map<String, bool> _dragOver = {
    'Fotos da Ocorrência': false,
    'Documentos': false,
  };
  final Map<String, List<PlatformFile>> _platformFiles = {};

  // Estado
  Client? _cliente;
  bool _isSaving = false;
  String? _savedDocId;

  static const _apiKey = 'AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE';

  // Lista de seguradoras
  List<String> _seguradoras = [];

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _places = FlutterGooglePlacesSdk(_apiKey, locale: const Locale('pt', 'BR'));
    _carregarSeguradoras();
  }

  Future<void> _loadConfig() async {
    final minutos = await ConfigService().getSlaAssistencia('Residencial');
    setState(() {
      _tempoSlaCtrl.text = minutos.toString();
    });
  }

  // ── Carregar seguradoras do banco de dados ──────────────────────────────
  Future<void> _carregarSeguradoras() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('seguradoras')
        .where('ativa', isEqualTo: true)
        .get();
    setState(() {
      _seguradoras = snapshot.docs
          .map((doc) => doc['nome'] as String)
          .toList();
    });
  }

  @override
  void dispose() {
    _clienteBuscaCtrl.dispose();
    _tipoServicoCtrl.dispose();
    _outroServicoCtrl.dispose();
    _enderecoCtrl.dispose();
    _nomeContatoCtrl.dispose();
    _telefoneCtrl.dispose();
    _relatoCtrl.dispose();
    _anotacoesCtrl.dispose();
    _seguradoraCtrl.dispose();
    _protocoloSeguradoraCtrl.dispose();
    _franquiaCtrl.dispose();
    _tempoSlaCtrl.dispose();
    _nomeContatoServicoCtrl.dispose();
    _telefoneContatoServicoCtrl.dispose();
    super.dispose();
  }

  // ── Tipos de serviço residencial ──────────────────────────────────────
  static const _tiposServico = [
    ('eletricista', '⚡ Eletricista'),
    ('encanador', '🔧 Encanador'),
    ('reparo_equipamentos', '🛠️ Reparo de Equipamentos'),
    ('chaveiro', '🔑 Chaveiro'),
    ('vidraceiro', '🪟 Vidraceiro'),
    ('pintura', '🎨 Pintura'),
    ('limpeza', '🧹 Limpeza'),
    ('outro', 'ℹ️ Outro'),
  ];

  // ── Google Places ─────────────────────────────────────────────────────
  /// Abre busca de endereço no Google Places.
  /// [onLatLng] recebe as coordenadas encontradas para preview de mapa.
  Future<String?> _openPlaceSearch({
    required void Function(LatLng latLng) onLatLng,
  }) async {
    final Place? place = await showSearch<Place?>(
      context: context,
      delegate: PlaceSearchDelegate(_places),
    );

    if (place != null) {
      if (place.latLng != null) {
        setState(() {
          onLatLng(LatLng(place.latLng!.lat, place.latLng!.lng));
        });
      }
      return place.address ?? place.name ?? '';
    }
    return null;
  }

  // ── Busca cliente ─────────────────────────────────────────────────────
    Future<void> _abrirBuscaCliente() async {
    final result = await showDialog<ClientSearchResult>(
      context: context,
      useRootNavigator: false,
      builder: (_) => ClientSearchDialog(
        initialQuery: _clienteBuscaCtrl.text,
        onClientSelected: (c) => c != null
            ? ClientSearchResult.client(c)
            : null,
      ),
    );

    if (result?.client != null) {
      setState(() {
        _cliente = result!.client!;
        _clienteBuscaCtrl.text = _cliente!.nome;
      });
    }
  }

  // ── Anexos ────────────────────────────────────────────────────────────
  void _adicionarArquivos(String categoria, List<XFile> arquivos,
      [List<PlatformFile>? platformFiles]) {
    setState(() {
      _anexos[categoria]!.addAll(arquivos);
      if (platformFiles != null) {
        _platformFiles[categoria] ??= [];
        _platformFiles[categoria]!.addAll(platformFiles);
      }
    });
  }

  void _removerArquivo(String categoria, XFile arquivo) {
    setState(() => _anexos[categoria]!.remove(arquivo));
  }

  Future<void> _pickArquivos(String categoria) async {
    final result = await FilePicker.platform.pickFiles(
        allowMultiple: true, type: FileType.any);
    if (result != null && result.files.isNotEmpty) {
      final xfiles = result.files
          .map((f) => XFile(f.path ?? '', name: f.name))
          .toList();
      _adicionarArquivos(categoria, xfiles, result.files);
    }
  }

  bool _isImageFile(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

  Future<Map<String, List<String>>> _uploadAnexos(String numeroAssistencia) async {
    final Map<String, List<String>> urls = {};

    for (final entry in _anexos.entries) {
      if (entry.value.isEmpty) continue;
      final categoria = entry.key;
      final arquivos = entry.value;
      final isImagem = categoria == 'Fotos da Ocorrência';

      if (isImagem) {
        final comprimidas = await ImageService().compressImages(arquivos);
        final fUrls = await _firestoreService.uploadSinistroFotos(numeroAssistencia, comprimidas);
        urls[categoria] = fUrls;
      } else {
        final platformFiles = _platformFiles[categoria] ??
            await Future.wait(arquivos.map((xf) async {
              if (kIsWeb) {
                final bytes = await xf.readAsBytes();
                return PlatformFile(name: xf.name, size: bytes.length, bytes: bytes);
              } else {
                return PlatformFile(name: xf.name, path: xf.path, size: 0);
              }
            }));
        if (platformFiles.isNotEmpty) {
          final dUrls = await _firestoreService.uploadArquivosLaudos(numeroAssistencia, platformFiles);
          urls[categoria] = dUrls;
        }
      }
    }
    return urls;
  }

  // ── Tarefas ───────────────────────────────────────────────────────────
  void _adicionarTarefaLocal() async {
    final descCtrl = TextEditingController();
    DateTime prazo = DateTime.now().add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nova Tarefa'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  minLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 8),
                    Text('Prazo: ${DateFormat('dd/MM/yyyy').format(prazo)}'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: prazo,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setS(() => prazo = picked);
                      },
                      child: const Text('Alterar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (descCtrl.text.isNotEmpty) {
                  setState(() => _tarefasLocais.add({
                        'descricao': descCtrl.text,
                        'prazo': prazo,
                        'status': 'Aberta',
                      }));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvarTarefas(
      String claimId, String numeroAssistencia) async {
    final collection = FirebaseFirestore.instance.collection('tasks');
    final user = FirebaseAuth.instance.currentUser;

    // Tarefa automática de agendamento
    if (_dataAgendamento != null) {
      final horaStr = _horaAgendamento != null
          ? '${_horaAgendamento!.hour.toString().padLeft(2, '0')}:${_horaAgendamento!.minute.toString().padLeft(2, '0')}'
          : '';
      final tipoLabel = _tiposServico
          .firstWhere((t) => t.$1 == _tipoServicoCtrl.text,
              orElse: () => ('', 'Serviço'))
          .$2;
      final endereco = _enderecoCtrl.text;

      await collection.add({
        'descricao':
            'Agendamento para ${_cliente?.nome ?? 'cliente'} • $tipoLabel'
                '${endereco.isNotEmpty ? ' • $endereco' : ''}',
        'prazo': Timestamp.fromDate(_dataAgendamento!),
        'status': 'Aberta',
        'claimId': claimId,
        'numeroSinistro': numeroAssistencia,
        'clientId': _cliente?.id ?? '',
        'clientNome': _cliente?.nome ?? '',
        'clientCnpjCpf': _cliente?.cnpjCpf ?? '',
        'responsavelEmail': user?.email ?? '',
        'criado_em': FieldValue.serverTimestamp(),
        'tipo': 'agendamento',
      });
    }

    for (final t in _tarefasLocais) {
      await collection.add({
        'descricao': t['descricao'],
        'prazo': Timestamp.fromDate(t['prazo'] as DateTime),
        'status': 'Aberta',
        'claimId': claimId,
        'numeroSinistro': numeroAssistencia,
        'clientId': _cliente?.id ?? '',
        'clientNome': _cliente?.nome ?? '',
        'clientCnpjCpf': _cliente?.cnpjCpf ?? '',
        'responsavelEmail': user?.email ?? '',
        'criado_em': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── WhatsApp ──────────────────────────────────────────────────────────
  Future<void> _abrirWhatsApp(
      String docId, String numeroAssistencia) async {
    final telefone =
        _cliente?.contatoTelefone ?? _cliente?.contato ?? '';
    final numeroLimpo = telefone.replaceAll(RegExp(r'\D'), '');

    final tipoLabel = _tiposServico
        .firstWhere((t) => t.$1 == _tipoServicoCtrl.text,
            orElse: () => ('', 'Serviço residencial'))
        .$2;

    final endereco = _enderecoCtrl.text;
    final agendamentoStr = _dataAgendamento != null
        ? '${DateFormat('dd/MM/yyyy').format(_dataAgendamento!)}'
            '${_horaAgendamento != null ? ' às ${_horaAgendamento!.format(context)}' : ''}'
        : 'a confirmar';

    final texto = 'Prezado(a) ${_cliente?.nome ?? 'cliente'},\n\n'
        'Informamos que a assistência residencial *$numeroAssistencia* foi registrada.\n\n'
        '*Serviço:* $tipoLabel\n'
        '${endereco.isNotEmpty ? '*Local:* $endereco\n' : ''}'
        '*Agendamento:* $agendamentoStr\n\n'
        'Em caso de dúvidas, entre em contato conosco.\n\n'
        'Atenciosamente,\nUpgrade Seguros';

    final encoded = Uri.encodeComponent(texto);
    final url = numeroLimpo.isNotEmpty
        ? 'https://wa.me/55$numeroLimpo?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool?> _mostrarDialogoSalvar() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar Assistência'),
        content:
            const Text('Deseja notificar o cliente via WhatsApp após salvar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Apenas Salvar')),
          FilledButton.icon(
            icon: const Icon(Icons.message, size: 18),
            label: const Text('Salvar e Avisar'),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  // ── Salvar ────────────────────────────────────────────────────────────
  Future<void> _salvar(
      {bool silent = true, bool notificarWhatsApp = false}) async {
    if (_cliente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cliente')),
      );
      return;
    }
    if (_tipoServicoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de serviço')),
      );
      return;
    }

    if (_enderecoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o endereço do serviço')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      print('=== SALVANDO ASSISTÊNCIA RESIDENCIAL ===');
      print('DEBUG 1: Cliente selecionado: ${_cliente!.nome}');
      print('DEBUG 2: Tipo de serviço raw: "${_tipoServicoCtrl.text}"');

      final agora = DateTime.now();
      final numeroAssistencia =
          'AR${agora.year}${agora.month.toString().padLeft(2, '0')}${agora.day.toString().padLeft(2, '0')}${agora.hour.toString().padLeft(2, '0')}${agora.minute.toString().padLeft(2, '0')}${agora.second.toString().padLeft(2, '0')}';

      print('DEBUG 3: numeroAssistencia = $numeroAssistencia');

      // Configura SLA padrão (30 minutos para a maioria)
      final minutosSla = int.tryParse(_tempoSlaCtrl.text) ?? 30;
      final slaPrevisto = DateTime.now().add(Duration(minutes: minutosSla));

      print('DEBUG 4: slaPrevisto = $slaPrevisto');

      final tipoLabel = _tiposServico
          .firstWhere((t) => t.$1 == _tipoServicoCtrl.text,
              orElse: () => ('outro', 'Outro'))
          .$2;

      print('DEBUG 5: tipoLabel encontrado: "$tipoLabel"');

      final assist = Claim(
        idCliente: _cliente!.id,
        numeroSinistro: numeroAssistencia,
        tipoOcorrencia: _tipoServicoCtrl.text == 'outro' &&
                _outroServicoCtrl.text.isNotEmpty
            ? 'outro:${_outroServicoCtrl.text}'
            : _tipoServicoCtrl.text,
        ramoSinistro: 'Assistência Residencial',
        dataOcorrencia: agora,
        dataAviso: agora,
        localOcorrencia: _enderecoCtrl.text,
        relatoEvento: _relatoCtrl.text,
        statusAtual: 'Aberto',
        dataAbertura: agora,
        dataUltimaAtualizacao: agora,
        clientNome: _cliente!.nome,
        clientCnpjCpf: _cliente!.cnpjCpf,
        numeroSeguradora: _cliente!.apolices
          .firstWhere(
            (a) => a.ramo == 'Residencial' &&
                  a.dataInicio.isBefore(DateTime.now()) &&
                  a.dataFim.isAfter(DateTime.now()),
            orElse: () => null as dynamic,
          )
          ?.numeroApolice ?? '',
        protocoloSeguradora: _protocoloSeguradoraCtrl.text.isNotEmpty ? _protocoloSeguradoraCtrl.text.toUpperCase() : null,
        valorFranquia: BRFormatters.parseFromMoeda(_franquiaCtrl.text),
        status: 'Aberto',
        enderecoTerceiro: _enderecoCtrl.text,
        tipo: 'assistencia',
        tipoAssistencia: 'residencial',
        slaPrevisto: slaPrevisto,
        tempoSlaMinutos: minutosSla,
        nomeContatoOficina: _nomeContatoServicoCtrl.text.isNotEmpty ? _nomeContatoServicoCtrl.text : null,
        telefoneContatoOficina: _telefoneContatoServicoCtrl.text.isNotEmpty ? _telefoneContatoServicoCtrl.text : null,
        telefoneCliente: _cliente!.contatoTelefone.isNotEmpty
            ? _cliente!.contatoTelefone
            : null,
        seguradora: _seguradoraCtrl.text.trim(),
        dataAgendamento: _dataAgendamento,
        horaAgendamento: _horaAgendamento != null
            ? '${_horaAgendamento!.hour.toString().padLeft(2, '0')}:${_horaAgendamento!.minute.toString().padLeft(2, '0')}'
            : null,
        anotacoes: _anotacoesCtrl.text.isNotEmpty
            ? [
                {
                  'autor': _authService.getUserEmail(),
                  'conteudo': _anotacoesCtrl.text,
                  'data': agora.toIso8601String(),
                }
              ]
            : [],
      );

      print('DEBUG 6: Claim criado com:');
      print('  - tipoOcorrencia: "${assist.tipoOcorrencia}"');
      print('  - tipoAssistencia: "${assist.tipoAssistencia}"');
      print('  - numeroSinistro: "${assist.numeroSinistro}"');

      print('DEBUG 7: Enviando para Firestore...');
      final docId = await _firestoreService.addClaim(assist);
      print('DEBUG 8: docId recebido = "$docId"');

      if (docId == null || docId.isEmpty) {
        throw Exception('Falha ao salvar no Firestore');
      }

      // Upload de anexos
      if (_anexos.values.any((l) => l.isNotEmpty)) {
        final urls = await _uploadAnexos(numeroAssistencia);
        assist.fotosUrls = urls['Fotos da Ocorrência'] ?? [];
        assist.arquivosLaudosUrls = urls['Documentos'] ?? [];
        assist.id = docId;
        await _firestoreService.updateClaim(assist);
      }

      await _salvarTarefas(docId, numeroAssistencia);

      if (notificarWhatsApp && mounted) {
        await _abrirWhatsApp(docId, numeroAssistencia);
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistência residencial criada!')),
        );
      }

      print('DEBUG 9: Assistência salva com sucesso');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AssistDetailScreen(assistId: docId),
          ),
        );
      }
    } catch (e) {
      print('❌ ERRO NA CATCH: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      print('DEBUG 10: Finalmente - definindo _isSaving = false');
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── UI helpers ────────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color)),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sair sem salvar?'),
            content:
                const Text('As informações preenchidas serão perdidas.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continuar')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sair',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (confirm == true && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        appBar: AppBar(
          title: const Text('Nova Assistência Residencial'),
          backgroundColor: Colors.blue.shade50,
          foregroundColor: const Color(0xFF1A1A2E),
          elevation: 1,
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            TextButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Criar & Abrir'),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.blue.shade700),
              onPressed: _isSaving
                  ? null
                  : () async {
                      final opcao = await _mostrarDialogoSalvar();
                      if (opcao == null) return;
                      await _salvar(
                          silent: false, notificarWhatsApp: opcao);
                    },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── 1. Cliente ─────────────────────────────────────────────
              _buildSectionCard(
                icon: Icons.person,
                color: const Color(0xFF1565C0),
                title: 'Cliente',
                children: [
                  TextField(
                    onTap: _abrirBuscaCliente,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Nome do Cliente',
                      hintText: 'Clique para buscar cliente',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.business),
                      suffixIcon: const Icon(Icons.search),
                    ),
                    controller: _clienteBuscaCtrl,
                  ),
                  if (_cliente != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'CNPJ / CPF',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            controller: TextEditingController(
                                text: _cliente!.cnpjCpf),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Telefone',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            controller: TextEditingController(
                                text: _cliente!.contatoTelefone),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ── 2. Tipo de Serviço & Seguradora ────────────────────────────
              _buildSectionCard(
                icon: Icons.home_repair_service,
                color: Colors.blue.shade700,
                title: 'Tipo de Serviço & Seguradora',
                children: [
                  // Linha 1: Seguradora (autocomplete) + Protocolo + Franquia + SLA
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                            return _seguradoras.where((s) =>
                                s.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (selection) =>
                              setState(() => _seguradoraCtrl.text = selection),
                          fieldViewBuilder: (ctx, autoCtrl, focusNode, onSubmitted) {
                            autoCtrl.text = _seguradoraCtrl.text;
                            return TextField(
                              controller: autoCtrl,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Seguradora',
                                prefixIcon: const Icon(Icons.business_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (v) => _seguradoraCtrl.text = v,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _protocoloSeguradoraCtrl,
                          decoration: InputDecoration(
                            labelText: 'Protocolo da Seguradora',
                            prefixIcon: const Icon(Icons.confirmation_number_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (v) {
                            final upper = v.toUpperCase();
                            if (upper != v) {
                              _protocoloSeguradoraCtrl.value = _protocoloSeguradoraCtrl.value
                                  .copyWith(text: upper, selection: TextSelection.collapsed(offset: upper.length));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _franquiaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Franquia',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [BRFormatters.moedaFormatter],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 130,
                        child: TextField(
                          controller: _tempoSlaCtrl,
                          decoration: InputDecoration(
                            labelText: 'SLA (minutos)',
                            prefixIcon: const Icon(Icons.timer_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            helperText: 'Padrão: 30 min',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Tipo de serviço
                  const Text('Tipo de serviço:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tiposServico.map((tipo) {
                      final isSelected = _tipoServicoCtrl.text == tipo.$1;
                      return FilterChip(
                        label: Text(tipo.$2),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            if (isSelected) {
                              // Se já está selecionado, deseleciona
                              _tipoServicoCtrl.text = '';
                              _outroServicoCtrl.clear();
                            } else {
                              // Se não está selecionado, seleciona este
                              _tipoServicoCtrl.text = tipo.$1;
                              if (tipo.$1 != 'outro') {
                                _outroServicoCtrl.clear();
                              }
                            }
                          });
                        },
                        selectedColor: Colors.blue.shade100,
                        side: BorderSide(
                          color: isSelected
                              ? Colors.blue.shade600
                              : Colors.grey.shade300,
                        ),
                      );
                    }).toList(),
                  ),
                  if (_tipoServicoCtrl.text == 'outro') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _outroServicoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Descreva o serviço',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // ── 3. Local do Serviço ────────────────────────────────────
              _buildSectionCard(
                icon: Icons.location_on,
                color: const Color(0xFF2E7D32),
                title: 'Local do Serviço',
                children: [
                  TextField(
                    controller: _enderecoCtrl,
                    readOnly: true,
                    onTap: () async {
                      final result = await _openPlaceSearch(
                        onLatLng: (ll) => _enderecoLatLng = ll,
                      );
                      if (result != null && result.isNotEmpty) {
                        setState(() => _enderecoCtrl.text = result);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Endereço do serviço',
                      hintText: 'Clique para buscar',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.home_outlined),
                      suffixIcon: _enderecoCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() {
                                    _enderecoCtrl.clear();
                                    _enderecoLatLng = null;
                                  }),
                            )
                          : const Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nomeContatoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nome do contato no local (opcional)',
                            prefixIcon:
                                const Icon(Icons.person_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _telefoneCtrl,
                          decoration: InputDecoration(
                            labelText: 'Telefone',
                            prefixIcon:
                                const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            BRFormatters.telefoneFormatter
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 4. Relato & Anotações ──────────────────────────────────
              _buildSectionCard(
                icon: Icons.description_outlined,
                color: const Color(0xFFD32F2F),
                title: 'Relato & Anotações',
                children: [
                  TextField(
                    controller: _relatoCtrl,
                    maxLines: 4,
                    minLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Relato do cliente',
                      hintText: 'Descreva o problema relatado...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _anotacoesCtrl,
                    maxLines: 3,
                    minLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Anotações internas (opcional)',
                      hintText: 'Observações para a equipe...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 5. Agendamento & Tarefas ───────────────────────────────
              _buildSectionCard(
                icon: Icons.task_alt,
                color: Colors.blue.shade700,
                title: 'Agendamento & Tarefas',
                trailing: TextButton.icon(
                  onPressed: _adicionarTarefaLocal,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Adicionar'),
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _dataAgendamento ??
                                  DateTime.now()
                                      .add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null)
                              setState(() => _dataAgendamento = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Data do agendamento',
                              prefixIcon: const Icon(
                                  Icons.calendar_today_outlined),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            child: Text(
                              _dataAgendamento != null
                                  ? DateFormat('dd/MM/yyyy')
                                      .format(_dataAgendamento!)
                                  : 'Selecionar',
                              style: TextStyle(
                                color: _dataAgendamento != null
                                    ? null
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime:
                                  _horaAgendamento ?? TimeOfDay.now(),
                            );
                            if (picked != null)
                              setState(() => _horaAgendamento = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Hora',
                              prefixIcon: const Icon(
                                  Icons.access_time_outlined),
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(8)),
                            ),
                            child: Text(
                              _horaAgendamento != null
                                  ? _horaAgendamento!.format(context)
                                  : 'Selecionar',
                              style: TextStyle(
                                color: _horaAgendamento != null
                                    ? null
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Contato que realizará o serviço
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nomeContatoServicoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nome do contato que realizará o serviço (opcional)',
                            prefixIcon: const Icon(Icons.person_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _telefoneContatoServicoCtrl,
                          decoration: InputDecoration(
                            labelText: 'Telefone',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          inputFormatters: [BRFormatters.telefoneFormatter],
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  if (_tarefasLocais.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nenhuma tarefa adicionada.',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                    )
                  else
                    Column(
                      children: _tarefasLocais
                          .asMap()
                          .entries
                          .map((entry) {
                        final i = entry.key;
                        final t = entry.value;
                        final prazo = t['prazo'] as DateTime;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule,
                              color: Colors.orange, size: 20),
                          title: Text(t['descricao'] as String,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            'Prazo: ${DateFormat('dd/MM/yyyy').format(prazo)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 18),
                            onPressed: () => setState(
                                () => _tarefasLocais.removeAt(i)),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── 6. Anexos ──────────────────────────────────────────────
              _buildSectionCard(
                icon: Icons.attach_file,
                color: const Color(0xFF00695C),
                title: 'Anexos',
                children: [
                  _AssistAnexosCard(
                    anexos: _anexos,
                    dragOver: _dragOver,
                    isUploading: false,
                    onAddArquivos: _adicionarArquivos,
                    onRemoveArquivo: _removerArquivo,
                    onPickArquivos: _pickArquivos,
                    onDragEntered: (cat, val) =>
                        setState(() => _dragOver[cat] = val),
                    onDragExited: (cat, val) =>
                        setState(() => _dragOver[cat] = val),
                    isImageFile: _isImageFile,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Botões de ação ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isSaving
                      ? null
                      : () async {
                          final opcao = await _mostrarDialogoSalvar();
                          if (opcao == null) return;
                          await _salvar(silent: false, notificarWhatsApp: opcao);
                        },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Criar Assistência'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange.shade600,
                    ),
                  ),
                ),
              ],
            ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delegate de busca de clientes ─────────────────────────────────────────
class _ClientSearchDelegate extends SearchDelegate<Client?> {
  final List<Client> clients;
  _ClientSearchDelegate(this.clients);

  @override
  List<Widget> buildActions(BuildContext context) =>
      [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final filtered = clients
        .where((c) =>
            c.nome.toLowerCase().contains(query.toLowerCase()) ||
            c.cnpjCpf.contains(query))
        .toList();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final c = filtered[i];
        return ListTile(
          leading: const Icon(Icons.business),
          title: Text(c.nome),
          subtitle: Text(c.cnpjCpf),
          onTap: () => close(ctx, c),
        );
      },
    );
  }
}

// ── Widget de Anexos (copiado do spreadsheet_assist_screen) ───────────────
class _AssistAnexosCard extends StatelessWidget {
  final Map<String, List<XFile>> anexos;
  final Map<String, bool> dragOver;
  final bool isUploading;
  final void Function(String, List<XFile>, [List<PlatformFile>?])
      onAddArquivos;
  final void Function(String, XFile) onRemoveArquivo;
  final Future<void> Function(String) onPickArquivos;
  final void Function(String, bool) onDragEntered;
  final void Function(String, bool) onDragExited;
  final bool Function(String) isImageFile;

  const _AssistAnexosCard({
    required this.anexos,
    required this.dragOver,
    required this.isUploading,
    required this.onAddArquivos,
    required this.onRemoveArquivo,
    required this.onPickArquivos,
    required this.onDragEntered,
    required this.onDragExited,
    required this.isImageFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: anexos.entries.map((entry) {
        final categoria = entry.key;
        final arquivos = entry.value;
        final isDragging = dragOver[categoria] ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoria,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            DropTarget(
              onDragDone: (details) {
                final xfiles = details.files
                    .map((f) => XFile(f.path, name: f.name))
                    .toList();
                onAddArquivos(categoria, xfiles);
              },
              onDragEntered: (_) => onDragEntered(categoria, true),
              onDragExited: (_) => onDragExited(categoria, false),
              child: GestureDetector(
                onTap: () => onPickArquivos(categoria),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDragging
                        ? Colors.blue.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDragging
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          color: Colors.grey.shade400, size: 28),
                      const SizedBox(height: 4),
                      Text(
                        'Arraste ou clique para adicionar',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (arquivos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: arquivos.map((xfile) {
                  final isImg = isImageFile(xfile.name);
                  return Stack(
                    alignment: Alignment.topRight,
                    children: [
                      isImg
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(xfile.path,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover)
                                  : Image.file(File(xfile.path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover),
                            )
                          : Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.insert_drive_file,
                                      size: 32),
                                  Text(
                                    p.extension(xfile.name)
                                        .toUpperCase()
                                        .replaceAll('.', ''),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                      GestureDetector(
                        onTap: () => onRemoveArquivo(categoria, xfile),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }
}
