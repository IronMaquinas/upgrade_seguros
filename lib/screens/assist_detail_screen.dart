// lib/screens/assist_detail_screen.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/models/config_model.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:upgrade_seguros/services/place_search_delegate.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:upgrade_seguros/widgets/nps_send_widget.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/claim_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/assist_sla_timer_widget.dart';
import '../widgets/notes_widget.dart';
import '../widgets/task_list_widget.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import '../services/image_services.dart';
import 'package:upgrade_seguros/widgets/selectable_text_helper.dart';

class AssistDetailScreen extends StatefulWidget {
  final String assistId;

  const AssistDetailScreen({
    super.key,
    required this.assistId,
  });

  @override
  State<AssistDetailScreen> createState() => _AssistDetailScreenState();
}

class _AssistDetailScreenState extends State<AssistDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  Claim? _assist;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAdmin = false;

  // Controladores para edição
  late TextEditingController _statusCtrl;
  late TextEditingController _anotacoesCtrl;

  bool _isEditing = false;
  bool _isUploadingAnexos = false;

    // Google Places
  final _places = FlutterGooglePlacesSdk('AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE');
  LatLng? _localOcorrenciaLatLng;
  LatLng? _localDestinoLatLng;
  LatLng? _oficinaTerceiroLatLng;

  // Controllers para campos editáveis
  late TextEditingController _enderecoTerceiroCtrl;
  late TextEditingController _nomeContatoOficinaCtrl;
  late TextEditingController _telefoneContatoOficinaCtrl;
  late TextEditingController _nomeOficinaCtrl;

  String _nomeUsuarioLogado = 'Desconhecido';

  // Anexos
  final Map<String, List<XFile>> _novosAnexos = {
    'Fotos da Ocorrência': [],
    'Documentos': [],
  };
  final Map<String, bool> _dragOver = {
    'Fotos da Ocorrência': false,
    'Documentos': false,
  };
  final Map<String, List<PlatformFile>> _platformFiles = {};

  final List<String> _statusOptions = [
    'Aberto',
    'Em Andamento',
    'Aguardando Cliente',
    'Concluído',
    'Cancelado',
  ];

  AppConfig _config = AppConfig(id: 'config');

  @override
  void initState() {
    super.initState();
    _statusCtrl = TextEditingController();
    _anotacoesCtrl = TextEditingController();
    _loadAssist();
    _enderecoTerceiroCtrl = TextEditingController();
    _nomeContatoOficinaCtrl = TextEditingController();
    _telefoneContatoOficinaCtrl = TextEditingController();
    _authService.isAdmin().then((v) => setState(() => _isAdmin = v));
    _nomeOficinaCtrl = TextEditingController();
    _loadNomeUsuario();
    _loadConfig();
  }

  @override
  void dispose() {
    _statusCtrl.dispose();
    _anotacoesCtrl.dispose();
    _enderecoTerceiroCtrl.dispose();
    _nomeContatoOficinaCtrl.dispose();
    _telefoneContatoOficinaCtrl.dispose();
    _nomeOficinaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await ConfigService().getConfig();
    setState(() {
      _config = config;
    });
  }

  Future<void> _loadNomeUsuario() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final nome = doc.data()?['nome'] as String?;
          if (nome != null && nome.isNotEmpty) {
            setState(() => _nomeUsuarioLogado = nome);
            return;
          }
        }
        setState(() => _nomeUsuarioLogado = user.displayName ?? user.email ?? 'Desconhecido');
      } else {
        setState(() => _nomeUsuarioLogado = 'Desconhecido');
      }
    } catch (e) {
      setState(() => _nomeUsuarioLogado = 'Desconhecido');
    }
  }

  Future<void> _loadAssist() async {
    try {
      print('DEBUG: Carregando assistência com ID: ${widget.assistId}');
      final assist = await _firestoreService.getClaimById(widget.assistId);
      if (assist != null) {
        assist.id = widget.assistId;  // ← Garante que o ID está no objeto
      }
      print('DEBUG: Assistência carregada: ${assist?.numeroSinistro}');
      if (mounted) {
        setState(() {
          _assist = assist;
          _enderecoTerceiroCtrl.text = _assist!.enderecoTerceiro;
          _nomeContatoOficinaCtrl.text = _assist!.nomeContatoOficina ?? '';
          _telefoneContatoOficinaCtrl.text = _assist!.telefoneContatoOficina ?? '';
          _statusCtrl.text = assist?.statusAtual ?? '';
          _anotacoesCtrl.text = assist?.anotacoes.toString() ?? '';
          _nomeOficinaCtrl.text = _assist!.nomeOficina ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar assistência: $e')),
        );
      }
    }
  }

  // ATUALIZA STATUS DO SLA
  Future<void> _iniciarSlaAtendimento() async {
    final tempoCtrl = TextEditingController(text: '30');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Em Andamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o tempo previsto (em minutos) para o atendimento chegar ao local:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tempoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Tempo previsto (minutos)',
                prefixIcon: const Icon(Icons.timer_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                helperText: 'Ex: 45 minutos para o guincho chegar',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Iniciar Contagem'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmar != true) {
      // Reverteu — volta pro status anterior
      setState(() => _statusCtrl.text = _assist!.statusAtual);
      return;
    }

    final minutos = int.tryParse(tempoCtrl.text) ?? 30;
    setState(() {
      _assist!.slaAtendimento = DateTime.now().add(Duration(minutes: minutos));
      _assist!.tempoSlaMinutos = minutos;
      _assist!.historicoStatus = [
        ..._assist!.historicoStatus,
        {
          'status': 'Tempo de atendimento definido: $minutos min',
          'data': DateTime.now().toIso8601String(),
        },
      ];
    });

    await _salvar(fechar: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏱️ Contagem iniciada: $minutos min para atendimento'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

    // ── Métodos de anexo ─────────────────────────────────────────────────────

  void _adicionarArquivos(String categoria, List<XFile> arquivos, [List<PlatformFile>? platformFiles]) {
    setState(() {
      _novosAnexos[categoria]!.addAll(arquivos);
      if (platformFiles != null) {
        _platformFiles[categoria] ??= [];
        _platformFiles[categoria]!.addAll(platformFiles);
      }
    });
  }

  void _removerArquivo(String categoria, XFile arquivo) {
    setState(() {
      _novosAnexos[categoria]!.remove(arquivo);
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
          _novosAnexos[categoria]!.addAll(xfiles);
        });
      }
    }
  }

  Future<Map<String, List<String>>> _uploadAnexos(String numeroAssistencia) async {
    final Map<String, List<String>> urls = {};

    for (final entry in _novosAnexos.entries) {
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
    void Function(double lat, double lng)? onLatLng,
  }) async {
    final Place? place = await showSearch<Place?>(
      context: context,
      delegate: PlaceSearchDelegate(_places),
    );
    if (place != null) {
      if (place.latLng != null && onLatLng != null) {
        onLatLng(place.latLng!.lat, place.latLng!.lng);
      }
      return place.address ?? place.name ?? '';
    }
    return null;
  }

  DateTime? _parseHistoricoData(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    if (value is DateTime) return value;
    return null;
  }

  // MÉTODO PARA ADICIONAR ANOTAÇÃO
  Future<void> _adicionarAnotacao() async {
    final ctrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Anotação'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          minLines: 2,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Anotação',
            border: OutlineInputBorder(),
            hintText: 'Digite a anotação...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirmar != true || ctrl.text.trim().isEmpty) return;

    setState(() {
      _assist!.anotacoes = [
        ..._assist!.anotacoes,
        {
          'autor': _authService.getUserEmail(),
          'conteudo': ctrl.text.trim(),
          'data': DateTime.now().toIso8601String(),
        },
      ];
    });

    await _salvar(fechar: false);
  }

  // MÉTODO PARA ADICIONAR TEMPO DE ATENDIMENTO
  Future<void> _adicionarTempoAtendimento() async {
    final tempoCtrl = TextEditingController(text: '15');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Tempo de Atendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Quantos minutos deseja adicionar ao tempo atual?',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: tempoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Minutos a adicionar',
                prefixIcon: const Icon(Icons.more_time),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Adicionar'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final minutosAdicionais = int.tryParse(tempoCtrl.text) ?? 0;
    if (minutosAdicionais <= 0) return;

    setState(() {
      final slaBase = _assist!.slaAtendimento ?? _assist!.slaPrevisto ?? DateTime.now();
      _assist!.slaAtendimento = slaBase.add(Duration(minutes: minutosAdicionais));
      _assist!.tempoSlaMinutos = (_assist!.tempoSlaMinutos ?? 30) + minutosAdicionais;
      _assist!.historicoStatus = [
        ..._assist!.historicoStatus,
        {
          'status': '+$minutosAdicionais min adicionados ao tempo de atendimento',
          'data': DateTime.now().toIso8601String(),
        },
      ];
    });

    await _salvar(fechar: false, resetarEdicao: false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+$minutosAdicionais min adicionados'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<dynamic> _mostrarDialogoSalvar() {
  return showDialog<dynamic>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Salvar Assistência'),
      content: const Text('Deseja notificar o cliente via WhatsApp?'),
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

        // NPS
        if (_statusCtrl.text == 'Concluído' && _config.enableNpsSurvey)
          FilledButton.icon(
            icon: const Icon(Icons.star_rounded, size: 18),
            label: const Text('Salvar e Enviar Pesquisa'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6B5DF8)),
            onPressed: () => Navigator.pop(ctx, 'nps'),
          ),
      ],
    ),
  );
}

  // FORMATAÇÃO DE TEXTOS PARA O WHATSAPP DE ACORDO COM A ASSISTÊNCIA
  String _montarTextoWhatsApp() {
    final tipoBase = _getTipoLabel(_assist!.tipoOcorrencia);
    final subtipoVidro = _assist!.tipoOcorrencia.startsWith('vidro:')
        ? ' (${_getTipoVidroLabel(_assist!.tipoOcorrencia)})'
        : '';
    final tipo = '$tipoBase$subtipoVidro';
    final veiculo = _assist!.veiculoSelecionado;
    final veiculoStr = veiculo != null
        ? '*Veículo:* ${veiculo.marca} ${veiculo.modelo}'
          '${veiculo.placa.isNotEmpty ? ' - Placa ${veiculo.placa}' : ''}'
        : '';

    final local = _assist!.localOcorrencia.isNotEmpty
        ? '*Local:* ${_assist!.localOcorrencia}' : '';
    final destino = _assist!.localDestino?.isNotEmpty == true
        ? '*Destino:* ${_assist!.localDestino}' : '';
    final tempoStr = _assist!.tempoSlaMinutos != null
        ? '*Previsão de chegada:* ${_assist!.tempoSlaMinutos} minutos' : '';
    final agendamento = _assist!.dataAgendamento != null
        ? '*Agendamento:* ${DateFormat('dd/MM/yyyy').format(_assist!.dataAgendamento!)}'
          '${_assist!.horaAgendamento != null ? ' às ${_assist!.horaAgendamento}' : ''}'
        : '';

    final detalhes = [veiculoStr, local, destino, agendamento, tempoStr]
        .where((s) => s.isNotEmpty)
        .join('\n');

    switch (tipo) {
      case 'guincho':
      case 'reboque':
        return 'Prezado(a) ${_assist!.clientNome},\n\n'
            'Sua solicitação de guincho foi registrada sob o número *${_assist!.numeroSinistro}*.\n\n'
            '$detalhes\n\n'
            'Nossa equipe já está providenciando o atendimento.\n\n'
            'Atenciosamente,\nUpgrade Seguros';

      case 'carga_bateria':
      case 'pane_eletrica':
        return 'Prezado(a) ${_assist!.clientNome},\n\n'
            'Sua solicitação de assistência foi registrada sob o número *${_assist!.numeroSinistro}*.\n\n'
            '$detalhes\n\n'
            'Nosso técnico está a caminho. Aguarde no local com segurança.\n\n'
            'Atenciosamente,\nUpgrade Seguros';

      case 'combustivel':
        return 'Prezado(a) ${_assist!.clientNome},\n\n'
            'Sua solicitação de abastecimento emergencial foi registrada sob o número *${_assist!.numeroSinistro}*.\n\n'
            '$detalhes\n\n'
            'Nosso atendente está a caminho com o combustível necessário.\n\n'
            'Atenciosamente,\nUpgrade Seguros';

      default:
        return 'Prezado(a) ${_assist!.clientNome},\n\n'
            'Sua assistência *${_assist!.numeroSinistro}* foi registrada e está em atendimento.\n\n'
            '$detalhes\n\n'
            'Em caso de dúvidas, entre em contato conosco.\n\n'
            'Atenciosamente,\nUpgrade Seguros';
    }
  }

  Future<void> _abrirWhatsApp() async {
    final tel = (_assist!.telefoneCliente ?? '').replaceAll(RegExp(r'\D'), '');

    final veiculo = _assist!.veiculoSelecionado;
    final veiculoStr = veiculo != null
        ? '${veiculo.marca} ${veiculo.modelo}${veiculo.placa.isNotEmpty ? ' - Placa ${veiculo.placa}' : ''}'
        : '';

    final oficina = _assist!.enderecoTerceiro.isNotEmpty
        ? '\n📍 *Local do serviço:* ${_assist!.enderecoTerceiro}' : '';
    final contato = _assist!.nomeContatoOficina?.isNotEmpty == true
        ? '\n👤 *Responsável:* ${_assist!.nomeContatoOficina}' : '';
    final fone = _assist!.telefoneContatoOficina?.isNotEmpty == true
        ? '\n📞 *Contato:* ${_assist!.telefoneContatoOficina}' : '';

    String agendamento = '';
    if (_assist!.dataAgendamento != null) {
      final data = DateFormat('dd/MM/yyyy').format(_assist!.dataAgendamento!);
      final hora = _assist!.horaAgendamento ?? '';
      agendamento = '\n📅 *Agendamento:* $data${hora.isNotEmpty ? ' às $hora' : ''}';
    }

    final texto = _montarTextoWhatsApp();

    final encoded = Uri.encodeComponent(texto);
    final url = tel.isNotEmpty
        ? 'https://wa.me/55$tel?text=$encoded'
        : 'https://wa.me/?text=$encoded';

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp')),
      );
    }
  }

  // MÉTODO DE REAGENDAMENTO
  Future<void> _reagendar() async {
    DateTime? novaData = _assist!.dataAgendamento;
    TimeOfDay? novaHora = _assist!.horaAgendamento != null
        ? TimeOfDay(
            hour: int.parse(_assist!.horaAgendamento!.split(':')[0]),
            minute: int.parse(_assist!.horaAgendamento!.split(':')[1]),
          )
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.event_repeat, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text('Reagendar')),
              if ((_assist!.totalReagendamentos) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_assist!.totalReagendamentos}º reagendamento',
                    style: TextStyle(fontSize: 11, color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_assist!.totalReagendamentos >= 2)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.red.shade400, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Atenção: este é o ${_assist!.totalReagendamentos + 1}º reagendamento para este cliente.',
                          style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined, color: Colors.orange),
                title: Text(novaData != null
                    ? DateFormat('dd/MM/yyyy').format(novaData!)
                    : 'Selecionar data'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: novaData ?? DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setS(() => novaData = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined, color: Colors.orange),
                title: Text(novaHora != null
                    ? novaHora!.format(ctx)
                    : 'Selecionar hora (opcional)'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: novaHora ?? TimeOfDay.now(),
                  );
                  if (picked != null) setS(() => novaHora = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.event_repeat, size: 18),
              label: const Text('Confirmar'),
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: novaData == null ? null : () async {
                Navigator.pop(ctx);
                final horaStr = novaHora != null
                    ? '${novaHora!.hour.toString().padLeft(2, '0')}:${novaHora!.minute.toString().padLeft(2, '0')}'
                    : null;
                final novoNumero = _assist!.totalReagendamentos + 1;

                setState(() {
                  _assist!.dataAgendamento = novaData;
                  _assist!.horaAgendamento = horaStr;
                  _assist!.totalReagendamentos = novoNumero;
                  _assist!.historicoStatus = [
                    ..._assist!.historicoStatus,
                    {
                      'status': 'Reagendamento #$novoNumero: ${DateFormat('dd/MM/yyyy').format(novaData!)}${horaStr != null ? ' às $horaStr' : ''}',
                      'data': DateTime.now().toIso8601String(),
                    },
                  ];
                });

                // Conclui tarefas anteriores de agendamento/reagendamento
                try {
                  final tarefasAnteriores = await FirebaseFirestore.instance
                      .collection('tasks')
                      .where('claimId', isEqualTo: _assist!.id)
                      .where('tipo', whereIn: ['agendamento', 'reagendamento'])
                      .get();

                  for (final doc in tarefasAnteriores.docs) {
                    final statusAtual = doc.data()['status'] as String? ?? '';
                    if (statusAtual != 'Concluída') {
                      await doc.reference.update({
                        'status': 'Concluída',
                        'motivoConclusao': 'Reagendado — nova data: ${DateFormat('dd/MM/yyyy').format(novaData!)}',
                      });
                    }
                  }
                } catch (e) {
                  debugPrint('Erro ao concluir tarefas anteriores: $e');
                }

                // Gera tarefa de lembrete
                final placa = _assist!.veiculoSelecionado?.placa ?? '';
                await FirebaseFirestore.instance.collection('tasks').add({
                  'descricao': 'Reagendamento #$novoNumero para ${_assist!.clientNome}'
                      '${placa.isNotEmpty ? ' • Veículo: $placa' : ''}'
                      '${_assist!.enderecoTerceiro.isNotEmpty ? ' • Local: ${_assist!.enderecoTerceiro}' : ''}',
                  'prazo': Timestamp.fromDate(novaData!),
                  'status': 'Aberta',
                  'claimId': _assist!.id,
                  'numeroSinistro': _assist!.numeroSinistro,
                  'clientId': _assist!.idCliente,
                  'clientNome': _assist!.clientNome,
                  'clientCnpjCpf': _assist!.clientCnpjCpf,
                  'responsavelEmail': _authService.getUserEmail(),
                  'criado_em': FieldValue.serverTimestamp(),
                  'tipo': 'reagendamento',
                });

                await _salvar(fechar: false, resetarEdicao: false);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reagendamento #$novoNumero registrado'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _salvar({bool fechar = true, bool notificarWhatsApp = false, bool resetarEdicao = true}) async {
    if (_assist == null) return;

    setState(() => _isSaving = true);
    try {
      _assist!.statusAtual = _statusCtrl.text;
      _assist!.dataUltimaAtualizacao = DateTime.now();

      if (_statusCtrl.text == 'Concluído') {
        _assist!.dataConclusao = Timestamp.now();
      }

      // Adiciona ao histórico
      _assist!.historicoStatus = [
        ..._assist!.historicoStatus,
        {
          'status': _statusCtrl.text,
          'data': DateTime.now().toIso8601String(),
          'registrado_por': _nomeUsuarioLogado,
        },
      ];

      // Campos editáveis de Serviços e Reparos
      _assist!.enderecoTerceiro = _enderecoTerceiroCtrl.text;
      _assist!.nomeContatoOficina = _nomeContatoOficinaCtrl.text.isNotEmpty
          ? _nomeContatoOficinaCtrl.text : null;
      _assist!.telefoneContatoOficina = _telefoneContatoOficinaCtrl.text.isNotEmpty
          ? _telefoneContatoOficinaCtrl.text : null;

      // 🆕 FAZER UPLOAD DOS NOVOS ANEXOS PRIMEIRO
      if (_novosAnexos.values.any((list) => list.isNotEmpty)) {
        setState(() => _isUploadingAnexos = true);
        
        final anexosUrls = await _uploadAnexos(_assist!.numeroSinistro);
        
        // 🆕 JUNTAR URLs antigas com URLs novas
        if (anexosUrls.containsKey('Fotos da Ocorrência')) {
          _assist!.fotosUrls = [
            ...?_assist!.fotosUrls,
            ...anexosUrls['Fotos da Ocorrência']!,
          ];
        }
        
        if (anexosUrls.containsKey('Documentos')) {
          _assist!.arquivosLaudosUrls = [
            ...?_assist!.arquivosLaudosUrls,
            ...anexosUrls['Documentos']!,
          ];
        }
        
        // 🆕 LIMPAR OS NOVOS ANEXOS APÓS UPLOAD
        setState(() {
          _novosAnexos.clear();
          _novosAnexos['Fotos da Ocorrência'] = [];
          _novosAnexos['Documentos'] = [];
          _platformFiles.clear();
          _isUploadingAnexos = false;
        });
      }

      // 🆕 AGORA SIM SALVA COM AS URLs
      await _firestoreService.updateClaim(_assist!);

      if (notificarWhatsApp && mounted) {
        await _abrirWhatsApp();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assistência atualizada com sucesso')),
        );
        if (fechar) {
          Navigator.of(context).pop(true);
        } else if (resetarEdicao) {
          setState(() => _isEditing = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _marcarComoConcluido() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como Concluído'),
        content: const Text(
          'Deseja marcar esta assistência como concluída? Isto é irreversível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _statusCtrl.text = 'Concluído');
              _salvar();
            },
            child: const Text('Sim, concluir'),
          ),
        ],
      ),
    );
  }

  void _excluir() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Assistência'),
        content: Text(
          'Tem certeza que deseja excluir a assistência ${_assist!.numeroSinistro}?\n\nEsta ação é irreversível.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isSaving = true);
              try {
                await _firestoreService.deleteClaim(
                  _assist!.id,
                  _assist!.numeroSinistro,
                );
                if (mounted) Navigator.of(context).pop(true);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  // HELPER PARA TIPO
  String _getTipoLabel(String? tipo) {
    const map = {
      // TIPOS VEICULARES
      'guincho': '🚗 Guincho',
      'vidro': '🪟 Vidros',
      'combustivel': '⛽ Combustível',
      'pane_eletrica': '⚡ Pane Elétrica',
      'carga_bateria': '🔋 Carga de Bateria',
      'falta': '🔧 Falta de Peça',
      'reboque': '🚕 Reboque',
      // TIPOS RESIDENCIAIS
      'eletricista': '⚡ Eletricista',
      'encanador': '🔧 Encanador',
      'reparo_equipamentos': '🛠️ Reparo de Equipamentos',
      'chaveiro': '🔑 Chaveiro',
      'vidraceiro': '🪟 Vidraceiro',
      'pintura': '🎨 Pintura',
      'limpeza': '🧹 Limpeza',
      // GENÉRICO
      'outro': 'ℹ️ Outro',
    };
    return map[tipo] ?? 'ℹ️ Outro';
  }

  // HELPER PARA TIPOS DE VIDROS
  String _getTipoVidroLabel(String tipoOcorrencia) {
    // Decodifica 'vidro:para_brisa,retrovisor,outro:teto solar'
    if (!tipoOcorrencia.startsWith('vidro:')) return '';

    const subtipos = {
      'para_brisa': 'Para-brisa',
      'farol': 'Farol',
      'retrovisor': 'Retrovisor',
      'lanterna': 'Lanterna',
      'vidro_lateral': 'Vidro Lateral',
      'vidro_traseiro': 'Vidro Traseiro',
      'farol_milha': 'Farol de Milha',
      'reparos': 'Pequenos Reparos',
    };

    final partes = tipoOcorrencia.substring(6).split(','); // remove 'vidro:'
    final labels = partes.map((p) {
      if (p.startsWith('outro:')) return p.substring(6); // texto livre
      return subtipos[p] ?? p;
    }).toList();

    return labels.join(', ');
  }

  // --- Método para Salvar Alterações de Agendamento ---
  Future<void> _salvarAlteracoes() async {
    if (_assist == null) return;
    
    try {
      await _firestoreService.updateClaim(_assist!);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agendamento atualizado!'))
      );
    } catch (e) {
      print('Erro ao salvar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carregando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_assist == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Erro')),
        body: const Center(child: Text('Assistência não encontrada')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Text(_assist!.clientNome),
        backgroundColor: Colors.orange.shade50,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 1,
        actions: [
          if (!_isEditing)
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Editar'),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Salvar'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              onPressed: _isSaving
              ? null
              : () async {
                  final opcao = await _mostrarDialogoSalvar();
                  if (opcao == null) return;
                  await _salvar(notificarWhatsApp: opcao == 'whatsapp');
                  if (opcao == 'nps' && mounted) {
                    NpsSendDialog.mostrar(
                      context,
                      claimId: _assist!.id,
                      numeroSinistro: _assist!.numeroSinistro,
                      clienteId: _assist!.idCliente,
                      clienteNome: _assist!.clientNome,
                      clienteTelefone: _assist!.telefoneCliente ?? '',
                      clienteEmail: '',
                      tipo: 'assistencia',
                    );
                  }
                },
            ),
          if (_assist!.statusAtual != 'Concluído')
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🎯 CABEÇALHO COM INFO BÁSICA
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getTipoLabel(_assist!.tipoOcorrencia),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _assist!.clientNome,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusBgColor(_assist!.statusAtual),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _assist!.statusAtual,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(_assist!.statusAtual),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm')
                              .format(_assist!.dataAbertura),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ⏱️ RELÓGIO DE SLA (PRINCIPAL)
            if (_assist!.slaPrevisto != null || _assist!.slaAtendimento != null)
              _assist!.statusAtual == 'Concluído' || _assist!.statusAtual == 'Cancelado'
                ? Card(
                    elevation: 2,
                    color: _assist!.statusAtual == 'Concluído'
                        ? const Color(0xFFEDE9FE)
                        : Colors.grey.shade100,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        children: [
                          Icon(
                            _assist!.statusAtual == 'Concluído'
                                ? Icons.check_circle
                                : Icons.cancel_outlined,
                            color: _assist!.statusAtual == 'Concluído'
                                ? const Color(0xFF6366F1)
                                : Colors.grey,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _assist!.statusAtual == 'Concluído'
                                    ? 'Assistência concluída'
                                    : 'Assistência cancelada',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: _assist!.statusAtual == 'Concluído'
                                      ? const Color(0xFF6366F1)
                                      : Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'SLA encerrado em ${DateFormat('dd/MM/yyyy HH:mm').format(_assist!.slaPrevisto!)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                  : Card(
                      elevation: 2,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: AssistSlaTimerWidget(
                                dataAbertura: _assist!.dataAbertura,
                                slaPrevisto: _assist!.slaAtendimento ?? _assist!.slaPrevisto,
                                dataAgendamento: _assist!.dataAgendamento,
                                size: 200,
                              showDetails: true,
                              onSlaWarning: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('⚠️ Atenção: SLA próximo de vencer!'),
                                    backgroundColor: Colors.orange.shade600,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              },
                              onSlaExceeded: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('❌ SLA excedido! Contactar cliente imediatamente.'),
                                    backgroundColor: Colors.red.shade600,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Botão adicionar tempo — só aparece quando em andamento
                          if (_assist!.statusAtual != 'Concluído' &&
                            _assist!.statusAtual != 'Cancelado')
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              child: OutlinedButton.icon(
                                onPressed: _adicionarTempoAtendimento,
                                icon: const Icon(Icons.more_time, size: 18, color: Colors.orange),
                                label: const Text('Adicionar Tempo',
                                    style: TextStyle(color: Colors.orange)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.orange),
                                  minimumSize: const Size.fromHeight(40),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

            const SizedBox(height: 20),

            // 📋 INFORMAÇÕES DETALHADAS
            _buildSection(
              title: 'Informações da Assistência',
              children: [
                // Número
                _buildInfoRow('Número', _assist!.numeroSinistro),
                const Divider(height: 20),

                // Linha: Cliente | CPF/CNPJ | Telefone
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInfoRow('Cliente', _assist!.clientNome),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildInfoRow('CPF/CNPJ', BRFormatters.formatarCpfOuCnpj(_assist!.clientCnpjCpf)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoRow(
                                  'Telefone',
                                  _assist!.telefoneCliente?.isNotEmpty == true
                                      ? BRFormatters.formatarTelefone(_assist!.telefoneCliente!)
                                      : '—',
                                ),
                              ),
                              if (_assist!.telefoneCliente?.isNotEmpty == true) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    final tel = _assist!.telefoneCliente!.replaceAll(RegExp(r'\D'), '');
                                    if (tel.isNotEmpty) launchUrlString('tel:$tel');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.call, size: 18, color: Colors.green.shade600),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    final tel = _assist!.telefoneCliente!.replaceAll(RegExp(r'\D'), '');
                                    if (tel.isNotEmpty) launchUrlString('https://wa.me/55$tel', mode: LaunchMode.externalApplication);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.message, size: 18, color: const Color(0xFF25D366)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Linha: Seguradora | Nº Apólice
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInfoRow('Seguradora', _assist!.seguradora.isNotEmpty ? _assist!.seguradora : '—'),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildInfoRow('Nº Apólice', _assist!.numeroSeguradora.isNotEmpty ? _assist!.numeroSeguradora : '—'),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Linha: Tipo | Protocolo
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Tipo', _getTipoLabel(_assist!.tipoOcorrencia)),
                          if (_assist!.tipoOcorrencia.startsWith('vidro:'))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _buildInfoRow('Peças', _getTipoVidroLabel(_assist!.tipoOcorrencia)),
                            ),
                          if (_assist!.tipoOcorrencia == 'outro')
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: _buildInfoRow(
                                'Descrição',
                                _assist!.tipoOcorrenciaOutro ?? '—',
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildInfoRow(
                        'Protocolo',
                        _assist!.protocoloSeguradora?.isNotEmpty == true
                            ? _assist!.protocoloSeguradora!
                            : '—',
                      ),
                    ),
                  ],
                ),

                if ((_assist!.valorFranquia) > 0) ...[
                  const Divider(height: 20),
                  _buildInfoRow(
                    'Franquia',
                    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$ ')
                        .format(_assist!.valorFranquia),
                  ),
                ],
              ],
            ),

            // 🚗 VEÍCULO DA ASSISTÊNCIA
            if (_assist!.veiculoSelecionado != null) ...[
              const SizedBox(height: 16),
              _buildSection(
                icon: Icons.directions_car,
                color: Colors.orange,
                title: 'Veículo da Assistência',
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          'Marca',
                          _assist!.veiculoSelecionado!.marca,
                        ),
                      ),
                      Expanded(
                        child: _buildInfoRow(
                          'Modelo',
                          _assist!.veiculoSelecionado!.modelo,
                        ),
                      ),
                      if (_assist!.veiculoSelecionado!.cor.isNotEmpty)
                        Expanded(
                          child: _buildInfoRow(
                            'Cor',
                            _assist!.veiculoSelecionado!.cor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_assist!.veiculoSelecionado!.placa.isNotEmpty)
                        Expanded(
                          child: _buildInfoRow(
                            'Placa',
                            _assist!.veiculoSelecionado!.placa,
                          ),
                        ),
                      if (_assist!.veiculoSelecionado!.chassi.isNotEmpty)
                        Expanded(
                          child: _buildInfoRow(
                            'Chassi',
                            _assist!.veiculoSelecionado!.chassi,
                          ),
                        ),
                      if (_assist!.veiculoSelecionado!.ano > 0)
                        Expanded(
                          child: _buildInfoRow(
                            'Ano',
                            '${_assist!.veiculoSelecionado!.ano}/${_assist!.veiculoSelecionado!.anomodelo}',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // 📍 LOCALIZAÇÃO & CONTATO
            if (_assist!.localOcorrencia.isNotEmpty ||
                (_assist!.localDestino?.isNotEmpty ?? false) ||
                (_assist!.nomeContato?.isNotEmpty ?? false) ||
                _assist!.localOcorrencia.isNotEmpty ||
                (_assist!.enderecoTerceiro.isNotEmpty))
              _buildSection(
                icon: Icons.location_on,
                color: const Color(0xFF2E7D32),
                title: 'Localização & Contato',
                children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_assist!.localOcorrencia.isNotEmpty)
                          Expanded(
                            child: _buildIconRow(Icons.pin_drop_outlined, Colors.red,
                                'Local da ocorrência', _assist!.localOcorrencia),
                          ),
                        if (_assist!.localDestino?.isNotEmpty ?? false) ...[
                          if (_assist!.localOcorrencia.isNotEmpty) const SizedBox(width: 16),
                          Expanded(
                            child: _buildIconRow(Icons.flag_outlined, Colors.blue,
                                'Local de destino', _assist!.localDestino!),
                          ),
                        ],
                      ],
                    ),
                  if ((_assist!.nomeContato?.isNotEmpty ?? false) ||
                      (_assist!.telefoneContatoLocal?.isNotEmpty ?? false)) ...[
                    const Divider(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── CONTATO NO LOCAL ───
                        Expanded(
                          flex: 2,
                          child: _buildInfoRow(
                            'Contato no local',
                            _assist!.nomeContato?.isNotEmpty ?? false
                                ? _assist!.nomeContato!
                                : '—',
                          ),
                        ),
                        
                        // ─── TELEFONE NO LOCAL (COM ÍCONES) ───
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoRow(
                                  'Telefone no local',
                                  _assist!.telefoneContatoLocal?.isNotEmpty ?? false
                                      ? BRFormatters.formatarTelefone(_assist!.telefoneContatoLocal!)
                                      : '—',
                                ),
                              ),
                              if (_assist!.telefoneContatoLocal?.isNotEmpty ?? false) ...[
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    final tel = _assist!.telefoneContatoLocal!.replaceAll(RegExp(r'\D'), '');
                                    if (tel.isNotEmpty) launchUrlString('tel:$tel');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.call, size: 18, color: Colors.green.shade600),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    final tel = _assist!.telefoneContatoLocal!.replaceAll(RegExp(r'\D'), '');
                                    if (tel.isNotEmpty) {
                                      launchUrlString('https://wa.me/55$tel', mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.message, size: 18, color: const Color(0xFF25D366)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 16),

            // 🔧 SERVIÇOS E REPAROS
            _buildSection(
              icon: Icons.build_outlined,
              color: Colors.orange,
              title: 'Serviços e Reparos',
              children: [
                if (_isEditing) ...[
                    // ✅ NOME DA OFICINA (NOVO!)
                  Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                      // ✨ Filtrar oficinas cadastradas (substitua com sua lógica real)
                      final oficinasDisponiveis = ['CARGLASS', 'OFICINA SILVA', 'MECANICA XYZ'];
                      return oficinasDisponiveis.where((o) =>
                          o.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (selection) {
                      setState(() => _nomeOficinaCtrl.text = selection.toUpperCase());
                    },
                    fieldViewBuilder: (ctx, autoCtrl, focusNode, onSubmitted) {
                      autoCtrl.text = _nomeOficinaCtrl.text;
                      return TextField(
                        controller: autoCtrl,
                        focusNode: focusNode,
                        inputFormatters: [
                          UpperCaseTextFormatter(), // ✨ FORÇA CAIXA ALTA
                        ],
                        decoration: InputDecoration(
                          labelText: 'Nome da Oficina',
                          prefixIcon: const Icon(Icons.build_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Digite ou selecione',
                          suffixIcon: _nomeOficinaCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    autoCtrl.clear();
                                    setState(() => _nomeOficinaCtrl.clear());
                                  },
                                )
                              : null,
                        ),
                        // ✨ IMPORTANTE: Use listener, NÃO onChanged!
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
                                return InkWell(
                                  onTap: () => onSelected(option.toUpperCase()),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      option.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
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
                  const SizedBox(height: 12),
                  TextField(
                    controller: _enderecoTerceiroCtrl,
                    readOnly: true,
                    onTap: () async {
                      final result = await _openPlaceSearch();
                      if (result != null) setState(() => _enderecoTerceiroCtrl.text = result);
                    },
                    decoration: InputDecoration(
                      labelText: 'Endereço local do serviço',
                      prefixIcon: const Icon(Icons.build_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: const Icon(Icons.location_on_outlined),
                      hintText: 'Clique para buscar endereço',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _nomeContatoOficinaCtrl,
                          decoration: InputDecoration(
                            labelText: 'Nome do contato do serviço',
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
                            labelText: 'Telefone do serviço',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [BRFormatters.telefoneFormatter],  // ← Adicione
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                // ─── AGENDAMENTO (SEMPRE VISÍVEL) ───────────────────
                _buildSection(
                icon: Icons.calendar_today_outlined,
                color: Colors.orange,
                title: 'Agendamento',
                children: [
                    // 1. Data & Hora do Agendamento
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _assist!.statusAtual != 'Concluído' && 
                                  _assist!.statusAtual != 'Cancelado'
                                ? () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _assist!.dataAgendamento ?? 
                                                  DateTime.now().add(const Duration(days: 1)),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      setState(() => _assist!.dataAgendamento = picked);
                                      // Salvar no Firestore
                                      await _salvarAlteracoes();
                                    }
                                  }
                                : null,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Data do agendamento',
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                _assist!.dataAgendamento != null
                                    ? DateFormat('dd/MM/yyyy').format(_assist!.dataAgendamento!)
                                    : 'Selecionar',
                                style: TextStyle(
                                  color: _assist!.dataAgendamento != null ? null : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _assist!.statusAtual != 'Concluído' && 
                                  _assist!.statusAtual != 'Cancelado'
                                ? () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _assist!.horaAgendamento = 
                                            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                      });
                                      // Salvar no Firestore
                                      await _salvarAlteracoes();
                                    }
                                  }
                                : null,
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Hora do agendamento',
                                prefixIcon: const Icon(Icons.access_time_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                _assist!.horaAgendamento != null
                                    ? _assist!.horaAgendamento!
                                    : 'Selecionar',
                                style: TextStyle(
                                  color: _assist!.horaAgendamento != null ? null : Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 2. Exibição + Reagendamento
                    if (_assist!.dataAgendamento != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildIconRow(
                              Icons.calendar_today_outlined,
                              Colors.orange,
                              'Data/Hora',
                              '${DateFormat('dd/MM/yyyy').format(_assist!.dataAgendamento!)}'
                              '${_assist!.horaAgendamento != null ? ' às ${_assist!.horaAgendamento}' : ''}',
                            ),
                          ),
                          // Contador de reagendamentos
                          if (_assist!.totalReagendamentos > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _assist!.totalReagendamentos >= 2
                                    ? Colors.red.shade50 : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _assist!.totalReagendamentos >= 2
                                      ? Colors.red.shade300 : Colors.orange.shade300,
                                ),
                              ),
                              child: Text(
                                '${_assist!.totalReagendamentos}º reagend.',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _assist!.totalReagendamentos >= 2
                                      ? Colors.red.shade700 : Colors.orange.shade700,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          // Botão Reagendar
                          if (_assist!.statusAtual != 'Concluído' &&
                              _assist!.statusAtual != 'Cancelado')
                            OutlinedButton.icon(
                              onPressed: _reagendar,
                              icon: const Icon(Icons.event_repeat, size: 14, color: Colors.orange),
                              label: const Text('Reagendar',
                                  style: TextStyle(fontSize: 12, color: Colors.orange)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.orange),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                // ✅ EXIBIR NOME DA OFICINA (quando não está editando)
                if (_assist!.nomeOficina != null && _assist!.nomeOficina!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.build_outlined, size: 20, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Oficina',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _assist!.nomeOficina!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                // Oficina
                if (_assist!.enderecoTerceiro.isNotEmpty)
                  _buildIconRow(Icons.build_outlined, Colors.orange,
                      'Oficina / Local do serviço', _assist!.enderecoTerceiro),
                if (_assist!.nomeContatoOficina?.isNotEmpty ?? false ||
                    _assist!.telefoneContatoOficina?.isNotEmpty == true) ...[
                  if (_assist!.enderecoTerceiro.isNotEmpty) const Divider(height: 16),
                  Row(
                    children: [
                      if (_assist!.nomeContatoOficina?.isNotEmpty ?? false)
                        Expanded(
                          flex: 3,
                          child: _buildIconRow(Icons.person_outlined, Colors.grey.shade600,
                              'Contato do serviço', _assist!.nomeContatoOficina!),
                        ),
                      if (_assist!.telefoneContatoOficina?.isNotEmpty ?? false)
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Telefone do serviço',
                                  style: TextStyle(fontSize: 11, color: Colors.grey,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(child: Text(_assist!.telefoneContatoOficina!,
                                      style: const TextStyle(fontSize: 13))),
                                  InkWell(
                                    onTap: () {
                                      final tel = _assist!.telefoneContatoOficina!
                                          .replaceAll(RegExp(r'\D'), '');
                                      if (tel.isNotEmpty) launchUrlString('tel:$tel');
                                    },
                                    child: Padding(padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.call, size: 18, color: Colors.green.shade600)),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      final tel = _assist!.telefoneContatoOficina!
                                          .replaceAll(RegExp(r'\D'), '');
                                      if (tel.isNotEmpty) launchUrlString(
                                          'https://wa.me/55$tel',
                                          mode: LaunchMode.externalApplication);
                                    },
                                    child: Padding(padding: const EdgeInsets.all(4),
                                        child: Icon(Icons.message, size: 18,
                                            color: const Color(0xFF25D366))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                if (_assist!.dataAgendamento == null &&
                    _assist!.enderecoTerceiro.isEmpty &&
                    (_assist!.nomeContatoOficina?.isEmpty ?? true))
                  Text('Nenhum serviço registrado. Clique em Editar para adicionar.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              ],
              ],
            ),

            const SizedBox(height: 16),

            // 📞 RELATO DO CLIENTE
            if (_assist!.relatoEvento.isNotEmpty)
              _buildSection(
                icon: Icons.record_voice_over_outlined,
                color: const Color(0xFFD32F2F),
                title: 'Relato do Cliente',
                children: [
                  SelectableText(_assist!.relatoEvento,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),

            const SizedBox(height: 16),

            // 📝 ANOTAÇÕES  
            _buildSection(
              icon: Icons.edit_note_outlined,
              color: const Color(0xFF5C6BC0),
              title: 'Anotações',
              trailing: TextButton.icon(
                onPressed: () => _adicionarAnotacao(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Adicionar'),
              ),
              children: [
                if (_assist!.anotacoes.isEmpty)
                  SelectableText('Nenhuma anotação.', 
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ..._assist!.anotacoes.map((a) {
                  final autor = a['autor'] as String? ?? '';
                  final conteudo = a['conteudo'] as String? ?? '';
                  final data = a['data'] as String? ?? '';
                  DateTime? dataObj;
                  try { dataObj = DateTime.parse(data); } catch (_) {}
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            SelectableText(autor, style: TextStyle(fontSize: 11,
                                color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (dataObj != null)
                              SelectableText(DateFormat('dd/MM/yyyy HH:mm').format(dataObj),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(conteudo, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ],
                    ),
                  );
                }),
              ],
            ),
            
            const SizedBox(height: 16),

            // 📝 TAREFAS
            _buildSection(
              icon: Icons.checklist,
              color: Colors.orange,
              title: 'Tarefas',
              children: [
                TaskListWidget(
                  numeroSinistro: _assist!.numeroSinistro,
                  clientId: _assist!.idCliente,
                  clientNome: _assist!.clientNome,
                  clientCnpjCpf: _assist!.clientCnpjCpf,
                  sinistroId: _assist!.id,
                ),
              ],
            ),

            const SizedBox(height: 16),
            _buildSection(
              icon: Icons.attach_file,
              color: const Color(0xFF00695C),
              title: 'Anexos',
              children: [
                // Fotos e docs já salvos (exibição)
                if (_assist!.fotosUrls.isNotEmpty) ...[
                  // mantém a exibição atual já implementada
                ],
                // Upload de novos
                _AssistAnexosCard(
                  anexos: _novosAnexos,
                  dragOver: _dragOver,
                  isUploading: _isUploadingAnexos,
                  onAddArquivos: _adicionarArquivos,
                  onRemoveArquivo: _removerArquivo,
                  onPickArquivos: _pickArquivos,
                  onDragEntered: (cat, val) => setState(() => _dragOver[cat] = val),
                  onDragExited: (cat, val) => setState(() => _dragOver[cat] = val),
                  isImageFile: _isImageFile,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 📝 STATUS E AÇÕES
            _buildSection(
              title: 'Status',
              children: [
                DropdownButtonFormField<String>(
                  value: _statusCtrl.text,
                  items: _statusOptions
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (val) async {
                    if (val == null) return;

                    // Bloqueia retorno para 'Aberto' se já passou por status avançado
                    final statusAvancados = ['Em Andamento', 'Concluído', 'Cancelado', 'Aguardando Cliente'];
                    if (val == 'Aberto' && statusAvancados.contains(_assist!.statusAtual)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Não é possível retornar para "Aberto" após o atendimento ter avançado.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() => _statusCtrl.text = val);
                    if (val == 'Em Andamento') {
                      await _iniciarSlaAtendimento();
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Status Atual',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 🖼️ ANEXOS
            if (_assist!.fotosUrls.isNotEmpty || _assist!.arquivosLaudosUrls.isNotEmpty)
              _buildSection(
                icon: Icons.attach_file,
                color: const Color(0xFF00695C),
                title: 'Anexos',
                children: [
                  if (_assist!.fotosUrls.isNotEmpty) ...[
                    const Text('FOTOS DA OCORRÊNCIA',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: Colors.grey, letterSpacing: 0.4)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _assist!.fotosUrls.map((url) {
                        final cleanedUrl = url.trim();
                        return GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: Stack(
                                children: [
                                  InteractiveViewer(
                                    child: Image.network(
                                      cleanedUrl,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8, right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              cleanedUrl,
                              width: 100, height: 100, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (_assist!.fotosUrls.isNotEmpty && _assist!.arquivosLaudosUrls.isNotEmpty)
                    const Divider(height: 20),
                  if (_assist!.arquivosLaudosUrls.isNotEmpty) ...[
                    const Text('DOCUMENTOS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: Colors.grey, letterSpacing: 0.4)),
                    const SizedBox(height: 8),
                    ..._assist!.arquivosLaudosUrls.map((url) {
                      final cleanedUrl = url.trim();
                      final nome = Uri.decodeFull(
                          cleanedUrl.split('/').last.split('?').first);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                        title: Text(nome, style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        onTap: () async {
                          try {
                            if (await canLaunchUrlString(cleanedUrl)) {
                              await launchUrlString(cleanedUrl,
                                  mode: LaunchMode.externalApplication);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Não foi possível abrir o arquivo')),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Erro ao abrir arquivo')),
                              );
                            }
                          }
                        },
                      );
                    }),
                  ],
                ],
              ),

            const SizedBox(height: 16),

            // 📜 HISTÓRICO DE STATUS
            if (_assist!.historicoStatus.isNotEmpty)
              _buildSection(
                title: 'Histórico',
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _assist!.historicoStatus.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.shade300),
                    itemBuilder: (_, idx) {
                      final evento = _assist!.historicoStatus[idx];
                      final status = evento['status'] as String?;
                      final data = _parseHistoricoData(evento['data']);
                      final registradoPor = evento['registrado_por'] as String?;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getStatusColor(status ?? ''),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _descricaoHistorico(status ?? ''),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    data != null
                                        ? DateFormat('dd/MM/yyyy HH:mm').format(data)
                                        : '--',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (registradoPor != null && registradoPor.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Registrado por: $registradoPor',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // 💾 BOTÕES DE AÇÃO
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Fechar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving
                    ? null
                    : () async {
                        final opcao = await _mostrarDialogoSalvar();
                        if (opcao == null) return;
                        await _salvar(notificarWhatsApp: opcao == 'whatsapp');
                        if (opcao == 'nps' && mounted) {
                          NpsSendDialog.mostrar(
                            context,
                            claimId: _assist!.id,
                            numeroSinistro: _assist!.numeroSinistro,
                            clienteId: _assist!.idCliente,
                            clienteNome: _assist!.clientNome,
                            clienteTelefone: _assist!.telefoneCliente ?? '',
                            clienteEmail: '',  // adicionar email no Claim se precisar
                            tipo: 'assistencia',
                          );
                        }
                      },
                    icon: const Icon(Icons.save),
                    label: const Text('Salvar'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ],
            ),

            if (_isAdmin) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _excluir,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Excluir Assistência',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              SelectableText(value, style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
}

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
    Color? color,
    Widget? trailing,
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon, 
                    size: 20,
                    color: color ?? const Color(0xFF1A1A2E)
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color ?? const Color(0xFF1A1A2E),
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

Widget _buildInfoRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
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

  Color _getStatusBgColor(String status) {
    return _getStatusColor(status).withOpacity(0.15);
  }

  // HELPER DA DESCRIÇÃO DO STATUS
  String _descricaoHistorico(String evento) {
    if (evento.startsWith('+')) return evento; // já é descritivo (ex: +30min)
    return 'Status alterado para $evento';
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