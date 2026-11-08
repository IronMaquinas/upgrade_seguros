import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:upgrade_seguros/screens/assist_detail_screen.dart';
import 'package:upgrade_seguros/screens/client_form_screen.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import 'package:upgrade_seguros/services/image_service_web.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:upgrade_seguros/utils/gatilho.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrade_seguros/widgets/apolice_visualizacao_dialog.dart';
import 'package:upgrade_seguros/widgets/recomendacao_chip.dart';
import 'package:upgrade_seguros/services/recomendacao_service.dart';
import 'package:upgrade_seguros/utils/recomendacao_cliente.dart';
import 'package:uuid/uuid.dart';
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../models/apolice_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../screens/claim_detail_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
    final FirestoreService _firestoreService = FirestoreService();
    final AuthService _authService = AuthService(); // Instância do AuthService
    Client? _currentClient; // ✅ Declaração correta
    List<Claim> _clientClaims = [];
    bool _isLoading = true; // ✅ Declaração correta
    bool _isLoadingClaims = false;
    // Etapa 07: % padrão do gatilho (Configurações)
    double _percentualGatilho = GatilhoApolice.percentualPadraoInicial;
    bool _vigenciaFoiEditada = false;
    bool _isAdmin = false;
    late String _currentUserId; // Adicionado para armazenar o userId
    String? _errorMessage;

    List<Claim> _clientSinistros = [];
    List<Claim> _clientAssistencias = [];

    // Etapa 09: recomendação pela regra única (lib/utils/recomendacao_cliente.dart).
    ResultadoRecomendacao get _recomendacao =>
        recomendarCliente(_currentClient!, _clientSinistros, _percentualGatilho);

  int get _totalSinistros => _clientSinistros.length;
  int get _totalAssistencias => _clientAssistencias.length;
  double get _valorTotalSinistros => _clientSinistros.fold(0.0, (sum, c) => sum + c.valorTotalSinistro);

  double get _valorTotalApolices {
    return _currentClient?.apolices.fold<double>(
      0.0,
      (sum, a) => sum + a.valorApolice,
    ) ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getUserId(); // Obtém o userId na inicialização
    //_fetchClientClaims();
    _loadIsAdmin();
    _loadClient(); // ✅ Carrega do Firestore
    ConfigService().getPercentualGatilho().then((p) {
      if (mounted) setState(() => _percentualGatilho = p);
    });
  }

  void _loadIsAdmin() async {
    final result = await _authService.isAdmin();  // ajuste para como está no seu AuthService
    if (mounted) {
      setState(() {
        _isAdmin = result;
      });
    }
  }

  Future<void> _loadClient() async {
    try {
      final client = await _firestoreService.getClientById(widget.client.id);
      if (mounted && client != null) {
        setState(() {
          _currentClient = client;
          _errorMessage = null; // ✅ Limpa erro se sucesso
          _fetchClientClaims(); 
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar cliente: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar cliente: $e';
        });
        // ✅ Mostra o erro no build em vez de no initState
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // [apoliceId]: vindo do "Editar" da visualização da apólice (Etapa 08), o
  // cadastro já abre a edição dessa apólice.
  Future<void> _editClient({String? apoliceId}) async {
    print('Editando cliente: ${_currentClient!.id}');
    
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientFormScreen(clientToEdit: _currentClient!, editarApoliceId: apoliceId),
      ),
    );

    print('Retorno da edição: $updated');
    
    if (updated == true && mounted) {
      print('Recarregando dados do cliente...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente atualizado com sucesso')),
      );
      
      await _loadClient();
      await _fetchClientClaims();
      print('Dados recarregados com sucesso');
    }
  }

  Future<void> _fetchClientClaims() async {
    setState(() => _isLoadingClaims = true);

    try {
      final allClaims = await _firestoreService.getAllClaims();
      setState(() {
        _clientClaims = allClaims
            .where((claim) => claim.idCliente == _currentClient?.id)
            .toList();
        
        _clientSinistros = _clientClaims.where((c) => c.tipo == 'sinistro').toList();
        _clientAssistencias = _clientClaims.where((c) => c.tipo == 'assistencia').toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar histórico: $e')),
      );
    } finally {
      setState(() => _isLoadingClaims = false);
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

    Future<String?> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return null;

      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${const Uuid().v4()}.jpg';

      final compressed = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        targetPath,
        quality: 50,
      );
      if (compressed == null) return null;

      final ref = FirebaseStorage.instance
          .ref()
          .child('veiculos/${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(File(compressed.path));

      return await ref.getDownloadURL();
    } catch (e) {
      print('Erro ao enviar imagem: $e');
      return null;
    }
  }

  Future<void> _showEditVehicleBottomSheet(Vehicle vehicle) async {
    final marcaController = TextEditingController(text: vehicle.marca);
    final modeloController = TextEditingController(text: vehicle.modelo);
    final anoController = TextEditingController(text: vehicle.ano.toString());
    final anoModeloController = TextEditingController(text: vehicle.ano.toString());
    final placaController = TextEditingController(text: vehicle.placa);
    final chassiController = TextEditingController(text: vehicle.chassi);

    // ✅ Mantém as URLs existentes
    final List<String> _fotosUrls = List<String>.from(vehicle.fotosUrls ?? []);
    final List<XFile> _newPhotos = [];
    final ImagePicker _picker = ImagePicker();

    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Editar Veículo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(controller: marcaController, decoration: const InputDecoration(labelText: 'Marca')),
                  TextFormField(controller: modeloController, decoration: const InputDecoration(labelText: 'Modelo')),
                  TextFormField(controller: anoController, decoration: const InputDecoration(labelText: 'Ano'), keyboardType: TextInputType.number),
                  TextFormField(controller: anoModeloController, decoration: const InputDecoration(labelText: 'Ano Modelo'), keyboardType: TextInputType.number),
                  TextFormField(controller: placaController, decoration: const InputDecoration(labelText: 'Placa')),
                  TextFormField(controller: chassiController, decoration: const InputDecoration(labelText: 'Chassi')),
                  const SizedBox(height: 16),

                  // Seção de fotos
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Fotos do Veículo', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Fotos existentes
                      ..._fotosUrls.map((url) => GestureDetector(
                            onTap: () => _showImageViewer(NetworkImage(url)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover),
                            ),
                          )),

                      // Novas fotos
                      ..._newPhotos.map((photo) => Stack(
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
                                      ? Image.network(photo.path, width: 80, height: 80, fit: BoxFit.cover)
                                      : Image.file(File(photo.path), width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _newPhotos.remove(photo);
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

                      // Botão de adicionar
                      InkWell(
                        onTap: () async {
                          final picked = await _picker.pickImage(source: ImageSource.gallery);
                          if (picked != null) {
                            final compressedFiles = await ImageService().compressImages([picked]);
                            if (compressedFiles.isNotEmpty) {
                              setModalState(() {
                                _newPhotos.add(compressedFiles.first);
                              });
                            }
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      // ✅ Upload das novas fotos
                      if (_newPhotos.isNotEmpty) {
                        final newUrls = await _firestoreService.uploadVehiclePhotos(
                          _currentClient!.id,
                          placaController.text,
                          _newPhotos,
                        );
                        _fotosUrls.addAll(newUrls);
                      }

                      // ✅ Atualiza o veículo com as novas URLs
                      final updatedVehicle = Vehicle(
                        marca: marcaController.text,
                        modelo: modeloController.text,
                        ano: int.tryParse(anoController.text) ?? vehicle.ano,
                        anomodelo: int.tryParse(anoModeloController.text) ?? vehicle.ano,
                        placa: placaController.text,
                        chassi: chassiController.text,
                        fotosUrls: _fotosUrls,
                      );

                      // ✅ Atualiza no Firestore
                      await _firestoreService.updateClientVehicle(
                        _currentClient!.id,
                        placaController.text,
                        _fotosUrls,
                      );

                      Navigator.pop(context);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Veículo atualizado com sucesso!')),
                        );
                        // ✅ Recarrega o cliente para refletir as mudanças
                        _loadClient();
                      }
                    },
                    child: const Text('Salvar Alterações'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {

    if (_isLoading || _currentClient == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final recomendacao = _recomendacao;

    final client = _currentClient!;

    final valorTotalSinistros = _clientClaims.fold<double>(
      0.0,
      (sum, claim) => sum + claim.valorTotalSinistro,
    );
    final valorTotalSinistrosFormatado = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
        .format(valorTotalSinistros);

    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Detalhes do Cliente'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 600;
          return SingleChildScrollView(
            child: Align(
              alignment: isLargeScreen ? Alignment.centerLeft : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isLargeScreen ? 900 : double.infinity),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: isLargeScreen ? 4 : 0,
                        shape: isLargeScreen
                            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Cabeçalho ──
                              Text(
                                _currentClient!.nome,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),

                              // ── Informações (2 colunas) ──
                              if (isLargeScreen)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildInfoColumn(context)),
                                    const SizedBox(width: 24),
                                    Expanded(child: _buildInfoColumn2(context)),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    _buildInfoColumn(context),
                                    const SizedBox(height: 8),
                                    _buildInfoColumn2(context),
                                  ],
                                ),

                              // ── Totais e Recomendação ──
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildTotalCard(
                                    icon: Icons.assignment_outlined,
                                    label: 'Sinistros',
                                    value: _totalSinistros.toString(),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTotalCard(
                                    icon: Icons.emergency_share_outlined,
                                    label: 'Assistências',
                                    value: _totalAssistencias.toString(),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTotalCard(
                                    icon: Icons.attach_money,
                                    label: 'Acumulado dos Sinistros',
                                    value: BRFormatters.formatarMoeda(_valorTotalSinistros),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildTotalCard(
                                    icon: Icons.policy_outlined,
                                    label: 'Total das Apólices',
                                    value: BRFormatters.formatarMoeda(_valorTotalApolices),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Text('Recomendação: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  RecomendacaoChip(recomendacao.rotulo),
                                  const SizedBox(width: 12),
                                  // Etapa 09: de onde vem a recomendação (uso do gatilho ×
                                  // valor da apólice, ou falta de apólice vigente).
                                  Expanded(
                                    child: Text(
                                      recomendacao.explicacao,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // ── Seção de Apólices com estilo do ClientFormScreen ──────────────────────
                              if (_currentClient?.apolices.isNotEmpty ?? false)
                                _buildSectionCard(
                                  icon: Icons.description,
                                  title: 'Apólices por Ramo',
                                  children: [
                                    ..._currentClient!.apolices.map((apolice) {
                                      final emoji = _getEmojiRamo(apolice.ramo);
                                      final cor = _getCorRamo(apolice.ramo);
                                      
                                      // Etapa 08: clicar na apólice abre a visualização.
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () async {
                                          final editar = await mostrarApoliceVisualizacao(
                                            context,
                                            apolice: apolice,
                                            percentualGatilho: _percentualGatilho,
                                            emojiRamo: emoji,
                                          );
                                          if (editar && mounted) _editClient(apoliceId: apolice.id);
                                        },
                                        child: Container(
                                        margin: const EdgeInsets.only(bottom: 10),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey.shade200),
                                          borderRadius: BorderRadius.circular(12),
                                          color: Colors.white,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            // Cabeçalho colorido com ramo e número
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: cor.withOpacity(0.1),
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                                border: Border(bottom: BorderSide(color: cor.withOpacity(0.3))),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(emoji, style: const TextStyle(fontSize: 18)),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '${apolice.ramo} • ${apolice.numeroApolice}',
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 15,
                                                        color: cor,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Icon(Icons.visibility_outlined, size: 18, color: cor.withOpacity(0.7)),
                                                ],
                                              ),
                                            ),
                                            
                                            // Detalhes e bens segurados
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        apolice.seguradora,
                                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                                                      ),
                                                      const Spacer(),
                                                      Text(
                                                        BRFormatters.formatarMoeda(apolice.valorApolice),
                                                        style: TextStyle(fontSize: 13, color: cor, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${DateFormat('dd/MM/yyyy').format(apolice.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(apolice.dataFim)}',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                                  ),
                                                  // Etapa 07: gatilho do contrato ou calculado pelo % padrão
                                                  if (apolice.gatilhoEfetivo(_percentualGatilho) > 0)
                                                    Text(
                                                      apolice.gatilhoInformado
                                                          ? 'Gatilho: ${BRFormatters.formatarMoeda(apolice.valorGatilho)}'
                                                          : 'Gatilho: ${BRFormatters.formatarMoeda(apolice.gatilhoEfetivo(_percentualGatilho))} '
                                                              '(${GatilhoApolice.formatarPercentual(_percentualGatilho)}% — não informado no contrato)',
                                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                                                    ),
                                                  
                                                  // Lista de bens segurados (mesmo estilo que já existe)
                                                  if (apolice.bensSegurados.isNotEmpty) ...[
                                                    const Divider(height: 16, thickness: 0.5),
                                                    const Text(
                                                      'Bens Segurados',
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    ...apolice.bensSegurados.map((bem) => Padding(
                                                      padding: const EdgeInsets.only(bottom: 6),
                                                      child: Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade50,
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: Colors.grey.shade200),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            // Descrição e tipo
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    bem.descricao,
                                                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors.blue.shade50,
                                                                    borderRadius: BorderRadius.circular(12),
                                                                  ),
                                                                  child: Text(
                                                                    bem.tipo,
                                                                    style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                            // Detalhes do bem (placa, marca, modelo, etc.)
                                                            Wrap(
                                                              spacing: 4,
                                                              runSpacing: 2,
                                                              children: [
                                                                // ═══ VEÍCULO INDIVIDUAL / CIVIL ÔNIBUS ═══
                                                                if (bem.tipo == 'Veículo Individual' || bem.tipo == 'Civil Ônibus (RCO)') ...[
                                                                  if (bem.placa != null && bem.placa!.isNotEmpty)
                                                                    _buildDetailChip('Placa: ${bem.placa}'),
                                                                  if (bem.marca != null && bem.marca!.isNotEmpty)
                                                                    _buildDetailChip(bem.marca!),
                                                                  if (bem.modelo != null && bem.modelo!.isNotEmpty)
                                                                    _buildDetailChip(bem.modelo!),
                                                                  if (bem.ano != null && bem.ano! > 0)
                                                                    _buildDetailChip('${bem.ano}'),
                                                                  if (bem.anoModelo != null && bem.anoModelo! > 0)
                                                                    _buildDetailChip('${bem.anoModelo}'),
                                                                  if (bem.cor != null && bem.cor!.isNotEmpty)
                                                                    _buildDetailChip(bem.cor!),
                                                                  if (bem.proprietarioNome != null && bem.proprietarioNome!.isNotEmpty)
                                                                    _buildDetailChip('Prop.: ${bem.proprietarioNome}'),
                                                                ],
                                                                // ═══ FROTA ═══
                                                                if (bem.tipo == 'Frota') ...[
                                                                  if (bem.placaCavalo != null && bem.placaCavalo!.isNotEmpty)
                                                                    _buildDetailChip('Cavalo: ${bem.placaCavalo}'),
                                                                  if (bem.marcaCavalo != null && bem.marcaCavalo!.isNotEmpty)
                                                                    _buildDetailChip(bem.marcaCavalo!),
                                                                  if (bem.modeloCavalo != null && bem.modeloCavalo!.isNotEmpty)
                                                                    _buildDetailChip(bem.modeloCavalo!),
                                                                  if (bem.placaCarreta != null && bem.placaCarreta!.isNotEmpty)
                                                                    _buildDetailChip('Carreta: ${bem.placaCarreta}'),
                                                                  if (bem.marcaCarreta != null && bem.marcaCarreta!.isNotEmpty)
                                                                    _buildDetailChip(bem.marcaCarreta!),
                                                                  if (bem.modeloCarreta != null && bem.modeloCarreta!.isNotEmpty)
                                                                    _buildDetailChip(bem.modeloCarreta!),
                                                                ],
                                                                // ═══ MÁQUINAS ═══
                                                                if (bem.tipo == 'Máquinas') ...[
                                                                  if (bem.modeloEquipamento != null && bem.modeloEquipamento!.isNotEmpty)
                                                                    _buildDetailChip(bem.modeloEquipamento!),
                                                                  if (bem.numeroSerie != null && bem.numeroSerie!.isNotEmpty)
                                                                    _buildDetailChip('SN: ${bem.numeroSerie}'),
                                                                  if (bem.fabricante != null && bem.fabricante!.isNotEmpty)
                                                                    _buildDetailChip(bem.fabricante!),
                                                                ],
                                                                // ═══ RESIDENCIAL ═══
                                                                if (bem.tipo == 'Residencial') ...[
                                                                  if (bem.logradouro != null && bem.logradouro!.isNotEmpty)
                                                                    _buildDetailChip('${bem.logradouro}, ${bem.numero ?? ''}'),
                                                                  if (bem.bairro != null && bem.bairro!.isNotEmpty)
                                                                    _buildDetailChip(bem.bairro!),
                                                                  if (bem.cidade != null && bem.cidade!.isNotEmpty)
                                                                    _buildDetailChip(bem.cidade!),
                                                                  if (bem.numeroDocumento != null && bem.numeroDocumento!.isNotEmpty)
                                                                    _buildDetailChip('Doc: ${bem.numeroDocumento}'),
                                                                ],
                                                                // ═══ VIDA ═══
                                                                if (bem.tipo == 'Vida') ...[
                                                                  if (bem.cpfVida != null && bem.cpfVida!.isNotEmpty)
                                                                    _buildDetailChip('CPF: ${bem.cpfVida}'),
                                                                  if (bem.capitalSegurado != null && bem.capitalSegurado! > 0)
                                                                    _buildDetailChip('Capital: ${BRFormatters.formatarMoeda(bem.capitalSegurado!)}'),
                                                                ],
                                                                // ═══ EMPRESARIAL (com fallback) ═══
                                                                if (bem.tipo == 'Empresarial') ...[
                                                                  if (bem.nomeEmpresa != null && bem.nomeEmpresa!.isNotEmpty)
                                                                    _buildDetailChip(bem.nomeEmpresa!),
                                                                  if (bem.enderecoEmpresa != null && bem.enderecoEmpresa!.isNotEmpty)
                                                                    _buildDetailChip(bem.enderecoEmpresa!),
                                                                  // Fallback para businessData (bens antigos)
                                                                  if ((bem.nomeEmpresa == null || bem.nomeEmpresa!.isEmpty) && bem.businessData != null) ...[
                                                                    if (bem.businessData!.nomeEmpresa.isNotEmpty)
                                                                      _buildDetailChip(bem.businessData!.nomeEmpresa),
                                                                    if (bem.businessData!.enderecoEmpresa.isNotEmpty)
                                                                      _buildDetailChip(bem.businessData!.enderecoEmpresa),
                                                                  ],
                                                                ],
                                                                // Fallback genérico (caso não seja nenhum dos ramos acima)
                                                                if (!['Veículo Individual', 'Civil Ônibus (RCO)', 'Frota', 'Máquinas', 'Residencial', 'Vida', 'Empresarial'].contains(bem.tipo)) ...[
                                                                  if (bem.descricao.isNotEmpty)
                                                                    _buildDetailChip(bem.descricao),
                                                                ],
                                                              ],
                                                            ),
                                                            // Documentos anexos
                                                            if (bem.documentosUrls != null && bem.documentosUrls!.isNotEmpty) ...[
                                                              const SizedBox(height: 6),
                                                              Row(
                                                                children: [
                                                                  const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                                                                  const SizedBox(width: 4),
                                                                  Text('Documentos:',
                                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                                                                  const Spacer(),
                                                                  Text('${bem.documentosUrls!.length} arquivo(s)',
                                                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                                                ],
                                                              ),
                                                              const SizedBox(height: 4),
                                                              Wrap(
                                                                spacing: 4,
                                                                runSpacing: 4,
                                                                children: bem.documentosUrls!.map((url) {
                                                                  // Ícone baseado na extensão
                                                                  IconData icon = Icons.insert_drive_file;
                                                                  Color iconColor = Colors.grey.shade700;
                                                                  final ext = url.split('.').last.toLowerCase();
                                                                  if (ext == 'pdf') {
                                                                    icon = Icons.picture_as_pdf;
                                                                    iconColor = Colors.red;
                                                                  } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
                                                                    icon = Icons.image;
                                                                    iconColor = Colors.orange;
                                                                  } else if (['doc', 'docx'].contains(ext)) {
                                                                    icon = Icons.description;
                                                                    iconColor = Colors.blue;
                                                                  } else if (['xls', 'xlsx'].contains(ext)) {
                                                                    icon = Icons.table_chart;
                                                                    iconColor = Colors.green;
                                                                  }

                                                                  return GestureDetector(
                                                                    onTap: () {
                                                                      showDialog(
                                                                        context: context,
                                                                        builder: (_) => AlertDialog(
                                                                          title: const Text('Documento'),
                                                                          content: Text('Clique em "Abrir" para visualizar o documento:\n\n${url.split('/').last}'),
                                                                          actions: [
                                                                            TextButton(
                                                                              onPressed: () => Navigator.pop(context),
                                                                              child: const Text('Fechar'),
                                                                            ),
                                                                            TextButton(
                                                                              onPressed: () async {
                                                                                final Uri uri = Uri.parse(url);
                                                                                if (await canLaunchUrl(uri)) {
                                                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                                                } else {
                                                                                  await Clipboard.setData(ClipboardData(text: url));
                                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                                    const SnackBar(content: Text('Link copiado para a área de transferência')),
                                                                                  );
                                                                                }
                                                                                Navigator.pop(context);
                                                                              },
                                                                              child: const Text('Abrir'),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      );
                                                                    },
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors.grey.shade200,
                                                                        borderRadius: BorderRadius.circular(12),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                          Icon(icon, size: 12, color: iconColor),
                                                                          const SizedBox(width: 2),
                                                                          Text(
                                                                            url.split('/').last.split('?').first.substring(0, 10) + '…',
                                                                            style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    )),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              const SizedBox(height: 16),
                              if (_isAdmin)
                                SwitchListTile(
                                  title: const Text('Cliente ativo'),
                                  value: _currentClient!.isAtivo,
                                  onChanged: (value) async {
                                    setState(() {
                                      _currentClient?.isAtivo = value;
                                    });
                                    await _firestoreService.updateClient(_currentClient!, _currentUserId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Status atualizado para ${value ? 'Ativo' : 'Inativo'}')),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // ── Histórico de Sinistros ──────────────────────────────────────────
                      _buildSectionCard(
                        icon: Icons.assignment,
                        title: 'Histórico de Sinistros (${_clientSinistros.length})',
                        children: [
                          if (_isLoadingClaims)
                            const Center(child: CircularProgressIndicator())
                          else if (_clientSinistros.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Nenhum sinistro registrado para este cliente.',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: _clientSinistros.map((claim) => _buildClaimCard(claim)).toList(),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Histórico de Assistências ──────────────────────────────────────
                      _buildSectionCard(
                        icon: Icons.emergency_share_outlined,
                        title: 'Histórico de Assistências (${_clientAssistencias.length})',
                        children: [
                          if (_isLoadingClaims)
                            const Center(child: CircularProgressIndicator())
                          else if (_clientAssistencias.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Nenhuma assistência registrada para este cliente.',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: _clientAssistencias.map((claim) => _buildClaimCard(claim)).toList(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editClient, // ✅ Use o método já implementado
        label: const Text('Editar Cliente'),
        icon: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildClaimCard(Claim claim) {
    // 🔥 Cor baseada no status (igual ao que já existe)
    Color statusColor;
    if (claim.statusAtual == 'Concluído' || claim.statusAtual == 'Finalizado') {
      statusColor = Colors.green;
    } else if (claim.statusAtual == 'Aguardando Peças' || 
              claim.statusAtual == 'Aguardando Aprovação' ||
              claim.statusAtual == 'Em Análise') {
      statusColor = Colors.orange;
    } else if (claim.statusAtual == 'Cancelado' || claim.statusAtual == 'Recusado') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.blue;
    }

    // 🔥 Ícone diferente para assistências
    final icon = claim.tipo == 'assistencia' ? Icons.emergency_share_outlined : Icons.assignment;

    return GestureDetector(
      onTap: () {
        if (claim.tipo == 'assistencia') {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AssistDetailScreen(assistId: claim.id),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ClaimDetailScreen(claim: claim),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho com número e status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.3))),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      claim.numeroSinistro,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      claim.statusAtual,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Detalhes do claim
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        'Data: ${DateFormat('dd/MM/yyyy').format(claim.dataOcorrencia)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      const Spacer(),
                      if (claim.tipo == 'sinistro')
                        Text(
                          BRFormatters.formatarMoeda(claim.valorTotalSinistro),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor),
                        )
                      else
                        Text(
                          claim.tipoAssistencia ?? 'Assistência',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                  if (claim.localOcorrencia.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            claim.localOcorrencia,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (claim.ramoSinistro.isNotEmpty && claim.tipo == 'sinistro') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.category, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Ramo: ${claim.ramoSinistro}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Primeira coluna ──────────────────────────────────────────────────────
  Widget _buildInfoColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.badge_outlined,
          label: 'CPF/CNPJ',
          value: _formatCpfCnpj(_currentClient!.cnpjCpf),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.phone_outlined,
          label: 'Telefone',
          value: _currentClient!.contatoTelefone.isNotEmpty
              ? BRFormatters.formatarTelefone(_currentClient!.contatoTelefone)
              : 'Não informado',
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.person_outline,
          label: 'Nome do Contato (ou sócio)',
          value: _currentClient!.contato.isNotEmpty ? _currentClient!.contato : 'Não informado',
        ),
      ],
    );
  }

  // ─── Segunda coluna ──────────────────────────────────────────────────────
  Widget _buildInfoColumn2(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          icon: Icons.email_outlined,
          label: 'E-mail',
          value: _currentClient!.email.isNotEmpty ? _currentClient!.email : 'Não informado',
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.calendar_today_outlined,
          label: 'Cadastro',
          value: DateFormat('dd/MM/yyyy').format(_currentClient!.dataCadastro),
        ),
        const SizedBox(height: 12),
        _buildInfoRow(
          icon: Icons.business_outlined,
          label: 'Status',
          value: _currentClient!.isAtivo ? 'Ativo' : 'Inativo',
        ),
      ],
    );
  }

  // ─── Linha com ícone ──────────────────────────────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A2E))),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Card de total (sinistros, assistências, valor) ──────────────────────
  Widget _buildTotalCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helper para formatar CPF/CNPJ ──────────────────────────────────────
  String _formatCpfCnpj(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return BRFormatters.formatarCPF(value);
    } else if (digits.length == 14) {
      return BRFormatters.formatarCNPJ(value);
    }
    return value;
  }

  // --- WIDGET PARA MOSTRAR A SEÇÃO DE ANEXOS ---
  Widget _buildDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: Colors.grey),
      ),
    );
  }

// ── Helper: card de seção com título e ícone ──────────────────────────────
Widget _buildSectionCard({
  required IconData icon,
  required String title,
  required List<Widget> children,
  Widget? trailing,
}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ),
  );
}

String _getEmojiRamo(String ramo) {
  const ramoEmojis = {
    'Veículo Individual': '🚗',
    'Frota': '🚚',
    'Transporte': '📦',
    'Máquinas': '⚙️',
    'Residencial': '🏠',
    'Empresarial': '🏢',
    'Vida': '💓',
  };
  return ramoEmojis[ramo] ?? '📋';
}

Color _getCorRamo(String ramo) {
  const ramoColors = {
    'Veículo Individual': Color(0xFFFFB74D),
    'Frota': Color(0xFF64B5F6),
    'Transporte': Color(0xFF81C784),
    'Máquinas': Color(0xFFA1887F),
    'Residencial': Color(0xFFE57373),
    'Empresarial': Color(0xFF424242),
    'Vida': Color(0xFFBA68C8),
  };
  return ramoColors[ramo] ?? Colors.grey;
}

}
