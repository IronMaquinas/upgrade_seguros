// claim_detail_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' hide LatLng;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:upgrade_seguros/formatter/number_input_formatter.dart';
import 'package:upgrade_seguros/helpers/signature_data_helper.dart';
import 'package:upgrade_seguros/models/corretora_model.dart';
import 'package:upgrade_seguros/models/employee_model.dart';
import 'package:upgrade_seguros/models/pdf_signature_model.dart';
import 'package:upgrade_seguros/models/third_party_model.dart';
import 'package:upgrade_seguros/widgets/terceiro_form.dart';
import 'package:upgrade_seguros/widgets/lancamentos_widget.dart';
import 'package:upgrade_seguros/services/employee_service.dart';
import 'package:upgrade_seguros/services/image_service_web.dart';
import 'package:upgrade_seguros/services/pdf_services.dart';
import 'package:upgrade_seguros/services/place_search_delegate.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:upgrade_seguros/widgets/notes_widget.dart';
import 'package:upgrade_seguros/widgets/task_list_widget.dart';
import 'package:upgrade_seguros/widgets/workshop_widget.dart';
import 'package:upgrade_seguros/widgets/videos_sinistro.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:upgrade_seguros/utils/videos.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'dart:convert';
import '../models/claim_task_model.dart';
import '../models/machinery_model.dart';
import 'package:upgrade_seguros/widgets/selectable_text_helper.dart';
import 'package:upgrade_seguros/services/tarefas_evento_service.dart'; // Etapa 14
import 'package:upgrade_seguros/utils/tarefas_evento.dart'; // Etapa 14
import 'package:upgrade_seguros/widgets/tarefas_evento_dialog.dart'; // Etapa 14

class ClaimDetailScreen extends StatefulWidget {
  final Claim claim;
  const ClaimDetailScreen({super.key, required this.claim});

  @override
  State<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06), // 🔥 fundo leve
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ClaimDetailScreenState extends State<ClaimDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  late Claim _currentClaim;
  bool _isLoading = false;

  static const STATUS_ABERTA = 'Aberta';
  static const STATUS_CONCLUIDA = 'Concluída';

  String _nomeUsuarioLogado = 'Desconhecido'; 
  LimitesVideo _limitesVideo = const LimitesVideo(); // Etapa 12

  bool _isStatusExterno(String status) {
    return [
      'Aguardando Peças',
      'Reparo em Andamento',
    ].contains(status);
  }

  // Controladores para campos editáveis
  late TextEditingController _relatoController;
  late TextEditingController _localController;
  late TextEditingController _numeroSinistroController;
  late TextEditingController _numeroSeguradoraController;
  late TextEditingController _enderecoTerceiroController;
  late TextEditingController _slaPrevistController;

  late TextEditingController _horaOcorrenciaController;
  late TextEditingController _nomeContatoSinistroController;
  late TextEditingController _telefoneContatoSinistroController;

  List<ThirdParty> _currentTerceiros = [];

  Client? _client;
  String? _userRole;
  Client? _originalClient;

  // ignore: prefer_final_fields
  List<String> _statusOptions = [
    'Aberto',
    'Vistoria em Andamento',
    'Aguardando Aprovação',
    'Aguardando Peças',
    'Reparo em Andamento',
    'Concluído',
  ];

  // Edição dos valores
  bool _isEditing = false;
  late TextEditingController _valorTotalSinistroController;

  final NumberFormat decimalFormat = NumberFormat.decimalPattern('pt_BR');
  late StreamSubscription<DocumentSnapshot> _sinistroSubscription;

    // API Key para Google places - Mesma conta da Iron Máquinas
  final _places = FlutterGooglePlacesSdk("AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE");
  final String _apiKey = 'AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE';

  LatLng? _enderecoTerceiroLatLng;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _currentClaim = widget.claim;
    _loadClient();
    _listenToClaimUpdates();
    _loadNomeUsuario();
    ConfigService().getLimitesVideo().then((l) {
      if (mounted) setState(() => _limitesVideo = l);
    }).catchError((_) {});
    _currentTerceiros = List.from(_currentClaim.terceiros); // Inicializa a lista
    _valorTotalSinistroController = TextEditingController(
    text: _currentClaim.valorTotalSinistro.toStringAsFixed(2));

    // Inicializa os controladores para edição do sinistro
    _relatoController = TextEditingController(text: _currentClaim.relatoEvento);
    _localController = TextEditingController(text: _currentClaim.localOcorrencia);
    _numeroSinistroController = TextEditingController(text: _currentClaim.numeroSinistro);
    _numeroSeguradoraController = TextEditingController(text: _currentClaim.numeroSeguradora);
    _enderecoTerceiroController = TextEditingController(text: _currentClaim.enderecoTerceiro);

    _horaOcorrenciaController = TextEditingController(text: _currentClaim.horaOcorrencia ?? '');
    _nomeContatoSinistroController = TextEditingController(text: _currentClaim.nomeContatoSinistro ?? '');
    _telefoneContatoSinistroController = TextEditingController(text: _currentClaim.telefoneContatoSinistro ?? '');
  
    _slaPrevistController = TextEditingController(
      text: _currentClaim.slaPrevisto != null
          ? DateFormat('dd/MM/yyyy').format(_currentClaim.slaPrevisto!)
          : 'Selecione',
    );
  
    _currentClaim.veiculoSelecionado ??= Vehicle(
      placa: '',
      marca: '',
      modelo: '',
      ano: 0,
      anomodelo: 0,
      chassi: '',
      cor: '',
      nomeCondutorMotorista: '',
      cpfCondutorMotorista: '',
      cnhCondutorMotorista: '',
    );

  }

  @override
  void dispose() {
    _valorTotalSinistroController.dispose();
    _relatoController.dispose();
    _localController.dispose();
    _numeroSinistroController.dispose();
    _numeroSeguradoraController.dispose();
    _enderecoTerceiroController.dispose();
    _slaPrevistController.dispose();
    _horaOcorrenciaController.dispose();
    _nomeContatoSinistroController.dispose();
    _telefoneContatoSinistroController.dispose();
    super.dispose();
    _sinistroSubscription.cancel();
  }

  Future<void> _loadNomeUsuario() async {
    try {
      final nome = await _authService.getUserName();
      setState(() => _nomeUsuarioLogado = nome);
    } catch (e) {
      print('🔴 ERRO EM _loadNomeUsuario(): $e'); // ← SE DER ERRO
    }
  }

  void _listenToClaimUpdates() {
    _sinistroSubscription = _firestoreService
        .getSinistrosCollection()
        .doc(widget.claim.id)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final updatedClaim = Claim.fromMap(snapshot.data()!)..id = snapshot.id;
        if (mounted) { // ✅ Verifica se o widget ainda está na árvore
          setState(() {
            _currentClaim = updatedClaim;
            _valorTotalSinistroController.text =
                decimalFormat.format(updatedClaim.valorTotalSinistro);
            _enderecoTerceiroController.text = _currentClaim.enderecoTerceiro;
          });
        }
      }
    });
  }

  // Carrega usuário admin / user
  Future<void> _loadUserRole() async {
    final role = await _authService.getUserRole();
    print('Role carregado: $role');
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  // UPDATE DE STATUS DE SINISTRO E COMUNICAÇÃO COM O CLIENTE
  Future<void> _showStatusWithDeadlineDialog(String newStatus) async {
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Definir previsão'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Informe a previsão para "$newStatus"'),

                  const SizedBox(height: 12),

                  // 🔥 BOTÃO MELHORADO
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                          : 'Selecionar data',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 8),

                  // 🔥 TEXTO CONFIRMANDO DATA
                  if (selectedDate != null)
                    Text(
                      'Data selecionada: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.pop(context),
                ),
                ElevatedButton(
                  child: const Text('Salvar'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateStatusWithDeadline(newStatus, selectedDate);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // SALVAR STATUS + PREVISÃO DE COMUNICAÇÃO COM O CLIENTE DA MUDANÇA DE STATUS
  Future<void> _updateStatusWithDeadline(
    String newStatus,
    DateTime? dataPrevisao,
  ) async {
    final userId = _authService.getUserId();
    final userEmail = _authService.getUserEmail();

    // 🔥 1. BUSCAR DATA ANTERIOR (ANTES DO UPDATE)
    final doc = await _firestoreService
        .getSinistrosCollection()
        .doc(_currentClaim.id)
        .get();

    final dataAnterior = doc.data()?['data_previsao_conclusao'] != null
        ? (doc.data()!['data_previsao_conclusao'] as Timestamp).toDate()
        : null;

    // 🔥 2. ATUALIZA STATUS
    await _firestoreService.updateClaimStatus(
      _currentClaim.id,
      newStatus,
      userId,
      userEmail,
      _nomeUsuarioLogado,
    );

    // 🔥 3. ATUALIZA PREVISÃO
    await _firestoreService.getSinistrosCollection()
        .doc(_currentClaim.id)
        .update({
      'data_previsao_conclusao': dataPrevisao,
    });

    // 🔥 4. CRIA TASK
    // Etapa 14: a tarefa de contato anterior deste sinistro fica substituída.
    await TarefasEventoService().concluirContatosAnteriores(
      _currentClaim.id,
      motivo: TarefasEvento.motivoSubstituida('status para "$newStatus"', DateTime.now()),
    );
    final taskId = await _firestoreService.addTask(
      ClaimTask(
        id: '',
        tipo: TarefasEvento.tipoContato,
        descricao: 'Informar status ao cliente: $newStatus',
        status: STATUS_ABERTA,
        prazo: dataPrevisao ?? DateTime.now().add(const Duration(days: 2)),
        criadoEm: DateTime.now(),
        claimId: _currentClaim.id,
        responsavelId: userId,
        numeroSinistro: _currentClaim.numeroSinistro,
        responsavelEmail: userEmail,
      ),
    );

    // 🔥 5. ABRE POPUP COM DATA ANTERIOR
    _showCommunicationDialog(
      newStatus,
      dataPrevisao,
      taskId,
      dataAnterior,
    );
  }

  // POP UP DE COMUNICAÇÃO DE ALTERAÇÃO DE STATUS DE SINISTRO
  Future<void> _showCommunicationDialog(
    String status,
    DateTime? data,
    String taskId,
    DateTime? dataAnterior,
  ) async {
    final cliente = _client;

    final email = cliente?.email ?? '';
    final phone = cliente?.contato ?? '';
    final phoneSanitized = phone.replaceAll(RegExp(r'\D'), '');

    // 🔥 DATA NOVA
    final dataNovaFormatada = data != null
        ? DateFormat('dd/MM/yyyy').format(data)
        : 'Não informada';

    // 🔥 DATA ANTERIOR
    final dataAnteriorFormatada = dataAnterior != null
        ? DateFormat('dd/MM/yyyy').format(dataAnterior)
        : null;

    // 🔥 IDENTIFICAÇÃO DINÂMICA
    String identificacao = '';
    String referencia = '';

    if (_currentClaim.veiculoSelecionado != null) {
      final v = _currentClaim.veiculoSelecionado!;
      identificacao = '${v.modelo ?? ''} (${v.placa ?? ''})';

      referencia = '''
  Referente a:
  Veículo: ${v.modelo ?? '-'}
  Placa: ${v.placa ?? '-'}
  ''';
    } else if (_currentClaim.life != null) {
      final vida = _currentClaim.life!;
      identificacao = vida.nomeSegurado;

      referencia = '''
  Referente a:
  Segurado: ${vida.nomeSegurado}
  CPF: ${vida.cpfSegurado}
  ''';
    } else if (_currentClaim.house != null) {
      final casa = _currentClaim.house!;
      identificacao = casa.localHouse;

      referencia = '''
  Referente a:
  Endereço: ${casa.localHouse}
  ''';
    }

    // 🔥 ASSUNTO
    final assunto =
        'Atualização do Sinistro ${_currentClaim.numeroSinistro}'
        '${identificacao.isNotEmpty ? ' – $identificacao' : ''}';

    // 🔥 COMPARAÇÃO CORRETA (IGNORA HORA)
    bool datasDiferentes = false;

    if (dataAnterior != null && data != null) {
      datasDiferentes =
          dataAnterior.day != data.day ||
          dataAnterior.month != data.month ||
          dataAnterior.year != data.year;
    }

    // 🔥 BLOCO DE PREVISÃO
    String blocoPrevisao;

    if (dataAnterior != null && datasDiferentes) {
      blocoPrevisao = '''
  Previsão anterior: $dataAnteriorFormatada
  Nova previsão: $dataNovaFormatada
  ''';
    } else {
      blocoPrevisao = 'Previsão de conclusão: $dataNovaFormatada';
    }

    // 🔥 MENSAGEM FINAL
    final mensagem = '''
  Prezado cliente,

  Seu sinistro ${_currentClaim.numeroSinistro} foi atualizado para:

  $status

  ${referencia.isNotEmpty ? '$referencia\n' : ''}$blocoPrevisao

  Estamos à disposição.
  ''';

    // 🟢 WHATSAPP
    final whatsUrl =
        'https://wa.me/$phoneSanitized?text=${Uri.encodeComponent(mensagem)}';

    // 🔵 OUTLOOK
    final outlookUrl =
        'https://outlook.office.com/mail/deeplink/compose'
        '?to=$email'
        '&subject=${Uri.encodeComponent(assunto)}'
        '&body=${Uri.encodeComponent(mensagem)}';

    // 🔴 GMAIL
    final gmailUrl =
        'https://mail.google.com/mail/?view=cm&fs=1'
        '&to=$email'
        '&su=${Uri.encodeComponent(assunto)}'
        '&body=${Uri.encodeComponent(mensagem)}';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comunicar cliente'),
        content: const Text('Deseja enviar atualização ao cliente?'),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🟢 WHATSAPP
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp'),
                onPressed: () async {
                  Navigator.pop(context);

                  await launchUrlString(whatsUrl);

                  final confirmou = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar envio'),
                      content: const Text('Você enviou a mensagem ao cliente?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Não'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sim'),
                        ),
                      ],
                    ),
                  );

                  if (confirmou == true) {
                    await _firestoreService.updateTaskStatus(taskId, 'Concluída');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tarefa concluída com sucesso')),
                    );
                  }
                },
              ),

              const SizedBox(height: 8),

              // 🔵 OUTLOOK
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.business),
                label: const Text('Outlook'),
                onPressed: () async {
                  Navigator.pop(context);

                  await launchUrlString(outlookUrl);

                  final confirmou = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar envio'),
                      content: const Text('Você enviou o email ao cliente?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Não'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sim'),
                        ),
                      ],
                    ),
                  );

                  if (confirmou == true) {
                    await _firestoreService.updateTaskStatus(taskId, 'Concluída');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tarefa concluída com sucesso')),
                    );
                  }
                },
              ),

              const SizedBox(height: 8),

              // 🔴 GMAIL
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.email),
                label: const Text('Gmail'),
                onPressed: () async {
                  Navigator.pop(context);

                  await launchUrlString(gmailUrl);

                  final confirmou = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmar envio'),
                      content: const Text('Você enviou o email ao cliente?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Não'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sim'),
                        ),
                      ],
                    ),
                  );

                  if (confirmou == true) {
                    await _firestoreService.updateTaskStatus(taskId, 'Concluída');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tarefa concluída com sucesso')),
                    );
                  }
                },
              ),

              const SizedBox(height: 8),

              // ☎️ Etapa 14: avisou por telefone/pessoalmente → conclui a tarefa
              OutlinedButton.icon(
                icon: const Icon(Icons.phone_in_talk_outlined),
                label: const Text('Já informei por outro meio'),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await TarefasEventoService().concluir(
                      [taskId],
                      motivo: TarefasEvento.motivoOutroMeio,
                      automatica: false,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Tarefa concluída: cliente informado por outro meio')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(content: Text('Erro ao concluir a tarefa: $e')),
                      );
                    }
                  }
                },
              ),

              const SizedBox(height: 8),

              // ⚪ DEPOIS
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fazer depois'),
              ),
            ],
          )
        ],
      ),
    );
  }

  // LOG DE MUDANÇA DE STATUS DE SINISTRO
  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);

    final userId = _authService.getUserId();
    final userEmail = _authService.getUserEmail();

    if (userId == 'anonymous_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado. Faça login.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (newStatus == 'Concluído') {
        _currentClaim.dataConclusao = Timestamp.now();
        await _firestoreService.updateClaim(_currentClaim);
      }
      await _firestoreService.updateClaimStatus(
        _currentClaim.id,
        newStatus,
        userId,
        userEmail,
        _nomeUsuarioLogado,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status atualizado para: $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar status: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // UPDATE DE STATUS ONLY PARA ALTERAÇÕES DE PRAZO EM PROCESSOS CRÍTICOS
  Future<void> _showUpdateDeadlineOnlyDialog() async {
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Atualizar previsão'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Informe a nova previsão de conclusão'),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      selectedDate != null
                          ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                          : 'Selecionar data',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );

                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 8),

                  if (selectedDate != null)
                    Text(
                      'Data selecionada: ${DateFormat('dd/MM/yyyy').format(selectedDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _updateDeadlineOnly(selectedDate);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // FUNÇÃO COMPLEMENTAR DO UPDATE ACIMA
  Future<void> _updateDeadlineOnly(DateTime? dataPrevisao) async {
    final userId = _authService.getUserId();
    final userEmail = _authService.getUserEmail();

    final doc = await _firestoreService
    .getSinistrosCollection()
    .doc(_currentClaim.id)
    .get();

    final dataAnterior = doc.data()?['data_previsao_conclusao'] != null
        ? (doc.data()!['data_previsao_conclusao'] as Timestamp).toDate()
        : null;

    await _firestoreService.getSinistrosCollection()
        .doc(_currentClaim.id)
        .update({
      'data_previsao_conclusao': dataPrevisao,
      'dataUltimaAtualizacao': DateTime.now(),
    });

    // 🔥 cria task
    // Etapa 14: a tarefa de contato anterior deste sinistro fica substituída.
    await TarefasEventoService().concluirContatosAnteriores(
      _currentClaim.id,
      motivo: TarefasEvento.motivoSubstituida('previsão', DateTime.now()),
    );
    final taskId = await _firestoreService.addTask(
      ClaimTask(
        id: '',
        tipo: TarefasEvento.tipoContato,
        descricao: 'Atualizar cliente: ${_currentClaim.statusAtual} (nova previsão)',
        status: STATUS_ABERTA,
        prazo: dataPrevisao ?? DateTime.now().add(const Duration(days: 2)),
        criadoEm: DateTime.now(),
        claimId: _currentClaim.id,
        responsavelId: userId,
        numeroSinistro: _currentClaim.numeroSinistro,
        responsavelEmail: userEmail,
      ),
    );

    // 🔥 abre comunicação
    _showCommunicationDialog(
      _currentClaim.statusAtual,
      dataPrevisao,
      taskId,
      dataAnterior,
    );
  }

  Future<void> _loadClient() async {
    final userId = _authService.getUserId();
    if (userId == 'anonymous_user') return;

    try {
      final client = await _firestoreService.getClientById(_currentClaim.idCliente);

      if (mounted) {
        setState(() {
          _client = client;
          _originalClient = client != null
              ? Client.fromMap(client.toMap())
              : null;
        });
      }
    } catch (e) {
      print('Erro ao buscar cliente: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);

    final userId = _authService.getUserId();
    if (userId == 'anonymous_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    bool clientChanged = false;

    if (_client != null && _originalClient != null) {
      if (_client!.nome != _originalClient!.nome ||
          _client!.contato != _originalClient!.contato ||
          _client!.email != _originalClient!.email) {
        clientChanged = true;
      }
    }

    try {
      final updates = <String, dynamic>{};

      // Campos básicos — só atualiza se mudou
      if (_currentClaim.relatoEvento != widget.claim.relatoEvento) {
        updates['relatoEvento'] = _currentClaim.relatoEvento;
      }
      if (_currentClaim.localOcorrencia != widget.claim.localOcorrencia) {
        updates['local_ocorrencia'] = _currentClaim.localOcorrencia;
      }
      if (_currentClaim.numeroSinistro != widget.claim.numeroSinistro) {
        updates['numero_sinistro'] = _currentClaim.numeroSinistro;
      }
      if (_currentClaim.numeroSeguradora != widget.claim.numeroSeguradora) {
        updates['numero_seguradora'] = _currentClaim.numeroSeguradora;
      }
      if (_currentClaim.valorTotalSinistro != widget.claim.valorTotalSinistro) {
        updates['valor_total_sinistro'] = _currentClaim.valorTotalSinistro;
      }
      if (_currentClaim.ramoSinistro != widget.claim.ramoSinistro) {
        updates['ramo_sinistro'] = _currentClaim.ramoSinistro;
      }
      if (_currentClaim.seguradora != widget.claim.seguradora) {
        updates['seguradora'] = _currentClaim.seguradora;
      }
      if (_currentClaim.tipoPerda != widget.claim.tipoPerda) {
        updates['tipoPerda'] = _currentClaim.tipoPerda;
      }
      if (_currentClaim.slaPrevisto != widget.claim.slaPrevisto) {
        updates['sla_previsto'] = _currentClaim.slaPrevisto;
      }
      if (_currentClaim.enderecoTerceiro != widget.claim.enderecoTerceiro) {
        updates['endereco_terceiro'] = _currentClaim.enderecoTerceiro;
      }

      // Listas — compara por tamanho/conteúdo
      if (_currentClaim.fotosUrls.length != widget.claim.fotosUrls.length ||
          !_currentClaim.fotosUrls.every(widget.claim.fotosUrls.contains)) {
        updates['fotos_urls'] = _currentClaim.fotosUrls;
      }

      if (_currentClaim.arquivosLaudosUrls.length != widget.claim.arquivosLaudosUrls.length ||
          !_currentClaim.arquivosLaudosUrls.every(widget.claim.arquivosLaudosUrls.contains)) {
        updates['arquivos_laudos_urls'] = _currentClaim.arquivosLaudosUrls;
      }

      // Terceiros — sempre salva (lista complexa, difícil comparar)
      updates['terceiros'] = _currentClaim.terceiros.map((t) => t.toMap()).toList();

      // Anotações — sempre salva
      updates['anotacoes'] = _currentClaim.anotacoes;

      // Objetos complexos — só salva se não for null (chave correta do Firestore)
      updates['veiculo_selecionado'] = _currentClaim.veiculoSelecionado?.toMap();

      if (_currentClaim.transporte != null) {
        updates['transporte'] = _currentClaim.transporte!.toMap();
      }

      if (_currentClaim.maquinaria != null) {
        updates['maquinaria'] = _currentClaim.maquinaria!.toMap();
      }

      if (_currentClaim.house != null) {
        updates['house'] = _currentClaim.house!.toMap();
      }

      if (_currentClaim.life != null) {
        updates['life'] = _currentClaim.life!.toMap();
      }

      if (_currentClaim.workshop != null) {
        updates['workshop'] = _currentClaim.workshop!.toMap();
      }

      if (_currentClaim.business != null) {
        updates['business'] = _currentClaim.business!.toMap();
      }

      if (_currentClaim.oficinas.isNotEmpty) {
        updates['oficinas'] = _currentClaim.oficinas.map((o) => o.toMap()).toList();
      }

      // Campos novos
      if (_currentClaim.horaOcorrencia != widget.claim.horaOcorrencia) {
        updates['hora_ocorrencia'] = _currentClaim.horaOcorrencia;
      }
      if (_currentClaim.nomeContatoSinistro != widget.claim.nomeContatoSinistro) {
        updates['nomeContatoSinistro'] = _currentClaim.nomeContatoSinistro;
      }
      if (_currentClaim.telefoneContatoSinistro != widget.claim.telefoneContatoSinistro) {
        updates['telefoneContatoSinistro'] = _currentClaim.telefoneContatoSinistro;
      }

      // 🔥 SALVA CLIENTE
      if (clientChanged && _client != null) {
        await _firestoreService.updateClient(_client!, userId);
      }

      // 🔥 SALVA SINISTRO
      if (updates.isNotEmpty) {
        await _firestoreService.getSinistrosCollection()
            .doc(_currentClaim.id)
            .update(updates);

        await _firestoreService.addStatusHistory(
          _currentClaim.id,
          'Edição de dados',
          userId,
          _authService.getUserEmail(),
          nomeUsuario: _nomeUsuarioLogado,
        );
      }

      // 🔥 HISTÓRICO CLIENTE (opcional TOP)
      if (clientChanged) {
        await _firestoreService.addStatusHistory(
          _currentClaim.id,
          'Edição de cliente',
          userId,
          _authService.getUserEmail(),
          nomeUsuario: _nomeUsuarioLogado,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alterações salvas com sucesso!')),
      );

      setState(() {
        _isEditing = false;
        _originalClient = _client != null
            ? Client.fromMap(_client!.toMap())
            : null;
      });

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadFoto() async {
    final results = await ImagePicker().pickMultiImage();
    if (results.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // ✅ Garante que o XFile tem path e name
      final xfiles = results.map((result) {
        return XFile(
          result.path,
          name: result.name.isNotEmpty
              ? result.name
              : 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          mimeType: 'image/jpeg',
        );
      }).toList();

      // Etapa 12: mesma compressão das outras telas (1024 px, JPG 50).
      // Antes a foto subia no tamanho original.
      final comprimidas = await ImageService().compressImages(xfiles);
      final urls = await _firestoreService.uploadSinistroFotos(
        _currentClaim.numeroSinistro,
        comprimidas,
      );

      if (urls.isNotEmpty) {
        setState(() {
          _currentClaim.fotosUrls.addAll(urls);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao subir foto: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadDocumento() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );
    if (result == null) return;

    _isLoading = true;
    try {
      // ✅ Usa diretamente result.files (que é List<PlatformFile>)
      final urls = await _firestoreService.uploadArquivosLaudos(
        _currentClaim.numeroSinistro,
        result.files, // ✅ Correto: List<PlatformFile>
      );

      if (urls.isNotEmpty) {
        setState(() {
          _currentClaim.arquivosLaudosUrls.addAll(urls);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao subir documento: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Funções para remover fotos e documentos
  void _removeFoto(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Foto'),
        content: const Text('Tem certeza que deseja remover esta foto?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _currentClaim.fotosUrls.remove(url);
              });
            },
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  // FUNÇÃO PARA REMOVER DOCUMENTO
  Future<void> _removeDocumento(String url) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Documento'),
        content: const Text('Tem certeza que deseja remover este documento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
        // 🔍 DEBUG
        print('CLAIM ID: ${_currentClaim.id}');
        print('NUMERO SINISTRO: ${_currentClaim.numeroSinistro}');

      // 🔥 remove da lista local
      _currentClaim.arquivosLaudosUrls.remove(url);

      // 🔥 atualiza Firestore
      await FirebaseFirestore.instance
          .collection('sinistros')
          .doc(_currentClaim.id)
          .update({
        'arquivos_laudos_urls': FieldValue.arrayRemove([url]),
      });

      // 🔥 remove do Storage via Cloud Function
      await _firestoreService.deleteFileByUrl(url);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover documento: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✨ MÉTODO DE CONFIRMAÇÃO E EXCLUSÃO
  void _showDeleteTerceiroConfirmation(ThirdParty terceiro, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Excluir Terceiro?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tem certeza que deseja excluir o terceiro:'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      terceiro.nome,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (terceiro.cpf.isNotEmpty)
                      Text('CPF/CNPJ: ${terceiro.cpf}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta ação não pode ser desfeita.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _currentClaim.terceiros.removeAt(index);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Terceiro removido com sucesso'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Excluir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateValorTotalSinistro() async {
    setState(() => _isLoading = true);
    final userId = _authService.getUserId();

    if (userId == 'anonymous_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado. Faça login.')));
      setState(() => _isLoading = false);
      return;
    }

    final raw = _valorTotalSinistroController.text;
    final clean = raw.replaceAll('.', '').replaceAll(',', '.');
    final novoValor = double.tryParse(clean) ?? 0.0;

    try {
      _currentClaim.valorTotalSinistro = novoValor;
      _currentClaim.dataConclusao = Timestamp.now();
      await _firestoreService.getSinistrosCollection()
        .doc(_currentClaim.id)
        .update({'valor_total_sinistro': novoValor});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor atualizado com sucesso!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar valor: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Excluir Sinistro
  void _confirmDeleteClaim() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Sinistro'),
        content: const Text('Tem certeza que deseja excluir este sinistro? TODOS os arquivos e dados serão permanentemente removidos. Esta ação não poderá ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir Permanentemente'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        
        // ✅ Agora passando o número do sinistro também
        await _firestoreService.deleteClaim(
          _currentClaim.id!, 
          _currentClaim.numeroSinistro
        );
        
        if (mounted) {
          Navigator.of(context).pop(); // Fecha a tela de detalhes
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sinistro e todos os arquivos excluídos com sucesso')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateAndSharePdf() async {
    setState(() => _isLoading = true);
    try {
      final pdfService = PdfService();
      final logoBytes = await pdfService.loadLogo();

      // 1️⃣ Usuário logado
      final usuarioLogado = await _obterDadosUsuarioLogado();

      // 2️⃣ Obter empresaId do usuário
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      final empresaId = userDoc.data()?['empresaId'] as String?;

      Corretora? corretora;
      PdfSignatureConfig? pdfConfig;

      if (empresaId != null && empresaId.isNotEmpty) {
        // Carrega a corretora
        final corretoraMap = await _firestoreService.getCorretoraById(empresaId);
        if (corretoraMap != null) {
          corretora = Corretora.fromMap(corretoraMap, empresaId);
        }

        // Carrega a configuração PDF
        final pdfConfigDoc = await FirebaseFirestore.instance
            .collection('pdf_signatures')
            .doc(empresaId)
            .get();
        if (pdfConfigDoc.exists) {
          pdfConfig = PdfSignatureConfig.fromJson(pdfConfigDoc.data() as Map<String, dynamic>);
        }
      }

      // 3️⃣ Dados da assinatura via helper
      final signatureData = SignatureDataHelper.getSignatureData(
        nomeSource: pdfConfig?.nomeSource ?? SignatureSource.funcionario,
        telefoneSource: pdfConfig?.telefoneSource ?? SignatureSource.funcionario,
        emailSource: pdfConfig?.emailSource ?? SignatureSource.funcionario,
        currentEmployee: usuarioLogado,
        corretora: corretora,
        nomeController: '',
        telefoneController: '',
        emailController: '',
      );

      // 4️⃣ Gerar PDF
      final pdfBytes = await pdfService.generateClaimPdf(
        _currentClaim,
        _client,
        _currentClaim.terceiros,
        logoBytes,
        usuarioNome: signatureData['nome'],
        usuarioEmail: signatureData['email'],
        usuarioTelefone: signatureData['telefone'],
      );

      final fileName = 'Upgrade Seguros - ${_currentClaim.numeroSinistro}.pdf';
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

   // 🆕 Helper para obter dados do usuário logado
  Future<Employee?> _obterDadosUsuarioLogado() async {
    try {
      final userId = _authService.getUserId();
       
      if (userId == 'anonymous_user' || userId.isEmpty) {
        print('❌ Usuário é anônimo ou vazio!');
        return null;
      }
      
      final employeeService = EmployeeService();
      final usuario = await employeeService.getUserById(userId);
      
      if (usuario == null) {
        print('⚠️ WARNING: usuário é null!');
        return null;
      }
      
      return usuario;
    } catch (e, stackTrace) {
      print('❌ ERRO ao obter dados do usuário: $e');
      print('📍 StackTrace: $stackTrace');
      print('═══════════════════════════════════════════════════');
      return null;
    }
  }

  // Generate EXCEL
    Future<void> _generateExcel() async {
    try {
      // 🔥 1. IDENTIFICAR PLACA CORRETA
      String placaSegurado = '';

      if (_currentClaim.transporte != null) {
        placaSegurado =
            _currentClaim.transporte?.placaCarreta?.isNotEmpty == true
                ? _currentClaim.transporte!.placaCarreta!
                : (_currentClaim.transporte?.placaCavalo ?? '');
      } else {
        placaSegurado = _currentClaim.veiculoSelecionado?.placa ?? '';
      }

      // 🔥 2. MODELO / MARCA
      String modeloMarca = '';

      if (_currentClaim.transporte != null) {
        modeloMarca = ''; // transporte geralmente não usa isso
      } else {
        final modelo = _currentClaim.veiculoSelecionado?.modelo ?? '';
        final marca = _currentClaim.veiculoSelecionado?.marca ?? '';
        modeloMarca = '$modelo / $marca';
      }

      // 🔥 3. DATAS FORMATADAS
      final dataSinistro =
          DateFormat('dd/MM/yyyy').format(_currentClaim.dataOcorrencia);

      final dataAviso = _currentClaim.dataAviso != null
          ? DateFormat('dd/MM/yyyy').format(_currentClaim.dataAviso!)
          : '';

      // 🔥 4. HEADERS EXATOS DO CLIENTE
      final headers = [
        'Empresa Segurada',
        'Placa do Segurado',
        'Reclamado',
        'Modelo/Marca',
        'Data do Sinistro',
        'Data do Aviso',
        'Tipo de Perda',
        'Numero de sinistro da seguradora',
        'Status',
        'Valor do sinistro',
        'Valor segurado',
        'Valor terceiros',
        'Qtd. lançamentos',
      ];

      // 🔥 5. LINHA DE DADOS
      final row = [
        _client?.nome ?? '',
        placaSegurado,
        placaSegurado, // 🔥 duplicado conforme sua necessidade
        modeloMarca,
        dataSinistro,
        dataAviso,
        _currentClaim.tipoPerda ?? '',
        _currentClaim.numeroSeguradora ?? '',
        _currentClaim.statusAtual ?? '',
        _currentClaim.valorTotalCalculado.toStringAsFixed(2),
        (_currentClaim.lancamentos.isEmpty
                ? _currentClaim.valorTotalSinistro
                : _currentClaim.resumoValores.segurado)
            .toStringAsFixed(2),
        _currentClaim.resumoValores.terceiros.toStringAsFixed(2),
        _currentClaim.resumoValores.ativos.toString(),
      ];

      // 🔥 6. CSV FINAL
      final csv = StringBuffer();
      csv.writeln(headers.join(';'));
      csv.writeln(row.join(';'));

      final bytes = utf8.encode(csv.toString());

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'sinistro_${_currentClaim.numeroSinistro}.csv',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar Excel: $e')),
      );
    }
  }

  // Etapa 02: o encerramento mostra o resumo dos lançamentos em vez de pedir
  // um valor digitado. Sem nenhum valor lançado, não encerra — oferece lançar.
  Future<void> _showConfirmCloseDialog() async {
    final resumo = _currentClaim.resumoValores;
    final total = _currentClaim.valorTotalCalculado;

    if (total <= 0) {
      final lancar = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Encerrar sinistro'),
          content: const Text(
            'Este sinistro ainda não tem nenhum valor lançado. '
            'Para encerrar, registre ao menos um lançamento (ex.: reparo, peças ou indenização).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Novo lançamento'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      );
      if (lancar == true && mounted) {
        await mostrarDialogoNovoLancamento(
          context,
          claim: _currentClaim,
          usuarioNome: _nomeUsuarioLogado,
          usuarioEmail: _authService.getUserEmail(),
        );
      }
      return;
    }

    final semHistorico = _currentClaim.lancamentos.isEmpty;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Encerramento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (semHistorico)
              Text('Valor registrado antes do histórico: ${formatarMoedaLancamento(total)}')
            else ...[
              Text('Segurado: ${formatarMoedaLancamento(resumo.segurado)}'),
              Text('Terceiros: ${formatarMoedaLancamento(resumo.terceiros)}'),
              const SizedBox(height: 4),
              Text(
                'Total: ${formatarMoedaLancamento(total)} (${resumo.ativos} lançamento(s))',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Confira os valores em "Valores do Sinistro" antes de encerrar.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(false)),
          ElevatedButton(child: const Text('Confirmar e Encerrar'), onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    // Etapa 14: tarefas abertas do sinistro (o funcionário escolhe quais concluir).
    final seguir = await confirmarTarefasAoEncerrar(context, claimId: _currentClaim.id, rotulo: 'sinistro');
    if (!seguir || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _firestoreService.atualizarRecomendacaoManutencao(_currentClaim.idCliente);
      await _updateStatus('Concluído');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao encerrar sinistro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showImageViewer(ImageProvider imageProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Container(
              color: Colors.black,
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddThirdPartyDialog() async {
    final _thirdPartyFormKey = GlobalKey<FormState>();
    final ImagePicker _picker = ImagePicker();

    // Etapa 02: campos agrupados (proprietário / motorista / contato / sinistro)
    final _tp = TerceiroFormControllers.novo();

    final List<XFile> _thirdPartyPhotos = [];
    final List<XFile> _thirdPartyDocuments = [];

    final novoTerceiro = await showDialog<ThirdParty>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Adicionar Terceiro',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 20),
                      Form(
                        key: _thirdPartyFormKey,
                        child: Column(
                          children: [
                            TerceiroIdentificacaoForm(
                              controllers: _tp,
                              onBuscarEndereco: () =>
                                  _openPlaceSearchTerceiro('Endereço do Terceiro', _tp.endereco),
                            ),
                            const SizedBox(height: 16),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Fotos do Veículo', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ..._thirdPartyPhotos.map((photo) => Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        final ImageProvider imageProvider = kIsWeb
                                            ? NetworkImage(photo.path)
                                            : FileImage(File(photo.path));
                                        _showImageViewer(imageProvider);
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: kIsWeb
                                            ? Image.network(
                                          photo.path,
                                          width: 160,
                                          height: 160,
                                          fit: BoxFit.cover,
                                        )
                                            : Image.file(
                                          File(photo.path),
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          _thirdPartyPhotos.remove(photo);
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ],
                                )),
                                InkWell(
                                  onTap: () async {
                                    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
                                    if (pickedFiles != null && pickedFiles.isNotEmpty) {
                                      final compressedFiles = await ImageService().compressImages(pickedFiles);
                                      setModalState(() {
                                        _thirdPartyPhotos.addAll(compressedFiles);
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.add_a_photo),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Arquivos/Laudos (PDF, etc.)',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                ..._thirdPartyDocuments.map((file) => Chip(
                                  label: Text(file.name),
                                  onDeleted: () {
                                    setModalState(() {
                                      _thirdPartyDocuments.remove(file);
                                    });
                                  },
                                )).toList(),
                                ActionChip(
                                  avatar: const Icon(Icons.attach_file),
                                  label: const Text('Adicionar Arquivo'),
                                  onPressed: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      allowMultiple: true,
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                                    );
                                    if (result != null && result.files.isNotEmpty) {
                                      final xFiles = result.files.map((pf) => XFile(pf.path!, name: pf.name)).toList();
                                      setModalState(() {
                                        _thirdPartyDocuments.addAll(xFiles);
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            child: const Text('Adicionar'),
                            onPressed: () async {
                              if (_thirdPartyFormKey.currentState!.validate()) {
                                // Mostra loading
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const AlertDialog(
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Fazendo upload dos arquivos...'),
                                      ],
                                    ),
                                  ),
                                );

                                try {
                                  // ✅ 1. Upload de fotos
                                  List<String> fotoUrls = [];
                                  if (_thirdPartyPhotos.isNotEmpty) {
                                    fotoUrls = await _firestoreService.uploadSinistroFotos(
                                      _currentClaim.numeroSinistro,
                                      _thirdPartyPhotos,
                                    );
                                  }

                                  // ✅ 2. Upload de documentos - USANDO A NOVA FUNÇÃO
                                  List<String> documentoUrls = [];
                                  if (_thirdPartyDocuments.isNotEmpty) {
                                    final terceiroId = _tp.id;
                                    documentoUrls = await _firestoreService.uploadThirdPartyDocuments(
                                      _currentClaim.numeroSinistro,
                                      terceiroId,
                                      _thirdPartyDocuments,
                                    );
                                  }

                                  // Fechar diálogo de loading
                                  Navigator.of(context).pop();

                                  final novoTerceiro = _tp.montar(
                                    fotosUrls: fotoUrls,
                                    documentosUrls: documentoUrls,
                                  );
                                  
                                  Navigator.of(context).pop(novoTerceiro);
                                } catch (e) {
                                  // Fechar diálogo de loading em caso de erro
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro ao fazer upload: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          )
        );
      },
    );

    // ✅ Correção: Adiciona ao _currentClaim.terceiros
    if (novoTerceiro != null && mounted) {
      setState(() {
        _currentClaim.terceiros.add(novoTerceiro);
      });

      // ✅ Salva no Firestore
      try {
        final docRef = _firestoreService.getSinistrosCollection().doc(_currentClaim.id);
        await docRef.update({
          'terceiros': FieldValue.arrayUnion([novoTerceiro.toMap()]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terceiro adicionado com sucesso!')),
        );
      } catch (e) {
        // ✅ Remove do estado se falhar
        setState(() {
          _currentClaim.terceiros.remove(novoTerceiro);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar terceiro: $e')),
        );
      }
    }
  }

  // Busca lugar pelo autocomplete e retorna endereço de TERCEIRO
  Future<void> _openPlaceSearchTerceiro(String label, TextEditingController controller) async {
    final Place? place = await showSearch<Place?>(
      context: context,
      delegate: PlaceSearchDelegate(_places),
    );

    if (place != null) {
      setState(() {
        controller.text = place.address ?? place.name ?? '';
        
        // ✅ Extraia latitude e longitude diretamente
        if (place.latLng != null) {
          _enderecoTerceiroLatLng = LatLng(
            place.latLng!.lat,
            place.latLng!.lng,
          );
        }
      });
    }
  }

  Future<void> _showEditThirdPartyDialog(ThirdParty terceiro, int index) async {
    final _thirdPartyFormKey = GlobalKey<FormState>();
    final ImagePicker _picker = ImagePicker();

    // Etapa 02: campos agrupados (proprietário / motorista / contato / sinistro)
    final _tp = TerceiroFormControllers.de(terceiro);

    // Listas para gerenciar fotos e documentos
    List<XFile> _thirdPartyPhotos = [];
    List<PlatformFile> _thirdPartyDocuments = []; // Alterado para PlatformFile
    List<String> _photosToDelete = [];
    List<String> _documentsToDelete = [];

    // Variáveis para controle de carregamento
    bool _isLoadingPhotos = false;
    bool _isLoadingDocuments = false;

    // Função para carregar fotos existentes
    Future<void> _loadExistingPhotos() async {
      if (terceiro.fotosUrls != null && terceiro.fotosUrls!.isNotEmpty) {
        setState(() => _isLoadingPhotos = true);
        try {
          for (String url in terceiro.fotosUrls!) {
            // Para URLs, criamos XFile com a URL como path
            _thirdPartyPhotos.add(XFile(url, name: Uri.parse(url).pathSegments.last));
          }
        } catch (e) {
          print('Erro ao carregar fotos: $e');
        } finally {
          setState(() => _isLoadingPhotos = false);
        }
      }
    }

    // Função para carregar documentos existentes
    Future<void> _loadExistingDocuments() async {
      if (terceiro.documentosUrls != null && terceiro.documentosUrls!.isNotEmpty) {
        setState(() => _isLoadingDocuments = true);
        try {
          for (String url in terceiro.documentosUrls!) {
            // Cria PlatformFile fake para documentos existentes (apenas para exibição)
            _thirdPartyDocuments.add(PlatformFile(
              name: getFileNameFromUrl(url),
              size: 0,
              path: url, // Usa a URL como path para identificar como existente
            ));
          }
        } catch (e) {
          print('Erro ao carregar documentos: $e');
        } finally {
          setState(() => _isLoadingDocuments = false);
        }
      }
    }

    // Carregar dados iniciais
    await _loadExistingPhotos();
    await _loadExistingDocuments();

    final atualizado = await showDialog<ThirdParty>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Editar Terceiro',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_isLoadingPhotos || _isLoadingDocuments)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: CircularProgressIndicator(),
                        ),
                      
                      Form(
                        key: _thirdPartyFormKey,
                        child: Column(
                          children: [
                            TerceiroIdentificacaoForm(
                              controllers: _tp,
                              onBuscarEndereco: () =>
                                  _openPlaceSearchTerceiro('Endereço do Terceiro', _tp.endereco),
                            ),

                            const SizedBox(height: 20),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Fotos do Veículo',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Fotos existentes
                                ..._thirdPartyPhotos.map((photo) {
                                  final isUrl = photo.path.startsWith('http');
                                  return Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Colors.grey[200],
                                        ),
                                        child: isUrl
                                            ? Image.network(
                                                photo.path,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                              )
                                            : FutureBuilder<Uint8List>(
                                                future: photo.readAsBytes(),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData) {
                                                    return Image.memory(
                                                      snapshot.data!,
                                                      width: 80,
                                                      height: 80,
                                                      fit: BoxFit.cover,
                                                    );
                                                  } else if (snapshot.hasError) {
                                                    return const Icon(Icons.error);
                                                  } else {
                                                    return const CircularProgressIndicator();
                                                  }
                                                },
                                              ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          setModalState(() {
                                            if (isUrl) {
                                              _photosToDelete.add(photo.path);
                                            }
                                            _thirdPartyPhotos.remove(photo);
                                          });
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                                
                                // Botão para adicionar nova foto
                                InkWell(
                                  onTap: () async {
                                    final picked = await _picker.pickImage(source: ImageSource.gallery);
                                    if (picked != null) {
                                      setModalState(() {
                                        _thirdPartyPhotos.add(picked);
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo, size: 24),
                                        SizedBox(height: 4),
                                        Text('Adicionar', style: TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Seção de documentos
                            const SizedBox(height: 20),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Documentos/Laudos',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 8),
                            
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Documentos existentes
                                ..._thirdPartyDocuments.map((file) {
                                  final isUrl = file.path != null && file.path!.startsWith('http');
                                  return Chip(
                                    label: Text(
                                      file.name,
                                      style: TextStyle(
                                        color: isUrl ? Colors.blue : Colors.orange,
                                      ),
                                    ),
                                    deleteIcon: const Icon(Icons.close, size: 16),
                                    onDeleted: () {
                                      setModalState(() {
                                        if (isUrl) {
                                          _documentsToDelete.add(file.path!);
                                        }
                                        _thirdPartyDocuments.remove(file);
                                      });
                                    },
                                  );
                                }),
                                
                                // Botão para adicionar novo documento
                                ActionChip(
                                  avatar: const Icon(Icons.attach_file, size: 16),
                                  label: const Text('Adicionar Arquivo'),
                                  onPressed: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      allowMultiple: true,
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                                    );
                                    
                                    if (result != null && result.files.isNotEmpty) {
                                      setModalState(() {
                                        _thirdPartyDocuments.addAll(result.files);
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              if (_thirdPartyFormKey.currentState!.validate()) {
                                // Mostrar loading durante o upload
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const AlertDialog(
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 16),
                                        Text('Fazendo upload dos arquivos...'),
                                      ],
                                    ),
                                  ),
                                );

                                try {
                                  // Separar fotos novas das existentes
                                  List<XFile> newPhotos = _thirdPartyPhotos
                                      .where((photo) => !photo.path.startsWith('http'))
                                      .toList();
                                  
                                  // Separar documentos novos dos existentes
                                  List<PlatformFile> newDocuments = _thirdPartyDocuments
                                      .where((doc) => doc.path == null || !doc.path!.startsWith('http'))
                                      .toList();

                                  // Upload de novas fotos (usando a mesma função dos veículos segurados)
                                  List<String> newPhotoUrls = [];
                                  if (newPhotos.isNotEmpty) {
                                    newPhotoUrls = await _firestoreService.uploadSinistroFotos(
                                      _currentClaim.numeroSinistro,
                                      newPhotos,
                                    );
                                  }

                                  // Upload de novos documentos (usando a mesma função dos veículos segurados)
                                  List<String> newDocumentUrls = [];
                                  if (newDocuments.isNotEmpty) {
                                    newDocumentUrls = await _firestoreService.uploadArquivosLaudos(
                                      _currentClaim.numeroSinistro,
                                      newDocuments,
                                    );
                                  }

                                  // Combinar URLs existentes com novas URLs
                                  List<String> finalPhotoUrls = [
                                    ...terceiro.fotosUrls?.where((url) => !_photosToDelete.contains(url)) ?? [],
                                    ...newPhotoUrls
                                  ];
                                  
                                  List<String> finalDocumentUrls = [
                                    ...terceiro.documentosUrls?.where((url) => !_documentsToDelete.contains(url)) ?? [],
                                    ...newDocumentUrls
                                  ];

                                  // Fechar diálogo de loading
                                  Navigator.of(context).pop();

                                  final novoTerceiro = _tp.montar(
                                    fotosUrls: finalPhotoUrls,
                                    documentosUrls: finalDocumentUrls,
                                  );
                                  
                                  Navigator.of(context).pop(novoTerceiro);
                                } catch (e) {
                                  // Fechar diálogo de loading em caso de erro
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Erro ao fazer upload: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Salvar Alterações'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            )
            );
          },
        );
      },
    );

    if (atualizado != null && mounted) {
      setState(() {
        _currentClaim.terceiros[index] = atualizado;
      });
      
      // Atualizar no Firestore
      try {
        await _firestoreService.getSinistrosCollection()
            .doc(_currentClaim.id)
            .update({
              'terceiros': _currentClaim.terceiros.map((t) => t.toMap()).toList()
            });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terceiro atualizado com sucesso!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar terceiro: $e')),
        );
      }
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sair sem salvar?'),
          content: const Text('Você tem alterações não salvas. Deseja realmente sair?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sair'),
            ),
          ],
        );
      },
    ) ?? false; // Retorna false se o diálogo for fechado sem resposta
  }

  // WIDGET PARA FORMATAR O HEADER
  
  Widget _infoItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12), // 👈 IMPORTANTE
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          Text(
            value ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET PARA FORMATAR TERCEIROS

  // ── Etapa 04: campo do veículo segurado (leitura ou edição) ─────────────
  Widget _campoVeiculoSegurado(
    String label,
    String Function(Vehicle v) ler,
    void Function(Vehicle v, String valor) gravar, {
    List<TextInputFormatter>? formatters,
  }) {
    final v = _currentClaim.veiculoSelecionado;
    return buildEditableField(
      label: label,
      value: v == null ? '' : ler(v).trim(),
      inputFormatters: formatters,
      onChanged: (valor) {
        if (_currentClaim.veiculoSelecionado != null) gravar(_currentClaim.veiculoSelecionado!, valor);
      },
    );
  }

  // ── Etapa 02: abre nota fiscal / evidência de um lançamento ─────────────
  Future<void> _abrirAnexoLancamento(String url) async {
    final limpa = url.trim();
    if (await canLaunchUrlString(limpa)) {
      await launchUrlString(limpa, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o arquivo.')),
      );
    }
  }

  // ── Etapa 02: exibição do terceiro agrupada por personagem ──────────────
  Widget _telefoneComWhatsApp(String label, String telefone) {
    return Row(
      children: [
        Expanded(child: buildField(label, telefone)),
        if (telefone.replaceAll(RegExp(r'\D'), '').isNotEmpty)
          IconButton(
            tooltip: 'Abrir no WhatsApp',
            icon: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green.shade600, size: 16),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            onPressed: () async {
              final phone = telefone.replaceAll(RegExp(r'\D'), '');
              final url = 'https://wa.me/55$phone';
              if (await canLaunchUrlString(url)) {
                await launchUrlString(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
      ],
    );
  }

  List<Widget> _blocosIdentificacaoTerceiro(ThirdParty tp) {
    const roxo = Colors.deepPurple;
    final valorPago = _currentClaim.resumoValores.porTerceiro[tp.id] ?? 0.0;
    final qtdLancamentos = _currentClaim.lancamentos
        .where((l) => l.isAtivo && l.isTerceiro && tp.id.isNotEmpty && l.terceiroId == tp.id)
        .length;

    return [
      buildInfoCard(
        title: 'Proprietário do veículo (CRLV)',
        icon: Icons.badge_outlined,
        color: roxo,
        children: [
          Row(children: [
            Expanded(child: buildField('Nome', tp.nome)),
            Expanded(child: buildField('CPF / CNPJ', tp.cpf)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _telefoneComWhatsApp('Telefone', tp.contato)),
            Expanded(child: buildField('E-mail', tp.email)),
          ]),
          if (tp.enderecoTerceiro.isNotEmpty) ...[
            const SizedBox(height: 8),
            buildField('Endereço', tp.enderecoTerceiro),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: buildField('Placa', tp.placa)),
            Expanded(child: buildField('Chassi', tp.chassi)),
            Expanded(child: buildField('Cor', tp.cor)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: buildField('Marca', tp.marcaTerceiro)),
            Expanded(child: buildField('Modelo', tp.modeloTerceiro)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: buildField('Ano Fab.', tp.anoFabricacaoTerceiro)),
            Expanded(child: buildField('Ano Mod.', tp.anoModeloTerceiro)),
          ]),
          if (tp.numeroSinistroTerceiro.isNotEmpty) ...[
            const SizedBox(height: 8),
            buildField('Sinistro Terceiro', tp.numeroSinistroTerceiro),
          ],
        ],
      ),
      buildInfoCard(
        title: 'Motorista',
        icon: Icons.airline_seat_recline_normal,
        color: roxo,
        children: [
          if (tp.motoristaMesmoProprietario) ...[
            const SelectableText('O motorista é o próprio proprietário.', style: TextStyle(fontSize: 12)),
            if (tp.cnhMotorista.isNotEmpty) ...[
              const SizedBox(height: 8),
              buildField('CNH', tp.cnhMotorista),
            ],
          ] else if (!tp.temMotorista)
            SelectableText('Não informado.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          else ...[
            Row(children: [
              Expanded(child: buildField('Nome', tp.nomeMotorista)),
              Expanded(child: buildField('CPF', tp.cpfMotorista)),
              Expanded(child: buildField('CNH', tp.cnhMotorista)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _telefoneComWhatsApp('Telefone', tp.telefoneMotorista)),
              Expanded(child: buildField('E-mail', tp.emailMotorista)),
            ]),
          ],
        ],
      ),
      if ((tp.nomeContatoTerceiro ?? '').isNotEmpty || (tp.telefoneContatoTerceiro ?? '').isNotEmpty)
        buildInfoCard(
          title: 'Contato',
          icon: Icons.contact_phone_outlined,
          color: roxo,
          children: [
            Row(children: [
              Expanded(child: buildField('Nome', tp.nomeContatoTerceiro ?? '')),
              Expanded(child: _telefoneComWhatsApp('Telefone', tp.telefoneContatoTerceiro ?? '')),
            ]),
          ],
        ),
      if ((tp.registroSeguradoraTerceiro ?? '').isNotEmpty || tp.relato.isNotEmpty)
        buildInfoCard(
          title: 'Sinistro do terceiro',
          icon: Icons.description_outlined,
          color: roxo,
          children: [
            if ((tp.registroSeguradoraTerceiro ?? '').isNotEmpty) ...[
              const Text('Nº do registro na seguradora do terceiro',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              SelectableText(
                tp.registroSeguradoraTerceiro!,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, backgroundColor: Colors.yellow.shade100),
              ),
              const SizedBox(height: 8),
            ],
            if (tp.relato.isNotEmpty) buildField('Relato', tp.relato),
          ],
        ),
      buildInfoCard(
        title: 'Valores pagos a este terceiro',
        icon: Icons.payments_outlined,
        color: const Color(0xFF2E7D32),
        children: [
          SelectableText(
            qtdLancamentos == 0
                ? 'Nenhum lançamento para este terceiro. Use "Novo lançamento" em Valores do Sinistro.'
                : '${formatarMoedaLancamento(valorPago)} em $qtdLancamentos lançamento(s) — detalhes em Valores do Sinistro.',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ];
  }

  Widget buildRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: children
            .map((e) => Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: e,
                )))
            .toList(),
      ),
    );
  }

  // WIDGET PARA O NOVO LAYOUT DO HEADER

  Widget sectionContentWrapper(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  // WIDGET PARA PADRONIZAR O BOTÃO '+'

  String getFileNameFromUrl(String url) {
    try {
      final String path = url.split('?').first;
      final String rawName = path.split('/').last;
      final String decodedName = Uri.decodeComponent(rawName);
      return decodedName.trim().replaceAll(RegExp(r'\s+'), ' ');
    } catch (e) {
      final rawName = url.split('/').last.split('?').first;
      return rawName.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Aberto': return Colors.red.shade400;
      case 'Vistoria em Andamento': return Colors.orange.shade400;
      case 'Aguardando Aprovação': return Colors.yellow.shade700;
      case 'Aguardando Peças': return Colors.blueGrey.shade400;
      case 'Reparo em Andamento': return Colors.blue.shade400;
      case 'Concluído': return const Color(0xFF6366F1);
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Aberto': return Icons.event;
      case 'Vistoria em Andamento': return Icons.search;
      case 'Aguardando Aprovação': return Icons.pending_actions;
      case 'Aguardando Peças': return Icons.widgets;
      case 'Reparo em Andamento': return Icons.build;
      case 'Concluído': return Icons.check_circle;
      default: return Icons.info_outline;
    }
  }

  Widget buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              SelectableText(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        SelectableText(
          value.isEmpty ? '-' : value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // Widget para editar os campos

  Widget buildEditableField({
    required String label,
    required String? value,
    required Function(String) onChanged,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    if (_isEditing) {
      return TextFormField(
        initialValue: value ?? '',
        maxLines: maxLines,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: Colors.amber.withOpacity(0.12), // 👈 leve destaque
        ),
        onChanged: onChanged,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
        SelectableText(
          (value == null || value.isEmpty) ? '-' : value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // 🆕 Widget para dropdown de ramo (com todas as opções)
  Widget buildEditableRamoDropdown({
    required String? value,
    required Function(String) onChanged,
  }) {
    const ramoOptions = [
      'Frota',
      'Veículo Individual',
      'Transporte',
      'Civil Ônibus (RCO)',
      'Residencial',
      'Empresarial',
      'Vidas',
      'Máquinas',
    ];

    if (_isEditing) {
      return DropdownButtonFormField<String>(
        value: value ?? 'Frota',
        decoration: const InputDecoration(
          labelText: 'Ramo',
          isDense: true,
          filled: true,
          fillColor: Color.fromARGB(255, 255, 205, 86),
          border: OutlineInputBorder(),
        ),
        items: ramoOptions.map((ramo) {
          return DropdownMenuItem(
            value: ramo,
            child: Text(ramo),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) {
            onChanged(v);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ramo',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        SelectableText(
          value ?? 'Frota',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value, {bool isPhone = false, bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? Colors.yellow.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: highlighted ? Border.all(color: Colors.yellow.shade300) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlighted ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          SelectableText(
            value,
            style: TextStyle(fontSize: 12, color: highlighted ? Colors.black : Colors.black87),
          ),
          if (isPhone) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: () async {
                final uri = Uri(scheme: 'tel', path: value.replaceAll(RegExp(r'\D'), ''));
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              child: const Icon(Icons.phone, color: Colors.green, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. Função para limpar strings (agora segura)
    String clean(String? s) => (s ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

    // ✅ 2. Valores limpos para uso em URLs
    final seguradora = clean(_currentClaim.seguradora);
    final reguladora = clean(_currentClaim.transporte?.reguladora) ?? 'Não informado';
    final nomeMotorista = clean(_currentClaim.transporte?.nomeMotorista) ?? 'Não informado';
    final ramo = _currentClaim.ramoSinistro ?? 'Frota';
    bool isTransporte = ramo == 'Transporte';
    bool isVeiculo = ramo == 'Frota' || ramo == 'Veículo Individual' || ramo == 'Civil Ônibus (RCO)';
    bool isResidencial = ramo == 'Residencial';
    bool isVida = ramo == 'Vidas';
    bool isMaquinas = ramo == 'Máquinas';
    bool isEmpresarial = ramo == 'Empresarial';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Detalhes do Sinistro'),
        actions: [
          if (!_isEditing && _authService.getUserId() != 'anonymous_user')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = true;
                });
              },
              tooltip: 'Editar',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: 'Salvar',
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _relatoController.text = widget.claim.relatoEvento;
                  _localController.text = widget.claim.localOcorrencia;
                  _numeroSinistroController.text = widget.claim.numeroSinistro;
                  _numeroSeguradoraController.text = widget.claim.numeroSeguradora;
                });
              },
              tooltip: 'Cancelar',
            ),
        ],
      ),

      body: WillPopScope(
        onWillPop: () async {
          if (_isEditing) {
            final shouldPop = await _showExitConfirmationDialog();
            return shouldPop;
          }
          return true;
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isLargeScreen = constraints.maxWidth > 600;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Align(
                      alignment: isLargeScreen ? Alignment.centerLeft : Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isLargeScreen ? 800 : double.infinity),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,  // ✨ ADICIONE ESTA LINHA
                          children: [
                            SectionCard(
                              title: 'Sinistro',
                              icon: Icons.description_outlined,
                              color: const Color(0xFF1565C0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 🔵 HEADER
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey.shade200),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(_currentClaim.statusAtual).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _currentClaim.statusAtual,
                                                style: TextStyle(
                                                  color: _getStatusColor(_currentClaim.statusAtual),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          _currentClaim.clientNome,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // LINHA 1
                                           Container(
                                              width: double.infinity,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: buildEditableField(
                                                      label: 'Data Ocorrência',
                                                      value: DateFormat('dd/MM/yyyy').format(_currentClaim.dataOcorrencia),
                                                      onChanged: (v) {},
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: buildEditableField(
                                                      label: 'Hora Ocorrência',
                                                      value: _currentClaim.horaOcorrencia ?? '',
                                                      onChanged: (v) => _currentClaim.horaOcorrencia = v,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: buildEditableField(
                                                      label: 'Data Aviso',
                                                      value: _currentClaim.dataAviso != null
                                                          ? DateFormat('dd/MM/yyyy').format(_currentClaim.dataAviso!)
                                                          : '',
                                                      onChanged: (v) {},
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            // LINHA 2
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Seguradora',
                                                    value: _currentClaim.seguradora,
                                                    onChanged: (v) => _currentClaim.seguradora = v,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Registro da Seguradora',
                                                    value: _currentClaim.numeroSeguradora,
                                                    onChanged: (v) => _currentClaim.numeroSeguradora = v,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Reguladora',
                                                    value: _currentClaim.transporte?.reguladora,
                                                    onChanged: (v) {
                                                      if (_currentClaim.transporte != null) {
                                                        _currentClaim.transporte!.reguladora = v;
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // LINHA 3
                                            buildEditableField(
                                              label: 'Endereço',
                                              value: _currentClaim.localOcorrencia,
                                              onChanged: (v) => _currentClaim.localOcorrencia = v,
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  // Etapa 02: o total é a soma dos lançamentos (segurado +
                                                  // terceiros) — não se digita mais aqui. Ver "Valores do Sinistro".
                                                  child: Tooltip(
                                                    message: 'Soma dos lançamentos. Para alterar, use "Novo lançamento" em Valores do Sinistro.',
                                                    child: buildField(
                                                      'Valor Total do Sinistro',
                                                      formatarMoedaLancamento(_currentClaim.valorTotalCalculado),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _isEditing
                                                      ? GestureDetector(
                                                          onTap: () async {
                                                            final picked = await showDatePicker(
                                                              context: context,
                                                              initialDate: _currentClaim.slaPrevisto ?? DateTime.now(),
                                                              firstDate: DateTime.now(),
                                                              lastDate: DateTime(2100),
                                                            );
                                                            if (picked != null) {
                                                              setState(() {
                                                                _currentClaim.slaPrevisto = picked;
                                                                _slaPrevistController.text =
                                                                    DateFormat('dd/MM/yyyy').format(picked);
                                                              });
                                                            }
                                                          },
                                                          child: TextFormField(
                                                            controller: _slaPrevistController,
                                                            enabled: false,
                                                            decoration: const InputDecoration(
                                                              labelText: 'Tempo Previsto',
                                                              suffixIcon: Icon(Icons.calendar_today),
                                                              isDense: true,
                                                              filled: true,
                                                            ),
                                                          ),
                                                        )
                                                      : _buildTempoPrevisto(),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // 👤 VIDA
                                  if (isVida && _currentClaim.life != null) ...[
                                    buildInfoCard(
                                      title: 'Dados do Segurado',
                                      icon: Icons.person_outlined,
                                      color: const Color(0xFF6A1B9A),
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Nome do Segurado',
                                                value: clean(_currentClaim.life?.nomeSegurado),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.life = _currentClaim.life?.copyWith(
                                                      nomeSegurado: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'CPF',
                                                value: clean(_currentClaim.life?.cpfSegurado),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.life = _currentClaim.life?.copyWith(
                                                      cpfSegurado: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Idade',
                                                value: _currentClaim.life?.idadeSegurado.toString() ?? '',
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.life = _currentClaim.life?.copyWith(
                                                      idadeSegurado: int.tryParse(v) ?? 0,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Parentesco',
                                                value: clean(_currentClaim.life?.parentesco),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.life = _currentClaim.life?.copyWith(
                                                      parentesco: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        buildEditableField(
                                          label: 'Causa da Morte',
                                          value: clean(_currentClaim.life?.causaMorte),
                                          onChanged: (v) {
                                            setState(() {
                                              _currentClaim.life = _currentClaim.life?.copyWith(
                                                causaMorte: v,
                                              );
                                            });
                                          },
                                          maxLines: 3,
                                        ),
                                      ],
                                    ),
                                  ],

                                  // 🏠 RESIDENCIAL
                                  if (isResidencial && _currentClaim.house != null) ...[
                                    buildInfoCard(
                                      title: 'Dados do Imóvel',
                                      icon: Icons.home_outlined,
                                      color: const Color(0xFFBF360C),
                                      children: [
                                        buildEditableField(
                                          label: 'Endereço',
                                          value: clean(_currentClaim.house?.localHouse),
                                          onChanged: (v) {
                                            setState(() {
                                              _currentClaim.house = _currentClaim.house?.copyWith(
                                                localHouse: v,
                                              );
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Tipo de Imóvel',
                                                value: clean(_currentClaim.house?.tipoImovel),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.house = _currentClaim.house?.copyWith(
                                                      tipoImovel: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Valor do Imóvel (R\$)',
                                                value: _currentClaim.house?.valorImovel != null
                                                    ? _currentClaim.house!.valorImovel.toString()
                                                    : '',
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.house = _currentClaim.house?.copyWith(
                                                      valorImovel: double.tryParse(v),
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],

                                  // 🏢 EMPRESARIAL
                                  if (isEmpresarial && _currentClaim.business != null) ...[
                                    buildInfoCard(
                                      title: 'Dados da Empresa',
                                      icon: Icons.business_outlined,
                                      color: const Color(0xFF424242),
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Nome da Empresa',
                                                value: clean(_currentClaim.business?.nomeEmpresa),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      nomeEmpresa: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'CNPJ',
                                                value: clean(_currentClaim.business?.cnpjEmpresa),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      cnpjEmpresa: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        buildEditableField(
                                          label: 'Endereço',
                                          value: clean(_currentClaim.business?.enderecoEmpresa),
                                          onChanged: (v) {
                                            setState(() {
                                              _currentClaim.business = _currentClaim.business?.copyWith(
                                                enderecoEmpresa: v,
                                              );
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Ramo de Atividade',
                                                value: clean(_currentClaim.business?.ramoAtividade),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      ramoAtividade: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Área (m²)',
                                                value: _currentClaim.business?.areaM2 != null
                                                    ? _currentClaim.business!.areaM2.toString()
                                                    : '',
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      areaM2: double.tryParse(v),
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Tipo de Estrutura',
                                                value: clean(_currentClaim.business?.tipoEstrutura),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      tipoEstrutura: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Número de Andares',
                                                value: _currentClaim.business?.numeroAndares != null
                                                    ? _currentClaim.business!.numeroAndares.toString()
                                                    : '',
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      numeroAndares: int.tryParse(v),
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Sistema de Segurança',
                                                value: clean(_currentClaim.business?.sistemaSeguranca),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      sistemaSeguranca: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Situação (Próprio/Alugado)',
                                                value: clean(_currentClaim.business?.situacaoImovel),
                                                onChanged: (v) {
                                                  setState(() {
                                                    _currentClaim.business = _currentClaim.business?.copyWith(
                                                      situacaoImovel: v,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],

                                  // 🚛 TRANSPORTE
                                  if (isTransporte && _currentClaim.transporte != null) ...[
                                    Column(
                                      children: [
                                        // Motorista
                                        buildInfoCard(
                                          title: 'Motorista',
                                          icon: Icons.person,
                                          color: Colors.blue,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Nome',
                                                    value: nomeMotorista,
                                                    onChanged: (v) {
                                                      _currentClaim.transporte!.nomeMotorista = v;
                                                    },
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'CPF',
                                                    value: clean(_currentClaim.transporte!.cpfMotorista),
                                                    onChanged: (v) {
                                                      _currentClaim.transporte!.cpfMotorista = v;
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Cavalo
                                        buildInfoCard(
                                          title: 'Cavalo',
                                          icon: Icons.local_shipping,
                                          color: Colors.green,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Placa',
                                                    value: clean(_currentClaim.transporte!.placaCavalo),
                                                    onChanged: (v) => _currentClaim.transporte!.placaCavalo = v,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Chassi',
                                                    value: clean(_currentClaim.transporte!.chassi),
                                                    onChanged: (v) => _currentClaim.transporte!.chassi = v,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Cor',
                                                    value: clean(_currentClaim.transporte!.cor),
                                                    onChanged: (v) => _currentClaim.transporte!.cor = v,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Ano',
                                                    value: '${_currentClaim.transporte!.ano ?? ''}',
                                                    onChanged: (v) =>
                                                        _currentClaim.transporte!.ano = int.tryParse(v) ?? 0,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Modelo',
                                                    value: '${_currentClaim.transporte!.anomodelo ?? ''}',
                                                    onChanged: (v) =>
                                                        _currentClaim.transporte!.anomodelo = int.tryParse(v) ?? 0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Carreta
                                        buildInfoCard(
                                          title: 'Carreta',
                                          icon: Icons.fire_truck,
                                          color: Colors.orange,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Placa',
                                                    value: clean(_currentClaim.transporte!.placaCarreta),
                                                    onChanged: (v) =>
                                                        _currentClaim.transporte!.placaCarreta = v,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Chassi',
                                                    value: clean(_currentClaim.transporte!.chassiCarreta),
                                                    onChanged: (v) =>
                                                        _currentClaim.transporte!.chassiCarreta = v,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Ano',
                                                    value: '${_currentClaim.transporte!.anoCarreta ?? ''}',
                                                    onChanged: (v) =>
                                                        _currentClaim.transporte!.anoCarreta = int.tryParse(v) ?? 0,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'Modelo',
                                                    value: '${_currentClaim.transporte!.anoModeloCarreta ?? ''}',
                                                    onChanged: (v) =>
                                                        _currentClaim.transporte!.anoModeloCarreta = int.tryParse(v) ?? 0,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        // Carga
                                        buildInfoCard(
                                          title: 'Carga',
                                          icon: Icons.inventory_2,
                                          color: Colors.purple,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'NFE',
                                                    value: clean(_currentClaim.transporte!.nfe),
                                                    onChanged: (v) => _currentClaim.transporte!.nfe = v,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: buildEditableField(
                                                    label: 'CTe',
                                                    value: clean(_currentClaim.transporte!.cte),
                                                    onChanged: (v) => _currentClaim.transporte!.cte = v,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            buildEditableField(
                                              label: 'Averbação',
                                              value: clean(_currentClaim.transporte!.numeroAverbacao),
                                              onChanged: (v) => _currentClaim.transporte!.numeroAverbacao = v,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ] else if (isVeiculo) ...[
                                    // 🚗 VEÍCULO
                                    // Etapa 04: espelha a abertura — Proprietário legal / Veículo /
                                    // Motorista / Contato do sinistro (mesmos ícones dos Terceiros).
                                    buildInfoCard(
                                      title: 'Proprietário legal (CRLV)',
                                      icon: Icons.badge_outlined,
                                      color: Colors.blueGrey,
                                      children: [
                                        Row(children: [
                                          Expanded(flex: 3, child: _campoVeiculoSegurado('Nome', (v) => v.nomeCondutor, (v, s) => v.nomeCondutor = s)),
                                          Expanded(flex: 2, child: _campoVeiculoSegurado('CPF / CNPJ', (v) => v.cpfCondutor, (v, s) => v.cpfCondutor = s,
                                              formatters: [BRFormatters.cpfCnpjFormatter])),
                                        ]),
                                      ],
                                    ),
                                    buildInfoCard(
                                      title: 'Veículo',
                                      icon: Icons.directions_car_outlined,
                                      color: Colors.blueGrey,
                                      children: [
                                        Row(children: [
                                          Expanded(child: _campoVeiculoSegurado('Placa', (v) => v.placa, (v, s) => v.placa = s)),
                                          Expanded(child: _campoVeiculoSegurado('Marca', (v) => v.marca, (v, s) => v.marca = s)),
                                          Expanded(child: _campoVeiculoSegurado('Modelo', (v) => v.modelo, (v, s) => v.modelo = s)),
                                        ]),
                                        const SizedBox(height: 8),
                                        Row(children: [
                                          Expanded(child: _campoVeiculoSegurado('Cor', (v) => v.cor, (v, s) => v.cor = s)),
                                          Expanded(flex: 2, child: _campoVeiculoSegurado('Chassi', (v) => v.chassi, (v, s) => v.chassi = s)),
                                        ]),
                                        const SizedBox(height: 8),
                                        Row(children: [
                                          Expanded(child: _campoVeiculoSegurado('Ano Fab.', (v) => v.ano > 0 ? '${v.ano}' : '',
                                              (v, s) => v.ano = int.tryParse(s) ?? 0)),
                                          Expanded(child: _campoVeiculoSegurado('Ano Mod.', (v) => v.anomodelo > 0 ? '${v.anomodelo}' : '',
                                              (v, s) => v.anomodelo = int.tryParse(s) ?? 0)),
                                        ]),
                                      ],
                                    ),
                                    buildInfoCard(
                                      title: 'Motorista',
                                      icon: Icons.airline_seat_recline_normal,
                                      color: Colors.blueGrey,
                                      children: [
                                        Row(children: [
                                          Expanded(flex: 2, child: _campoVeiculoSegurado('Condutor do Veículo', (v) => v.nomeCondutorMotorista,
                                              (v, s) => v.nomeCondutorMotorista = s)),
                                          Expanded(child: _campoVeiculoSegurado('CPF do Condutor', (v) => v.cpfCondutorMotorista,
                                              (v, s) => v.cpfCondutorMotorista = s, formatters: [BRFormatters.cpfCnpjFormatter])),
                                          Expanded(child: _campoVeiculoSegurado('CNH do Condutor', (v) => v.cnhCondutorMotorista,
                                              (v, s) => v.cnhCondutorMotorista = s, formatters: [FilteringTextInputFormatter.digitsOnly])),
                                        ]),
                                      ],
                                    ),
                                    buildInfoCard(
                                      title: 'Contato do sinistro',
                                      icon: Icons.contact_phone_outlined,
                                      color: Colors.blueGrey,
                                      children: [
                                        Row(children: [
                                          Expanded(
                                            child: buildEditableField(
                                              label: 'Nome do Contato do Sinistro',
                                              value: _currentClaim.nomeContatoSinistro ?? '',
                                              onChanged: (v) => _currentClaim.nomeContatoSinistro = v,
                                            ),
                                          ),
                                          Expanded(
                                            child: _isEditing
                                                ? buildEditableField(
                                                    label: 'Telefone de Contato',
                                                    value: _currentClaim.telefoneContatoSinistro ?? '',
                                                    onChanged: (v) => _currentClaim.telefoneContatoSinistro = v,
                                                    inputFormatters: [BRFormatters.telefoneFormatter],
                                                  )
                                                : _telefoneComWhatsApp('Telefone de Contato', _currentClaim.telefoneContatoSinistro ?? ''),
                                          ),
                                        ]),
                                      ],
                                    ),
                                  ],

                                  // 🔧 MÁQUINAS
                                  if (isMaquinas && _currentClaim.maquinaria != null) ...[
                                    buildInfoCard(
                                      title: 'Máquina e Equipamento',
                                      icon: Icons.settings_outlined,
                                      color: Colors.orange,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Descrição',
                                                value: clean(_currentClaim.maquinaria?.descricao),
                                                onChanged: (v) {
                                                  if (_currentClaim.maquinaria != null) {
                                                    _currentClaim.maquinaria!.descricao = v;
                                                  }
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Número de Série',
                                                value: clean(_currentClaim.maquinaria?.numeroSerie),
                                                onChanged: (v) {
                                                  if (_currentClaim.maquinaria != null) {
                                                    _currentClaim.maquinaria!.numeroSerie = v;
                                                  }
                                                },
                                              ),
                                            ),
                                            Expanded(
                                              child: buildEditableField(
                                                label: 'Modelo',
                                                value: clean(_currentClaim.maquinaria?.modelo),
                                                onChanged: (v) {
                                                  if (_currentClaim.maquinaria != null) {
                                                    _currentClaim.maquinaria!.modelo = v;
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        buildEditableField(
                                          label: 'Descrição do Sinistro',
                                          value: clean(_currentClaim.maquinaria?.descricaoSinistro),
                                          onChanged: (v) {
                                            if (_currentClaim.maquinaria != null) {
                                              _currentClaim.maquinaria!.descricaoSinistro = v;
                                            }
                                          },
                                          maxLines: 3,
                                        ),
                                      ],
                                    ),
                                  ],

                                  const SizedBox(height: 16),

                                  // 📝 RELATO
                                  SelectableText(
                                    'Relato do Evento:',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),

                                  if (_isEditing)
                                    TextFormField(
                                      enabled: _isEditing,
                                      controller: _relatoController,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        labelText: 'Relato do Evento',
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (value) {
                                        _currentClaim.relatoEvento = value;
                                      },
                                    )
                                  else
                                    SelectableText(_currentClaim.relatoEvento),

                                  const Divider(height: 30),

                                  // 👤 CLIENTE
                                  buildInfoCard(
                                    title: 'Cliente',
                                    icon: Icons.business,
                                    color: Colors.indigo,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: buildEditableField(
                                              label: 'Nome do Cliente',
                                              value: _client?.nome,
                                              onChanged: (v) {
                                                if (_client != null) {
                                                  _client!.nome = v;
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: buildEditableField(
                                              label: 'Telefone do Cliente',
                                              value: _client?.contato,
                                              onChanged: (v) {
                                                if (_client != null) {
                                                  _client!.contato = v;
                                                }
                                              },
                                            inputFormatters: [BRFormatters.telefoneFormatter],
                                            ),
                                          ),
                                          Expanded(
                                            child: buildEditableField(
                                              label: 'Email',
                                              value: _client?.email,
                                              onChanged: (v) {
                                                if (_client != null) {
                                                  _client!.email = v;
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Etapa 04: nos ramos de veículo o contato do sinistro aparece
                                      // em "Veículo Segurado → Contato do sinistro".
                                      if (!isVeiculo)
                                      Row(
                                        children: [
                                          Expanded(child: buildEditableField(label: 'Nome do Contato do Cliente', value: _currentClaim.nomeContatoSinistro ?? '', onChanged: (v) => _currentClaim.nomeContatoSinistro = v)),
                                          Expanded(
                                            child: buildEditableField(
                                              label: 'Telefone do Contato do Cliente',
                                              value: _currentClaim.telefoneContatoSinistro ?? '',
                                              onChanged: (v) => _currentClaim.telefoneContatoSinistro = v,
                                              inputFormatters: [BRFormatters.telefoneFormatter], // <-- ADICIONADO
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                            label: const Text('WhatsApp'),
                                            onPressed: () async {
                                              final phone = (_client?.contato ?? '').replaceAll(RegExp(r'\D'), '');
                                              final text = Uri.encodeFull(
                                                  'Atualização do sinistro número ${_currentClaim.numeroSinistro}');
                                              final url = 'https://wa.me/$phone?text=$text';
                                              if (await canLaunchUrlString(url)) {
                                                await launchUrlString(url, mode: LaunchMode.externalApplication);
                                              }
                                            },
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.email, color: Colors.redAccent),
                                            label: const Text('E-mail'),
                                            onPressed: () async {
                                              final email = _client?.email ?? '';
                                              final subject =
                                                  Uri.encodeFull('${_currentClaim.numeroSinistro} - Atualização de Status');
                                              final url = 'mailto:$email?subject=$subject';
                                              if (await canLaunchUrlString(url)) {
                                                await launchUrlString(url);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // 📸 FOTOS
                                  Text(
                                    'Fotos da Ocorrência:',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_currentClaim.fotosUrls.isNotEmpty) const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _currentClaim.fotosUrls.map((url) {
                                      final cleanedUrl = url.trim();
                                      return GestureDetector(
                                        onTap: () {
                                          showDialog(
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
                                                    top: 8,
                                                    right: 8,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.close, color: Colors.white),
                                                      onPressed: () => Navigator.of(context).pop(),
                                                    ),
                                                  ),
                                                  if (_isEditing)
                                                    Positioned(
                                                      top: 8,
                                                      left: 8,
                                                      child: IconButton(
                                                        icon: const Icon(Icons.delete, color: Colors.red),
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                          _removeFoto(url);
                                                        },
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            cleanedUrl,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_isEditing)
                                    ElevatedButton.icon(
                                      onPressed: _uploadFoto,
                                      icon: const Icon(Icons.add_a_photo),
                                      label: const Text('Adicionar Foto'),
                                    ),
                                  const SizedBox(height: 16),

                                  // 🎬 VÍDEOS — Etapa 12: tocam numa janela sobre esta tela.
                                  GaleriaVideosSinistro(
                                    documento: _currentClaim.id.isEmpty
                                        ? null
                                        : _firestoreService.getSinistrosCollection().doc(_currentClaim.id),
                                    numeroSinistro: _currentClaim.numeroSinistro,
                                    videos: _currentClaim.videos,
                                    limites: _limitesVideo,
                                    editando: _isEditing,
                                    enviadoPor: _nomeUsuarioLogado != 'Desconhecido'
                                        ? _nomeUsuarioLogado
                                        : _authService.getUserEmail(),
                                    onAlterado: (lista) => setState(() => _currentClaim.videos = lista),
                                  ),
                                  const SizedBox(height: 16),

                                  // 📎 ARQUIVOS
                                  Text(
                                    'Arquivos/Laudos:',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_currentClaim.arquivosLaudosUrls.isNotEmpty)
                                    ..._currentClaim.arquivosLaudosUrls.map((url) {
                                      final nomeArquivo = getFileNameFromUrl(url);
                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                                        title: Text(nomeArquivo),
                                        trailing: _isEditing
                                            ? IconButton(
                                                icon: const Icon(Icons.delete, color: Colors.red),
                                                onPressed: () => _removeDocumento(url),
                                              )
                                            : null,
                                        onTap: () async {
                                          final cleanedUrl = url.trim();
                                          try {
                                            if (await canLaunchUrlString(cleanedUrl)) {
                                              await launchUrlString(cleanedUrl, mode: LaunchMode.externalApplication);
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Não foi possível abrir o arquivo')),
                                              );
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Erro ao abrir arquivo: link inválido')),
                                            );
                                          }
                                        },
                                      );
                                    }),
                                  const SizedBox(height: 8),
                                  if (_isEditing)
                                    ElevatedButton.icon(
                                      onPressed: _uploadDocumento,
                                      icon: const Icon(Icons.attach_file),
                                      label: const Text('Anexar Documento'),
                                    ),
                                  const SizedBox(height: 16),
                                  if (_isEditing)
                                    ElevatedButton.icon(
                                      onPressed: _showAddThirdPartyDialog,
                                      icon: const Icon(Icons.person_add),
                                      label: const Text('Adicionar Terceiro'),
                                    ),
                                ],
                              ),
                            ),
                            // 👥 TERCEIROS
                            const Divider(height: 30),
                            SectionCard(
                              title: 'Terceiros Envolvidos',
                              icon: Icons.people_outline,
                              color: const Color(0xFF6A1B9A),
                              child: Column(
                                children: [
                                  if (_currentClaim.terceiros.isEmpty) ...[
                                    // ✨ MENSAGEM QUANDO VAZIO
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.person_add_outlined,
                                            size: 48,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Nenhum terceiro adicionado',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          if (_isEditing) ...[
                                            const SizedBox(height: 16),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: _showAddThirdPartyDialog,
                                              icon: const Icon(Icons.person_add),
                                              label: const Text('Adicionar Terceiro'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    // ✨ LISTA DE TERCEIROS
                                    ..._currentClaim.terceiros.map((tp) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.grey.shade200),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Row(
                                                children: [
                                                const Icon(Icons.person, size: 18, color: Colors.deepPurple),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: SelectableText(
                                                    tp.nome,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                if (_isEditing) ...[
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 18),
                                                    onPressed: () => _showEditThirdPartyDialog(
                                                      tp,
                                                      _currentClaim.terceiros.indexOf(tp),
                                                    ),
                                                  ),
                                                  // ✨ BOTÃO DE DELETE
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                    onPressed: () => _showDeleteTerceiroConfirmation(
                                                      tp,
                                                      _currentClaim.terceiros.indexOf(tp),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                              ),
                                            ),
                                            const Divider(height: 1),
                                            Padding(
                                              padding: const EdgeInsets.all(12.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // ── Etapa 02: proprietário / motorista / contato / sinistro / valores ──
                                                  ..._blocosIdentificacaoTerceiro(tp),
                                                  const SizedBox(height: 8),
                                                  // ✨ CONTATO DO TERCEIRO
/*
                                                  if ((tp.nomeContatoTerceiro?.isNotEmpty ?? false) ||
                                                    (tp.telefoneContatoTerceiro?.isNotEmpty ?? false) ||
                                                    (tp.registroSeguradoraTerceiro?.isNotEmpty ?? false)) ...[
                                                    const Divider(),
                                                    const SizedBox(height: 8),
                                                    const SelectableText(
                                                      'Contato do Terceiro:',
                                                      style: TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    if (tp.nomeContatoTerceiro?.isNotEmpty ?? false)
                                                      SelectableText('Nome Contato: ${tp.nomeContatoTerceiro}'),
                                                    if (tp.telefoneContatoTerceiro?.isNotEmpty ?? false)
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: SelectableText(
                                                              'Telefone Contato: ${tp.telefoneContatoTerceiro}',
                                                            ),
                                                          ),
                                                          IconButton(
                                                            icon: const Icon(Icons.phone, color: Colors.green),
                                                            onPressed: () async {
                                                              final uri = Uri(
                                                                scheme: 'tel',
                                                                path: tp.telefoneContatoTerceiro!,
                                                              );
                                                              if (await canLaunchUrl(uri)) {
                                                                await launchUrl(uri);
                                                              }
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                    if (tp.registroSeguradoraTerceiro?.isNotEmpty ?? false)
                                                      SelectableText(
                                                        'Registro Seguradora: ${tp.registroSeguradoraTerceiro}',
                                                      ),
                                                  ],
*/
                                                  const SizedBox(height: 8),
                                                  if (tp.fotosUrls != null && tp.fotosUrls!.isNotEmpty) ...[
                                                    Text(
                                                      'Fotos do veículo:',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(fontWeight: FontWeight.bold),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children: tp.fotosUrls!.map((url) {
                                                        final cleanedUrl = url.trim();
                                                        return GestureDetector(
                                                          onTap: () {
                                                            _showImageViewer(NetworkImage(cleanedUrl));
                                                          },
                                                          child: ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: Image.network(
                                                              cleanedUrl,
                                                              width: 100,
                                                              height: 100,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ],
                                                  if (tp.documentosUrls != null && tp.documentosUrls!.isNotEmpty) ...[
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Documentos:',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(fontWeight: FontWeight.bold),
                                                    ),
                                                    ...tp.documentosUrls!.map((url) => ListTile(
                                                      contentPadding: EdgeInsets.zero,
                                                      leading: const Icon(Icons.insert_drive_file, color: Colors.blue),
                                                      title: Text(getFileNameFromUrl(url)),
                                                      onTap: () async {
                                                        final cleanedUrl = url.trim();
                                                        if (await canLaunchUrlString(cleanedUrl)) {
                                                          await launchUrlString(
                                                            cleanedUrl,
                                                            mode: LaunchMode.externalApplication,
                                                          );
                                                        }
                                                      },
                                                    )),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )),
                                    const SizedBox(height: 8),
                                    if (_isEditing)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: _showAddThirdPartyDialog,
                                        icon: const Icon(Icons.person_add),
                                        label: const Text('Adicionar Terceiro'),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                            // 💰 VALORES DO SINISTRO (Etapa 02)
                            const Divider(height: 30),
                            SectionCard(
                              title: 'Valores do Sinistro',
                              icon: Icons.payments_outlined,
                              color: const Color(0xFF2E7D32),
                              child: LancamentosSinistroCard(
                                claim: _currentClaim,
                                usuarioNome: _nomeUsuarioLogado,
                                usuarioEmail: _authService.getUserEmail(),
                                onAbrirAnexo: _abrirAnexoLancamento,
                              ),
                            ),
                            // 🔴 DANOS CORPORAIS
                            if (_currentClaim.danoscorporais.isNotEmpty) ...[
                              const Divider(height: 30),
                              SectionCard(
                                title: 'Danos Corporais',
                                icon: Icons.medical_information_outlined,
                                color: const Color(0xFFD32F2F),
                                child: Column(
                                  children: [
                                    ..._currentClaim.danoscorporais.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final dano = entry.value;
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Dano Corporal ${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFD32F2F),
                                                  ),
                                                ),
                                                if (_isEditing)
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                    onPressed: () {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Edição indisponível nesta tela')),
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                            
                                            // Dados
                                            if (dano.nome.isNotEmpty)
                                              SelectableText(
                                                'Nome: ${dano.nome}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.cpfCnpj.isNotEmpty)
                                              SelectableText(
                                                'CPF/CNPJ: ${dano.cpfCnpj}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.telefone.isNotEmpty)
                                              SelectableText(
                                                'Telefone: ${dano.telefone}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.email.isNotEmpty)
                                              SelectableText(
                                                'E-mail: ${dano.email}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.endereco.isNotEmpty)
                                              SelectableText(
                                                'Endereço: ${dano.endereco}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.numeroSinistro.isNotEmpty)
                                              SelectableText(
                                                'Nº Sinistro: ${dano.numeroSinistro}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.relato.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              SelectableText(
                                                'Relato: ${dano.relato}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                            
                                            // 🆕 FOTOS (com null check)
                                            if ((dano.fotosUrls?.isNotEmpty ?? false)) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                'Fotos',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  ...dano.fotosUrls!.map((url) {
                                                    return Container(
                                                      width: 60,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.grey.shade300),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (context) {
                                                                return Dialog(
                                                                  insetPadding: const EdgeInsets.all(10),
                                                                  child: InteractiveViewer(
                                                                    panEnabled: true,
                                                                    minScale: 0.5,
                                                                    maxScale: 4,
                                                                    child: Container(
                                                                      color: Colors.black,
                                                                      child: Image.network(
                                                                        url,
                                                                        fit: BoxFit.contain,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          },
                                                          child: Image.network(url, fit: BoxFit.cover),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ],
                            
                                            // 🆕 DOCUMENTOS (com null check)
                                            if ((dano.documentosUrls?.isNotEmpty ?? false)) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                'Documentos',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ...dano.documentosUrls!.map((url) {
                                                    final fileName = url.split('/').last;
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.description, size: 14, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              fileName,
                                                              style: const TextStyle(fontSize: 10),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                            
                            // 🟡 DANOS MATERIAIS
                            if (_currentClaim.danosmateriais.isNotEmpty) ...[
                              const Divider(height: 30),
                              SectionCard(
                                title: 'Danos Materiais',
                                icon: Icons.home_outlined,
                                color: const Color(0xFFF57F17),
                                child: Column(
                                  children: [
                                    ..._currentClaim.danosmateriais.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final dano = entry.value;
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Dano Material ${index + 1}',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFFF57F17),
                                                  ),
                                                ),
                                                if (_isEditing)
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                                                    onPressed: () {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Edição indisponível nesta tela')),
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                            
                                            // Dados
                                            if (dano.nome.isNotEmpty)
                                              SelectableText(
                                                'Nome: ${dano.nome}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.cpfCnpj.isNotEmpty)
                                              SelectableText(
                                                'CPF/CNPJ: ${dano.cpfCnpj}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.telefone.isNotEmpty)
                                              SelectableText(
                                                'Telefone: ${dano.telefone}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.email.isNotEmpty)
                                              SelectableText(
                                                'E-mail: ${dano.email}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.endereco.isNotEmpty)
                                              SelectableText(
                                                'Endereço: ${dano.endereco}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.numeroSinistro.isNotEmpty)
                                              SelectableText(
                                                'Nº Sinistro: ${dano.numeroSinistro}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.tipoPatrimonio.isNotEmpty)
                                              SelectableText(
                                                'Tipo de Patrimônio: ${dano.tipoPatrimonio}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.descricao.isNotEmpty)
                                              SelectableText(
                                                'Descrição: ${dano.descricao}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            if (dano.relato.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              SelectableText(
                                                'Relato: ${dano.relato}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                            ],
                            
                                            // 🆕 FOTOS (com null check)
                                            if ((dano.fotosUrls?.isNotEmpty ?? false)) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                'Fotos',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: [
                                                  ...dano.fotosUrls!.map((url) {
                                                    return Container(
                                                      width: 60,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: Colors.grey.shade300),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(4),
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            showDialog(
                                                              context: context,
                                                              builder: (context) {
                                                                return Dialog(
                                                                  insetPadding: const EdgeInsets.all(10),
                                                                  child: InteractiveViewer(
                                                                    panEnabled: true,
                                                                    minScale: 0.5,
                                                                    maxScale: 4,
                                                                    child: Container(
                                                                      color: Colors.black,
                                                                      child: Image.network(
                                                                        url,
                                                                        fit: BoxFit.contain,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          },
                                                          child: Image.network(url, fit: BoxFit.cover),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ],
                            
                                            // 🆕 DOCUMENTOS (com null check)
                                            if ((dano.documentosUrls?.isNotEmpty ?? false)) ...[
                                              const SizedBox(height: 12),
                                              Text(
                                                'Documentos',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  ...dano.documentosUrls!.map((url) {
                                                    final fileName = url.split('/').last;
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                                      child: Row(
                                                        children: [
                                                          const Icon(Icons.description, size: 14, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              fileName,
                                                              style: const TextStyle(fontSize: 10),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            // 📝 ANOTAÇÕES
                            SectionCard(
                              title: 'Anotações',
                              icon: Icons.note_alt_outlined,
                              color: Colors.grey,
                              child: _currentClaim.id != null
                                  ? NotesWidget(
                                      claimId: _currentClaim.id!,
                                      anotacoes: _currentClaim.anotacoes,
                                      isAdmin: _userRole == 'admin',
                                    )
                                  : const SelectableText("Carregando ID do sinistro..."),
                            ),
                            // ✅ TAREFAS
                            SectionCard(
                              title: 'Lista de Tarefas',
                              icon: Icons.checklist,
                              color: Colors.orange,
                              child: TaskListWidget(
                                numeroSinistro: _currentClaim.numeroSinistro.isNotEmpty
                                    ? _currentClaim.numeroSinistro
                                    : 'SEM_NUMERO',
                                clientId: _currentClaim.idCliente,
                                clientNome: _currentClaim.clientNome,
                                clientCnpjCpf: _currentClaim.clientCnpjCpf,
                                sinistroId: _currentClaim.id,
                              ),
                            ),
                            // 🔧 OFICINAS
                            SectionCard(
                              title: 'Oficinas Envolvidas',
                              icon: Icons.build,
                              color: Colors.blue,
                              child: WorkshopWidget(
                                claimId: _currentClaim.id!,
                                oficinas: _currentClaim.oficinas,
                                clientNome: '',
                                isEditing: _isEditing,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _generateAndSharePdf,
                              icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                              label: const Text('Gerar PDF', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                backgroundColor: Colors.blueAccent,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _generateExcel,
                              icon: const Icon(Icons.table_chart, color: Colors.white),
                              label: const Text('Gerar Excel', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                backgroundColor: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Atualizar Status',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _currentClaim.statusAtual,
                              decoration: const InputDecoration(
                                labelText: 'Novo Status',
                                border: OutlineInputBorder(),
                              ),
                              items: _statusOptions.map((status) =>
                                  DropdownMenuItem(value: status, child: Text(status))).toList(),
                              onChanged: (value) {
                                if (value != null && value != _currentClaim.statusAtual) {
                                  if (_isStatusExterno(value)) {
                                    _showStatusWithDeadlineDialog(value);
                                  } else if (value == 'Concluído') {
                                    _showConfirmCloseDialog();
                                  } else {
                                    _updateStatus(value);
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.edit_calendar, size: 16),
                                label: const Text('Atualizar previsão'),
                                onPressed: _showUpdateDeadlineOnlyDialog,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Histórico de Status',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_currentClaim.historicoStatus.isEmpty)
                              const Text('Nenhum histórico de status.')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _currentClaim.historicoStatus.length,
                                itemBuilder: (context, index) {
                                  final entry = _currentClaim.historicoStatus[index];
                                  final status = entry['status'] as String;
                                  final date = (entry['data'] as Timestamp).toDate();
                                  final registradoPor = entry['registrado_por'] as String?;
                                  final responsavel = registradoPor ?? (entry['responsavel'] as String? ?? 'N/A');
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                status,
                                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getStatusColor(status),
                                                ),
                                              ),
                                              Text(
                                                'Data: ${DateFormat('dd/MM/yyyy HH:mm').format(date)}',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              Text(
                                                'Responsável: $responsavel',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            if (_userRole == 'admin') ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _confirmDeleteClaim,
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text('Excluir Sinistro'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade100,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // Formatação de cor de SLA
  Widget _buildTempoPrevisto() {
    if (_currentClaim.slaPrevisto == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('Não definido'),
      );
    }

    final diasRestantes = _currentClaim.slaPrevisto!.difference(DateTime.now()).inDays;
    final dataFormatada = DateFormat('dd/MM/yyyy').format(_currentClaim.slaPrevisto!);

    Color textColor;
    if (diasRestantes < 0) {
      textColor = Colors.red;  // 🔴 Vencido
    } else if (diasRestantes <= 3) {
      textColor = Colors.orange;  // 🟠 Atenção
    } else {
      textColor = Colors.green;  // 🟢 OK
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        border: Border.all(color: textColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tempo Previsto', style: TextStyle(fontSize: 12, color: Colors.grey)),
          SizedBox(height: 4),
          Text(
            '$diasRestantes dias ($dataFormatada)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

}