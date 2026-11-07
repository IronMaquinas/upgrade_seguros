// Workshop_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:latlong2/latlong.dart' hide LatLng;
import 'package:upgrade_seguros/services/place_search_delegate.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/workshop_model.dart';

class WorkshopWidget extends StatefulWidget {
  final String claimId;
  final List<Workshop> oficinas;
  final String clientNome;
  final bool isEditing;

  const WorkshopWidget({
    super.key,
    required this.claimId,
    required this.oficinas,
    required this.clientNome,
    required this.isEditing,
  });

  @override
  State<WorkshopWidget> createState() => _WorkshopWidgetState();
}

class _WorkshopWidgetState extends State<WorkshopWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  LatLng? _localOcorrenciaLatLng;

  final _places = FlutterGooglePlacesSdk("AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE");
  final String _apiKey = 'AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE';

  Future<void> _addOficina(Workshop oficina) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.addOficinaToClaim(widget.claimId, oficina);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar oficina: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOficina(Workshop oficina) async {
    setState(() => _isLoading = true);
    try {
      await _firestoreService.updateOficinaInClaim(widget.claimId, oficina);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar oficina: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeOficina(Workshop oficina) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir a oficina "${oficina.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    // ✅ Se o usuário cancelou, não faz nada
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await _firestoreService.removeOficinaFromClaim(widget.claimId, oficina);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oficina excluída com sucesso!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover oficina: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

    // Busca lugar pelo autocomplete e retorna endereço
    Future<void> _openPlaceSearch(String label, TextEditingController controller) async {
      final Place? place = await showSearch<Place?>(
        context: context,
        delegate: PlaceSearchDelegate(_places),
      );

      if (place != null) {
        setState(() {
          controller.text = place.address ?? place.name ?? '';
          // REMOVA temporariamente a parte das coordenadas para testar
        });
      }
    }

  void _showAddEditWorkshopDialog({Workshop? oficina}) {
    final _formKey = GlobalKey<FormState>();
    final _nomeController = TextEditingController(text: oficina?.nome);
    final _contatoController = TextEditingController(text: oficina?.contato);
    final _telefoneController = TextEditingController(text: oficina?.telefone);
    final _emailController = TextEditingController(text: oficina?.email);
    final _enderecoController = TextEditingController(text: oficina?.endereco);
    String _tipoSelecionado = oficina?.tipo ?? 'segurado';
    List<PlatformFile> _novosDocumentos = [];
    List<String> _documentosParaExcluir = []; // ✅ Documentos marcados para exclusão
    LatLng? _enderecoLatLng;
    bool _isUploading = false; // ✅ Indicador de upload

    // ✅ Carregar documentos existentes como PlatformFiles fictícios para exibição
    final List<PlatformFile> _documentosExistentes = oficina?.documentosUrls
        .map((url) => PlatformFile(
              name: _getFileNameFromUrl(url),
              size: 0,
              path: url, // Usamos a URL como identificador
            ))
        .toList() ??
    [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // TÍTULO
                          Text(
                            oficina == null ? 'Adicionar Oficina' : 'Editar Oficina',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),

                          // CAMPO NOME
                          TextFormField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                              labelText: 'Nome da Oficina*',
                            ),
                            validator: (value) => value!.isEmpty ? 'Campo obrigatório' : null,
                          ),
                          const SizedBox(height: 16),

                          // CAMPO CONTATO
                          TextFormField(
                            controller: _contatoController,
                            decoration: const InputDecoration(
                              labelText: 'Nome do Contato',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // CAMPO TELEFONE
                          TextFormField(
                            controller: _telefoneController,
                            decoration: const InputDecoration(
                              labelText: 'Telefone',
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),

                          // CAMPO EMAIL
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),

                          // CAMPO ENDEREÇO COM SEARCH
                          TextFormField(
                            controller: _enderecoController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Endereço da Oficina',
                              suffixIcon: Icon(Icons.search),
                            ),
                            onTap: () async {
                              final Place? place = await showSearch<Place?>(
                                context: context,
                                delegate: PlaceSearchDelegate(_places),
                              );
                              
                              if (place != null) {
                                setState(() {
                                  _enderecoController.text = place.address ?? place.name ?? '';
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Campo obrigatório';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // DROPDOWN TIPO
                          DropdownButtonFormField<String>(
                            value: _tipoSelecionado,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Oficina',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'segurado', child: Text('Oficina do Segurado')),
                              DropdownMenuItem(value: 'terceiro', child: Text('Oficina do Terceiro')),
                            ],
                            onChanged: (value) => setState(() => _tipoSelecionado = value!),
                          ),
                          const SizedBox(height: 20),

                          // DOCUMENTOS
                          const Text('Documentos:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          
                          // ✅ DOCUMENTOS EXISTENTES
                          if (_documentosExistentes.isNotEmpty) ...[
                            const Text('Documentos existentes:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Wrap(
                              spacing: 8,
                              children: _documentosExistentes.map((file) => Chip(
                                label: Text(file.name),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () {
                                  setState(() {
                                    _documentosExistentes.remove(file);
                                    _documentosParaExcluir.add(file.path!);
                                  });
                                },
                              )).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          // ✅ NOVOS DOCUMENTOS
                          if (_novosDocumentos.isNotEmpty) ...[
                            const Text('Novos documentos:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Wrap(
                              spacing: 8,
                              children: _novosDocumentos.map((file) => Chip(
                                label: Text(file.name),
                                onDeleted: () => setState(() => _novosDocumentos.remove(file)),
                              )).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          // ✅ BOTÃO ADICIONAR COM INDICADOR DE CARREGAMENTO
                          _isUploading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  icon: const Icon(Icons.attach_file),
                                  label: const Text('Adicionar Documento'),
                                  onPressed: () async {
                                    final result = await FilePicker.platform.pickFiles(
                                      allowMultiple: true,
                                      type: FileType.custom,
                                      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
                                    );
                                    if (result != null) {
                                      setState(() => _novosDocumentos.addAll(result.files));
                                    }
                                  },
                                ),

                          // BOTÕES
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isUploading 
                                    ? null 
                                    : () async {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _isUploading = true);
                                    
                                    try {
                                      // ✅ FILTRAR DOCUMENTOS EXISTENTES (remover os marcados para exclusão)
                                      final documentosExistentesFinais = oficina?.documentosUrls
                                          .where((url) => !_documentosParaExcluir.contains(url))
                                          .toList() ?? [];
                                      
                                      // ✅ UPLOAD DE NOVOS DOCUMENTOS
                                      List<String> novosDocumentosUrls = [];
                                      if (_novosDocumentos.isNotEmpty) {
                                        novosDocumentosUrls = await _firestoreService.uploadArquivosLaudos(
                                          widget.claimId,
                                          _novosDocumentos,
                                        );
                                      }

                                      final novaOficina = Workshop(
                                        id: oficina?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                        nome: _nomeController.text,
                                        contato: _contatoController.text.isEmpty ? null : _contatoController.text,
                                        telefone: _telefoneController.text.isEmpty ? null : _telefoneController.text,
                                        email: _emailController.text.isEmpty ? null : _emailController.text,
                                        endereco: _enderecoController.text.isEmpty ? null : _enderecoController.text,
                                        tipo: _tipoSelecionado,
                                        documentosUrls: [...documentosExistentesFinais, ...novosDocumentosUrls],
                                        dataCriacao: oficina?.dataCriacao ?? DateTime.now(),
                                        responsavelEmail: _authService.getUserEmail(),
                                      );

                                      if (oficina == null) {
                                        await _addOficina(novaOficina);
                                      } else {
                                        await _updateOficina(novaOficina);
                                      }
                                      
                                      Navigator.pop(context); // ✅ Fechar só depois do upload
                                      
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Erro ao salvar: $e')),
                                      );
                                    } finally {
                                      setState(() => _isUploading = false);
                                    }
                                  }
                                },
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Salvar'),
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
          },
        );
      },
    );
  }

  // ✅ Adicione esta função auxiliar para extrair nome do arquivo da URL
  String _getFileNameFromUrl(String url) {
    try {
      return Uri.decodeFull(url.split('/').last.split('?').first);
    } catch (e) {
      return 'documento';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Agrupar oficinas por tipo
    final oficinasSegurado = widget.oficinas.where((o) => o.tipo == 'segurado').toList();
    final oficinasTerceiro = widget.oficinas.where((o) => o.tipo == 'terceiro').toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Oficinas Envolvidas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Adicionar Oficina',
                  onPressed: () => _showAddEditWorkshopDialog(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.oficinas.isEmpty
                    ? const Text('Nenhuma oficina adicionada ainda.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ SEÇÃO OFICINAS DO SEGURADO
                          if (oficinasSegurado.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Oficinas do Segurado',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            ...oficinasSegurado.map((oficina) => _WorkshopCard(
                              oficina: oficina,
                              onEdit: () => widget.isEditing  // ← Mude aqui
                                ? _showAddEditWorkshopDialog(oficina: oficina)
                                : null,
                              onDelete: () => widget.isEditing  // ← E aqui
                                ? _removeOficina(oficina)
                                : null,
                              isEditing: widget.isEditing,  // ← E aqui
                            )),
                            const SizedBox(height: 16),
                          ],

                          // ✅ SEÇÃO OFICINAS DO TERCEIRO
                          if (oficinasTerceiro.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Oficinas do Terceiro',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            ...oficinasTerceiro.map((oficina) => _WorkshopCard(
                                  oficina: oficina,
                                  onEdit: () => _showAddEditWorkshopDialog(oficina: oficina),
                                  onDelete: () => _removeOficina(oficina),
                                )),
                          ],
                        ],
                      ),
          ],
        ),
      ),
    );
  }
}

class _enderecoController {
}

// No _WorkshopCard, atualize as cores para uma diferenciação clara
class _WorkshopCard extends StatelessWidget {
  final Workshop oficina;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isEditing;

  const _WorkshopCard({
    required this.oficina,
    required this.onEdit,
    required this.onDelete,
    this.isEditing = false,
  });

  Color _getCardColor(String tipo) {
    return tipo == 'segurado' 
      ? Colors.blue.shade50  // Azul claro para segurado
      : Colors.orange.shade50; // Laranja claro para terceiro
  }

  Color _getBorderColor(String tipo) {
    return tipo == 'segurado' 
      ? Colors.blue.shade300  // Borda azul para segurado
      : Colors.orange.shade300; // Borda laranja para terceiro
  }

  Color _getChipColor(String tipo) {
    return tipo == 'segurado' 
      ? Colors.blue.shade100  // Chip azul para segurado
      : Colors.orange.shade100; // Chip laranja para terceiro
  }

  Color _getTextColor(String tipo) {
    return tipo == 'segurado' 
      ? Colors.blue.shade800  // Texto azul escuro para segurado
      : Colors.orange.shade800; // Texto laranja escuro para terceiro
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: _getCardColor(oficina.tipo),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getBorderColor(oficina.tipo),
          width: 2,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(
                    oficina.tipo == 'segurado' ? 'OFICINA SEGURADO' : 'OFICINA TERCEIRO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getTextColor(oficina.tipo),
                    ),
                  ),
                  backgroundColor: _getChipColor(oficina.tipo),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: _getBorderColor(oficina.tipo)),
                  ),
                ),
                const Spacer(),
                if (isEditing) ...[  // ← Mostra botões apenas em edição
                  IconButton(
                    icon: Icon(Icons.edit, size: 20, color: _getTextColor(oficina.tipo)),
                    onPressed: onEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              oficina.nome, 
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getTextColor(oficina.tipo),
                fontSize: 16,
              ),
            ),
            if (oficina.contato != null) 
              SelectableText('Contato: ${oficina.contato}', style: const TextStyle(fontSize: 14)),
            if (oficina.telefone != null) 
              SelectableText('Telefone: ${oficina.telefone}', style: const TextStyle(fontSize: 14)),
            if (oficina.email != null) 
              SelectableText('Email: ${oficina.email}', style: const TextStyle(fontSize: 14)),
            if (oficina.endereco != null) 
              SelectableText('Endereço: ${oficina.endereco}', style: const TextStyle(fontSize: 14)),
            
            if (oficina.documentosUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Documentos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: oficina.documentosUrls.map((url) => ActionChip(
                  label: Text(
                    _getFileNameFromUrl(url),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _openDocument(url),
                  backgroundColor: _getChipColor(oficina.tipo),
                )).toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Adicionado em: ${DateFormat('dd/MM/yyyy HH:mm').format(oficina.dataCriacao)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            if (oficina.responsavelEmail != null)
              Text(
                'Por: ${oficina.responsavelEmail}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  String _getFileNameFromUrl(String url) {
    try {
      return Uri.decodeFull(url.split('/').last.split('?').first);
    } catch (e) {
      return 'documento';
    }
  }

  void _openDocument(String url) async {
    // Implementar abertura de documento
    try {
      if (await canLaunchUrlString(url)) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Erro ao abrir documento: $e');
    }
  }
}