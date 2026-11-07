// lib/screens/spreadsheet_assist_screen.dart
// ignore_for_file: use_build_context_synchronously

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
import 'package:upgrade_seguros/dialogs/apolice_selection_dialog.dart';
import 'package:upgrade_seguros/models/apolice_model.dart';
import 'package:upgrade_seguros/models/vehicle_model.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/image_services.dart';
import '../services/place_search_delegate.dart';
import '../utils/formatters.dart';
import '../widgets/client_search_dialog.dart';
import '../widgets/task_list_widget.dart';
import '../screens/assist_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:upgrade_seguros/models/workshop_model.dart';

class SpreadsheetAssistScreen extends StatefulWidget {
  final String tipoAssistencia;
  const SpreadsheetAssistScreen({Key? key, required this.tipoAssistencia}) : super(key: key);
  
  @override
  State<SpreadsheetAssistScreen> createState() => _SpreadsheetAssistScreenState();
}

class _SpreadsheetAssistScreenState extends State<SpreadsheetAssistScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  // Cliente selecionado
  Client? _cliente;
  final TextEditingController _clienteBuscaCtrl = TextEditingController();
  bool _isNovoCliente = false;
  DateTime? _dataAgendamento;
  TimeOfDay? _horaAgendamento;
  final List<Map<String, dynamic>> _tarefasLocais = [];
  bool _isRetroativo = false;
  DateTime? _dataRecebimentoComunicado;
  TimeOfDay? _horaRecebimentoComunicado;


  Vehicle? _veiculoSelecionado;
  bool _veiculoManual = false;
  final TextEditingController _veiculoMarcaCtrl = TextEditingController();
  final TextEditingController _veiculoModeloCtrl = TextEditingController();
  final TextEditingController _veiculoCorCtrl = TextEditingController();
  final TextEditingController _veiculoAnoCtrl = TextEditingController();
  final TextEditingController _veiculoPlacaCtrl = TextEditingController();
  final TextEditingController _veiculoChassiCtrl = TextEditingController();
  final TextEditingController _outroAssistenciaCtrl = TextEditingController(); 

  // Campos de assistência
  final TextEditingController _tipoAssistenciaCtrl = TextEditingController();
  final TextEditingController _protocoloSeguradoraCtrl = TextEditingController();
  final TextEditingController _localizacaoCtrl = TextEditingController();
  final TextEditingController _localDestinoCtrl = TextEditingController();
  final TextEditingController _nomeContatoCtrl = TextEditingController();
  final TextEditingController _contatoCtrl = TextEditingController();
  final TextEditingController telefoneClienteCtrl = TextEditingController();
  final TextEditingController _oficinaTerceiroCtrl = TextEditingController();
  final TextEditingController _franquiaCtrl = TextEditingController();
  final TextEditingController _relatoCtrl = TextEditingController();
  final TextEditingController _anotacoesCtrl = TextEditingController();
  final TextEditingController _seguradoraCtrl = TextEditingController();
  final TextEditingController _nomeContatoOficinaCtrl = TextEditingController();
  final TextEditingController _telefoneContatoOficinaCtrl = TextEditingController();
  final TextEditingController _tempoSlaCtrl = TextEditingController(text: '30');
  final List<String> _tiposVidroSelecionados = [];
  final TextEditingController _outroVidroCtrl = TextEditingController();
  List<String> _seguradoras = [];
  final TextEditingController _numeroApoliceCtrl = TextEditingController();

  final TextEditingController _cpfCnpjCtrl = TextEditingController();
  final TextEditingController _telefoneCtrl = TextEditingController();
  final TextEditingController _vigenciaCtrl = TextEditingController();

  // ─── Controllers específicos de RESIDENCIAL ───────────────────────────────
  final TextEditingController _tipoServicoCtrl = TextEditingController();
  final TextEditingController _outroServicoCtrl = TextEditingController();
  final TextEditingController _enderecoCtrl = TextEditingController();
  final TextEditingController _telefoneContatoLocalCtrl  = TextEditingController(); // telefoneContatoLocal
  final TextEditingController _telefoneClienteCtrl = TextEditingController(); // telefoneCliente

  // Google Places
  final _places = FlutterGooglePlacesSdk('AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE');
  LatLng? _localOcorrenciaLatLng;
  LatLng? _localDestinoLatLng;
  LatLng? _oficinaTerceiroLatLng;
  LatLng? _enderecoLatLng;

  bool _localOcorrenciaManualMode = false;
  bool _localDestinoManualMode = false;

  bool _isSaving = false;
  bool _isUploadingAnexos = false;
  String? _savedDocId;       // ID do doc após primeiro save (para tarefas)
  String? _savedNumero;      // número da assistência após primeiro save

  String _vigenciaApolice = '';
  String _nomeUsuarioLogado = 'Desconhecido';

  List<Workshop> _workshopsDisponiveis = [];
  Workshop? _workshopSelecionado;
  bool _carregandoWorkshops = false;
  List<String> _oficinasNomes = [];
  final _oficinaNomeCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _loadNomeUsuario();
    _carregarSeguradoras();
    _loadConfig();
    _carregarWorkshops();

    // 🔥 Listener para resetar quando o nome for apagado
     _clienteBuscaCtrl.addListener(() {
      if (_clienteBuscaCtrl.text.trim().isEmpty) {
        setState(() {
          _cliente = null;
          _cpfCnpjCtrl.clear();
          _telefoneCtrl.clear();
          _contatoCtrl.clear();
          _numeroApoliceCtrl.clear();
          _vigenciaCtrl.clear();
          _vigenciaApolice = ''; // se você ainda tiver essa variável
        });
      }
    });
  }

  @override
  void dispose() {
    _clienteBuscaCtrl.dispose();
    _tipoAssistenciaCtrl.dispose();
    _protocoloSeguradoraCtrl.dispose();
    _localizacaoCtrl.dispose();
    _localDestinoCtrl.dispose();
    _nomeContatoCtrl.dispose();
    _contatoCtrl.dispose();
    telefoneClienteCtrl.dispose();
    _oficinaTerceiroCtrl.dispose();
    _franquiaCtrl.dispose();
    _relatoCtrl.dispose();
    _anotacoesCtrl.dispose();
    super.dispose();
    _seguradoraCtrl.dispose();
    _nomeContatoOficinaCtrl.dispose();
    _telefoneContatoOficinaCtrl.dispose();
    _veiculoMarcaCtrl.dispose();
    _veiculoModeloCtrl.dispose();
    _veiculoCorCtrl.dispose();
    _veiculoAnoCtrl.dispose();
    _veiculoPlacaCtrl.dispose();
    _veiculoChassiCtrl.dispose();
    _tempoSlaCtrl.dispose();
    _outroVidroCtrl.dispose();
    _outroAssistenciaCtrl.dispose();
  }

  String _formatarVigencia(DateTime data) {
    return DateFormat('dd/MM/yyyy').format(data);
  }

  Future<void> _loadNomeUsuario() async {
    final nome = await _authService.getUserName();
    setState(() => _nomeUsuarioLogado = nome);
  }

  // Método para carregar workshops do Firestore
  Future<void> _carregarWorkshops() async {
    setState(() => _carregandoWorkshops = true);
    try {
      final docs = await FirebaseFirestore.instance
          .collection('workshops')
          .orderBy('nome')
          .get();
      
      setState(() {
        _workshopsDisponiveis = docs.docs
            .map((doc) => Workshop.fromMap({...doc.data(), 'id': doc.id}))
            .toList();
        
        // ✨ NOVO: Extrair nomes
        _oficinasNomes = _workshopsDisponiveis
            .map((w) => w.nome.toUpperCase())
            .toList();
        
        _carregandoWorkshops = false;
      });
    } catch (e) {
      debugPrint('❌ Erro ao carregar workshops: $e');
      setState(() => _carregandoWorkshops = false);
    }
  }

  Future<void> _loadConfig() async {
    final tipoRamo = widget.tipoAssistencia == 'veiculo' ? 'Veicular' : 'Residencial';
    final minutos = await ConfigService().getSlaAssistencia(tipoRamo);
    setState(() {
      _tempoSlaCtrl.text = minutos.toString();
    });
  }

  Future<void> _abrirBuscaCliente() async {
    final result = await showDialog<ClientSearchResult>(
      context: context,
      useRootNavigator: false,
      builder: (_) => ClientSearchDialog(
        initialQuery: _clienteBuscaCtrl.text,
        onClientSelected: (c) => c != null ? ClientSearchResult.client(c) : null,
      ),
    );
    if (result == null) return;

    if (result.client != null) {
      final cliente = result.client!;
      
      // 🔥 DEFINE OS RAMOS VÁLIDOS PARA ESSE TIPO
      final ramosValidos = widget.tipoAssistencia == 'veiculo'
          ? ['Frota', 'Veículo Individual', 'Transporte', 'Civil Ônibus (RCO)']
          : ['Residencial'];

      // 🔥 FILTRA APÓLICES - DEVE ESTAR EM UM DOS RAMOS VÁLIDOS E ATIVA
      final apolicesDoRamo = cliente.apolices
          .where((a) => ramosValidos.contains(a.ramo) &&
                a.dataInicio.isBefore(DateTime.now()) &&
                a.dataFim.isAfter(DateTime.now()))
          .toList();

      Apolice? apoliceParaMostrar;

      if (apolicesDoRamo.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Cliente não possui apólice ativa para ${widget.tipoAssistencia == 'veiculo' ? 'veículos' : 'residencial'}.'),
            backgroundColor: Colors.orange,
          ),
        );
        apoliceParaMostrar = null;
      } else if (apolicesDoRamo.length > 1) {
        // 🔥 ABRE MODAL PARA ESCOLHER
        apoliceParaMostrar = await showDialog<Apolice>(
          context: context,
          builder: (_) => ApoliceSelectionDialog(
            apolices: apolicesDoRamo,
            ramoSelecionado: widget.tipoAssistencia == 'veiculo' ? 'Veicular' : 'Residencial',
          ),
        );
      } else {
        // Uma única apólice, seleciona automaticamente
        apoliceParaMostrar = apolicesDoRamo.first;
      }

      // ✅ PREENCHE OS DADOS DO CLIENTE (SEMPRE)
      final cpfCnpjFormatado = cliente.cnpjCpf.length <= 11
          ? BRFormatters.formatarCPF(cliente.cnpjCpf)
          : BRFormatters.formatarCNPJ(cliente.cnpjCpf);

      final telefoneFormatado = cliente.contatoTelefone.isNotEmpty
          ? BRFormatters.formatarTelefone(cliente.contatoTelefone)
          : 'Não informado';

      setState(() {
        _cliente = cliente;
        _clienteBuscaCtrl.text = cliente.nome;
        _cpfCnpjCtrl.text = cpfCnpjFormatado;
        _telefoneCtrl.text = telefoneFormatado;
        _contatoCtrl.text = cliente.contato.isNotEmpty ? cliente.contato : 'Não informado';

        // ✅ PREENCHE DADOS DA APÓLICE (SE HOUVER)
        if (apoliceParaMostrar != null) {
          _numeroApoliceCtrl.text = apoliceParaMostrar.numeroApolice;
          _vigenciaApolice = BRFormatters.formatarData(apoliceParaMostrar.dataFim);
          _seguradoraCtrl.text = apoliceParaMostrar.seguradora;
        } else {
          // Limpa campos da apólice se não encontrou
          _numeroApoliceCtrl.clear();
          _vigenciaApolice = '';
          _seguradoraCtrl.clear();
        }
      });
    }
  }

  // CARREGAR SEGURADORAS DO BANCO DE DADOS
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

  /// Abre popup para selecionar data/hora do comunicado retroativo
  Future<void> _abrirPopupRecebimentoComunicado() async {
    DateTime dataSelecionada = _dataRecebimentoComunicado ?? DateTime.now();
    TimeOfDay horaSelecionada = _horaRecebimentoComunicado ?? TimeOfDay.now();
  
    final resultado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Quando a assistência foi comunicada?'),
          // ✨ NOVA MENSAGEM INFORMATIVA
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✨ MENSAGEM DE INSTRUÇÃO
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Preencha somente se o atendimento já foi realizado e trata-se de atualização do sistema',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // DATA
                Row(
                  children: [
                    // DATA (Esquerda)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dataSelecionada,
                            firstDate: DateTime.now().subtract(const Duration(days: 60)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setStateDialog(() => dataSelecionada = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_outlined, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('dd/MM/yyyy').format(dataSelecionada),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // HORA (Direita)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: horaSelecionada,
                          );
                          if (picked != null) {
                            setStateDialog(() => horaSelecionada = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_outlined, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  horaSelecionada.format(context),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  
    if (resultado == true) {
      setState(() {
        _isRetroativo = true;
        _dataRecebimentoComunicado = dataSelecionada;
        _horaRecebimentoComunicado = horaSelecionada;
      });
    }
  }

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
                  maxLines: 3, minLines: 2,
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
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

  Future<void> _salvarTarefasNoFirestore(String claimId, String numeroAssistencia) async {
    final collection = FirebaseFirestore.instance.collection('tasks');
    final user = FirebaseAuth.instance.currentUser;

    DateTime? prazoAgendamento;
      if (_dataAgendamento != null) {
        prazoAgendamento = _dataAgendamento!;
        if (_horaAgendamento != null) {
          prazoAgendamento = DateTime(
            _dataAgendamento!.year,
            _dataAgendamento!.month,
            _dataAgendamento!.day,
            _horaAgendamento!.hour,
            _horaAgendamento!.minute,
          );
        }
      }

      if (prazoAgendamento != null) {
        final placa = _veiculoSelecionado?.placa ?? '';
        final oficina = _oficinaTerceiroCtrl.text;

        final descricao = [
          'Agendamento para ${_cliente?.nome ?? 'cliente'}',
          if (placa.isNotEmpty) 'Veículo: $placa',
          if (oficina.isNotEmpty) 'Local: $oficina',
        ].join(' • ');

        print('📅 Criando tarefa automática para agendamento em $prazoAgendamento');

        await collection.add({
          'descricao': descricao,
          'prazo': Timestamp.fromDate(prazoAgendamento),
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

        print('✅ Tarefa de agendamento salva com sucesso');
      } else {
        print('⚠️ Nenhuma data de agendamento definida – tarefa automática não criada');
      }

    // Tarefas manuais adicionadas pelo funcionário
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

  Future<void> _abrirWhatsApp(String docId, String numeroAssistencia) async {
    final telefone = _cliente?.contatoTelefone ?? _cliente?.contato ?? '';
    final numeroLimpo = telefone.replaceAll(RegExp(r'\D'), '');

    final tipo = _getTipoAssistenciaLabel();
    final localOcorrencia = _localizacaoCtrl.text;
    final oficina = _oficinaTerceiroCtrl.text;
    final agendamentoStr = _dataAgendamento != null
        ? '${DateFormat('dd/MM/yyyy').format(_dataAgendamento!)}'
          '${_horaAgendamento != null ? ' às ${_horaAgendamento!.format(context)}' : ''}'
        : 'a confirmar';

    final veiculo = _veiculoSelecionado;
    final veiculoStr = veiculo != null
        ? '*Veículo:* ${veiculo.marca} ${veiculo.modelo}'
          '${veiculo.placa.isNotEmpty ? ' - Placa ${veiculo.placa}' : ''}\n'
        : '';

    final tempoStr = '*Previsão de atendimento:* ${_tempoSlaCtrl.text.isNotEmpty ? _tempoSlaCtrl.text : '30'} minutos\n';

    final texto = 'Prezado(a) ${_cliente?.nome ?? 'cliente'},\n\n'
        'Informamos que a assistência *$numeroAssistencia* foi registrada em nosso sistema.\n\n'
        '*Tipo:* $tipo\n'
        '${veiculoStr}'
        '${localOcorrencia.isNotEmpty ? '*Local da ocorrência:* $localOcorrencia\n' : ''}'
        '${oficina.isNotEmpty ? '*Destino/Oficina:* $oficina\n' : ''}'
        '*Agendamento:* $agendamentoStr\n'
        '$tempoStr'
        'Em caso de dúvidas, entre em contato conosco.\n\n'
        'Atenciosamente,\n'
        'Upgrade Seguros';

    final encoded = Uri.encodeComponent(texto);
    final url = numeroLimpo.isNotEmpty
        ? 'https://wa.me/55$numeroLimpo?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
        );
      }
    }
  }

  String _getTipoAssistenciaLabel() {
    final map = {
      'guincho': 'Guincho',
      'vidro': 'Vidros',
      'combustivel': 'Combustível',
      'pane_eletrica': 'Pane Elétrica',
      'carga_bateria': 'Carga de Bateria',
      'falta': 'Falta de Peça',
      'reboque': 'Reboque',
      'outro': 'Outro',
    };
    return map[_tipoAssistenciaCtrl.text] ?? 'Assistência';
  }

  Future<bool?> _mostrarDialogoSalvar() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salvar Assistência'),
        content: const Text('Deseja notificar o cliente via WhatsApp após salvar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Apenas Salvar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.message, size: 18),
            label: const Text('Salvar e Comunicar Cliente'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  // ── Métodos de anexo ─────────────────────────────────────────────────────

  void _adicionarArquivos(String categoria, List<XFile> arquivos, [List<PlatformFile>? platformFiles]) {
    setState(() {
      _anexos[categoria]!.addAll(arquivos);
      if (platformFiles != null) {
        _platformFiles[categoria] ??= [];
        _platformFiles[categoria]!.addAll(platformFiles);
      }
    });
  }

  void _removerArquivo(String categoria, XFile arquivo) {
    setState(() {
      _anexos[categoria]!.remove(arquivo);
      _platformFiles[categoria]?.removeWhere((pf) => pf.name == arquivo.name);
    });
  }

  Future<void> _pickArquivos(String categoria) async {
    final isImagem = categoria == 'Fotos da Ocorrência';

    if (isImagem && !kIsWeb) {
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) _adicionarArquivos(categoria, picked);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: isImagem ? FileType.image : FileType.custom,
      allowedExtensions: isImagem ? null : ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx'],
    );

    if (result != null && result.files.isNotEmpty) {
      if (isImagem) {
        final xfiles = result.files.map((f) => XFile(f.path ?? '', name: f.name)).toList();
        _adicionarArquivos(categoria, xfiles);
      } else {
        setState(() {
          _platformFiles[categoria] ??= [];
          _platformFiles[categoria]!.addAll(result.files);
          final xfiles = result.files.map((f) => XFile(f.path ?? '', name: f.name)).toList();
          _anexos[categoria]!.addAll(xfiles);
        });
      }
    }
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

  bool _isImageFile(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

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

  Future<void> _salvar({bool silent = true, bool notificarWhatsApp = false}) async {
    final userId = _authService.getUserId();
    final userEmail = _authService.getUserEmail();
    // Validações
    if (_cliente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cliente')),
      );
      return;
    }

    // Valida tipo de assistência (veicular) ou tipo de serviço (residencial)
    late String tipoSelecionado = widget.tipoAssistencia == 'veiculo' 
      ? _tipoAssistenciaCtrl.text 
      : _tipoServicoCtrl.text;

    if (tipoSelecionado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o tipo de assistência')),
      );
      return;
    }

    if (_localizacaoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a localização')),
      );
      return;
    }

    // Validação: Se é "outro", campo descrição é obrigatório
    if (widget.tipoAssistencia == 'veiculo' && _tipoAssistenciaCtrl.text == 'outro') {
      if (_outroAssistenciaCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Descreva qual foi a requisição do cliente'))
        );
        setState(() => _isSaving = false);
        return;
      }
    }

    // ✨ VALIDAÇÃO: Se é retroativo, agendamento é obrigatório
    if (_isRetroativo && _dataAgendamento == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Se o comunicado é retroativo, a data de agendamento é obrigatória'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {

      // Gera número de assistência
      final agora = DateTime.now();
      final numeroAssistencia = 'AS'
          '${agora.year}'
          '${agora.month.toString().padLeft(2, '0')}'
          '${agora.day.toString().padLeft(2, '0')}'
          '${agora.hour.toString().padLeft(2, '0')}'
          '${agora.minute.toString().padLeft(2, '0')}'
          '${agora.second.toString().padLeft(2, '0')}';

      // Configura SLA padrão (30 minutos para a maioria)
      final minutosSla = int.tryParse(_tempoSlaCtrl.text) ?? 30;  // ← Já vem preenchido da config
      final slaPrevisto = DateTime.now().add(Duration(minutes: minutosSla));
      //final tipoSelecionado = _tipoAssistenciaCtrl.text;
      final ramoApolice = tipoSelecionado == 'Veicular' ? 'Veículo Individual' : 'Residencial';

      // Cria o claim como assistência
      final assist = Claim(
        idCliente: _cliente!.id,
        numeroSinistro: numeroAssistencia,
        tipoOcorrencia: widget.tipoAssistencia == 'veiculo' && _tipoAssistenciaCtrl.text == 'vidro' && _tiposVidroSelecionados.isNotEmpty
        ? 'vidro:${_tiposVidroSelecionados.join(',')}'
        : widget.tipoAssistencia == 'veiculo'
            ? _tipoAssistenciaCtrl.text
            : _tipoServicoCtrl.text,
        tipoOcorrenciaOutro: widget.tipoAssistencia == 'veiculo'
            ? (_tipoAssistenciaCtrl.text == 'outro' && _outroAssistenciaCtrl.text.isNotEmpty ? _outroAssistenciaCtrl.text : null)
            : (_tipoServicoCtrl.text == 'outro' && _outroServicoCtrl.text.isNotEmpty ? _outroServicoCtrl.text : null),
        ramoSinistro: 'Assistência',
        dataOcorrencia: DateTime.now(),
        dataAviso: DateTime.now(),
        localOcorrencia: _localizacaoCtrl.text,
        relatoEvento: _relatoCtrl.text,
        statusAtual: 'Aberto',
        dataAbertura: DateTime.now(),
        dataUltimaAtualizacao: DateTime.now(),
        clientNome: _cliente!.nome,
        clientCnpjCpf: _cliente!.cnpjCpf,
        numeroSeguradora: _numeroApoliceCtrl.text.isNotEmpty
            ? _numeroApoliceCtrl.text
            : '',
        status: 'Aberto',
        enderecoTerceiro: widget.tipoAssistencia == 'veiculo' ? _oficinaTerceiroCtrl.text : _enderecoCtrl.text,
        localDestino: _localDestinoCtrl.text.isNotEmpty ? _localDestinoCtrl.text : null,
        nomeContato: _nomeContatoCtrl.text.isNotEmpty ? _nomeContatoCtrl.text : null,
        telefoneContatoLocal: _telefoneContatoLocalCtrl.text.isNotEmpty ? _telefoneContatoLocalCtrl.text : null,
        protocoloSeguradora: _protocoloSeguradoraCtrl.text.isNotEmpty ? _protocoloSeguradoraCtrl.text.toUpperCase() : null,
        valorFranquia: BRFormatters.parseFromMoeda(_franquiaCtrl.text),
        // 🆕 Campos de assistência
        tipo: 'assistencia',
        tipoAssistencia: tipoSelecionado.toLowerCase().replaceAll(' ', '_'),        slaPrevisto: slaPrevisto,
        tempoSlaMinutos: minutosSla,
        dataAgendamento: _dataAgendamento,
        horaAgendamento: _horaAgendamento != null
            ? '${_horaAgendamento!.hour.toString().padLeft(2, '0')}:${_horaAgendamento!.minute.toString().padLeft(2, '0')}'
            : null,
        seguradora: _seguradoraCtrl.text.trim(),
        nomeContatoOficina: _nomeContatoOficinaCtrl.text.isNotEmpty
            ? _nomeContatoOficinaCtrl.text : null,
        telefoneContatoOficina: _telefoneContatoOficinaCtrl.text.isNotEmpty
            ? _telefoneContatoOficinaCtrl.text : null,

        telefoneCliente: _cliente!.contatoTelefone.isNotEmpty
          ? _cliente!.contatoTelefone
          : null,
        enderecoOficina: _oficinaTerceiroCtrl.text.isNotEmpty
          ? _oficinaTerceiroCtrl.text
          : null,
        responsavelId: userId,
        responsavelEmail: userEmail,       
        historicoStatus: [
          {
            'status': 'Aberto',
            'data': Timestamp.now(),
            'responsavel': userId,
            'responsavelEmail': userEmail,
            'registrado_por': _nomeUsuarioLogado,
          }
        ],
        veiculoSelecionado: _veiculoSelecionado ?? (
          _veiculoMarcaCtrl.text.isNotEmpty ? Vehicle(
            marca: _veiculoMarcaCtrl.text,
            modelo: _veiculoModeloCtrl.text,
            cor: _veiculoCorCtrl.text,
            ano: int.tryParse(_veiculoAnoCtrl.text) ?? 0,
            anomodelo: int.tryParse(_veiculoAnoCtrl.text) ?? 0,
            placa: _veiculoPlacaCtrl.text.toUpperCase(),
            chassi: _veiculoChassiCtrl.text.toUpperCase(),
          ) : null
        ),
        dataRecebimentoComunicado: _isRetroativo ? _dataRecebimentoComunicado : null,
        horaRecebimentoComunicado: _isRetroativo && _horaRecebimentoComunicado != null
            ? '${_horaRecebimentoComunicado!.hour.toString().padLeft(2, '0')}:${_horaRecebimentoComunicado!.minute.toString().padLeft(2, '0')}'
            : null,
      );

      // ✨ Se retroativo, adiciona data/hora do comunicado às anotações
      if (_isRetroativo && _dataRecebimentoComunicado != null) {
        final horaStr = _horaRecebimentoComunicado != null
            ? ' ${_horaRecebimentoComunicado!.format(context)}'
            : '';
        final dataReceb = DateFormat('dd/MM/yyyy').format(_dataRecebimentoComunicado!);
        
        assist.anotacoes = [
          {
            'autor': '⏰ SISTEMA',
            'conteudo': '[RETROATIVO] Comunicado recebido em: $dataReceb$horaStr',
            'data': DateTime.now().toIso8601String(),
            'tipo': 'retroativo',
          },
          ...?assist.anotacoes,
        ];
      }

      // Se houver anotações, adiciona
      if (_anotacoesCtrl.text.isNotEmpty) {
        assist.anotacoes = [
          ...assist.anotacoes,
          {
            'autor': _authService.getUserEmail(),
            'conteudo': _anotacoesCtrl.text,
            'data': DateTime.now().toIso8601String(),
          },
        ];
      }

      // Salva no Firestore
      final docId = await _firestoreService.addClaim(assist);

      if (docId == null || docId.isEmpty) {
        throw Exception('Falha ao obter ID do documento do Firestore');
      }

      // Armazena para o widget de tarefas
      setState(() {
        _savedDocId = docId;
        _savedNumero = numeroAssistencia;
      });

      // Upload de anexos (se houver)
      final temAnexos = _anexos.values.any((list) => list.isNotEmpty);
      if (temAnexos) {
        setState(() => _isUploadingAnexos = true);
        try {
          final anexosUrls = await _uploadAnexos(assist.numeroSinistro);
          if (anexosUrls.isNotEmpty) {
            assist.id = docId;
            assist.fotosUrls = anexosUrls['Fotos da Ocorrência'] ?? [];
            assist.arquivosLaudosUrls = anexosUrls['Documentos'] ?? [];
            await _firestoreService.updateClaim(assist);
          }
        } finally {
          if (mounted) setState(() => _isUploadingAnexos = false);
        }
      }

      // Salva tarefas locais no Firestore
      await _salvarTarefasNoFirestore(docId, numeroAssistencia);

      // WhatsApp
      if (notificarWhatsApp && mounted) {
        await _abrirWhatsApp(docId, numeroAssistencia);
      }

      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistência criada com sucesso')),
        );
      }

      // Redireciona para o detalhe
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AssistDetailScreen(assistId: docId),
          ),
        );
      } else {
      }
    } catch (e) {
      print('❌ ERRO NA CATCH: $e');
      print('Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar assistência: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- Tipos de Serviços ---
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Assistência'),
        backgroundColor: Colors.orange.shade50,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 1,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          TextButton.icon(
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Criar & Abrir'),
            style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
            onPressed: _isSaving
              ? null
              : () async {
                  final opcao = await _mostrarDialogoSalvar();
                  if (opcao == null) return;
                  await _salvar(silent: false, notificarWhatsApp: opcao);
                },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
      color: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── 1. Cliente & Apólice ─────────────────────────────────────
            _buildSectionCard(
              icon: Icons.person,
              color: const Color(0xFF1565C0),
              title: 'Cliente & Apólice',
              children: [
                TextField(
                  controller: _clienteBuscaCtrl,
                  onTap: _abrirBuscaCliente,
                  decoration: InputDecoration(
                    labelText: 'Nome do Cliente',
                    hintText: 'Digite o nome ou clique para buscar',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.business),
                    suffixIcon: _clienteBuscaCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _clienteBuscaCtrl.clear();
                                _cliente = null;
                                _numeroApoliceCtrl.clear();
                                _vigenciaApolice = '';
                              });
                            },
                          )
                        : const Icon(Icons.search),
                  ),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          controller: _cpfCnpjCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Nº Apólice',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          controller: _numeroApoliceCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Vigência da Apólice',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            suffixIcon: _vigenciaCtrl.text.isNotEmpty
                                ? _statusVigenciaIcon(_vigenciaCtrl.text)
                                : null,
                          ),
                          controller: _vigenciaCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Telefone do Cliente',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                          controller: _telefoneCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Nome do Contato (sócio/representante)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          controller: _contatoCtrl,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (widget.tipoAssistencia == 'veiculo') ...[
            // ── 2. Tipo de Assistência ───────────────────────────────────
            _buildSectionCard(
              icon: Icons.assignment,
              color: Colors.orange,
              title: 'Tipo de Assistência',
              children: [
                // ─────── LINHA 1: Seguradora + Protocolo + Franquia + SLA ────────
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
                    // ✨ RETROATIVO - WIDTH DOBRADO (260)
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 260,
                      child: GestureDetector(
                        onTap: () async {
                          if (!_isRetroativo) {
                            await _abrirPopupRecebimentoComunicado();
                          } else {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Comunicado Retroativo'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_dataRecebimentoComunicado != null)
                                      Text(
                                        '${DateFormat('dd/MM/yyyy').format(_dataRecebimentoComunicado!)} ${_horaRecebimentoComunicado != null ? _horaRecebimentoComunicado!.format(context) : ''}',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                      ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isRetroativo = false;
                                        _dataRecebimentoComunicado = null;
                                        _horaRecebimentoComunicado = null;
                                      });
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Remover'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      await _abrirPopupRecebimentoComunicado();
                                    },
                                    child: const Text('Editar'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: _isRetroativo ? 'Comunicado Retroativo' : 'Comunicado Retroativo',
                            prefixIcon: Icon(
                              _isRetroativo ? Icons.check_circle : Icons.circle_outlined,
                              color: _isRetroativo ? Colors.orange : Colors.grey.shade400,
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            helperText: _isRetroativo ? 'Clique para editar' : null,
                            filled: _isRetroativo,
                            fillColor: _isRetroativo ? Colors.orange.shade50 : Colors.transparent,
                          ),
                          child: Text(
                            _isRetroativo && _dataRecebimentoComunicado != null
                                ? '${DateFormat('dd/MM').format(_dataRecebimentoComunicado!)} ${_horaRecebimentoComunicado != null ? _horaRecebimentoComunicado!.format(context) : ''}'
                                : '',
                            style: TextStyle(
                              fontSize: 13,
                              color: _isRetroativo ? Colors.black : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Linha 4: Tipo de assistência (MANTÉM IGUAL)
                const Text('Tipo de assistência:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _buildTipoAssistenciaSelector(),

                // ── VEÍCULO ────────────────────────────────
                //if (widget.tipoAssistencia == 'veiculo') ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_car_outlined, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    const Text('Veículo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (_cliente != null && _cliente!.veiculosSegurados.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() {
                          _veiculoManual = !_veiculoManual;
                          _veiculoSelecionado = null;
                          _veiculoMarcaCtrl.clear();
                          _veiculoModeloCtrl.clear();
                          _veiculoCorCtrl.clear();
                          _veiculoAnoCtrl.clear();
                          _veiculoPlacaCtrl.clear();
                          _veiculoChassiCtrl.clear();
                        }),
                        child: Text(_veiculoManual ? 'Selecionar da lista' : 'Digitar manualmente'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_cliente != null &&
                    _cliente!.veiculosSegurados.isNotEmpty &&
                    !_veiculoManual) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cliente!.veiculosSegurados.map((v) {
                      final selected = _veiculoSelecionado == v;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _veiculoSelecionado = selected ? null : v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? Colors.orange.shade100 : Colors.grey.shade100,
                            border: Border.all(
                              color: selected ? Colors.orange : Colors.grey.shade300,
                              width: selected ? 1.5 : 0.8,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.directions_car,
                                  size: 16,
                                  color: selected ? Colors.orange.shade700 : Colors.grey.shade600),
                              const SizedBox(width: 6),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${v.marca} ${v.modelo}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected ? Colors.orange.shade700 : Colors.black87,
                                    ),
                                  ),
                                  if (v.placa.isNotEmpty)
                                    Text(
                                      '${v.placa}${v.cor.isNotEmpty ? ' · ${v.cor}' : ''}',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                ],
                              ),
                              if (selected) ...[
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle, size: 16, color: Colors.orange.shade700),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toque para selecionar o veículo da ocorrência',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                
                ] else ...[
                  if (_cliente == null)
                    Text(
                      'Selecione um cliente primeiro para ver os veículos cadastrados.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: _veiculoMarcaCtrl, decoration: InputDecoration(labelText: 'Marca', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: TextField(controller: _veiculoModeloCtrl, decoration: InputDecoration(labelText: 'Modelo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _veiculoCorCtrl, decoration: InputDecoration(labelText: 'Cor', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _veiculoPlacaCtrl, decoration: InputDecoration(labelText: 'Placa', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textCapitalization: TextCapitalization.characters)),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: TextField(controller: _veiculoChassiCtrl, decoration: InputDecoration(labelText: 'Chassi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), textCapitalization: TextCapitalization.characters)),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _veiculoAnoCtrl, decoration: InputDecoration(labelText: 'Ano', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.number)),
                      ],
                    ),
                  ],
                ],
              ],
            ),
            ],
            const SizedBox(height: 12),

            // ── 3. Localização & Contato ─────────────────────────────────
            _buildSectionCard(
              icon: Icons.location_on,
              color: const Color(0xFF2E7D32),
              title: 'Localização & Contato',
              children: [

                // Campos lado a lado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 LOCAL DA OCORRÊNCIA
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header com toggle
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                'Local da ocorrência',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _localOcorrenciaManualMode = !_localOcorrenciaManualMode;
                                  });
                                },
                                icon: Icon(
                                  _localOcorrenciaManualMode ? Icons.location_on : Icons.edit,
                                  size: 16,
                                ),
                                label: Text(
                                  _localOcorrenciaManualMode ? 'Usar Mapa' : 'Entrada Manual',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  backgroundColor: Colors.grey.shade200,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Campo
                          TextField(
                            controller: _localizacaoCtrl,
                            readOnly: !_localOcorrenciaManualMode,  // ✅ Dinâmico
                            onTap: () async {
                              if (!_localOcorrenciaManualMode) {  // ✅ Só abre mapa se estiver em modo mapa
                                final result = await _openPlaceSearch(
                                  onLatLng: (ll) => _localOcorrenciaLatLng = ll,
                                );
                                if (result != null && result.isNotEmpty) {
                                  setState(() => _localizacaoCtrl.text = result);
                                }
                              }
                            },
                            onChanged: _localOcorrenciaManualMode  // ✅ Reage ao digitado se estiver em modo manual
                                ? (value) {}
                                : null,
                            decoration: InputDecoration(
                              labelText: _localOcorrenciaManualMode ? 'Digite o endereço' : 'Clique para buscar',
                              hintText: _localOcorrenciaManualMode ? 'Digite o endereço' : 'Clique para buscar',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: const Icon(Icons.pin_drop_outlined),
                              suffixIcon: Icon(
                                _localOcorrenciaManualMode ? Icons.edit_note : Icons.location_on,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // 🔹 LOCAL DE DESTINO (só aparece se for veículo)
                    if (widget.tipoAssistencia == 'veiculo') ...[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header com toggle
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Local de destino',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _localDestinoManualMode = !_localDestinoManualMode;
                                    });
                                  },
                                  icon: Icon(
                                    _localDestinoManualMode ? Icons.flag_outlined : Icons.edit,
                                    size: 16,
                                  ),
                                  label: Text(
                                    _localDestinoManualMode ? 'Usar Mapa' : 'Entrada Manual',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    backgroundColor: Colors.grey.shade200,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Campo
                            TextField(
                              controller: _localDestinoCtrl,
                              readOnly: !_localDestinoManualMode,  // ✅ Dinâmico
                              onTap: () async {
                                if (!_localDestinoManualMode) {  // ✅ Só abre mapa se estiver em modo mapa
                                  final result = await _openPlaceSearch(
                                    onLatLng: (ll) => _localDestinoLatLng = ll,
                                  );
                                  if (result != null && result.isNotEmpty) {
                                    setState(() => _localDestinoCtrl.text = result);
                                  }
                                }
                              },
                              onChanged: _localDestinoManualMode  // ✅ Reage ao digitado se estiver em modo manual
                                  ? (value) {}
                                  : null,
                              decoration: InputDecoration(
                                labelText: _localDestinoManualMode 
                                    ? 'Digite o destino' 
                                    : 'Clique para buscar',
                                hintText: _localDestinoManualMode
                                    ? 'Ex: oficina, residência'
                                    : 'Ex: oficina, residência',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                prefixIcon: const Icon(Icons.flag_outlined),
                                suffixIcon: _localDestinoCtrl.text.isNotEmpty && !_localDestinoManualMode
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () => setState(() {
                                          _localDestinoCtrl.clear();
                                          _localDestinoLatLng = null;
                                        }),
                                      )
                                    : Icon(
                                        _localDestinoManualMode ? Icons.location_on_outlined : Icons.edit,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),

                // Mapas lado a lado (só aparecem quando há coordenadas)
                if (_localOcorrenciaLatLng != null || _localDestinoLatLng != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _localOcorrenciaLatLng != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  height: 140,
                                  child: Image.network(
                                    'https://maps.googleapis.com/maps/api/staticmap'
                                    '?center=${_localOcorrenciaLatLng!.latitude},${_localOcorrenciaLatLng!.longitude}'
                                    '&zoom=15&size=400x280'
                                    '&markers=color:red|${_localOcorrenciaLatLng!.latitude},${_localOcorrenciaLatLng!.longitude}'
                                    '&key=AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            : const SizedBox(),
                      ),
                      if (_localDestinoLatLng != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 140,
                              child: Image.network(
                                'https://maps.googleapis.com/maps/api/staticmap'
                                '?center=${_localDestinoLatLng!.latitude},${_localDestinoLatLng!.longitude}'
                                '&zoom=15&size=400x280'
                                '&markers=color:blue|${_localDestinoLatLng!.latitude},${_localDestinoLatLng!.longitude}'
                                '&key=AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ] else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Nome do contato + Telefone lado a lado
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nomeContatoCtrl,
                        decoration: InputDecoration(
                          labelText: 'Nome do contato no local',
                          hintText: 'Ex: João Silva',
                          prefixIcon: const Icon(Icons.person_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _telefoneContatoLocalCtrl,
                        decoration: InputDecoration(
                          labelText: 'Telefone',
                          hintText: '(11) 99999-9999',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        inputFormatters: [BRFormatters.telefoneFormatter],
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (widget.tipoAssistencia == 'residencial') ...[
              // ── 2. Tipo de Serviço & Seguradora ────────────────────────────
              _buildSectionCard(
                icon: Icons.home_repair_service,
                color: Colors.blue.shade700,
                title: 'Tipo de Serviço & Seguradora',
                children: [
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
                    Text(
                      'Qual foi a requisição do cliente?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _outroServicoCtrl,
                      decoration: InputDecoration(
                        labelText: 'Descreva o serviço',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.edit_outlined),
                      ),
                    ),
                  ],                ],
              ),
              const SizedBox(height: 12),

              if (widget.tipoAssistencia == 'veiculo') ...[
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
                  ),                ],
              ),
              ],
              const SizedBox(height: 12),
            ],

            // ── 4. Relato & Anotações ────────────────────────────────────
            _buildSectionCard(
              icon: Icons.notes,
              color: const Color(0xFFD32F2F),
              title: 'Relato & Anotações',
              children: [
                TextField(
                  controller: _relatoCtrl,
                  decoration: InputDecoration(
                    labelText: 'O que aconteceu? (relato do cliente)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Ex: Carro apresentou pane elétrica, não liga mais...',
                    prefixIcon: const Icon(Icons.record_voice_over_outlined),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _anotacoesCtrl,
                  decoration: InputDecoration(
                    labelText: 'Anotações do operador (opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    hintText: 'Ex: Cliente muito apressado, precisa de prioridade...',
                    prefixIcon: const Icon(Icons.edit_note_outlined),
                    alignLabelWithHint: true,
                  ),
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── 5. Tarefas & Agendamentos ────────────────────────────────
            if (_savedDocId != null)
              _buildSectionCard(
                icon: Icons.task_alt,
                color: const Color(0xFF1565C0),
                title: 'Tarefas & Agendamentos',
                children: [
                  TaskListWidget(
                    numeroSinistro: _savedNumero ?? '',
                    clientId: _cliente?.id ?? '',
                    clientNome: _cliente?.nome ?? '',
                    clientCnpjCpf: _cliente?.cnpjCpf ?? '',
                    sinistroId: _savedDocId!,
                  ),
                ],
              )
            else
              // ── 5. Tarefas & Agendamentos ────────────────────────────────
            _buildSectionCard(
              icon: Icons.task_alt,
              color: const Color(0xFF1565C0),
              title: 'Tarefas & Agendamentos',
              trailing: TextButton.icon(
                onPressed: _adicionarTarefaLocal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar'),
              ),
              children: [

                // Pickers de data e hora do agendamento
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          // ✨ ELEGÂNCIA: Permite datas passadas SÓ se retroativo
                          final firstDate = _isRetroativo && _dataRecebimentoComunicado != null
                              ? DateTime.now().subtract(const Duration(days: 90))
                              : DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dataAgendamento ??
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: firstDate,  // ✅ Condicional
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _dataAgendamento = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Data do agendamento',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            _dataAgendamento != null
                                ? DateFormat('dd/MM/yyyy').format(_dataAgendamento!)
                                : 'Selecionar',
                            style: TextStyle(
                              color: _dataAgendamento != null ? null : Colors.grey.shade500,
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
                            initialTime: _horaAgendamento ?? TimeOfDay.now(),
                          );
                          if (picked != null) setState(() => _horaAgendamento = picked);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Hora do agendamento',
                            prefixIcon: const Icon(Icons.access_time_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            _horaAgendamento != null
                                ? _horaAgendamento!.format(context)
                                : 'Selecionar',
                            style: TextStyle(
                              color: _horaAgendamento != null ? null : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (widget.tipoAssistencia == 'veiculo') ...[
                // Endereço da Oficina E Nome da Oficina (lado a lado)
                Row(
                  children: [
                    // ─── ESQUERDA: Nome da Oficina (40%)
                    Expanded(
                      flex: 40,
                      child: Autocomplete<String>(
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                          return _oficinasNomes.where((o) =>
                              o.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (selection) {
                          // Quando clica em uma sugestão, busca o endereço
                          final oficinaSelecionada = _workshopsDisponiveis
                              .firstWhereOrNull((w) => w.nome.toUpperCase() == selection.toUpperCase());
                          if (oficinaSelecionada?.endereco != null && 
                              _oficinaTerceiroCtrl.text.isEmpty) {
                            setState(() => _oficinaTerceiroCtrl.text = oficinaSelecionada!.endereco!);
                          }
                        },
                        fieldViewBuilder: (ctx, autoCtrl, focusNode, onSubmitted) {
                          autoCtrl.addListener(() {
                            _oficinaNomeCtrl.text = autoCtrl.text.toUpperCase();
                          });
                          
                          return TextField(
                            controller: autoCtrl,
                            focusNode: focusNode,
                            inputFormatters: [
                              UpperCaseTextFormatter(),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Nome da Oficina (opcional)',
                              hintText: 'Digite ou selecione',
                              prefixIcon: const Icon(Icons.build_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              suffixIcon: autoCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        autoCtrl.clear();
                                        _oficinaNomeCtrl.clear();
                                      },
                                    )
                                  : null,
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              child: Container(
                                color: Colors.white,
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final String option = options.elementAt(index);
                                    final oficina = _workshopsDisponiveis
                                        .firstWhereOrNull((w) => w.nome.toUpperCase() == option.toUpperCase());
                                    
                                    return InkWell(
                                      onTap: () => onSelected(option.toUpperCase()),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option.toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                            if (oficina?.endereco != null && 
                                                oficina!.endereco!.isNotEmpty)
                                              Text(
                                                oficina.endereco!,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ─── DIREITA: Endereço da Oficina (60%)
                    Expanded(
                      flex: 60,
                      child: TextField(
                        controller: _oficinaTerceiroCtrl,
                        readOnly: true,
                        onTap: () async {
                          final result = await _openPlaceSearch(
                            onLatLng: (ll) => _oficinaTerceiroLatLng = ll,
                          );
                          if (result != null && result.isNotEmpty) {
                            setState(() => _oficinaTerceiroCtrl.text = result);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Endereço da oficina / local do serviço (opcional)',
                          hintText: 'Clique para buscar',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: _oficinaTerceiroCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() {
                                    _oficinaTerceiroCtrl.clear();
                                    _oficinaTerceiroLatLng = null;
                                  }),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Contato da oficina lado a lado (mantém como estava)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nomeContatoOficinaCtrl,
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
                        controller: _telefoneContatoOficinaCtrl,
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
                ],
                // Lista de tarefas locais
                if (_tarefasLocais.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Nenhuma tarefa adicionada. Clique em "Adicionar" para incluir.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  )
                else
                  Column(
                    children: _tarefasLocais.asMap().entries.map((entry) {
                      final i = entry.key;
                      final t = entry.value;
                      final prazo = t['prazo'] as DateTime;
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        tileColor: Colors.orange.shade50,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: const Icon(Icons.schedule, color: Colors.orange, size: 20),
                        title: Text(t['descricao'] as String,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          'Prazo: ${DateFormat('dd/MM/yyyy').format(prazo)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          onPressed: () => setState(() => _tarefasLocais.removeAt(i)),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // ── 6. Anexos ────────────────────────────────────────────────
            _AssistAnexosCard(
              anexos: _anexos,
              dragOver: _dragOver,
              isUploading: _isUploadingAnexos,
              onAddArquivos: _adicionarArquivos,
              onRemoveArquivo: _removerArquivo,
              onPickArquivos: _pickArquivos,
              onDragEntered: (cat, val) => setState(() => _dragOver[cat] = val),
              onDragExited: (cat, val) => setState(() => _dragOver[cat] = val),
              isImageFile: _isImageFile,
            ),

            const SizedBox(height: 24),

            // ── Botões de ação ───────────────────────────────────────────
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

            const SizedBox(height: 32),
          ],
        ),
      ),
      )
    );
  }

  // ── Helper: card de seção ─────────────────────────────────────────────────
  Widget _buildSectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTipoAssistenciaSelector() {
    final tipos = [
      ('guincho', '🚗 Guincho'),
      ('vidro', '🪟 Vidros'),
      ('combustivel', '⛽ Combustível'),
      ('pane_eletrica', '⚡ Pane Elétrica'),
      ('carga_bateria', '🔋 Carga de Bateria'),
      ('falta', '🔧 Falta de Peça'),
      ('reboque', '🚕 Reboque'),
      ('outro', 'ℹ️ Outro'),
    ];

    final tiposVidro = [
      ('para_brisa', 'Para-brisa'),
      ('farol', 'Farol'),
      ('retrovisor', 'Retrovisor'),
      ('lanterna', 'Lanterna'),
      ('vidro_lateral', 'Vidro Lateral'),
      ('vidro_traseiro', 'Vidro Traseiro'),
      ('farol_milha', 'Farol de Milha'),
      ('reparos', 'Pequenos Reparos'),
      ('outro_vidro', 'Outro'),
    ];

    if (widget.tipoAssistencia != 'veiculo') {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tipos.map((tipo) => FilterChip(
            label: Text(tipo.$2),
            selected: _tipoAssistenciaCtrl.text == tipo.$1,
            onSelected: (selected) {
              setState(() {
                _tipoAssistenciaCtrl.text = selected ? tipo.$1 : '';
                if (!selected || tipo.$1 != 'vidro') {
                  _tiposVidroSelecionados.clear();
                }
              });
            },
            selectedColor: Colors.orange.shade200,
            side: BorderSide(
              color: _tipoAssistenciaCtrl.text == tipo.$1
                  ? Colors.orange.shade600
                  : Colors.grey.shade300,
            ),
          )).toList(),
        ),

        // ─── NOVO: AnimatedSwitcher para "OUTRO" ────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tipoAssistenciaCtrl.text == 'outro'
              ? Padding(
                  key: const ValueKey('outro_assistencia'),
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            'Qual foi a requisição do cliente?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _outroAssistenciaCtrl,
                        decoration: InputDecoration(
                          labelText: 'Descrição da Assistência',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('vazio_outro')),
        ),

        // Subtipo de vidro — aparece apenas quando vidro está selecionado
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tipoAssistenciaCtrl.text == 'vidro'
              ? Padding(
                  key: const ValueKey('vidro_subtipo'),
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.carpenter, size: 14, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            'Qual peça de vidro?',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tiposVidro.map((sub) {
                          final isOutro = sub.$1 == 'outro_vidro';
                          return // FilterChip de subtipo — seleção múltipla
                          FilterChip(
                            label: Text(sub.$2),
                            selected: _tiposVidroSelecionados.contains(sub.$1),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _tiposVidroSelecionados.add(sub.$1);
                                } else {
                                  _tiposVidroSelecionados.remove(sub.$1);
                                }
                              });
                            },
                            selectedColor: Colors.blue.shade100,
                            side: BorderSide(
                              color: _tiposVidroSelecionados.contains(sub.$1)
                                  ? Colors.blue.shade400
                                  : Colors.grey.shade300,
                            ),
                          );
                        }).toList(),
                      ),

                      // Campo de texto livre para "Outro"
                      if (_tiposVidroSelecionados.contains('outro_vidro') ||
                          _tiposVidroSelecionados.any((t) => t.startsWith('outro:'))) ...[
                        const SizedBox(height: 10),
                        TextField(
                          controller: _outroVidroCtrl,
                          decoration: InputDecoration(
                            labelText: 'Descreva o item',
                            hintText: 'Ex: vidro do teto solar',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            prefixIcon: const Icon(Icons.edit_outlined),
                          ),
                          onChanged: (v) {
                            // Atualiza a lista sem setState que reconstrói o campo
                            _tiposVidroSelecionados.removeWhere((t) => t == 'outro_vidro' || t.startsWith('outro:'));
                            if (v.isNotEmpty) {
                              _tiposVidroSelecionados.add('outro:$v');
                            } else {
                              _tiposVidroSelecionados.add('outro_vidro'); // mantém selecionado enquanto vazio
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('vazio')),
        ),
      ],
    );
  }

  // --- WIDGET PARA COR DE VIGÊNCIA DA APÓLICE ---
  Widget? _statusVigenciaIcon(String dataStr) {
    try {
      final data = DateFormat('dd/MM/yyyy').parse(dataStr);
      final hoje = DateTime.now();
      final diff = data.difference(hoje).inDays;

      if (diff < 0) {
        return const Icon(Icons.error, color: Colors.red);
      } else if (diff <= 30) {
        return const Icon(Icons.warning_amber_rounded, color: Colors.orange);
      } else {
        return const Icon(Icons.check_circle, color: Colors.green);
      }
    } catch (e) {
      return null;
    }
  }

}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS DE ANEXO
// ═══════════════════════════════════════════════════════════════════════════

class _AssistAnexosCard extends StatelessWidget {
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

  final Map<String, List<XFile>> anexos;
  final Map<String, bool> dragOver;
  final bool isUploading;
  final void Function(String, List<XFile>, [List<PlatformFile>?]) onAddArquivos;
  final void Function(String, XFile) onRemoveArquivo;
  final void Function(String) onPickArquivos;
  final void Function(String, bool) onDragEntered;
  final void Function(String, bool) onDragExited;
  final bool Function(String) isImageFile;

  static const _color = Color(0xFF00695C);

  static const _categoryIcons = <String, IconData>{
    'Fotos da Ocorrência': Icons.photo_library_outlined,
    'Documentos': Icons.description_outlined,
  };

  int get _totalAnexos => anexos.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho da seção
            Row(
              children: [
                const Icon(Icons.attach_file, color: _color, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Anexos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _color),
                ),
                const SizedBox(width: 8),
                if (_totalAnexos > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_totalAnexos arquivo${_totalAnexos == 1 ? "" : "s"}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
                    ),
                  ),
                const Spacer(),
                if (isUploading)
                  const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: _color),
                  ),
              ],
            ),
            const Divider(height: 20),

            // Categorias
            ...anexos.keys.map((categoria) {
              final arquivos = anexos[categoria]!;
              final isDragging = dragOver[categoria] ?? false;
              final icon = _categoryIcons[categoria] ?? Icons.folder_outlined;
              final isImagem = categoria == 'Fotos da Ocorrência';

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Label + botão adicionar
                    Row(
                      children: [
                        Icon(icon, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 5),
                        Text(
                          categoria.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600, letterSpacing: 0.4,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => onPickArquivos(categoria),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: _color.withOpacity(0.4), width: 0.8),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add, size: 12, color: _color),
                                const SizedBox(width: 3),
                                Text(
                                  isImagem ? 'Adicionar fotos' : 'Adicionar arquivos',
                                  style: TextStyle(fontSize: 11, color: _color),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Zona de drop
                    DropTarget(
                      onDragEntered: (_) => onDragEntered(categoria, true),
                      onDragExited: (_) => onDragExited(categoria, false),
                      onDragDone: (details) async {
                        onDragExited(categoria, false);
                        if (kIsWeb) {
                          final platformFiles = <PlatformFile>[];
                          for (final xf in details.files) {
                            final bytes = await xf.readAsBytes();
                            platformFiles.add(PlatformFile(name: xf.name, size: bytes.length, bytes: bytes));
                          }
                          onAddArquivos(categoria, details.files, platformFiles);
                        } else {
                          onAddArquivos(categoria, details.files);
                        }
                      },
                      child: GestureDetector(
                        onTap: () => onPickArquivos(categoria),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          constraints: const BoxConstraints(minHeight: 72),
                          decoration: BoxDecoration(
                            color: isDragging ? _color.withOpacity(0.06) : const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDragging ? _color : Colors.grey.shade300,
                              width: isDragging ? 1.5 : 0.8,
                            ),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: arquivos.isEmpty
                              ? _AssistDropPlaceholder(isDragging: isDragging, isImagem: isImagem, color: _color)
                              : _AssistArquivosGrid(
                                  categoria: categoria,
                                  arquivos: arquivos,
                                  isImagem: isImagem,
                                  isImageFile: isImageFile,
                                  onRemove: onRemoveArquivo,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AssistDropPlaceholder extends StatelessWidget {
  const _AssistDropPlaceholder({required this.isDragging, required this.isImagem, required this.color});
  final bool isDragging;
  final bool isImagem;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDragging ? Icons.file_download_outlined
                  : isImagem ? Icons.add_photo_alternate_outlined
                  : Icons.upload_file_outlined,
              size: 22,
              color: isDragging ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              isDragging ? 'Solte aqui para adicionar' : 'Arraste arquivos aqui ou clique para selecionar',
              style: TextStyle(fontSize: 11, color: isDragging ? color : Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistArquivosGrid extends StatelessWidget {
  const _AssistArquivosGrid({
    required this.categoria,
    required this.arquivos,
    required this.isImagem,
    required this.isImageFile,
    required this.onRemove,
  });
  final String categoria;
  final List<XFile> arquivos;
  final bool isImagem;
  final bool Function(String) isImageFile;
  final void Function(String, XFile) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: arquivos.map((arquivo) {
        final nome = arquivo.name.isNotEmpty ? arquivo.name : arquivo.path.split('/').last;
        final ehImagem = isImageFile(nome);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ehImagem ? _AssistImagemThumb(arquivo: arquivo, nome: nome) : _AssistDocChip(nome: nome),
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Remover anexo'),
                      content: const Text('Tem certeza que deseja excluir este arquivo?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) onRemove(categoria, arquivo);
                },
                child: Container(
                  width: 18, height: 18,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _AssistImagemThumb extends StatelessWidget {
  const _AssistImagemThumb({required this.arquivo, required this.nome});
  final XFile arquivo;
  final String nome;

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (kIsWeb) {
      img = Image.network(arquivo.path, width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    } else if (arquivo.path.isNotEmpty) {
      img = Image.file(File(arquivo.path), width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    } else {
      img = const Icon(Icons.image_outlined, size: 32);
    }

    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(10),
          child: InteractiveViewer(
            panEnabled: true, minScale: 0.5, maxScale: 4,
            child: Container(
              color: Colors.black,
              child: kIsWeb
                  ? Image.network(arquivo.path, fit: BoxFit.contain)
                  : Image.file(File(arquivo.path), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(width: 72, height: 72, color: Colors.grey.shade200, child: img),
      ),
    );
  }
}

class _AssistDocChip extends StatelessWidget {
  const _AssistDocChip({required this.nome});
  final String nome;

  static IconData _iconForExt(String nome) {
    final ext = nome.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_outlined;
      case 'doc': case 'docx': return Icons.article_outlined;
      case 'xls': case 'xlsx': return Icons.table_chart_outlined;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForExt(nome), size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(nome,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

// ─── Extension para firstWhereOrNull ──────────────────────────────────────
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
 
// ─── Formatter para forçar CAIXA ALTA ─────────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}