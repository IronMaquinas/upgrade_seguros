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
import 'package:upgrade_seguros/services/image_service_web.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../models/client_model.dart';
import '../models/vehicle_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdf/pdf.dart' as PDFLib;

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

  DateTime? _vigenciaInicio;
  DateTime? _vigenciaFim;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

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

      final client = widget.clientToEdit;
      if (client != null) {
        _nameController.text = client.nome;
        _cpfCnpjController.text = client.cnpjCpf;
        _emailController.text = client.email;
        _contactController.text = client.contato;
        _phoneController.text = client.contatoTelefone;
        _selectedRamos = List.from(client.ramos);
        _apolices = List.from(client.apolices);

        // Formatando valor da apólice para exibir no campo como "1.234,56"
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
    final ano = TextEditingController(text: vehicleToEdit?.ano?.toString() ?? '');
    final cor = TextEditingController(text: vehicleToEdit?.cor ?? '');
    final anomodelo = TextEditingController(text: vehicleToEdit?.anomodelo?.toString() ?? '');
    final placa = TextEditingController(text: vehicleToEdit?.placa ?? '');
    final chassi = TextEditingController(text: vehicleToEdit?.chassi ?? '');

    // ✅ Lista de fotos locais (XFile)
    final List<XFile> _vehiclePhotos = List<XFile>.from(vehicleToEdit?.fotos ?? []);

  // ✅ Adiciona as fotos do Firestore como XFile (via download)
    if (vehicleToEdit?.fotosUrls != null) {
      for (final url in vehicleToEdit!.fotosUrls!) {
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

  // ════════════════════════════════════════════════════════════════════════════════
  // BUSCAR CNPJ
  // ════════════════════════════════════════════════════════════════════════════════

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
        // PlatformFile tem bytes na web
        final bytes = file.bytes;
        if (bytes == null) throw Exception('Arquivo vazio');
        final pdfDocument = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(pdfDocument).extractText();
        return text;
      } catch (e, stackTrace) {
        print('📍 Stack trace: $stackTrace');
        return '';
      }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sair sem salvar?'),
            content: const Text('As alterações não salvas serão perdidas.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar editando'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Sair', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(title: Text(widget.clientToEdit == null ? 'Novo Cliente' : 'Editar Cliente')),
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

                        // ── Seção 1: Identificação ──────────────────────────────
                        _buildSectionCard(
                          icon: Icons.business,
                          title: 'Identificação',
                          children: [

                            // CNPJ/CPF no topo com botão de busca
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cpfCnpjController,
                                    decoration: InputDecoration(
                                      labelText: 'CNPJ / CPF',
                                      hintText: 'Digite o CNPJ para busca automática',
                                      prefixIcon: const Icon(Icons.badge_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
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
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.search),
                                    label: Text(_buscandoCNPJ ? 'Buscando...' : 'Buscar CNPJ'),
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Nome (preenchido automaticamente pelo CNPJ)
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Nome / Razão Social',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                helperText: 'Preenchido automaticamente ao buscar CNPJ',
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                            ),
                            const SizedBox(height: 16),

                            // Contato / Sócio + Telefone lado a lado
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _contactController,
                                    decoration: InputDecoration(
                                      labelText: 'Contato / Sócio',
                                      prefixIcon: const Icon(Icons.contacts_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      helperText: 'Preenchido automaticamente ao buscar CNPJ',
                                    ),
                                    //validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: 'Telefone',
                                      prefixIcon: const Icon(Icons.phone_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Email
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'E-mail',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Obrigatório' : null,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        _buildApolicesSection(),
                        const SizedBox(height: 16),

                        // ── Seção 3: Veículos ───────────────────────────────────
                        _buildSectionCard(
                          icon: Icons.directions_car_outlined,
                          title: 'Veículos Segurados',
                          trailing: TextButton.icon(
                            onPressed: _addVehicleDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Adicionar'),
                          ),
                          children: [
                            if (_vehicles.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    'Nenhum veículo cadastrado',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                                  ),
                                ),
                              )
                            else
                              Column(
                                children: _vehicles.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final vehicle = entry.value;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade200),
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [

                                        // Cabeçalho azul com marca/modelo e botões
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.directions_car, size: 18, color: Colors.blueAccent),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${vehicle.marca} ${vehicle.modelo}',
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () => _addVehicleDialog(vehicleToEdit: vehicle, indexToUpdate: index),
                                              ),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                                onPressed: () async {
                                                  final confirmar = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Remover veículo'),
                                                      content: Text('Remover ${vehicle.marca} ${vehicle.modelo}?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          child: const Text('Remover', style: TextStyle(color: Colors.red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmar == true) setState(() => _vehicles.removeAt(index));
                                                },
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Detalhes em grid
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  if (vehicle.cor.isNotEmpty)
                                                    Text('Cor: ${vehicle.cor}  •  ', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                                  Text('${vehicle.ano}/${vehicle.anomodelo}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                                  if (vehicle.placa.isNotEmpty)
                                                    Text('  •  Placa: ${vehicle.placa}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                                ],
                                              ),
                                              if (vehicle.chassi.isNotEmpty)
                                                Text('Chassi: ${vehicle.chassi}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                            ],
                                          ),
                                        ),

                                        // Fotos (mantém a lógica atual, só o container muda)
                                        if ((vehicle.fotos?.isNotEmpty ?? false) || (vehicle.fotosUrls?.isNotEmpty ?? false))
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                if (vehicle.fotosUrls != null)
                                                  ...vehicle.fotosUrls!.map((url) => GestureDetector(
                                                    onTap: () => _showImageViewer(NetworkImage(url), () {
                                                      setState(() => vehicle.fotosUrls!.remove(url));
                                                    }),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: Image.network(url, width: 64, height: 64, fit: BoxFit.cover),
                                                    ),
                                                  )),
                                                if (vehicle.fotos != null)
                                                  ...vehicle.fotos!.map((photo) => GestureDetector(
                                                    onTap: () {
                                                      final ImageProvider img = kIsWeb
                                                          ? NetworkImage(photo.path)
                                                          : FileImage(File(photo.path));
                                                      _showImageViewer(img, () => setState(() => vehicle.fotos!.remove(photo)));
                                                    },
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: kIsWeb
                                                          ? Image.network(photo.path, width: 64, height: 64, fit: BoxFit.cover)
                                                          : Image.file(File(photo.path), width: 64, height: 64, fit: BoxFit.cover),
                                                    ),
                                                  )),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),

                        const SizedBox(height: 24),

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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: _isLoading
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: _isLoading
                                        ? const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      )
    );
  }

  // HELPER CARD DE VEÍCULOS
  Widget _vehicleChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
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
              
              return Container(
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
                          if (apolice.valorGatilho > 0)
                            Text(
                              'Gatilho: ${BRFormatters.formatarMoeda(apolice.valorGatilho)}',
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

    // Controllers (já estavam fora do StatefulBuilder, ok)
    //final descricaoCtrl = TextEditingController(text: bemToEdit?.descricao ?? '');
    //final placaCtrl = TextEditingController(text: bemToEdit?.placa ?? '');
    //final marcaCtrl = TextEditingController(text: bemToEdit?.marca ?? '');
    //final modeloCtrl = TextEditingController(text: bemToEdit?.modelo ?? '');
    //final anoCtrl = TextEditingController(text: bemToEdit?.ano?.toString() ?? '');
    //final anoModeloCtrl = TextEditingController(text: bemToEdit?.anoModelo?.toString() ?? '');
    //final corCtrl = TextEditingController(text: bemToEdit?.cor ?? '');
    //final chassiCtrl = TextEditingController(text: bemToEdit?.chassi ?? '');
    //final proprietarioNomeCtrl = TextEditingController(text: bemToEdit?.proprietarioNome ?? '');
    //final proprietarioCPFCtrl = TextEditingController(text: bemToEdit?.proprietarioCPF ?? '');

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

/*
    // Frota
    final tipoCavaloCtrl = TextEditingController(text: bemToEdit?.tipoCavalo ?? '');
    final placaCavaloCtrl = TextEditingController(text: bemToEdit?.placaCavalo ?? '');
    final marcaCavaloCtrl = TextEditingController(text: bemToEdit?.marcaCavalo ?? '');
    final modeloCavaloCtrl = TextEditingController(text: bemToEdit?.modeloCavalo ?? '');
    final anoCavaloCtrl = TextEditingController(text: bemToEdit?.anoCavalo?.toString() ?? '');
    final tipoCarretaCtrl = TextEditingController(text: bemToEdit?.tipoCarreta ?? '');
    final placaCarretaCtrl = TextEditingController(text: bemToEdit?.placaCarreta ?? '');
    final marcaCarretaCtrl = TextEditingController(text: bemToEdit?.marcaCarreta ?? '');
    final modeloCarretaCtrl = TextEditingController(text: bemToEdit?.modeloCarreta ?? '');
    final anoCarretaCtrl = TextEditingController(text: bemToEdit?.anoCarreta?.toString() ?? '');
*/
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

    // Vida
    final cpfVidaCtrl = TextEditingController(text: bemToEdit?.cpfVida ?? '');
    DateTime? dataVida = bemToEdit?.dataVida;
    final capitalCtrl = TextEditingController(text: bemToEdit?.capitalSegurado?.toString() ?? '');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        // ════════════════════════════════════════════════════
        // 🔥 VARIÁVEIS QUE PERSISTEM ENTRE REBUILDS
        // ════════════════════════════════════════════════════
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
                        '${bemToEdit == null ? 'Adicionar' : 'Editar'} ${ramo == 'Frota' ? 'Veículos (Cavalo + Carreta)' : ramo}',
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
                              // DESCRIÇÃO
                              TextField(
                                controller: descricaoCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Descrição/Identificação',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  helperText: 'Ex: Carro branco, Caminhão azul, etc',
                                ),
                              ),
                              const SizedBox(height: 12),

                              // ═══ SCAN CRLV ═══
                              if (ramo == 'Veículo Individual' || ramo == 'Frota') ...[
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
                              if (ramo == 'Veículo Individual' || ramo == 'Frota') ...[
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
                              if (ramo == 'Veículo Individual') ...[
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
                                      flex: 1,
                                      child: TextField(
                                        controller: anoCtrl,
                                        decoration: InputDecoration(labelText: 'Ano', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: corCtrl,
                                        decoration: InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
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
                                    ButtonSegment(value: 'Cavalo', label: Text('🐴 Cavalo')),
                                    ButtonSegment(value: 'Carreta', label: Text('🚛 Carreta')),
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
                                      flex: 1,
                                      child: TextField(
                                        controller: anoCtrl,
                                        decoration: InputDecoration(labelText: 'Ano', border: OutlineInputBorder()),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: corCtrl,
                                        decoration: InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
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

    // Vida
    cpfVida: cpfVidaCtrl.text.isNotEmpty ? cpfVidaCtrl.text : null,
    dataVida: dataVida,
    capitalSegurado: double.tryParse(capitalCtrl.text.replaceAll('R\$ ', '').replaceAll(',', '.')),

    // URLs dos CRLV (se houver) – você pode salvar em um campo separado se quiser
    // Vou usar documentosUrls para tudo, mas se quiser separar, crie um campo crlvUrls no modelo
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
  void _addApoliceDialog({
    required String clientId,
    Apolice? apoliceToEdit,
    int? indexToUpdate,
  }) {
    
    final isEditing = apoliceToEdit != null;
    
    final ramoCtrl = TextEditingController(text: apoliceToEdit?.ramo ?? '');
    final seguradoraCtrl = TextEditingController(text: apoliceToEdit?.seguradora ?? '');
    final numeroCtrl = TextEditingController(text: apoliceToEdit?.numeroApolice ?? '');
    final valorCtrl = TextEditingController(text: apoliceToEdit?.valorApolice.toString() ?? '');
    final gatilhoCtrl = TextEditingController(text: apoliceToEdit?.valorGatilho.toString() ?? '');
    
    DateTime? dataInicio = apoliceToEdit?.dataInicio;
    DateTime? dataFim = apoliceToEdit?.dataFim;
    List<BemSegurado> bensSegurados = List.from(apoliceToEdit?.bensSegurados ?? []);

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
                    isEditing ? 'Editar Apólice' : 'Adicionar Apólice',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Preencha os dados da apólice e seus bens segurados',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),

                  // CONTEÚDO SCROLLÁVEL
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ═══ SEÇÃO DE APÓLICE ═══
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
                              'Transporte',
                              'Máquinas',
                              'Residencial',
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
                            onChanged: (val) {
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
                            decoration: InputDecoration(
                              labelText: 'Número da Apólice',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // VALOR DA APÓLICE
                          TextField(
                            controller: valorCtrl,
                            decoration: InputDecoration(
                              labelText: 'Valor da Apólice',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              BRFormatters.moedaFormatter,
                            ],
                          ),
                          const SizedBox(height: 12),

                          // VALOR DO GATILHO
                          TextField(
                            controller: gatilhoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Valor do Gatilho',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              BRFormatters.moedaFormatter,
                            ],
                          ),
                          const SizedBox(height: 12),

                          // DATA DE INÍCIO
                          ListTile(
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
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dataInicio ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => dataInicio = picked);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // DATA DE FIM
                          ListTile(
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
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dataFim ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setModalState(() => dataFim = picked);
                              }
                            },
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
                              if (ramoCtrl.text.isNotEmpty)
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
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Detalhes do bem
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
                                            const SizedBox(height: 6),
                                            Text(
                                              bem.tipo,
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                      ),
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
                              valorApolice: BRFormatters.parseFromMoeda(valorCtrl.text) ?? 0,
                              valorGatilho: BRFormatters.parseFromMoeda(gatilhoCtrl.text) ?? 0,
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
      'Vida': '💓',
    };
    return ramoEmojis[ramo] ?? '📋';
  }

  Color _getCorRamo(String ramo) {
    const ramoColors = {
      'Veículo Individual': Color(0xFFFFB74D),  // Amarelo
      'Frota': Color(0xFF64B5F6),                // Azul
      'Transporte': Color(0xFF81C784),           // Verde
      'Máquinas': Color(0xFFA1887F),             // Marrom
      'Residencial': Color(0xFFE57373),          // Vermelho
      'Vida': Color(0xFFBA68C8),                 // Roxo
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