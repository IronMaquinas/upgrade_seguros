import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:upgrade_seguros/screens/client_form_screen.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import 'package:upgrade_seguros/services/image_service_web.dart';
import 'package:url_launcher/url_launcher.dart';
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
    bool _vigenciaFoiEditada = false;
    bool _isAdmin = false;
    late String _currentUserId; // Adicionado para armazenar o userId
    String? _errorMessage;

    String calcularRecomendacaoManutencao(double valorApoliceTotal, List<Claim> claims) {
    final totalSinistros = claims.fold<double>(0.0, (sum, claim) => sum + claim.valorTotalSinistro);
    
    if (valorApoliceTotal <= 0) return 'Não recomendado';
    
    final percentual = totalSinistros / valorApoliceTotal;
    
    if (percentual < 0.5) return 'Ótimo';
    else if (percentual < 0.75) return 'Regular';
    else if (percentual < 1.0) return 'Atenção';
    else return 'Não recomendado';
  }

  @override
  void initState() {
    super.initState();
    _currentUserId = _authService.getUserId(); // Obtém o userId na inicialização
    //_fetchClientClaims();
    _loadIsAdmin();
    _loadClient(); // ✅ Carrega do Firestore
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

  Future<void> _editClient() async {
    print('Editando cliente: ${_currentClient!.id}');
    
    final updated = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientFormScreen(clientToEdit: _currentClient!),
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
    setState(() {
      _isLoadingClaims = true;
    });

    try {
      final allClaims = await _firestoreService.getClaims();
      setState(() {
        _clientClaims = allClaims
            .where((claim) => claim.idCliente == _currentClient?.id)
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar sinistros do cliente: $e')),
      );
    } finally {
      setState(() {
        _isLoadingClaims = false;
      });
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

    // Procure por:
    final recomendacao = calcularRecomendacaoManutencao(
      _currentClient?.valorTotalApolicesAtivas ?? 0,  // Valor total de apólices ativas
      _clientClaims,
    );

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
                              Text(
                                _currentClient!.nome,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('CPF/CNPJ: ${_currentClient?.cnpjCpf}'),
                              Text('Contato: ${_currentClient?.contato}'),
                              Text('Email: ${_currentClient?.email}'),
                              const SizedBox(height: 4),
                              Text('Valor total dos sinistros: $valorTotalSinistrosFormatado'),
                              const Divider(height: 20),
                              Text(
                                'Total de Sinistros Acionados: ${_currentClient?.totalSinistrosAcionados}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Recomendação: ',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Chip(
                                    label: Text(recomendacao),
                                    backgroundColor:
                                        recomendacao == 'Ótimo'
                                            ? Colors.green.shade100
                                            : recomendacao == 'Regular'
                                                ? Colors.amber.shade100
                                                : recomendacao == 'Atenção'
                                                    ? Colors.orange.shade100
                                                    : Colors.red.shade100,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_currentClient?.apolices.isNotEmpty ?? false)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Apólices',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 8),
                                    ..._currentClient!.apolices.map((apolice) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${apolice.ramo} • ${apolice.numeroApolice}',
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          Text('${apolice.seguradora}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          Text('R\$ ${apolice.valorApolice.toStringAsFixed(2)} • Gatilho: R\$ ${apolice.valorGatilho.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          Text('${DateFormat('dd/MM/yyyy').format(apolice.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(apolice.dataFim)}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                          
                                          // 🔥 NOVO: Lista de bens segurados com documentos
                                          if (apolice.bensSegurados.isNotEmpty) ...[
                                            const Divider(height: 16, thickness: 0.5),
                                            const Text('Bens Segurados',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                                                    ),

                                                    // 🔥 DOCUMENTOS ANEXOS (CRLV e documentos genéricos)
                                                    if (bem.documentosUrls != null && bem.documentosUrls!.isNotEmpty) ...[
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                                                          const SizedBox(width: 4),
                                                          Text('Documentos:',
                                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
                                                          const Spacer(),
                                                          // Mostra o número de documentos
                                                          Text('${bem.documentosUrls!.length} arquivo(s)',
                                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      // Lista de miniaturas dos documentos (clique para visualizar)
                                                      Wrap(
                                                        spacing: 4,
                                                        runSpacing: 4,
                                                        children: bem.documentosUrls!.map((url) {
                                                          // Determina o ícone baseado na extensão
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
                                    )).toList(),
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
                      Text(
                        'Veículos Segurados (${_currentClient?.veiculosSegurados.length})',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_currentClient!.veiculosSegurados.isEmpty)
                        const Text('Nenhum veículo segurado cadastrado.')
                      else
                        ..._currentClient!.veiculosSegurados.map((vehicle) => Card(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.directions_car),
                                    title: Text('${vehicle.marca} ${vehicle.modelo} (${vehicle.ano})'),
                                    subtitle: Text('Chassi: ${vehicle.chassi} - Placa: ${vehicle.placa}'),
                                  ),
                                  if (vehicle.fotosUrls != null && vehicle.fotosUrls!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                                      child: Wrap(
                                        spacing: 8,
                                        children: vehicle.fotosUrls!.map((url) {
                                          return GestureDetector(
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (_) => Dialog(
                                                  child: Stack(
                                                    children: [
                                                      InteractiveViewer(
                                                        child: Image.network(url),
                                                      ),
                                                      Positioned(
                                                        top: 10,
                                                        right: 10,
                                                        child: IconButton(
                                                          icon: const Icon(Icons.close, color: Colors.white),
                                                          onPressed: () => Navigator.of(context).pop(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            )),
                      const SizedBox(height: 24),
                      Text(
                        'Histórico de Sinistros (${_clientClaims.length})',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _isLoadingClaims
                          ? const Center(child: CircularProgressIndicator())
                          : _clientClaims.isEmpty
                              ? const Text('Nenhum sinistro registrado para este cliente.')
                              : Column(
                                  children: _clientClaims.map((claim) => Card(
                                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: ListTile(
                                      leading: const Icon(Icons.assignment),
                                      title: Text(claim.numeroSinistro),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Status: ${claim.statusAtual}'),
                                          Text('Data: ${DateFormat('dd/MM/yyyy').format(claim.dataOcorrencia)}'),
                                          Text('Valor Total: ${currencyFormat.format(claim.valorTotalSinistro)}'),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(MaterialPageRoute(
                                            builder: (context) => ClaimDetailScreen(claim: claim)));
                                      },
                                    ),
                                  )).toList(),
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

}
