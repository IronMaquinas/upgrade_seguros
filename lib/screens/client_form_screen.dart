// ignore_for_file: unused_local_variable, unnecessary_null_comparison

import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' hide PdfDocument;
import 'package:upgrade_seguros/formatter/number_input_formatter.dart';
import 'package:upgrade_seguros/models/apolice_model.dart';
import 'package:upgrade_seguros/models/bem_segurado_model.dart';
import 'package:upgrade_seguros/models/business_model.dart';
import 'package:upgrade_seguros/models/contrato_dto.dart';
import 'package:upgrade_seguros/parsers/parser_factory.dart';
import 'package:upgrade_seguros/services/image_service_web.dart';
import 'package:upgrade_seguros/services/place_search_delegate.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:upgrade_seguros/utils/gatilho.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../models/client_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdf/pdf.dart' as PDFLib;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' hide LatLng;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/vigencia_date_range_widget.dart';

class ClientFormScreen extends StatefulWidget {
  final Client? clientToEdit;
  final VoidCallback? onSaved;
  const ClientFormScreen({super.key, this.clientToEdit, this.onSaved});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _phoneController = TextEditingController();
  final _numeroApoliceController = TextEditingController();
  final _valorApoliceController = TextEditingController();
  final _valorGatilhoController = TextEditingController();
  // Etapa 07: % padrão do gatilho (Configurações), para exibir o gatilho calculado.
  double _percentualGatilho = GatilhoApolice.percentualPadraoInicial;
  final nomeEmpresaCtrl = TextEditingController();
  final cnpjEmpresaCtrl = TextEditingController();
  final enderecoEmpresaCtrl = TextEditingController();

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // API Key para Google places - Mesma conta da Iron Máquinas
  final _places = FlutterGooglePlacesSdk("AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE");
  LatLng? _localOcorrenciaLatLng;

  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  bool _buscandoCNPJ = false;

  bool _isAdmin = false;
  List<String> _selectedRamos = [];

  List<Apolice> _apolices = [];
  List<String> _seguradoras = [];

  @override
    void initState() {
      super.initState();
      _authService.isAdmin().then((value) {
        if (mounted) setState(() => _isAdmin = value);
      });
      _carregarSeguradoras();
      ConfigService().getPercentualGatilho().then((p) {
        if (mounted) setState(() => _percentualGatilho = p);
      });

      final client = widget.clientToEdit;
      if (client != null) {
        _nameController.text = client.nome;
        _cpfCnpjController.text = client.cnpjCpf;
        _emailController.text = client.email;
        _contactController.text = client.contato;
        _phoneController.text = client.contatoTelefone;
        _selectedRamos = List.from(client.ramos);
        _apolices = List.from(client.apolices);

        final numberFormat = NumberFormat.currency(
          locale: 'pt_BR',
          symbol: '',
          decimalDigits: 2,
        );
        _vehicles = List.from(client.veiculosSegurados);
      }
    }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfCnpjController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _phoneController.dispose();
    _numeroApoliceController.dispose();
    _valorApoliceController.dispose();
    _valorGatilhoController.dispose();
    super.dispose();
  }

  // Carregar seguradoras do firestore
  Future<void> _carregarSeguradoras() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('seguradoras')
          .where('ativa', isEqualTo: true)
          .get();

      setState(() {
        _seguradoras = snapshot.docs
            .map((doc) => doc['nome'] as String)
            .toList();
      });
    } catch (e) {
      debugPrint('Erro ao carregar seguradoras: $e');
    }
  }

   // BUSCAR LOCAL NO MAPS
  Future<String?> _openPlaceSearch() async {
    final Place? place = await showSearch<Place?>(
      context: context,
      delegate: PlaceSearchDelegate(_places),
    );

    if (place != null) {
      // salva lat/lng se quiser usar depois
      if (place.latLng != null) {
        setState(() {
          _localOcorrenciaLatLng = LatLng(
            place.latLng!.lat,
            place.latLng!.lng,
          );
        });
      }

      return place.address ?? place.name ?? '';
    }

    return null;
  }

  void _showImageViewer(ImageProvider imageProvider, VoidCallback onDelete) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(10),
          child: SizedBox(
            width: 400,
            height: 500,
            child: Stack(
              children: [
                // Imagem com zoom
                InteractiveViewer(
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
                // Botão de fechar (X)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 28),
                    ),
                  ),
                ),
                // Botão de exclusão
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(); // Fecha o visualizador
                      onDelete(); // Chama a exclusão
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addVehicleDialog({Vehicle? vehicleToEdit, int? indexToUpdate}) async {
    final marca = TextEditingController(text: vehicleToEdit?.marca ?? '');
    final modelo = TextEditingController(text: vehicleToEdit?.modelo ?? '');
    final ano = TextEditingController(text: vehicleToEdit?.ano.toString() ?? '');
    final cor = TextEditingController(text: vehicleToEdit?.cor ?? '');
    final anomodelo = TextEditingController(text: vehicleToEdit?.anomodelo.toString() ?? '');
    final placa = TextEditingController(text: vehicleToEdit?.placa ?? '');
    final chassi = TextEditingController(text: vehicleToEdit?.chassi ?? '');

    // ✅ Lista de fotos locais (XFile)
    final List<XFile> _vehiclePhotos = List<XFile>.from(vehicleToEdit?.fotos ?? []);

  // ✅ Adiciona as fotos do Firestore como XFile (via download)
    if (vehicleToEdit?.fotosUrls != null) {
      for (final url in vehicleToEdit!.fotosUrls) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final xFile = XFile.fromData(
              response.bodyBytes,
              name: 'downloaded_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
              mimeType: 'image/jpeg',
            );
            _vehiclePhotos.add(xFile);
          }
        } catch (e) {
          debugPrint('Erro ao baixar foto do Firestore: $e');
          // Opcional: exibir placeholder
        }
      }
    }

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Detalhes do Veículo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Linha 1: Marca | Modelo | Cor
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: marca,
                        decoration: InputDecoration(
                          labelText: 'Marca',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: modelo,
                        decoration: InputDecoration(
                          labelText: 'Modelo',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: cor,
                        decoration: InputDecoration(
                          labelText: 'Cor',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Linha 2: Ano Fabricação | Ano Modelo
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: ano,
                        decoration: InputDecoration(
                          labelText: 'Ano Fabricação',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: anomodelo,
                        decoration: InputDecoration(
                          labelText: 'Ano Modelo',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Linha 3: Placa | Chassi
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: placa,
                        decoration: InputDecoration(
                          labelText: 'Placa',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: chassi,
                        decoration: InputDecoration(
                          labelText: 'Chassi',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Fotos (mantém igual ao atual)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Fotos do Veículo',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Miniaturas das fotos já adicionadas
                      ..._vehiclePhotos.map((photo) => Stack(
                            alignment: Alignment.topRight,
                            children: [
                              // Miniatura
                              GestureDetector(
                                onTap: () {
                                  final ImageProvider imageProvider = kIsWeb
                                      ? NetworkImage(photo.path)
                                      : FileImage(File(photo.path));
                                  _showImageViewer(
                                    imageProvider,
                                    () {
                                      // ✅ Função de exclusão
                                      setState(() {
                                        _vehiclePhotos.remove(photo);
                                      });
                                    },
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: kIsWeb
                                      ? Image.network(photo.path, width: 80, height: 80, fit: BoxFit.cover)
                                      : Image.file(File(photo.path), width: 80, height: 80, fit: BoxFit.cover),
                                ),
                              ),
                              // Botão de exclusão
                              GestureDetector(
                                onTap: () {
                                  setModalState(() {
                                    _vehiclePhotos.remove(photo);
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

                      // Botão para adicionar nova foto
                      InkWell(
                        onTap: () async {
                          final pickedList = await _picker.pickMultiImage();
                            if (pickedList.isNotEmpty) {
                              final compressedFiles = await ImageService().compressImages(pickedList);
                              setModalState(() {
                                _vehiclePhotos.addAll(compressedFiles);
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (marca.text.isEmpty || modelo.text.isEmpty || ano.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Preencha os campos obrigatórios')),
                      );
                      return;
                    }

                    final newVehicle = Vehicle(
                      marca: marca.text,
                      modelo: modelo.text,
                      cor: cor.text,           // ← campo adicionado
                      ano: int.tryParse(ano.text) ?? 0,
                      anomodelo: int.tryParse(anomodelo.text) ?? 0,
                      placa: placa.text.toUpperCase(),
                      chassi: chassi.text.toUpperCase(),
                      fotos: List<XFile>.from(_vehiclePhotos),
                    );

                    if (indexToUpdate != null) {
                      _vehicles[indexToUpdate] = newVehicle;
                    } else {
                      _vehicles.add(newVehicle);
                    }

                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Salvar Veículo'),
                ),
                const SizedBox(height: 12),
              ],
            ),
            );
          },
        );
      },
    );

    // ✅ Este bloco será executado após o pop(true)
    if (result == true && mounted) {
      setState(() {}); // ✅ Reconstrói o widget
    }
  }

  Future<void> _deleteClient() async {
    if (widget.clientToEdit == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: const Text('Tem certeza que deseja excluir este cliente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Instância do serviço
      final firestoreService = FirestoreService();

      // ✅ ID do cliente
      final clientId = widget.clientToEdit!.id;
      if (clientId == null || clientId.isEmpty) {
        throw Exception('ID do cliente inválido.');
      }

      // ✅ Chama o método de exclusão
      await firestoreService.deleteClient(clientId);

      if (mounted) {
        Navigator.of(context).pop(true); // Fecha o formulário com sucesso
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente excluído com sucesso!')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao excluir cliente: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir cliente: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- Diálogo de sair sem salvar ---
  Future<bool> _showExitDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar cadastro?'),
        content: const Text('Você tem certeza que deseja sair? As informações preenchidas serão perdidas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  // --- Importar novo contrato ---
  Future<void> _importarContrato() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      Navigator.of(context).pop();

      if (result == null) return;

      final file = result.files.single;
      final texto = await _extractText(file);
 
final linhasDebug = texto
    .split('\n')
    .map((l) => l.trim())
    .where((l) => l.isNotEmpty)
    .toList();
 
for (int i = 0; i < linhasDebug.length; i++) {
  final linha = linhasDebug[i];
  print('[$i] ${linha.substring(0, linha.length > 100 ? 100 : linha.length)}${linha.length > 100 ? '...' : ''}');
}
 
for (int i = 0; i < linhasDebug.length; i++) {
  if (linhasDebug[i].toLowerCase().contains('proponente')) {
    print('  [$i] ${linhasDebug[i]}');
    if (i + 1 < linhasDebug.length) {
      print('  [$i+1] ${linhasDebug[i + 1]} ← próxima linha');
    }
  }
}
 
for (int i = 0; i < linhasDebug.length; i++) {
  if (linhasDebug[i].toLowerCase().contains('cpf') ||
      RegExp(r'\d{3}\.\d{3}\.\d{3}-\d{2}').hasMatch(linhasDebug[i])) {
    print('  [$i] ${linhasDebug[i]}');
  }
}
 
for (int i = 0; i < linhasDebug.length; i++) {
  if (linhasDebug[i].toLowerCase().contains('placa')) {
    print('  [$i] ${linhasDebug[i]}');
    if (i + 1 < linhasDebug.length) {
      print('  [$i+1] ${linhasDebug[i + 1]} ← dados da placa?');
    }
  }
}
 
for (int i = 0; i < linhasDebug.length; i++) {
  if (linhasDebug[i].toLowerCase().contains('apólice') ||
      linhasDebug[i].toLowerCase().contains('número da')) {
    print('  [$i] ${linhasDebug[i]}');
    if (i + 1 < linhasDebug.length) {
      print('  [$i+1] ${linhasDebug[i + 1]} ← dados?');
    }
  }
}
 
for (int i = 0; i < linhasDebug.length; i++) {
  if (RegExp(r'\d{3}\.\d{3}\.\d{3}-\d{2}').hasMatch(linhasDebug[i])) {
    print('  [$i] ${linhasDebug[i]}');
  }
}
 
for (int i = 0; i < linhasDebug.length; i++) {
  if (RegExp(r'[A-Z]{3}-?\d[A-Z0-9]-?\d{2}').hasMatch(linhasDebug[i])) {
    print('  [$i] ${linhasDebug[i]}');
  }
}
      final contrato = ParserFactory.parseContrato(texto);

      print('📋 Contrato parseado:');
      if (contrato.veiculos.isNotEmpty) {
        print('    Marca: ${contrato.veiculos.first.marca}');
        print('    Modelo: ${contrato.veiculos.first.modelo}');
        print('    Ano: ${contrato.veiculos.first.ano}');
      }

      final clienteExistente = await _firestoreService.getClientByCnpjCpf(
        contrato.cnpjCpfProponente
      );

      if (clienteExistente != null) {
        final adicionar = await _mostrarDialogoClienteExistente(clienteExistente, contrato);
        if (adicionar) {
          _atualizarClienteExistente(clienteExistente, contrato);
        }
      } else {
        _preencherNovoCliente(contrato);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Dados do contrato importados! Revise e salve.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      print('❌ Erro na importação: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao importar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Preencher novo cliente se for o caso ---
  void _preencherNovoCliente(ContratoDTO contrato) {
    setState(() {
      _nameController.text = contrato.nomeProponente;
      _cpfCnpjController.text = contrato.cnpjCpfProponente;
      _contactController.text = contrato.contato ?? '';
      _phoneController.text = BRFormatters.formatarTelefone(contrato.telefone ?? '');
      _emailController.text = contrato.email ?? '';

      final apolice = _criarApolice(contrato);
      _apolices = [apolice];
    });

    // 🔥 AVISO DE CHASSI FALTANTE (FORA DO setState)
    if (contrato.veiculos.isNotEmpty && contrato.veiculos.first.chassi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Chassi não foi extraído. Preencha manualmente.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  void _atualizarClienteExistente(Client cliente, ContratoDTO contrato) {
    setState(() {
      _nameController.text = cliente.nome;
      _cpfCnpjController.text = cliente.cnpjCpf;
      _contactController.text = cliente.contato;
      _phoneController.text = BRFormatters.formatarTelefone(cliente.contatoTelefone);
      _emailController.text = cliente.email;
      
      _selectedRamos = List.from(cliente.ramos);  // ✅ Já tem
      _apolices = List.from(cliente.apolices);

      final existe = _apolices.any((a) => a.numeroApolice == contrato.numeroApolice);
      if (!existe) {
        final novaApolice = _criarApolice(contrato);
        _apolices.add(novaApolice);
        
        // 🆕 ADICIONE TAMBÉM:
        if (!_selectedRamos.contains(contrato.ramo)) {
          _selectedRamos.add(contrato.ramo);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Apólice ${contrato.numeroApolice} adicionada.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
    // 🔥 AVISO DE CHASSI FALTANTE
    if (contrato.veiculos.isNotEmpty && contrato.veiculos.first.chassi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Chassi não foi extraído. Preencha manualmente.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  // --- Criar nova apólice de novo cliente ou cliente existente ---
  Apolice _criarApolice(ContratoDTO contrato) {
    final bens = contrato.veiculos.map((v) {
      return BemSegurado(
        id: const Uuid().v4(),
        tipo: contrato.ramo,
        descricao: '${v.marca} ${v.modelo} - ${v.ano}',
        dataCadastro: DateTime.now(),
        placa: v.placa.isNotEmpty ? v.placa : null,
        marca: v.marca.isNotEmpty ? v.marca : null,
        modelo: v.modelo.isNotEmpty ? v.modelo : null,
        ano: v.ano > 0 ? v.ano : null,
        anoModelo: v.anoModelo > 0 ? v.anoModelo : null,
        cor: v.cor.isNotEmpty ? v.cor : null,
        chassi: v.chassi.isNotEmpty ? v.chassi : null,
        proprietarioNome: v.proprietarioNome,
        proprietarioCPF: v.proprietarioCPF,
      );
    }).toList();

    return Apolice(
      id: const Uuid().v4(),
      ramo: contrato.ramo,
      seguradora: contrato.seguradora,
      numeroApolice: contrato.numeroApolice,
      dataInicio: contrato.dataInicio,
      dataFim: contrato.dataFim,
      valorApolice: contrato.valorPremioTotal,
      valorGatilho: contrato.valorFranquia ?? 0.0,
      bensSegurados: bens,
    );
  }

// --- Diálogo para importar dados do contrato ----
Future<bool> _mostrarDialogoClienteExistente(Client cliente, ContratoDTO contrato) async {
  return await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cliente já existe'),
      content: Text(
        'Cliente ${cliente.nome} já está cadastrado.\n'
        'Nova apólice: ${contrato.numeroApolice} (${contrato.seguradora})\n\n'
        'Deseja adicionar esta apólice e seus bens ao cliente?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Adicionar', style: TextStyle(color: Colors.blue)),
        ),
      ],
    ),
  ) ?? false;
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

  /// Normaliza CNPJ/CPF removendo símbolos
  String _normalizarCnpjCpf(String valor) {
    if (valor.isEmpty) return '';
    // Remove tudo que não é número
    return valor.replaceAll(RegExp(r'[^\d]'), '');
  }

  // --- BUSCAR CNPJ ---
  Future<void> _buscarCNPJ() async {
    final cnpj = _cpfCnpjController.text.replaceAll(RegExp(r'\D'), '');

    if (cnpj.isEmpty || cnpj.length != 14) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CNPJ inválido — informe os 14 dígitos')),
      );
      return;
    }

    setState(() => _buscandoCNPJ = true);

    try {
      final response = await http
          .get(Uri.parse('https://brasilapi.com.br/api/cnpj/v1/$cnpj'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        final razaoSocial = json['razao_social'] ?? '';
        final nomeFantasia = json['nome_Fantasia'] ?? json['nome_fantasia'] ?? '';
        final nomeSocio = (json['qsa'] as List?)?.isNotEmpty == true
            ? json['qsa'][0]['nome_socio'] ?? ''
            : '';

        final nomeParaUsar = nomeFantasia.isNotEmpty ? nomeFantasia : razaoSocial;

        setState(() {
          _nameController.text = nomeParaUsar;
          _contactController.text = nomeSocio;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Empresa encontrada: $nomeParaUsar'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ CNPJ não encontrado na Receita Federal'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao consultar CNPJ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _buscandoCNPJ = false);
    }
  }

  Map<String, dynamic> parseCRLV(String text) {
      final linhas = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      String placa = '';
      String chassi = '';
      String marca = '';
      String modelo = '';
      String anoFab = '';
      String anoModelo = '';
      String cor = '';

      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i];

        // 🔥 PLACA
        if (placa.isEmpty) {
          final match = RegExp(r'^[A-Z]{3}[0-9][A-Z0-9][0-9]{2}$').firstMatch(linha);
          if (match != null) {
            placa = linha;
          }
        }

        // 🔥 CHASSI
        if (chassi.isEmpty) {
          final match = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').firstMatch(linha);
          if (match != null) {
            chassi = linha;
          }
        }

        // 🔥 ANOS (linha: 2009 / 2010)
        if (i < linhas.length - 1) {
          if (RegExp(r'^\d{4}$').hasMatch(linha) &&
              RegExp(r'^\d{4}$').hasMatch(linhas[i + 1])) {
            anoFab = linha;
            anoModelo = linhas[i + 1];
          }
        }

        // 🔥 COR
        if (cor.isEmpty && chassi.isNotEmpty && i + 1 < linhas.length) {
          // se a linha atual é o chassi
          if (linha == chassi) {
            final possivelCor = linhas[i + 1].toUpperCase().trim();

            final isValida =
                possivelCor.length >= 3 &&
                possivelCor.length <= 25 &&
                !possivelCor.contains('/') &&
                !RegExp(r'\d').hasMatch(possivelCor) &&
                !possivelCor.contains('*') &&
                !possivelCor.contains('TIPO') &&
                !possivelCor.contains('ESPÉCIE') &&
                !possivelCor.contains('CARROCERIA') &&
                !possivelCor.contains('COMBUST') &&
                !possivelCor.contains('PASSAGEIRO') &&
                !possivelCor.contains('AUTOMOVEL') &&
                !possivelCor.contains('PESO');

            if (isValida) {
              cor = possivelCor;
            }
          }
        }

        // 🔥 MARCA / MODELO
        if (marca.isEmpty && linha.contains('/')) {
          final upper = linha.toUpperCase();

          // ❌ BLOQUEIOS SEMÂNTICOS
          const bloqueadas = [
            'CPF',
            'CNPJ',
            'CILINDRADA',
            'POTENCIA',
            'CAPACIDADE',
            'PESO',
            'EIXOS',
            'COMBUSTIVEL',
            'PASSAGEIRO',
            'AUTOMOVEL',
            'CARROCERIA',
            'ESPECIE'
          ];

          if (bloqueadas.any((p) => upper.contains(p))) continue;

          // ❌ BLOQUEIA CABEÇALHO DO CRLV
          if (upper.contains('MARCA') &&
              upper.contains('MODELO') &&
              upper.contains('VERSAO')) {
            continue;
          }

          // ❌ ignora placa/UF
          if (RegExp(r'^[A-Z]{3}[0-9].*/[A-Z]{2}$').hasMatch(linha)) {
            continue;
          }

          // ❌ ignora linhas com muitos números
          if (RegExp(r'\d{5,}').hasMatch(linha)) {
            continue;
          }

          final partes = linha.split('/');

          if (partes.length >= 2) {
            final marcaCandidate = partes[0].trim();
            final modeloCandidate = partes.sublist(1).join('/').trim();

            // ❌ evita pegar literalmente "MARCA"
            if (marcaCandidate.toUpperCase() == 'MARCA') continue;

            // ✅ valida estrutura
            final isMarcaValida = RegExp(r'^[A-Z]{2,}$').hasMatch(marcaCandidate);
            final isModeloValido = modeloCandidate.length >= 3;

            if (isMarcaValida && isModeloValido) {
              marca = marcaCandidate;
              modelo = modeloCandidate;
            }
          }
        }
      }

      return {
        "placa": placa,
        "chassi": chassi,
        "marca": marca,
        "modelo": modelo,
        "ano": anoFab,
        "anoModelo": anoModelo,
        "cor": cor,
      };
    }

    Map<String, dynamic> parseCondutorFromCRLV(String text) {
      final linhas = text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      String nome = '';
      String documento = '';

      for (int i = 0; i < linhas.length; i++) {
        final linha = linhas[i].toUpperCase();

        // CPF
        final docMatch = RegExp(
          r'(\d{3}\.\d{3}\.\d{3}-\d{2})|(\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2})'
        ).firstMatch(linha);
        if (docMatch != null) {
          documento = docMatch.group(0)!;

          // 🔥 nome geralmente está logo acima
          if (i > 0) {
            nome = linhas[i - 1];
          }
        }
      }

      return {
        "nome": nome,
        "cpf": documento,
      };
    }

    Future<String> _extractText(PlatformFile file) async {
      try {
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Arquivo vazio');

        final pdfDocument = PdfDocument(inputBytes: bytes);

        // 🔥 Tenta extrair com diferentes opções
        String text = '';
        try {
          text = PdfTextExtractor(pdfDocument).extractText();
        } catch (e) {
          print('Erro ao extrair texto padrão: $e');
        }

        pdfDocument.dispose();

        // Se o texto estiver vazio, tenta extrair página por página
        if (text.isEmpty) {
          text = await _extractTextPageByPage(bytes);
        }

        return _normalizePdfText(text);
      } catch (e, stackTrace) {
        print('❌ Erro ao extrair texto: $e');
        print('📍 Stack trace: $stackTrace');
        return '';
      }
    }

    Future<String> _extractTextPageByPage(Uint8List bytes) async {
    final doc = PdfDocument(inputBytes: bytes);
    final buffer = StringBuffer();
    final extractor = PdfTextExtractor(doc);
    
    for (int i = 0; i < doc.pages.count; i++) {
      try {
        // ✅ Extrai a página específica usando o extrator com índices
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        buffer.writeln('===== Page ${i + 1} =====');
        buffer.writeln(text);
      } catch (e) {
        buffer.writeln('===== Page ${i + 1} (erro ao extrair) =====');
      }
    }
    doc.dispose();
    return buffer.toString();
  }

   /// 🔥 VERSÃO CORRIGIDA - Preserva quebras de linha estruturantes
  String _normalizePdfText(String text) {
    print('🔧 Normalizando texto PDF...');
  
    // 0. Normalizar quebras de linha
    String normalized = text.replaceAll('\r\n', '\n');
  
    // 1. Insere espaço entre letras minúsculas e maiúsculas
    normalized = normalized.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match[1]} ${match[2]}',
    );
  
    // 2. Insere espaço entre letras maiúsculas e minúsculas após 2+ maiúsculas
    normalized = normalized.replaceAllMapped(
      RegExp(r'([A-Z]{2,})([a-z])'),
      (match) => '${match[1]} ${match[2]}',
    );
  
    // 3. Insere espaço entre números e letras
    normalized = normalized.replaceAllMapped(
      RegExp(r'(\d)([A-Za-z])'),
      (match) => '${match[1]} ${match[2]}',
    );
  
    // 4. Insere espaço entre letras e números
    normalized = normalized.replaceAllMapped(
      RegExp(r'([A-Za-z])(\d)'),
      (match) => '${match[1]} ${match[2]}',
    );
  
    // 5. Insere espaço após pontuação
    normalized = normalized.replaceAllMapped(
      RegExp(r'([:,;])(\d)'),
      (match) => '${match[1]} ${match[2]}',
    );
  
    // 🔥 CRÍTICO: 5a. Insere quebra de linha ANTES de LABELS IMPORTANTES
    // Isso reconstrói a estrutura do PDF que foi perdida
    final labels = [
      'Proponente',
      'Nome Social',
      'Endereço de correspondência',
      'Telefone',
      'Celular',
      'E-mail',
      'Principal Condutor',
      'Fabricante',
      'Veículo',
      'Combustível',
      'Lotação',
      'Placa',
      'Chassi',
      'Ano modelo',
      'Ano',
      'Cor',
      'Número da apólice',
      'Vigência',
      'Fim de vigência',
      'Prêmio Líquido',
      'Indenização',
      'Tipo de utilização',
    ];
  
    for (var label in labels) {
      // Insere \n antes do label usando regex case-insensitive
      normalized = normalized.replaceAll(
        RegExp('(?<!\\n)\\s+($label\\b)', caseSensitive: false),
        '\n$label',
      );
    }
  
    // 6. Remove múltiplos espaços preservando estrutura
    normalized = normalized.split('\n')
        .map((linha) {
          // Remove múltiplos espaços dentro da linha
          return linha.replaceAll(RegExp(r'\s+'), ' ').trim();
        })
        .where((linha) => linha.isNotEmpty) // Remove linhas vazias
        .join('\n');
  
    // 7. Remove espaços antes de pontuação (dentro de linhas)
    normalized = normalized.replaceAll(RegExp(r'\s([,;:\.!?])'), r'$1');
  
    print('✅ Normalização concluída');
    print('📊 Total de linhas: ${normalized.split('\n').length}');
  
    return normalized.trim();
  }

// ✨ PADRÃO VISUAL ADICIONAR APÓLICE
  InputDecoration _buildModernInputDecoration(
    String label, {
    IconData? icon,
    String? helperText,
    TextInputType? keyboardType,
  }) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF6A1B9A)) : null,
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: Color(0xFF6A1B9A),
        fontWeight: FontWeight.w500,
      ),
      helperStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6A1B9A), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

    Future<void> _saveClient() async {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isLoading = true);
      final userId = _authService.getUserId();

      if (userId == 'anonymous_user') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuário não autenticado')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Converter valor da apólice
      final valorApoliceStr = _valorApoliceController.text
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final valorApolice = double.tryParse(valorApoliceStr) ?? 0.0;

            // Converter valor do gatilho
      final valorGatilhoStr = _valorGatilhoController.text
          .replaceAll('.', '')
          .replaceAll(',', '.');
      final valorGatilho = double.tryParse(valorGatilhoStr) ?? 0.0;

      final totalSinistros = widget.clientToEdit?.totalSinistrosAcionados ?? 0;

      // Calcular recomendação
      String recomendacao;
      if (totalSinistros >= 5) {
        recomendacao = 'Crítico';
      } else if (totalSinistros >= 3) {
        recomendacao = 'Regular';
      } else {
        recomendacao = 'Bom';
      }

      // 🆕 VALIDAÇÃO: Verificar duplicata de CNPJ/CPF
      final cnpjCpfNormalizado = _normalizarCnpjCpf(_cpfCnpjController.text);
      
      if (cnpjCpfNormalizado.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CNPJ/CPF inválido')),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Se é novo cliente, verificar se já existe com este CNPJ/CPF
      if (widget.clientToEdit == null) {
        final jaExiste = await _firestoreService.verificarCnpjCpfDuplicado(
          cnpjCpfNormalizado,
        );
        
        if (jaExiste) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Já existe um cliente com este CNPJ/CPF!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      } else {
        // 🆕 Se está EDITANDO, também verificar se outro cliente tem este CNPJ/CPF
        final jaExiste = await _firestoreService.verificarCnpjCpfDuplicado(
          cnpjCpfNormalizado,
          clienteIdExcluir: widget.clientToEdit!.id,
        );
        
        if (jaExiste) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Já existe outro cliente com este CNPJ/CPF!'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // Criar ou atualizar
      final clientId = widget.clientToEdit?.id ?? '';

      // ✅ Processa cada veículo e atualiza o _vehicles local
      final List<Vehicle> updatedVehicles = [];
      for (var vehicle in _vehicles) {
        List<String> fotosUrls = List.from(vehicle.fotosUrls);

        if (vehicle.fotos.isNotEmpty) {
          final newUrls = await _firestoreService.uploadVehiclePhotos(
            clientId,
            vehicle.placa,
            vehicle.fotos,
          );
          fotosUrls.addAll(newUrls);
        }

        // ✅ Atualiza o veículo local com as URLs
        final updatedVehicle = Vehicle(
          marca: vehicle.marca,
          modelo: vehicle.modelo,
          ano: vehicle.ano,
          anomodelo: vehicle.anomodelo,
          placa: vehicle.placa,
          chassi: vehicle.chassi,
          cor: vehicle.cor,
          fotos: [], // ✅ Limpa as fotos locais após upload (opcional)
          fotosUrls: fotosUrls,
        );

        updatedVehicles.add(updatedVehicle);

        // ✅ Atualiza o _vehicles para refletir as mudanças
        final index = _vehicles.indexOf(vehicle);
        if (index != -1) {
          _vehicles[index] = updatedVehicle;
        }
      }

      final updatedClient = Client(
        id: clientId,
        nome: _nameController.text,
        cnpjCpf: _cpfCnpjController.text,
        cnpjCpfNormalizado: cnpjCpfNormalizado,
        contato: _contactController.text,
        contatoTelefone: _phoneController.text,
        email: _emailController.text,
        dataCadastro: widget.clientToEdit?.dataCadastro ?? DateTime.now(),
        veiculosSegurados: updatedVehicles,
        totalSinistrosAcionados: totalSinistros,
        recomendacaoManutencao: recomendacao,
        ramos: _selectedRamos,
        apolices: _apolices,
      );

      try {
        if (widget.clientToEdit == null) {
          final newClient = await _firestoreService.addClient(updatedClient, userId);
          updatedClient.id = newClient.id;
        } else {
          await _firestoreService.updateClient(updatedClient, userId);
        }

        // ✅ Atualiza o estado local para reconstruir com as fotos
        if (mounted) {
          setState(() {}); // ✅ Força a reconstrução com os dados atualizados
          if (widget.onSaved != null) {
              widget.onSaved!();
            } else {
              Navigator.of(context).pop(true);
            }
        }
      } catch (e) {
        debugPrint('Erro ao salvar cliente: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

  // --- FUNÇÃO PARA CARREGAR DOCUMENTOS ANEXOS ---
  Widget _buildDocumentUploadSection({
    required String titulo,
    required List<PlatformFile> arquivos,
    required bool isUploading,
    required VoidCallback onAdd,
    required Function(int) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('📎 $titulo', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: isUploading ? null : onAdd,
              icon: const Icon(Icons.attach_file, size: 16),
              label: const Text('Adicionar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (arquivos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade50,
            ),
            child: Text(
              'Nenhum documento anexado',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(
            children: arquivos.asMap().entries.map((entry) {
              final idx = entry.key;
              final arquivo = entry.value;
              final ext = arquivo.name.split('.').last.toLowerCase();
              IconData icon;
              Color cor;
              if (['pdf'].contains(ext)) {
                icon = Icons.picture_as_pdf;
                cor = Colors.red.shade700;
              } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
                icon = Icons.image;
                cor = Colors.orange.shade700;
              } else if (['doc', 'docx'].contains(ext)) {
                icon = Icons.description;
                cor = Colors.blue.shade700;
              } else if (['xls', 'xlsx'].contains(ext)) {
                icon = Icons.table_chart;
                cor = Colors.green.shade700;
              } else {
                icon = Icons.insert_drive_file;
                cor = Colors.grey.shade700;
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    Icon(icon, color: cor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            arquivo.name,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${(arquivo.size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: Colors.red.shade700),
                      onPressed: () => onRemove(idx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

@override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      final confirm = await _showExitDialog();
      return confirm;
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(widget.clientToEdit == null ? 'Novo Cliente' : 'Editar Cliente'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _importarContrato,
            tooltip: 'Importar Contrato (PDF)',
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () async {
              final confirm = await _showExitDialog();
              if (confirm && mounted) {
                Navigator.of(context).pop();
              }
            },
            tooltip: 'Cancelar',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = constraints.maxWidth > 600;
              return SingleChildScrollView(
                child: Align(
                  alignment: isLargeScreen ? Alignment.centerLeft : Alignment.center,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isLargeScreen ? 900 : double.infinity),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Seção 1: Identificação (única e completa) ──────────
                        _buildSectionCard(
                          icon: Icons.business,
                          title: 'Identificação',
                          children: [
                            // Linha: CNPJ/CPF + Botão Buscar
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cpfCnpjController,
                                    decoration: _buildModernInputDecoration(
                                      'CNPJ / CPF',
                                      icon: Icons.badge_outlined,
                                      helperText: 'Digite o CNPJ para busca automática',
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    validator: (value) =>
                                        value == null || value.isEmpty ? 'Obrigatório' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  height: 58,
                                  child: ElevatedButton.icon(
                                    onPressed: _buscandoCNPJ ? null : _buscarCNPJ,
                                    icon: _buscandoCNPJ
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.search),
                                    label: Text(_buscandoCNPJ ? 'Buscando...' : 'Buscar CNPJ'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Nome / Razão Social
                            TextFormField(
                              controller: _nameController,
                              decoration: _buildModernInputDecoration(
                                'Nome / Razão Social',
                                icon: Icons.person_outline,
                                helperText: 'Preenchido automaticamente ao buscar CNPJ',
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 16),

                            // Linha: Contato + Telefone
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _contactController,
                                    decoration: _buildModernInputDecoration(
                                      'Contato / Sócio',
                                      icon: Icons.contacts_outlined,
                                      helperText: 'Preenchido automaticamente ao buscar CNPJ',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: _buildModernInputDecoration(
                                      'Telefone',
                                      icon: Icons.phone_outlined,
                                    ),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      BRFormatters.telefoneFormatter,
                                    ],
                                    validator: (value) =>
                                        value == null || value.isEmpty ? 'Obrigatório' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // E-mail
                            TextFormField(
                              controller: _emailController,
                              decoration: _buildModernInputDecoration(
                                'E-mail',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty ? 'Obrigatório' : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        _buildApolicesSection(),
                        const SizedBox(height: 16),

                        // ── Botões de ação ──────────────────────────────────────
                        LayoutBuilder(
                          builder: (context, buttonConstraints) {
                            final isLargeButtonScreen = buttonConstraints.maxWidth > 600;
                            if (isLargeButtonScreen) {
                              return Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _saveClient,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2)),
                                              SizedBox(width: 12),
                                              Text('Salvando...'),
                                            ],
                                          )
                                        : const Text('Salvar Cliente', style: TextStyle(fontSize: 15)),
                                  ),
                                  if (_isAdmin && widget.clientToEdit != null) ...[
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _isLoading ? null : _deleteClient,
                                      child: const Text('Excluir Cliente', style: TextStyle(fontSize: 15)),
                                    ),
                                  ],
                                ],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _saveClient,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2)),
                                              SizedBox(width: 12),
                                              Text('Salvando...'),
                                            ],
                                          )
                                        : const Text('Salvar Cliente', style: TextStyle(fontSize: 15)),
                                  ),
                                  if (_isAdmin && widget.clientToEdit != null) ...[
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      onPressed: _isLoading ? null : _deleteClient,
                                      child: const Text('Excluir Cliente', style: TextStyle(fontSize: 15)),
                                    ),
                                  ],
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

  Widget _buildApolicesSection() {
    return _buildSectionCard(
      icon: Icons.description,
      title: 'Apólices por Ramo',
      trailing: TextButton.icon(
      onPressed: () => _addApoliceDialog(
          clientId: widget.clientToEdit?.id ?? '',  // ✅ AQUI
        ),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Adicionar'),
      ),
      children: [
        if (_apolices.isEmpty)
          Center(
            child: Text(
              'Nenhuma apólice cadastrada',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          )
        else
          Column(
            children: _apolices.asMap().entries.map((entry) {
              final index = entry.key;
              final apolice = entry.value;
              final emoji = _getEmojiRamo(apolice.ramo);
              final cor = _getCorRamo(apolice.ramo);
              
              // Etapa 07: clicar na apólice abre a visualização (sem edição).
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _addApoliceDialog(
                  clientId: widget.clientToEdit?.id ?? '',
                  apoliceToEdit: apolice,
                  indexToUpdate: index,
                  somenteLeitura: true,
                ),
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
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: cor, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _addApoliceDialog(
                                clientId: widget.clientToEdit?.id ?? '',  // ✅ AQUI
                                apoliceToEdit: apolice,
                                indexToUpdate: index,
                              ),                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () async {
                              final confirmar = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remover apólice'),
                                  content: Text('Remover apólice de ${apolice.ramo}?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Remover', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmar == true) setState(() => _apolices.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Detalhes de Bens Segurados
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

                          // 🔥 NOVO: LISTA DE BENS SEGURADOS
                          if (apolice.bensSegurados.isNotEmpty) ...[
                            const Divider(height: 16, thickness: 0.5),
                            const Text(
                              'Bens Segurados',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            ...apolice.bensSegurados.take(3).map((bem) => Padding(
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
                                  // Linha superior: descrição + tipo
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          bem.descricao,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getCorRamo(bem.tipo).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          bem.tipo,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: _getCorRamo(bem.tipo),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Detalhes do bem (varia por ramo)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      // ═══ VEÍCULO INDIVIDUAL ═══
                                      if (bem.tipo == 'Veículo Individual') ...[
                                        if (bem.placa != null && bem.placa!.isNotEmpty)
                                          _buildDetailChip('${bem.placa}'),
                                        if (bem.marca != null && bem.marca!.isNotEmpty)
                                          _buildDetailChip('${bem.marca}'),
                                        if (bem.modelo != null && bem.modelo!.isNotEmpty)
                                          _buildDetailChip('${bem.modelo}'),
                                        if (bem.cor != null && bem.cor!.isNotEmpty)
                                          _buildDetailChip('${bem.cor}'),
                                        if (bem.ano != null && bem.ano! > 0)
                                          _buildDetailChip('${bem.ano}'),
                                        if (bem.anoModelo != null && bem.anoModelo! > 0)
                                          _buildDetailChip('${bem.anoModelo}'),
                                      ],

                                      // ═══ Civil Ônibus (RCO) ═══
                                      if (bem.tipo == 'Civil Ônibus (RCO)') ...[
                                        if (bem.placa != null && bem.placa!.isNotEmpty)
                                          _buildDetailChip('${bem.placa}'),
                                        if (bem.marca != null && bem.marca!.isNotEmpty)
                                          _buildDetailChip('${bem.marca}'),
                                        if (bem.modelo != null && bem.modelo!.isNotEmpty)
                                          _buildDetailChip('${bem.modelo}'),
                                        if (bem.cor != null && bem.cor!.isNotEmpty)
                                          _buildDetailChip('${bem.cor}'),
                                        if (bem.ano != null && bem.ano! > 0)
                                          _buildDetailChip('${bem.ano}'),
                                        if (bem.anoModelo != null && bem.anoModelo! > 0)
                                          _buildDetailChip('${bem.anoModelo}'),
                                      ],

                                      // ═══ FROTA ═══
                                      if (bem.tipo == 'Frota') ...[
                                        if (bem.placaCavalo != null && bem.placaCavalo!.isNotEmpty)
                                          _buildDetailChip('🐴 ${bem.placaCavalo}'),
                                        if (bem.marcaCavalo != null && bem.marcaCavalo!.isNotEmpty)
                                          _buildDetailChip('${bem.marcaCavalo}'),
                                        if (bem.modeloCavalo != null && bem.modeloCavalo!.isNotEmpty)
                                          _buildDetailChip('${bem.modeloCavalo}'),
                                        if (bem.placaCarreta != null && bem.placaCarreta!.isNotEmpty)
                                          _buildDetailChip('🚛 ${bem.placaCarreta}'),
                                        if (bem.marcaCarreta != null && bem.marcaCarreta!.isNotEmpty)
                                          _buildDetailChip('${bem.marcaCarreta}'),
                                        if (bem.modeloCarreta != null && bem.modeloCarreta!.isNotEmpty)
                                          _buildDetailChip('${bem.modeloCarreta}'),
                                      ],

                                      // ═══ MÁQUINAS ═══
                                      if (bem.tipo == 'Máquinas') ...[
                                        if (bem.modeloEquipamento != null && bem.modeloEquipamento!.isNotEmpty)
                                          _buildDetailChip('${bem.modeloEquipamento}'),
                                        if (bem.numeroSerie != null && bem.numeroSerie!.isNotEmpty)
                                          _buildDetailChip('SN: ${bem.numeroSerie}'),
                                        if (bem.fabricante != null && bem.fabricante!.isNotEmpty)
                                          _buildDetailChip('${bem.fabricante}'),
                                      ],

                                      // ═══ EMPRESARIAL ═══
                                      if (bem.tipo == 'Empresarial') ...[
                                        // Prioriza campos diretos
                                        if (bem.nomeEmpresa != null && bem.nomeEmpresa!.isNotEmpty)
                                          _buildDetailChip(bem.nomeEmpresa!),
                                        if (bem.enderecoEmpresa != null && bem.enderecoEmpresa!.isNotEmpty)
                                          _buildDetailChip(bem.enderecoEmpresa!),
                                        if (bem.cnpjEmpresa != null && bem.cnpjEmpresa!.isNotEmpty)
                                          _buildDetailChip('CNPJ: ${bem.cnpjEmpresa}'),
                                        // Fallback para businessData (bens antigos)
                                        if ((bem.nomeEmpresa == null || bem.nomeEmpresa!.isEmpty) && bem.businessData != null) ...[
                                          if (bem.businessData!.nomeEmpresa.isNotEmpty)
                                            _buildDetailChip(bem.businessData!.nomeEmpresa),
                                          if (bem.businessData!.enderecoEmpresa.isNotEmpty)
                                            _buildDetailChip(bem.businessData!.enderecoEmpresa),
                                          if (bem.businessData!.cnpjEmpresa.isNotEmpty)
                                            _buildDetailChip('CNPJ: ${bem.businessData!.cnpjEmpresa}'),
                                        ],
                                      ],

                                      // ═══ RESIDENCIAL ═══
                                      if (bem.tipo == 'Residencial') ...[
                                        if (bem.logradouro != null && bem.logradouro!.isNotEmpty)
                                          _buildDetailChip('${bem.logradouro}, ${bem.numero ?? ''}'),
                                        if (bem.bairro != null && bem.bairro!.isNotEmpty)
                                          _buildDetailChip('${bem.bairro}'),
                                        if (bem.cidade != null && bem.cidade!.isNotEmpty)
                                          _buildDetailChip('${bem.cidade}'),
                                      ],

                                      // ═══ VIDA ═══
                                      if (bem.tipo == 'Vida') ...[
                                        if (bem.cpfVida != null && bem.cpfVida!.isNotEmpty)
                                          _buildDetailChip('CPF: ${bem.cpfVida}'),
                                        if (bem.capitalSegurado != null && bem.capitalSegurado! > 0)
                                          _buildDetailChip('Capital: ${BRFormatters.formatarMoeda(bem.capitalSegurado!)}'),
                                      ],
                                    ],
                                  ),

                                  // Proprietário (se existir)
                                  if (bem.proprietarioNome != null && bem.proprietarioNome!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Proprietário: ${bem.proprietarioNome}',
                                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          )),
                            if (apolice.bensSegurados.length > 3)
                              Text(
                                '+ ${apolice.bensSegurados.length - 3} outro(s)',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _addBemDialog({
    required String ramo,
    required String clientId,
    required String apoliceId,
    required Function(BemSegurado) onBemAdded,
    BemSegurado? bemToEdit,
  }) {
    // Determina se o bem existente é Cavalo ou Carreta
    String tipoFrotaInicial = 'Cavalo';
    if (bemToEdit != null && bemToEdit.tipo == 'Frota') {
      if (bemToEdit.placaCavalo != null && bemToEdit.placaCavalo!.isNotEmpty) {
        tipoFrotaInicial = 'Cavalo';
      } else if (bemToEdit.placaCarreta != null && bemToEdit.placaCarreta!.isNotEmpty) {
        tipoFrotaInicial = 'Carreta';
      }
    }

    // Função auxiliar para obter o valor correto ao editar
    String getValor(String? generico, String? cavalo, String? carreta) {
      if (generico != null && generico.isNotEmpty) return generico;
      if (tipoFrotaInicial == 'Cavalo' && cavalo != null && cavalo.isNotEmpty) return cavalo;
      if (tipoFrotaInicial == 'Carreta' && carreta != null && carreta.isNotEmpty) return carreta;
      return '';
    }

    final numeroDocumentoCtrl = TextEditingController(text: bemToEdit?.numeroDocumento ?? '');

    final descricaoCtrl = TextEditingController(text: bemToEdit?.descricao ?? '');
    final placaCtrl = TextEditingController(
      text: getValor(bemToEdit?.placa, bemToEdit?.placaCavalo, bemToEdit?.placaCarreta)
    );
    final marcaCtrl = TextEditingController(
      text: getValor(bemToEdit?.marca, bemToEdit?.marcaCavalo, bemToEdit?.marcaCarreta)
    );
    final modeloCtrl = TextEditingController(
      text: getValor(bemToEdit?.modelo, bemToEdit?.modeloCavalo, bemToEdit?.modeloCarreta)
    );
    final anoCtrl = TextEditingController(
      text: getValor(
        bemToEdit?.ano?.toString(), 
        bemToEdit?.anoCavalo?.toString(), 
        bemToEdit?.anoCarreta?.toString()
      )
    );
    final anoModeloCtrl = TextEditingController(
      text: getValor(
        bemToEdit?.anoModelo?.toString(), 
        bemToEdit?.anoModeloCavalo?.toString(), 
        bemToEdit?.anoModeloCarreta?.toString()
      )
    );
    final corCtrl = TextEditingController(
      text: getValor(bemToEdit?.cor, null, null) // cor não tem específico
    );
    final chassiCtrl = TextEditingController(
      text: getValor(bemToEdit?.chassi, bemToEdit?.chassiCavalo, bemToEdit?.chassiCarreta)
    );
    final proprietarioNomeCtrl = TextEditingController(
      text: getValor(bemToEdit?.proprietarioNome, null, null)
    );
    final proprietarioCPFCtrl = TextEditingController(
      text: getValor(bemToEdit?.proprietarioCPF, null, null)
    );

    // Equipamento
    final modeloEquipCtrl = TextEditingController(text: bemToEdit?.modeloEquipamento ?? '');
    final numeroSerieCtrl = TextEditingController(text: bemToEdit?.numeroSerie ?? '');
    final fabricanteCtrl = TextEditingController(text: bemToEdit?.fabricante ?? '');

    // Endereço
    final logradouroCtrl = TextEditingController(text: bemToEdit?.logradouro ?? '');
    final numeroCtrl = TextEditingController(text: bemToEdit?.numero ?? '');
    final complementoCtrl = TextEditingController(text: bemToEdit?.complemento ?? '');
    final bairroCtrl = TextEditingController(text: bemToEdit?.bairro ?? '');
    final cidadeCtrl = TextEditingController(text: bemToEdit?.cidade ?? '');
    final estadoCtrl = TextEditingController(text: bemToEdit?.estado ?? '');
    final cepCtrl = TextEditingController(text: bemToEdit?.cep ?? '');

    // ✨ NOVO: Empresarial
    final nomeEmpresaCtrl = TextEditingController(
      text: bemToEdit?.businessData?.nomeEmpresa ?? bemToEdit?.nomeEmpresa ?? ''
    );
    final cnpjEmpresaCtrl = TextEditingController(
      text: bemToEdit?.businessData?.cnpjEmpresa ?? bemToEdit?.cnpjEmpresa ?? ''
    );
    final enderecoEmpresaCtrl = TextEditingController(
      text: bemToEdit?.businessData?.enderecoEmpresa ?? bemToEdit?.enderecoEmpresa ?? ''
    );
    final ramoAtividadeCtrl = TextEditingController(text: bemToEdit?.businessData?.ramoAtividade ?? '');
    final numeroCnaeCtrl = TextEditingController(text: bemToEdit?.businessData?.numeroCnae ?? '');
    final anoFundacaoCtrl = TextEditingController(text: bemToEdit?.businessData?.anoFundacao?.toString() ?? '');
    final descricaoImovelCtrl = TextEditingController(text: bemToEdit?.businessData?.descricaoImovel ?? '');
    final areaM2Ctrl = TextEditingController(text: bemToEdit?.businessData?.areaM2?.toString() ?? '');
    final tipoEstruturaCtrl = TextEditingController(text: bemToEdit?.businessData?.tipoEstrutura ?? '');
    final numeroAndaresCtrl = TextEditingController(text: bemToEdit?.businessData?.numeroAndares?.toString() ?? '');
    final sistemaSegurancaCtrl = TextEditingController(text: bemToEdit?.businessData?.sistemaSeguranca ?? '');
    final situacaoImovelCtrl = TextEditingController(text: bemToEdit?.businessData?.situacaoImovel ?? '');

    // Vida
    final cpfVidaCtrl = TextEditingController(text: bemToEdit?.cpfVida ?? '');
    DateTime? dataVida = bemToEdit?.dataVida;
    final capitalCtrl = TextEditingController(text: bemToEdit?.capitalSegurado?.toString() ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        List<PlatformFile> crlvArquivos = [];
        bool isUploadingCRLV = false;
        String tipoFrotaSelecionado = tipoFrotaInicial;
        List<PlatformFile> documentosArquivos = [];
        bool isUploadingDocumentos = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CABEÇALHO
                      Text(
                        '${bemToEdit == null ? 'Adicionar' : 'Editar'} ${ramo == 'Frota' ? 'Veículos (Cavalo OU Carreta)' : ramo}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CONTEÚDO
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // ═══ SCAN CRLV ═══
                              if (ramo == 'Veículo Individual' || ramo == 'Frota' || ramo == 'Civil Ônibus (RCO)') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Text('📄 CRLV do Veículo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    const Spacer(),
                                    // 🔥 Botão só aparece se NÃO houver arquivo já importado
                                    if (crlvArquivos.isEmpty)
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          final result = await FilePicker.platform.pickFiles(
                                            type: FileType.custom,
                                            allowedExtensions: ['pdf'],
                                            allowMultiple: false,
                                          );
                                          if (result != null) {
                                            try {
                                              final file = result.files.single;
                                              final texto = await _extractText(file);
                                              final parsedData = parseCRLV(texto);
                                              final condutor = parseCondutorFromCRLV(texto);

                                              setModalState(() {
                                                // Preenche os campos
                                                placaCtrl.text = parsedData['placa'] ?? '';
                                                marcaCtrl.text = parsedData['marca'] ?? '';
                                                modeloCtrl.text = parsedData['modelo'] ?? '';
                                                anoCtrl.text = parsedData['ano'] ?? '';
                                                anoModeloCtrl.text = parsedData['anoModelo'] ?? '';
                                                corCtrl.text = parsedData['cor'] ?? '';
                                                chassiCtrl.text = parsedData['chassi'] ?? '';
                                                proprietarioNomeCtrl.text = condutor['nome'] ?? '';
                                                proprietarioCPFCtrl.text = condutor['cpf'] ?? '';
                                                // 🔥 Adiciona o arquivo à lista persistente
                                                crlvArquivos.add(file);
                                              });

                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('✅ CRLV processado com sucesso'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('❌ Erro: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.upload_file),
                                        label: const Text('Importar CRLV'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue.shade100,
                                          foregroundColor: Colors.blue.shade900,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 🔥 LISTA DE CRLV IMPORTADOS (aparece quando há arquivos)
                                if (crlvArquivos.isNotEmpty)
                                  Column(
                                    children: crlvArquivos.map((arquivo) => Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.green.shade300),
                                        borderRadius: BorderRadius.circular(8),
                                        color: Colors.green.shade50,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.picture_as_pdf, color: Colors.red.shade700),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              arquivo.name,
                                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.close, size: 18, color: Colors.red.shade700),
                                            onPressed: () => setModalState(() => crlvArquivos.remove(arquivo)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    )).toList(),
                                  ),
                                const SizedBox(height: 12),
                              ],

                              // ═══ PROPRIETÁRIO ═══
                              if (ramo == 'Veículo Individual' || ramo == 'Frota' || ramo == 'Civil Ônibus (RCO)') ...[
                                const SizedBox(height: 12),
                                const Text('👤 Proprietário', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: proprietarioNomeCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Nome do Proprietário',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: proprietarioCPFCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'CPF do Proprietário',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    BRFormatters.cpfFormatter,
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],

                              // ═══ VEÍCULO INDIVIDUAL ═══ (seus campos, mantidos)
                              if (ramo == 'Veículo Individual' || ramo == 'Civil Ônibus (RCO)') ...[
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: placaCtrl,
                                        decoration: InputDecoration(labelText: 'Placa', border: OutlineInputBorder()),
                                        textCapitalization: TextCapitalization.characters,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: marcaCtrl,
                                        decoration: InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: modeloCtrl,
                                        decoration: InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                   Expanded(
                                      child: TextField(
                                        controller: corCtrl,
                                        decoration: InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: anoCtrl,
                                        decoration: InputDecoration(labelText: 'Ano Fabricação', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: anoModeloCtrl,
                                        decoration: InputDecoration(labelText: 'Ano Modelo', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: chassiCtrl,
                                  decoration: InputDecoration(labelText: 'Chassi', border: OutlineInputBorder()),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                              ],

                              if (ramo == 'Frota') ...[
                                const SizedBox(height: 12),
                                const Text('🚛 Tipo de Veículo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(value: 'Cavalo', label: Text('Cavalo')),
                                    ButtonSegment(value: 'Carreta', label: Text('Carreta')),
                                  ],
                                  selected: {tipoFrotaSelecionado},
                                  onSelectionChanged: (Set<String> newSelection) {
                                    setModalState(() {
                                      tipoFrotaSelecionado = newSelection.first;
                                    });
                                  },
                                  style: ButtonStyle(
                                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return Colors.blue.shade100;
                                      }
                                      return Colors.grey.shade200;
                                    }),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Campos genéricos (comuns a ambos)
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: placaCtrl,
                                        decoration: InputDecoration(labelText: 'Placa', border: OutlineInputBorder()),
                                        textCapitalization: TextCapitalization.characters,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: marcaCtrl,
                                        decoration: InputDecoration(labelText: 'Marca', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: modeloCtrl,
                                        decoration: InputDecoration(labelText: 'Modelo', border: OutlineInputBorder()),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                      Expanded(
                                      child: TextField(
                                        controller: corCtrl,
                                        decoration: InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                  Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: anoCtrl,
                                        decoration: InputDecoration(labelText: 'Ano Fabricação', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),  
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: anoModeloCtrl,
                                        decoration: InputDecoration(labelText: 'Ano Modelo', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: chassiCtrl,
                                  decoration: InputDecoration(labelText: 'Chassi', border: OutlineInputBorder()),
                                  textCapitalization: TextCapitalization.characters,
                                ),
                                const SizedBox(height: 12),
                              ],

                              // --- RESIDENCIAL ----
                              if (ramo == 'Residencial') ...[
                                const SizedBox(height: 12),
                                const Text('🏠 Dados do Imóvel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                
                                // Logradouro
                                TextField(
                                  controller: logradouroCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Logradouro',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // Número + Complemento
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: numeroCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Número',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: complementoCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Complemento',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Bairro + Cidade
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: bairroCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Bairro',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: cidadeCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Cidade',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Estado + CEP
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: estadoCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Estado',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        textCapitalization: TextCapitalization.characters,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: cepCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'CEP',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          BRFormatters.cepFormatter,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Número do Documento (novo campo)
                                TextField(
                                  controller: numeroDocumentoCtrl, // você precisa criar este controller
                                  decoration: InputDecoration(
                                    labelText: 'Número do Documento (Matrícula/Escritura)',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    helperText: 'Ex: Matrícula do imóvel, número da escritura',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // 📎 Documentos Anexos
                                _buildDocumentUploadSection(
                                  titulo: 'Documentos do Imóvel',
                                  arquivos: documentosArquivos,
                                  isUploading: isUploadingDocumentos,
                                  onAdd: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      allowMultiple: true,
                                      type: FileType.any,
                                    );
                                    if (result != null) {
                                      setModalState(() {
                                        documentosArquivos.addAll(result.files);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('📎 ${result.files.length} documento(s) adicionado(s)'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  onRemove: (index) {
                                    setModalState(() {
                                      documentosArquivos.removeAt(index);
                                    });
                                  },
                                ),
                              ],

                              // --- EMPRESARIAL ----
                              if (ramo == 'Empresarial') ...[
                                const SizedBox(height: 12),
                                const Text('🏢 Dados da Empresa', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                
                                // NOME E CNPJ
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: nomeEmpresaCtrl,
                                        decoration: InputDecoration(labelText: 'Nome da Unidade', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // ENDEREÇO
                                TextField(
                                  controller: enderecoEmpresaCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Endereço da Empresa',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    prefixIcon: const Icon(Icons.location_on_outlined),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () async {
                                        final endereco = await _openPlaceSearch();
                                        if (endereco != null) {
                                          enderecoEmpresaCtrl.text = endereco;
                                        }
                                      },
                                    ),
                                  ),
                                  readOnly: true,
                                ),
                                const SizedBox(height: 12),
                                
                                // RAMO E ANO FUNDAÇÃO
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: ramoAtividadeCtrl,
                                        decoration: InputDecoration(labelText: 'Ramo de Atividade', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: anoFundacaoCtrl,
                                        decoration: InputDecoration(labelText: 'Ano de Fundação', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                // DESCRIÇÃO DO IMÓVEL
                                TextField(
                                  controller: descricaoCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Descrição do Bem',
                                      hintText: 'Ex: Prédio comercial, fábrica, etc',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    maxLines: 2,
                                  ),
                                const SizedBox(height: 12),
                                
                                // ÁREA E TIPO ESTRUTURA
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: areaM2Ctrl,
                                        decoration: InputDecoration(labelText: 'Área (m²)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: tipoEstruturaCtrl,
                                        decoration: InputDecoration(labelText: 'Tipo de Estrutura', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // ANDARES E SEGURANÇA
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: numeroAndaresCtrl,
                                        decoration: InputDecoration(labelText: 'Número de Andares', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: sistemaSegurancaCtrl,
                                        decoration: InputDecoration(labelText: 'Sistema de Segurança', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // SITUAÇÃO
                                TextField(
                                  controller: situacaoImovelCtrl,
                                  decoration: InputDecoration(labelText: 'Situação (Próprio/Alugado)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                                ),

                                // ANEXOS
                                const SizedBox(height: 16),

                                // 📎 Documentos da Empresa
                                _buildDocumentUploadSection(
                                  titulo: 'Documentos da Empresa',
                                  arquivos: documentosArquivos,
                                  isUploading: isUploadingDocumentos,
                                  onAdd: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      allowMultiple: true,
                                      type: FileType.any,
                                    );
                                    if (result != null) {
                                      setModalState(() {
                                        documentosArquivos.addAll(result.files);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('📎 ${result.files.length} documento(s) adicionado(s)'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  onRemove: (index) {
                                    setModalState(() {
                                      documentosArquivos.removeAt(index);
                                    });
                                  },
                                ),
                              ],

                              // --- VIDAS ---
                              if (ramo == 'Vida') ...[
                                const SizedBox(height: 12),
                                const Text('👤 Dados do Segurado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 8),
                                
                                // Nome (usa descricaoCtrl)
                                TextField(
                                  controller: descricaoCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Nome do Segurado',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                
                                // CPF
                                TextField(
                                  controller: cpfVidaCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'CPF do Segurado',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    BRFormatters.cpfFormatter,
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Data de Nascimento
                                ListTile(
                                  title: Text(
                                    dataVida == null
                                        ? 'Data de Nascimento'
                                        : DateFormat('dd/MM/yyyy').format(dataVida!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: dataVida == null ? Colors.grey : Colors.black,
                                      fontWeight: dataVida == null ? FontWeight.normal : FontWeight.w600,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.calendar_today, size: 20),
                                  tileColor: Colors.grey.shade50,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: dataVida ?? DateTime(1990),
                                      firstDate: DateTime(1900),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setModalState(() => dataVida = picked);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                
                                // Endereço do Segurado (pode usar os mesmos controllers de endereço)
                                const Text('📍 Endereço do Segurado', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: logradouroCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Logradouro',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: numeroCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Número',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: complementoCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Complemento',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: bairroCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Bairro',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: cidadeCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Cidade',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: estadoCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Estado',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        textCapitalization: TextCapitalization.characters,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
                                          LengthLimitingTextInputFormatter(2),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 1,
                                      child: TextField(
                                        controller: cepCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'CEP',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          BRFormatters.cepFormatter,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                
                                // Capital Segurado
                                TextField(
                                  controller: capitalCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Capital Segurado',
                                    prefixText: 'R\$ ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    BRFormatters.moedaFormatter,
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // 📎 Documentos Anexos
                                _buildDocumentUploadSection(
                                  titulo: 'Documentos do Segurado',
                                  arquivos: documentosArquivos,
                                  isUploading: isUploadingDocumentos,
                                  onAdd: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      allowMultiple: true,
                                      type: FileType.any,
                                    );
                                    if (result != null) {
                                      setModalState(() {
                                        documentosArquivos.addAll(result.files);
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('📎 ${result.files.length} documento(s) adicionado(s)'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  onRemove: (index) {
                                    setModalState(() {
                                      documentosArquivos.removeAt(index);
                                    });
                                  },
                                ),
                              ],

                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // BOTÕES
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Cancelar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isUploadingCRLV || isUploadingDocumentos ? null : () async {
                                if (descricaoCtrl.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Informe a descrição')),
                                  );
                                  return;
                                }

                                // 🔥 UPLOAD DE CRLV (se houver)
                                List<String> crlvUrls = [];
                                if (crlvArquivos.isNotEmpty) {
                                  setModalState(() => isUploadingCRLV = true);
                                  try {
                                    crlvUrls = await _firestoreService.uploadCRLV(
                                      clientId,
                                      apoliceId,
                                      const Uuid().v4(), // bemId
                                      crlvArquivos,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ CRLV(s) enviado(s) com sucesso'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('❌ Erro ao enviar CRLV: $e')),
                                    );
                                    setModalState(() => isUploadingCRLV = false);
                                    return;
                                  }
                                  setModalState(() => isUploadingCRLV = false);
                                }

                                // 🔥 UPLOAD DE DOCUMENTOS ANEXOS (Residencial/Vida)
                                List<String> documentosUrls = [];
                                if (documentosArquivos.isNotEmpty) {
                                  setModalState(() => isUploadingDocumentos = true);
                                  try {
                                    documentosUrls = await _firestoreService.uploadDocumentosBem(
                                      clientId,
                                      apoliceId,
                                      const Uuid().v4(), // bemId
                                      documentosArquivos,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Documento(s) anexado(s) com sucesso'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('❌ Erro ao enviar documentos: $e')),
                                    );
                                    setModalState(() => isUploadingDocumentos = false);
                                    return;
                                  }
                                  setModalState(() => isUploadingDocumentos = false);
                                }

                                // 🔥 CRIAÇÃO DO BEM
                                final novoBem = BemSegurado(
                                  id: bemToEdit?.id ?? const Uuid().v4(),
                                  tipo: ramo,
                                  descricao: descricaoCtrl.text,
                                  dataCadastro: bemToEdit?.dataCadastro ?? DateTime.now(),

                                  // Veículo (campos comuns)
                                  placa: placaCtrl.text.isNotEmpty ? placaCtrl.text : null,
                                  marca: marcaCtrl.text.isNotEmpty ? marcaCtrl.text : null,
                                  modelo: modeloCtrl.text.isNotEmpty ? modeloCtrl.text : null,
                                  ano: int.tryParse(anoCtrl.text),
                                  anoModelo: int.tryParse(anoModeloCtrl.text),
                                  cor: corCtrl.text.isNotEmpty ? corCtrl.text : null,
                                  chassi: chassiCtrl.text.isNotEmpty ? chassiCtrl.text : null,
                                  proprietarioNome: proprietarioNomeCtrl.text.isNotEmpty ? proprietarioNomeCtrl.text : null,
                                  proprietarioCPF: proprietarioCPFCtrl.text.isNotEmpty ? proprietarioCPFCtrl.text : null,

                                  // Frota (se aplicável)
                                  tipoCavalo: (ramo == 'Frota' && tipoFrotaSelecionado == 'Cavalo') ? 'Cavalo Mecânico' : null,
                                  placaCavalo: (ramo == 'Frota' && tipoFrotaSelecionado == 'Cavalo') ? placaCtrl.text : null,
                                  marcaCavalo: (ramo == 'Frota' && tipoFrotaSelecionado == 'Cavalo') ? marcaCtrl.text : null,
                                  modeloCavalo: (ramo == 'Frota' && tipoFrotaSelecionado == 'Cavalo') ? modeloCtrl.text : null,
                                  anoCavalo: (ramo == 'Frota' && tipoFrotaSelecionado == 'Cavalo') ? int.tryParse(anoCtrl.text) : null,
                                  chassiCavalo: (ramo == 'Frota' && tipoFrotaSelecionado == 'Cavalo') ? chassiCtrl.text : null,
                                  tipoCarreta: (ramo == 'Frota' && tipoFrotaSelecionado == 'Carreta') ? 'Carreta' : null,
                                  placaCarreta: (ramo == 'Frota' && tipoFrotaSelecionado == 'Carreta') ? placaCtrl.text : null,
                                  marcaCarreta: (ramo == 'Frota' && tipoFrotaSelecionado == 'Carreta') ? marcaCtrl.text : null,
                                  modeloCarreta: (ramo == 'Frota' && tipoFrotaSelecionado == 'Carreta') ? modeloCtrl.text : null,
                                  anoCarreta: (ramo == 'Frota' && tipoFrotaSelecionado == 'Carreta') ? int.tryParse(anoCtrl.text) : null,
                                  chassiCarreta: (ramo == 'Frota' && tipoFrotaSelecionado == 'Carreta') ? chassiCtrl.text : null,

                                  // Equipamento
                                  modeloEquipamento: modeloEquipCtrl.text.isNotEmpty ? modeloEquipCtrl.text : null,
                                  numeroSerie: numeroSerieCtrl.text.isNotEmpty ? numeroSerieCtrl.text : null,
                                  fabricante: fabricanteCtrl.text.isNotEmpty ? fabricanteCtrl.text : null,

                                  // Residencial
                                  logradouro: logradouroCtrl.text.isNotEmpty ? logradouroCtrl.text : null,
                                  numero: numeroCtrl.text.isNotEmpty ? numeroCtrl.text : null,
                                  complemento: complementoCtrl.text.isNotEmpty ? complementoCtrl.text : null,
                                  bairro: bairroCtrl.text.isNotEmpty ? bairroCtrl.text : null,
                                  cidade: cidadeCtrl.text.isNotEmpty ? cidadeCtrl.text : null,
                                  estado: estadoCtrl.text.isNotEmpty ? estadoCtrl.text : null,
                                  cep: cepCtrl.text.isNotEmpty ? cepCtrl.text : null,
                                  numeroDocumento: numeroDocumentoCtrl.text.isNotEmpty ? numeroDocumentoCtrl.text : null,

                                  nomeEmpresa: nomeEmpresaCtrl.text.isNotEmpty ? nomeEmpresaCtrl.text : null,
                                  cnpjEmpresa: cnpjEmpresaCtrl.text.isNotEmpty ? cnpjEmpresaCtrl.text : null,
                                  enderecoEmpresa: enderecoEmpresaCtrl.text.isNotEmpty ? enderecoEmpresaCtrl.text : null,

                                  businessData: ramo == 'Empresarial' ? Business(
                                    id: const Uuid().v4(),
                                    nomeEmpresa: nomeEmpresaCtrl.text,
                                    cnpjEmpresa: cnpjEmpresaCtrl.text,
                                    enderecoEmpresa: enderecoEmpresaCtrl.text,
                                    ramoAtividade: ramoAtividadeCtrl.text.isNotEmpty ? ramoAtividadeCtrl.text : null,
                                    numeroCnae: numeroCnaeCtrl.text.isNotEmpty ? numeroCnaeCtrl.text : null,
                                    anoFundacao: int.tryParse(anoFundacaoCtrl.text),
                                    descricaoImovel: descricaoImovelCtrl.text.isNotEmpty ? descricaoImovelCtrl.text : null,
                                    areaM2: double.tryParse(areaM2Ctrl.text),
                                    tipoEstrutura: tipoEstruturaCtrl.text.isNotEmpty ? tipoEstruturaCtrl.text : null,
                                    numeroAndares: int.tryParse(numeroAndaresCtrl.text),
                                    sistemaSeguranca: sistemaSegurancaCtrl.text.isNotEmpty ? sistemaSegurancaCtrl.text : null,
                                    situacaoImovel: situacaoImovelCtrl.text.isNotEmpty ? situacaoImovelCtrl.text : null,
                                    anexos: documentosArquivos.map((file) => file.name).toList(),
                                  ) : null,

                                  // Vida
                                  cpfVida: cpfVidaCtrl.text.isNotEmpty ? cpfVidaCtrl.text : null,
                                  dataVida: dataVida,
                                  capitalSegurado: double.tryParse(capitalCtrl.text.replaceAll('R\$ ', '').replaceAll(',', '.')),

                                  documentosUrls: [...crlvUrls, ...documentosUrls].isNotEmpty ? [...crlvUrls, ...documentosUrls] : null,
                                );

                                onBemAdded(novoBem);
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: isUploadingCRLV
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Adicionar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Adicionar Apólice
  // Etapa 07:
  //  • valores aparecem formatados em R$ (antes vinham "120000.1" e, ao salvar sem
  //    redigitar, a leitura tirava o ponto e gravava R$ 1.200.001,00);
  //  • o gatilho é sugerido com o % das Configurações enquanto o usuário não
  //    digita o valor do contrato;
  //  • [somenteLeitura] = visualização (clicar na apólice), com botão "Editar".
  Future<void> _addApoliceDialog({
    required String clientId,
    Apolice? apoliceToEdit,
    int? indexToUpdate,
    bool somenteLeitura = false,
  }) async {
    final percentual = await ConfigService().getPercentualGatilho();
    if (!mounted) return;

    final isEditing = apoliceToEdit != null;
    String moeda(double v) => v > 0 ? BRFormatters.formatarMoeda(v) : '';

    final ramoCtrl = TextEditingController(text: apoliceToEdit?.ramo ?? '');
    final seguradoraCtrl = TextEditingController(text: apoliceToEdit?.seguradora ?? '');
    final numeroCtrl = TextEditingController(text: apoliceToEdit?.numeroApolice ?? '');
    final valorCtrl = TextEditingController(text: moeda(apoliceToEdit?.valorApolice ?? 0));
    // Gatilho do contrato, se houver; senão a sugestão (% × valor da apólice).
    bool gatilhoDoContrato = apoliceToEdit?.gatilhoInformado ?? false;
    final gatilhoCtrl = TextEditingController(
      text: gatilhoDoContrato
          ? moeda(apoliceToEdit!.valorGatilho)
          : moeda(GatilhoApolice.sugerido(apoliceToEdit?.valorApolice ?? 0, percentual)),
    );
    final textoPercentual = GatilhoApolice.formatarPercentual(percentual);
    
    DateTime? dataInicio = apoliceToEdit?.dataInicio;
    DateTime? dataFim = apoliceToEdit?.dataFim;
    List<BemSegurado> bensSegurados = List.from(apoliceToEdit?.bensSegurados ?? []);

    final dialogContext = context;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CABEÇALHO
                  Text(
                    somenteLeitura ? 'Apólice' : (isEditing ? 'Editar Apólice' : 'Adicionar Apólice'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    somenteLeitura ? 'Dados da apólice e seus bens segurados' : 'Preencha os dados da apólice e seus bens segurados',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // RAMO
                          DropdownButtonFormField<String>(
                            value: ramoCtrl.text.isEmpty ? null : ramoCtrl.text,
                            decoration: InputDecoration(
                              labelText: 'Ramo',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              prefixIcon: ramoCtrl.text.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(_getEmojiRamo(ramoCtrl.text), style: const TextStyle(fontSize: 18)),
                                    )
                                  : null,
                            ),
                            items: [
                              'Frota',
                              'Veículo Individual',
                              'Civil Ônibus (RCO)',
                              'Transporte',
                              'Máquinas',
                              'Residencial',
                              'Empresarial',
                              'Vida',
                            ]
                                .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Row(
                                    children: [
                                      Text(_getEmojiRamo(r), style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text(r),
                                    ],
                                  ),
                                ))
                                .toList(),
                            onChanged: somenteLeitura
                                ? null
                                : (val) {
                                    setModalState(() => ramoCtrl.text = val ?? '');
                                  },
                          ),
                          const SizedBox(height: 12),

                          // SEGURADORA (com autocomplete)
                          Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return const Iterable<String>.empty();
                              }
                              return _seguradoras.where((option) =>
                                option.toLowerCase().contains(textEditingValue.text.toLowerCase())
                              );
                            },
                            onSelected: (String selection) {
                              setModalState(() => seguradoraCtrl.text = selection);
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              textEditingController.text = seguradoraCtrl.text;
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                readOnly: somenteLeitura,
                                decoration: InputDecoration(
                                  labelText: 'Seguradora',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (val) => seguradoraCtrl.text = val,
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // NÚMERO DA APÓLICE
                          TextField(
                            controller: numeroCtrl,
                            readOnly: somenteLeitura,
                            decoration: InputDecoration(
                              labelText: 'Número da Apólice',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // VALOR DA APÓLICE E GATILHO (lado a lado)
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: valorCtrl,
                                  readOnly: somenteLeitura,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Valor da Apólice',
                                    hintText: 'R\$ 0,00',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    BRFormatters.moedaFormatter,
                                  ],
                                  onChanged: (v) {
                                    // Sugere o gatilho enquanto não há valor do contrato
                                    if (!gatilhoDoContrato) {
                                      setModalState(() {
                                        gatilhoCtrl.text = moeda(
                                          GatilhoApolice.sugerido(GatilhoApolice.lerMoeda(v), percentual),
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: gatilhoCtrl,
                                  readOnly: somenteLeitura,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Valor do Gatilho',
                                    hintText: 'R\$ 0,00',
                                    helperText: gatilhoDoContrato
                                        ? 'Valor do contrato'
                                        : '$textoPercentual% do valor da apólice${somenteLeitura ? '' : ' — pode alterar'}',
                                    helperMaxLines: 2,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    BRFormatters.moedaFormatter,
                                  ],
                                  onChanged: (v) {
                                    // Digitou = valor do contrato. Apagou = volta a sugerir.
                                    setModalState(() {
                                      gatilhoDoContrato = v.trim().isNotEmpty;
                                      if (!gatilhoDoContrato) {
                                        gatilhoCtrl.text = moeda(
                                          GatilhoApolice.sugerido(GatilhoApolice.lerMoeda(valorCtrl.text), percentual),
                                        );
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // DATA DE INÍCIO E DATA DE FIM (lado a lado)
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    dataInicio == null
                                        ? 'Data de Início'
                                        : DateFormat('dd/MM/yyyy').format(dataInicio!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: dataInicio == null ? Colors.grey : Colors.black,
                                      fontWeight: dataInicio == null ? FontWeight.normal : FontWeight.w600,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.calendar_today, size: 20),
                                  tileColor: Colors.grey.shade50,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onTap: somenteLeitura ? null : () async {
                                    final picked = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: dataInicio ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      locale: const Locale('pt', 'BR'), // ✨ PORTUGUÊS
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        dataInicio = picked;
                                        // ✨ AUTO-PREENCHER DATA FIM COM +1 ANO
                                        dataFim = picked.add(const Duration(days: 365));
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    dataFim == null
                                        ? 'Data de Fim'
                                        : DateFormat('dd/MM/yyyy').format(dataFim!),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: dataFim == null ? Colors.grey : Colors.black,
                                      fontWeight: dataFim == null ? FontWeight.normal : FontWeight.w600,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.calendar_today, size: 20),
                                  tileColor: Colors.grey.shade50,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  onTap: somenteLeitura ? null : () async {
                                    final picked = await showDatePicker(
                                      context: dialogContext,
                                      initialDate: dataFim ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      locale: const Locale('pt', 'BR'), // ✨ PORTUGUÊS
                                    );
                                    if (picked != null) {
                                      setModalState(() => dataFim = picked);
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),         
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 12),

                          // ═══ SEÇÃO DE BENS SEGURADOS ═══
                          Row(
                            children: [
                              const Text(
                                'Bens Segurados',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              if (!somenteLeitura && ramoCtrl.text.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () => _addBemDialog(
                                    ramo: ramoCtrl.text,
                                    clientId: clientId,
                                    apoliceId: apoliceToEdit?.id ?? const Uuid().v4(),
                                    onBemAdded: (bem) {
                                      setModalState(() => bensSegurados.add(bem));
                                    },
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Adicionar Bem'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (bensSegurados.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  'Nenhum bem cadastrado',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: bensSegurados.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final bem = entry.value;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Detalhes do bem (já existentes)
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                // ═══ VEÍCULO INDIVIDUAL ═══
                                                if (bem.tipo == 'Veículo Individual') ...[
                                                  if (bem.placa != null && bem.placa!.isNotEmpty)
                                                    _buildDetailChip('${bem.placa}'),
                                                  if (bem.marca != null && bem.marca!.isNotEmpty)
                                                    _buildDetailChip('${bem.marca}'),
                                                  if (bem.modelo != null && bem.modelo!.isNotEmpty)
                                                    _buildDetailChip('${bem.modelo}'),
                                                  if (bem.cor != null && bem.cor!.isNotEmpty)
                                                    _buildDetailChip('${bem.cor}'),
                                                  if (bem.ano != null && bem.ano! > 0)
                                                    _buildDetailChip('${bem.ano}'),
                                                  if (bem.anoModelo != null && bem.anoModelo! > 0)
                                                    _buildDetailChip('${bem.anoModelo}'),
                                                ],

                                                // ═══ CIVIL ÔNIBUS (RCO) ═══
                                                if (bem.tipo == 'Civil Ônibus (RCO)') ...[
                                                  if (bem.placa != null && bem.placa!.isNotEmpty)
                                                    _buildDetailChip('${bem.placa}'),
                                                  if (bem.marca != null && bem.marca!.isNotEmpty)
                                                    _buildDetailChip('${bem.marca}'),
                                                  if (bem.modelo != null && bem.modelo!.isNotEmpty)
                                                    _buildDetailChip('${bem.modelo}'),
                                                  if (bem.cor != null && bem.cor!.isNotEmpty)
                                                    _buildDetailChip('${bem.cor}'),
                                                  if (bem.ano != null && bem.ano! > 0)
                                                    _buildDetailChip('${bem.ano}'),
                                                  if (bem.anoModelo != null && bem.anoModelo! > 0)
                                                    _buildDetailChip('${bem.anoModelo}'),
                                                ],

                                                // ═══ FROTA ═══
                                                if (bem.tipo == 'Frota') ...[
                                                  if (bem.placaCavalo != null && bem.placaCavalo!.isNotEmpty)
                                                    _buildDetailChip('${bem.placaCavalo}'),
                                                  if (bem.marcaCavalo != null && bem.marcaCavalo!.isNotEmpty)
                                                    _buildDetailChip('${bem.marcaCavalo}'),
                                                  if (bem.modeloCavalo != null && bem.modeloCavalo!.isNotEmpty)
                                                    _buildDetailChip('${bem.modeloCavalo}'),
                                                  if (bem.placaCarreta != null && bem.placaCarreta!.isNotEmpty)
                                                    _buildDetailChip('🚛 ${bem.placaCarreta}'),
                                                  if (bem.marcaCarreta != null && bem.marcaCarreta!.isNotEmpty)
                                                    _buildDetailChip('${bem.marcaCarreta}'),
                                                  if (bem.modeloCarreta != null && bem.modeloCarreta!.isNotEmpty)
                                                    _buildDetailChip('${bem.modeloCarreta}'),
                                                ],

                                                // ═══ MÁQUINAS ═══
                                                if (bem.tipo == 'Máquinas') ...[
                                                  if (bem.modeloEquipamento != null && bem.modeloEquipamento!.isNotEmpty)
                                                    _buildDetailChip('${bem.modeloEquipamento}'),
                                                  if (bem.numeroSerie != null && bem.numeroSerie!.isNotEmpty)
                                                    _buildDetailChip('SN: ${bem.numeroSerie}'),
                                                  if (bem.fabricante != null && bem.fabricante!.isNotEmpty)
                                                    _buildDetailChip('${bem.fabricante}'),
                                                ],

                                                // ═══ EMPRESARIAL ═══
                                                if (bem.tipo == 'Empresarial') ...[
                                                  // Prioriza campos diretos
                                                  if (bem.nomeEmpresa != null && bem.nomeEmpresa!.isNotEmpty)
                                                    _buildDetailChip(bem.nomeEmpresa!),
                                                  if (bem.enderecoEmpresa != null && bem.enderecoEmpresa!.isNotEmpty)
                                                    _buildDetailChip(bem.enderecoEmpresa!),
                                                  if (bem.cnpjEmpresa != null && bem.cnpjEmpresa!.isNotEmpty)
                                                    _buildDetailChip('CNPJ: ${bem.cnpjEmpresa}'),
                                                  // Fallback para businessData (bens antigos)
                                                  if ((bem.nomeEmpresa == null || bem.nomeEmpresa!.isEmpty) && bem.businessData != null) ...[
                                                    if (bem.businessData!.nomeEmpresa.isNotEmpty)
                                                      _buildDetailChip(bem.businessData!.nomeEmpresa),
                                                    if (bem.businessData!.enderecoEmpresa.isNotEmpty)
                                                      _buildDetailChip(bem.businessData!.enderecoEmpresa),
                                                    if (bem.businessData!.cnpjEmpresa.isNotEmpty)
                                                      _buildDetailChip('CNPJ: ${bem.businessData!.cnpjEmpresa}'),
                                                  ],
                                                ],

                                                // ═══ RESIDENCIAL ═══
                                                if (bem.tipo == 'Residencial') ...[
                                                  if (bem.logradouro != null && bem.logradouro!.isNotEmpty)
                                                    _buildDetailChip('${bem.logradouro}, ${bem.numero ?? ''}'),
                                                  if (bem.bairro != null && bem.bairro!.isNotEmpty)
                                                    _buildDetailChip('${bem.bairro}'),
                                                  if (bem.cidade != null && bem.cidade!.isNotEmpty)
                                                    _buildDetailChip('${bem.cidade}'),
                                                  if (bem.numeroDocumento != null && bem.numeroDocumento!.isNotEmpty)
                                                    _buildDetailChip('Doc: ${bem.numeroDocumento}'),
                                                ],

                                                // ═══ VIDA ═══
                                                if (bem.tipo == 'Vida') ...[
                                                  if (bem.descricao != null && bem.descricao.isNotEmpty)
                                                    _buildDetailChip('${bem.descricao}'),
                                                  if (bem.cpfVida != null && bem.cpfVida!.isNotEmpty)
                                                    _buildDetailChip('CPF: ${bem.cpfVida}'),
                                                  if (bem.dataVida != null)
                                                    _buildDetailChip('Nasc: ${DateFormat('dd/MM/yyyy').format(bem.dataVida!)}'),
                                                  if (bem.capitalSegurado != null && bem.capitalSegurado! > 0)
                                                    _buildDetailChip('Capital: ${BRFormatters.formatarMoeda(bem.capitalSegurado!)}'),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              bem.tipo,
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                            ),

                                            // 🔥 NOVO: EXIBIR DOCUMENTOS ANEXADOS (CRLV, etc.)
                                            if (bem.documentosUrls != null && bem.documentosUrls!.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Icon(Icons.attach_file, size: 14, color: Colors.grey),
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
                                                  // Determina ícone baseado na extensão
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
                                                    onTap: () async {
                                                      final Uri uri = Uri.parse(url);
                                                      try {
                                                        if (await canLaunchUrl(uri)) {
                                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                        } else {
                                                          await Clipboard.setData(ClipboardData(text: url));
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            const SnackBar(
                                                              content: Text('Link copiado para a área de transferência'),
                                                              backgroundColor: Colors.blue,
                                                            ),
                                                          );
                                                        }
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Erro ao abrir: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
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
                                      // Botões de editar/excluir (escondidos na visualização)
                                      if (!somenteLeitura) ...[
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 16, color: Colors.blue),
                                        onPressed: () {
                                          _addBemDialog(
                                            ramo: ramoCtrl.text,
                                            clientId: clientId,
                                            apoliceId: apoliceToEdit?.id ?? const Uuid().v4(),
                                            bemToEdit: bem,
                                            onBemAdded: (bemEditado) {
                                              setModalState(() {
                                                final index = bensSegurados.indexOf(bem);
                                                if (index != -1) {
                                                  bensSegurados[index] = bemEditado;
                                                }
                                              });
                                            },
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                                        onPressed: () {
                                          setModalState(() => bensSegurados.removeAt(idx));
                                        },
                                      ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // BOTÕES
                  if (somenteLeitura)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text('Fechar'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _addApoliceDialog(
                                clientId: clientId,
                                apoliceToEdit: apoliceToEdit,
                                indexToUpdate: indexToUpdate,
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Editar'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                        ),
                      ],
                    )
                  else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (ramoCtrl.text.isEmpty || dataInicio == null || dataFim == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Preencha os campos obrigatórios')),
                              );
                              return;
                            }
                            final novaApolice = Apolice(
                              id: apoliceToEdit?.id ?? const Uuid().v4(),
                              ramo: ramoCtrl.text,
                              seguradora: seguradoraCtrl.text,
                              numeroApolice: numeroCtrl.text,
                              dataInicio: dataInicio!,
                              dataFim: dataFim!,
                              valorApolice: GatilhoApolice.lerMoeda(valorCtrl.text),
                              valorGatilho: GatilhoApolice.lerMoeda(gatilhoCtrl.text),
                              bensSegurados: bensSegurados,  // ← NOVO
                            );

                            setState(() {
                              if (isEditing && indexToUpdate != null) {
                                _apolices[indexToUpdate] = novaApolice;
                              } else {
                                _apolices.add(novaApolice);
                              }
                            });

                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(isEditing ? 'Atualizar' : 'Salvar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
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
      color: Colors.white,  // ✨ ADICIONE ESTA LINHA
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
      'Frota': '🚛',
      'Civil Ônibus (RCO)': '🚌',
      'Transporte': '📦',
      'Máquinas': '⚙️',
      'Residencial': '🏠',
      'Vida': '💓',
      'Empresarial': '🏢',
    };
    return ramoEmojis[ramo] ?? '📋';
  }

  Color _getCorRamo(String ramo) {
    const ramoColors = {
      'Veículo Individual': Color(0xFFFFB74D),
      'Frota': Color(0xFF64B5F6),
      'Civil Ônibus (RCO)': Color(0xFF00838F),
      'Transporte': Color(0xFF81C784),
      'Máquinas': Color(0xFFA1887F),
      'Residencial': Color(0xFFE57373),
      'Empresarial': Color(0xFF424242),
      'Vida': Color(0xFFBA68C8),
    };
    return ramoColors[ramo] ?? Colors.grey;
  }

  Widget _buildDetailChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }

}