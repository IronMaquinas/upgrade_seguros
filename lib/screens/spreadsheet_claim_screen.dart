// lib/screens/spreadsheet_claim_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart'; 
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:upgrade_seguros/dialogs/apolice_selection_dialog.dart';
import 'package:upgrade_seguros/models/business_model.dart';
import 'package:upgrade_seguros/models/config_model.dart';
import 'package:upgrade_seguros/models/third_party_model.dart';
import 'package:upgrade_seguros/models/transport_model.dart';
import 'package:upgrade_seguros/models/vehicle_model.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:upgrade_seguros/utils/formatters.dart';
import 'package:uuid/uuid.dart';
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../models/apolice_model.dart';
import '../models/house_model.dart';
import '../models/life_model.dart';
import '../models/machinery_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/image_services.dart';
import '../widgets/client_search_dialog.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart' hide LatLng;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:upgrade_seguros/services/place_search_delegate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:upgrade_seguros/models/bodily_injury_model.dart';
import 'package:upgrade_seguros/models/material_damage_model.dart';

 enum RelatoStep {
    situacao,
    acao,
    evento,
    impacto,
  }

enum StatusSinistro {
  normal,
  aviso,      // amarelo - >= 80%
  limite,     // vermelho - > 100%
}

  // 🆕 WIDGET CUSTOMIZADO PARA LISTA DE MÚLTIPLOS TERCEIROS

// ═════════════════════════════════════════════════════════════════════════════
// 🆕 WIDGET CUSTOMIZADO PARA LISTA DE MÚLTIPLOS TERCEIROS
// ═════════════════════════════════════════════════════════════════════════════

class _TerceirosListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> terceiros;
  final Function(Map<String, dynamic>) onAdd;
  final Function(int) onRemove;
  final Function(int, String, dynamic) onEditField;

  const _TerceirosListWidget({
    Key? key,
    required this.terceiros,
    required this.onAdd,
    required this.onRemove,
    required this.onEditField,
  }) : super(key: key);

  @override
  State<_TerceirosListWidget> createState() => _TerceirosListWidgetState();
}

class _TerceirosListWidgetState extends State<_TerceirosListWidget> {
  late Map<int, Map<String, TextEditingController>> _controllers = {};

  // 🆕 FORMATADORES
  late Map<int, Map<String, TextInputFormatter>> _formatters = {};

  final _cpfCnpjFormatter = BRFormatters.cpfCnpjFormatter;

  final MaskTextInputFormatter _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',     // (11) 99999-9999
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  // 🆕 FORMATTER PARA MOEDA
  TextInputFormatter _criarFormatterMoeda() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) {
        return newValue;
      }

      // Remove caracteres não numéricos
      final numericText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');

      // Se vazio, retorna vazio
      if (numericText.isEmpty) {
        return TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }

      // Converte para número (centavos)
      final int value = int.parse(numericText);

      // Formata como moeda
      final formattedText = _formatarMoeda(value);

      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    });
  }

  // 🆕 FUNÇÃO AUXILIAR PARA FORMATAR MOEDA
  String _formatarMoeda(int centavos) {
    final reais = centavos ~/ 100;
    final cents = centavos % 100;

    final formatter = NumberFormat('#,##0.00', 'pt_BR');
    final valor = reais + (cents / 100);

    return 'R\$ ${formatter.format(valor)}';
  }

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // 🔥 DISPOSE ANTES
    for (var map in _controllers.values) {
      for (var c in map.values) {
        c.dispose();
      }
    }
    _controllers.clear();
    _formatters.clear();  // 🆕 Limpar formatadores também

    for (int i = 0; i < widget.terceiros.length; i++) {
      _controllers[i] = {
        'nome': TextEditingController(text: widget.terceiros[i]['nome'] ?? ''),
        'cpf': TextEditingController(text: widget.terceiros[i]['cpf'] ?? ''),
        'contato': TextEditingController(text: widget.terceiros[i]['contato'] ?? ''),
        'email': TextEditingController(text: widget.terceiros[i]['email'] ?? ''),
        'placa': TextEditingController(text: widget.terceiros[i]['placa'] ?? ''),
        'chassi': TextEditingController(text: widget.terceiros[i]['chassi'] ?? ''),
        'marca': TextEditingController(text: widget.terceiros[i]['marca'] ?? ''),
        'modelo': TextEditingController(text: widget.terceiros[i]['modelo'] ?? ''),
        'ano': TextEditingController(text: widget.terceiros[i]['ano'] ?? ''),
        'anoModelo': TextEditingController(text: widget.terceiros[i]['anoModelo'] ?? ''),
        'cor': TextEditingController(text: widget.terceiros[i]['cor'] ?? ''),
        
        // ✨ NOVOS CAMPOS
        'nomeContatoTerceiro': TextEditingController(text: widget.terceiros[i]['nomeContatoTerceiro'] ?? ''),
        'telefoneContatoTerceiro': TextEditingController(text: widget.terceiros[i]['telefoneContatoTerceiro'] ?? ''),
        'registroSeguradoraTerceiro': TextEditingController(text: widget.terceiros[i]['registroSeguradoraTerceiro'] ?? ''),
        
        'relato': TextEditingController(text: widget.terceiros[i]['relato'] ?? ''),
      };
      
      // 🆕 INICIALIZAR FORMATADORES
      _formatters[i] = {
        'cpf': _cpfCnpjFormatter,
        'contato': _telefoneFormatter,
        'telefoneContatoTerceiro': _telefoneFormatter,
      };
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

  void _confirmDeleteFoto(int index, XFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover foto'),
          content: const Text('Tem certeza que deseja excluir esta foto?'),
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
        );
      },
    );

    if (confirm == true) {
      setState(() {
        final lista = widget.terceiros[index]['fotosLocais'] as List<XFile> ?? [];
        lista.remove(file);
      });

      widget.onEditField(index, 'fotosLocais', 
        widget.terceiros[index]['fotosLocais']);
    }
  }

  void _confirmDeleteDocumento(int index, PlatformFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover documento'),
          content: const Text('Tem certeza que deseja excluir este documento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() {
        final lista = widget.terceiros[index]['documentosLocais'] as List<PlatformFile>;
        lista.remove(file);
      });

      widget.onEditField(
        index,
        'documentosLocais',
        widget.terceiros[index]['documentosLocais'],
      );
    }
  }

  @override
  void didUpdateWidget(_TerceirosListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.terceiros.length != oldWidget.terceiros.length) {
      _initializeControllers();
      return;
    }
    _initializeControllers();
  }

  @override
  void dispose() {
    for (var controllerMap in _controllers.values) {
      for (var controller in controllerMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.terceiros.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Nenhum terceiro adicionado',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.terceiros.length,
            itemBuilder: (context, index) {
              final terceiro = widget.terceiros[index];
              final ctrls = _controllers[index] ?? {};
              
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
                    // Header com índice e botão delete
                    Row(
                      children: [
                        Text(
                          'Terceiro ${index + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6A1B9A),
                          ),
                        ),

                        const SizedBox(width: 8),

                        TextButton.icon(
                          onPressed: () {
                            widget.onEditField(index, 'autoFill', true);
                          },
                          icon: const Icon(Icons.auto_fix_high, size: 14),
                          label: const Text('Auto'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(50, 30),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Campos de texto do terceiro
                    Row(
                      children: [
                        Expanded (
                        child: _buildTerceiroField(
                          label: 'Nome',
                          controller: ctrls['nome'],
                          onChanged: (val) => widget.onEditField(index, 'nome', val),
                        ),
                        ),
                        const SizedBox(width: 8),
                        Expanded (
                        child: _buildTerceiroField(
                          label: 'CPF',
                          controller: ctrls['cpf'],
                          inputFormatters: [BRFormatters.cpfCnpjFormatter],
                          onChanged: (val) => widget.onEditField(index, 'cpf', val),
                        ),
                        )
                      ]
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Telefone',
                            controller: ctrls['contatoSegurado'],
                            inputFormatters: [_telefoneFormatter],
                            onChanged: (val) => widget.onEditField(index, 'contato', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'E-mail',
                            controller: ctrls['email'],
                            onChanged: (val) => widget.onEditField(index, 'email', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Placa',
                            controller: ctrls['placa'],
                            inputFormatters: [
                              _UpperCase(),
                            ],
                            onChanged: (val) => widget.onEditField(index, 'placa', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Chassi',
                            controller: ctrls['chassi'],
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(17),
                              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                            ],
                            onChanged: (val) {
                              final upper = val.toUpperCase();

                              if (upper != val) {
                                final cursor = ctrls['chassi']!.selection;

                                ctrls['chassi']!.value = TextEditingValue(
                                  text: upper,
                                  selection: cursor,
                                );
                              }

                              widget.onEditField(index, 'chassi', upper);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Marca',
                            controller: ctrls['marca'],
                            onChanged: (val) => widget.onEditField(index, 'marca', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Modelo',
                            controller: ctrls['modelo'],
                            onChanged: (val) => widget.onEditField(index, 'modelo', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Cor',
                            controller: ctrls['cor'],
                            onChanged: (val) => widget.onEditField(index, 'cor', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Ano Fabr.',
                            controller: ctrls['ano'],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            onChanged: (val) => widget.onEditField(index, 'ano', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Ano Modelo',
                            controller: ctrls['anoModelo'],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            onChanged: (val) => widget.onEditField(index, 'anoModelo', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // ✨ CONTATO DO TERCEIRO
                    Row(
                      children: [
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Nome de Contato do Terceiro',
                            controller: ctrls['nomeContatoTerceiro'],
                            onChanged: (val) => widget.onEditField(index, 'nomeContatoTerceiro', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTerceiroField(
                            label: 'Telefone de Contato do Terceiro',
                            controller: ctrls['telefoneContatoTerceiro'],
                            inputFormatters: [_telefoneFormatter],
                            onChanged: (val) => widget.onEditField(index, 'telefoneContatoTerceiro', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                          Expanded(
                            child: _buildTerceiroField(
                              label: 'Nº de Registro do Sinistro do Terceiro',
                              controller: ctrls['registroSeguradoraTerceiro'],
                              onChanged: (val) => widget.onEditField(index, 'registroSeguradoraTerceiro', val),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTerceiroField(
                      label: 'Relato',
                      controller: ctrls['relato'],
                      onChanged: (val) => widget.onEditField(index, 'relato', val),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    
                    // 🆕 FOTOS DO TERCEIRO
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fotos do Terceiro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (((terceiro['fotosUrls'] as List<String>?)?.isEmpty ?? true) &&
                              ((terceiro['fotosLocais'] as List<XFile>?)?.isEmpty ?? true))
                            Text(
                              'Nenhuma foto',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                // Fotos salvas no Firestore (URLs)
                                ...((terceiro['fotosUrls'] as List<String>?) ?? []).map((url) {
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
                                          _showImageViewer(NetworkImage(url));
                                        },
                                        child: Image.network(url, fit: BoxFit.cover),
                                      ),                                    
                                    ),
                                  );
                                }).toList(),
                                // Fotos locais (antes de salvar)
                                ...((terceiro['fotosLocais'] as List<XFile>?) ?? []).map((xfile) {
                                  return FutureBuilder<Uint8List>(
                                    future: xfile.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          alignment: Alignment.center,
                                          child: const CircularProgressIndicator(strokeWidth: 2),
                                        );
                                      }

                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              _showImageViewer(MemoryImage(snapshot.data!));
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.memory(
                                                snapshot.data!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),

                                          // ❌ BOTÃO REMOVER
                                          Positioned(
                                            top: -5,
                                            right: -5,
                                            child: GestureDetector(
                                              onTap: () => _confirmDeleteFoto(index, xfile),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }).toList(),
                              ],
                            ),
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            onPressed: () {
                              widget.onEditField(index, 'adicionarFoto', true);
                            },
                            icon: const Icon(Icons.add_photo_alternate, size: 14),
                            label: const Text('Adicionar Foto', style: TextStyle(fontSize: 10)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A1B9A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // 🆕 DOCUMENTOS DO TERCEIRO
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Documentos do Terceiro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (((terceiro['documentosUrls'] as List<String>?)?.isEmpty ?? true) &&
                              ((terceiro['documentosLocais'] as List<PlatformFile>?)?.isEmpty ?? true))
                            Text(
                              'Nenhum documento',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Documentos salvos no Firestore (URLs)
                                ...((terceiro['documentosUrls'] as List<String>?) ?? []).map((url) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            url.split('/').last,
                                            style: const TextStyle(fontSize: 9),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // Documentos locais (antes de salvar)
                                ...((terceiro['documentosLocais'] as List<PlatformFile>?) ?? []).map((file) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.cloud_upload, size: 14, color: Colors.orange),
                                            const SizedBox(width: 5),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 120),
                                              child: Text(
                                                file.name,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // ❌ BOTÃO REMOVER
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: GestureDetector(
                                          onTap: () => _confirmDeleteDocumento(index, file),
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                          const SizedBox(height: 6),
                          ElevatedButton.icon(
                            onPressed: () {
                              widget.onEditField(index, 'adicionarDocumento', true);
                            },
                            icon: const Icon(Icons.upload_file, size: 14),
                            label: const Text('Adicionar Doc.', style: TextStyle(fontSize: 10)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6A1B9A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        
        // Botão para adicionar novo terceiro
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => widget.onAdd({
            'nome': '',
            'cpf': '',
            'contato': '',
            'email': '',
            'placa': '',
            'marca': '',
            'modelo': '',
            'ano': '',
            'cor': '',
            'anoModelo': '',
            'relato': '',
            'fotosUrls': <String>[],
            'documentosUrls': <String>[],
          }),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar Terceiro'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6A1B9A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
        ),
      ],
    );
  }

  static Widget _buildTerceiroField({
    required String label,
    TextEditingController? controller,
    required Function(String) onChanged,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters, // 👈 NOVO
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      textAlign: TextAlign.left,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
          );
        }
      }

// ─── Formatter de maiúsculas para placas ────────────────────────────────────
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(_, TextEditingValue n) =>
      n.copyWith(text: n.text.toUpperCase(), selection: n.selection);
}

// ─── Formatter de data DD/MM/AAAA ───────────────────────────────────────────
class _DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue n) {
    var digits = n.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final text = buf.toString();
    return n.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

// ─── Modelo de campo de uma linha de entrada ─────────────────────────────────
class _Field {
  final String id;
  final String label;
  final String? hint;
  final TextInputType keyboard;
  final bool isDate;
  final bool isUpperCase;
  final bool isDropdown;
  final List<String>? options;
  final bool isMultiline;
  final bool required;
  final double flex;
  final List<TextInputFormatter>? inputFormatters;
  final Widget Function(String value)? suffixBuilder;
  final bool isReadOnly;  // 🆕 Novo parâmetro
  final bool isAutocomplete;
  final List<String>? autocompleteOptions;
  final VoidCallback? onTap;
  final bool isTime;
  final bool isCheckbox; 

  const _Field({
    required this.id,
    required this.label,
    this.hint,
    this.keyboard = TextInputType.text,
    this.isDate = false,
    this.isUpperCase = false,
    this.isDropdown = false,
    this.options,
    this.isMultiline = false,
    this.required = false,
    this.flex = 1,
    this.inputFormatters,
    this.suffixBuilder,
    this.isReadOnly = false,
    this.isAutocomplete = false,
    this.autocompleteOptions,
    this.onTap,
    this.isTime = false,
    this.isCheckbox = false,
  });
}

// ─── Grupos de campos (hierarquia visual) ────────────────────────────────────
class _Group {
  final String id;
  final String title;
  final IconData icon;
  final Color color;
  final List<List<_Field>> rows;

  const _Group({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.rows,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class SpreadsheetClaimScreen extends StatefulWidget {
  final String? ramoSelecionado;
  const SpreadsheetClaimScreen({super.key, this.ramoSelecionado, this.ramoInicial});
  final String? ramoInicial;

  @override
  State<SpreadsheetClaimScreen> createState() =>
      _SpreadsheetClaimScreenState();
}

class _SpreadsheetClaimScreenState extends State<SpreadsheetClaimScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final GlobalKey<_TerceirosListWidgetState> _terceirosKey = GlobalKey();
  bool _condutorEhProprietario = false;

  // ── Estado geral ──────────────────────────────────────────────────────────
  bool _isSaving = false;
  bool _savedOnce = false;
  String? _numeroSinistroGerado;
  String _saveStatus = ''; // feedback inline
  String? _ramoSelecionado;
  bool _isApplyingMask = false;
  String _nomeUsuarioLogado = 'Desconhecido';
  String? _selectedApoliceId;

  // FUNÇÃO PARA AUTO GERAR RELATO
  RelatoStep _stepAtualRelato = RelatoStep.situacao;

  Map<RelatoStep, String> _respostasRelato = {};

  final Map<RelatoStep, List<String>> _opcoesRelato = {
    RelatoStep.situacao: [
      'O segurado estava regularmente estacionado',
      'imobilizado no trânsito',
      'em circulação pela via',
      'realizando manobra',
    ],
    RelatoStep.acao: [
      'quando foi surpreendido',
      'quando realizava deslocamento',
      'quando executava manobra',
    ],
    RelatoStep.evento: [
      'veio a ser atingido',
      'colidiu com',
      'perdeu o controle e atingiu',

    ],
    RelatoStep.impacto: [
      'sem vítimas, apenas danos materiais',
      'causando danos materiais',
      'resultando em avarias de grande monta',
      'atingindo múltiplos veículos',
    ],
  };

  bool _localOcorrenciaManualMode = false;

  // --- Verifica se há alterações ---
  bool get _hasUnsavedChanges {
    if (_savedOnce) return false;
    final hasText = _ctrl.values.any((c) => c.text.isNotEmpty);
    final hasTerceiros = _terceiros.isNotEmpty;
    final hasAnexos = _anexos.values.any((list) => list.isNotEmpty);
    return hasText || hasTerceiros || hasAnexos;
  }

  // ── Cliente ───────────────────────────────────────────────────────────────
  Client? _cliente;
  bool _isNovoCliente = false;
  //final _clienteBuscaCtrl = TextEditingController();

  // API Key para Google places - Mesma conta da Iron Máquinas
  final _places = FlutterGooglePlacesSdk("AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE");
  final String _apiKey = 'AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE';

  LatLng? _localOcorrenciaLatLng;

  // ── Grupos expandidos ─────────────────────────────────────────────────────
  final Set<String> _expanded = {'apolice', 'veiculo', 'terceiros', 'danoscorporais', 'danosmateriais', 'acomp', 'anexos', 'vida', 'residencial', 'maquinas', 'empresarial'};

  // 🆕 LISTA DE MÚLTIPLOS TERCEIROS (com fotos e documentos)
  List<Map<String, dynamic>> _terceiros = [];
  List<Map<String, dynamic>> _danoscorporais = [];
  List<Map<String, dynamic>> _danosmateriais = [];

  // -- Ajustes do correção de upload
  String? _currentClaimId;

  // ── Anexos ────────────────────────────────────────────────────────────────
  // PlatformFiles originais para documentos — preservam bytes no web
  final Map<String, List<PlatformFile>> _platformFiles = {};

  // CARREGA SEGURADORAS
  List<String> _seguradoras = [];

  // --- Pop up para sair sem salvar ---
  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) {
      return true; // Pode sair sem aviso
    }

    // Mostra diálogo de confirmação
    final shouldPop = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // impede fechar ao clicar fora
      builder: (context) => AlertDialog(
        title: const Text('Sair sem salvar?'),
        content: const Text(
          'Você tem alterações não salvas. Tem certeza que deseja sair?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Sair',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  final Map<String, List<XFile>> _anexos = {
    'Fotos do Sinistro': [],
    'Documentos do Segurado': [],
    'Documentos do Veículo': [],
    'Laudos / Boletins': [],
  };
  final Map<String, bool> _dragOver = {
    'Fotos do Sinistro': false,
    'Documentos do Segurado': false,
    'Documentos do Veículo': false,
    'Laudos / Boletins': false,
  };
  bool _isUploadingAnexos = false;
  String _ramoSelecionadoLabel = 'Novo Sinistro';
  bool _usarHoje = false;
  bool _usarHojeAviso = false;

  final phoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  // ── Map de controllers por campo id ──────────────────────────────────────
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, FocusNode> _focus = {};

  // ── Definição dos grupos e campos ─────────────────────────────────────────
  List<_Group> _groups = [];

  // autosave timer
  Timer? _debounce;
  
  // 🆕 VALIDAÇÃO DE VIGÊNCIA DA APÓLICE
  StatusApolice _statusApolice(String dataStr) {
    try {
      final data = DateFormat('dd/MM/yyyy').parse(dataStr);
      final hoje = DateTime.now();
      final diff = data.difference(hoje).inDays;

      if (diff <= 0) return StatusApolice.vencida;
      if (diff <= 30) return StatusApolice.atencao;
      return StatusApolice.normal;
    } catch (e) {
      return StatusApolice.normal;
    }
  }
  
  // 🆕 CALCULAR STATUS DO SINISTRO (comparar com gatilho)
  StatusSinistro _statusSinistro(String valorSinistroStr, String usoAtualStr, String gatilhoStr) {
    try {
      final valorSinistro = double.tryParse(
        valorSinistroStr
          .replaceAll(RegExp(r'[^\d,]'), '')
          .replaceAll(',', '.')
      ) ?? 0.0;
      
      final usoAtual = double.tryParse(
        usoAtualStr
          .replaceAll(RegExp(r'[^\d,]'), '')
          .replaceAll(',', '.')
      ) ?? 0.0;
      
      final gatilho = double.tryParse(
        gatilhoStr
          .replaceAll(RegExp(r'[^\d,]'), '')
          .replaceAll(',', '.')
      ) ?? 0.0;

      if (gatilho <= 0) return StatusSinistro.normal;

      final total = valorSinistro + usoAtual;
      final percentual = (total / gatilho) * 100;

      if (percentual > 100) return StatusSinistro.limite;     // Vermelho
      if (percentual >= 80) return StatusSinistro.aviso;      // Amarelo
      return StatusSinistro.normal;                            // Normal
    } catch (e) {
      print('Erro em _statusSinistro: $e'); // 🆕 Debug
      return StatusSinistro.normal;
    }
  }

  final Map<String, MaskTextInputFormatter> _maskMap = {};

    // 🆕 FORMATTER PARA MOEDA
  TextInputFormatter _criarFormatterMoeda() {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      if (newValue.text.isEmpty) {
        return newValue;
      }
 
      // Remove caracteres não numéricos
      final numericText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
 
      // Se vazio, retorna vazio
      if (numericText.isEmpty) {
        return TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
 
      // Converte para número (centavos)
      final int value = int.parse(numericText);
 
      // Formata como moeda
      final formattedText = _formatarMoeda(value);
 
      return TextEditingValue(
        text: formattedText,
        selection: TextSelection.collapsed(offset: formattedText.length),
      );
    });
  }
 
  // CARREGA SEGURADORAS PARA PREENCHER AUTOCOMPLETE
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

  // 🆕 FUNÇÃO AUXILIAR PARA FORMATAR MOEDA
  String _formatarMoeda(int centavos) {
    final reais = centavos ~/ 100;
    final cents = centavos % 100;
 
    final formatter = NumberFormat('#,##0.00', 'pt_BR');
    final valor = reais + (cents / 100);
 
    return 'R\$ ${formatter.format(valor)}';
  }
  
   void _applyMask({
    required TextEditingController controller,
    required String newValue,
    required MaskTextInputFormatter formatter,
  }) {
    final masked = formatter.maskText(newValue);

    controller.value = TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }

  // FORMAT DATE PICKER
  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
  }

  Future<void> _pickDate(String fieldId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _ctrl[fieldId]?.text = _formatDate(picked);
        _usarHoje = false;
      });
    }

    if (picked != null) {
      setState(() {
        _ctrl[fieldId]?.text = _formatDate(picked);
        _usarHojeAviso = false;
      });
    }

  }

  List<_Group> _buildGroups() => [
        _Group(
          id: 'apolice',
          title: 'Apólice / Seguro',
          icon: Icons.policy_outlined,
          color: const Color.fromARGB(255, 25, 62, 105),
          rows: [
            [
              _Field(  // ← Mude de 'const' para normal
                id: 'empresaSegurada',
                label: 'Nome do Segurado',
                hint: 'Razão social ou nome do cliente',
                required: true,
                flex: 3,
                onTap: () {
                  print('🔍 DEBUG: onTap empresaSegurada ACIONADO!');  // 🆕
                  _abrirBuscaCliente();
                },// 🆕 NOVO - Abre o dialog
              ),
              _Field(id: 'cnpjSegurado', label: 'CNPJ / CPF', keyboard: TextInputType.number, flex: 2, inputFormatters: [BRFormatters.cpfCnpjFormatter],),
              const _Field(id: 'contatoSegurado', label: 'Telefone do Segurado', keyboard: TextInputType.phone, flex: 2,),
            ],
            [
              _Field(
                id: 'seguradora',
                label: 'Seguradora',
                isAutocomplete: true,
                autocompleteOptions: _seguradoras, // vindo do Firestore
                required: true,
                flex: 2,
              ),
              const _Field(id: 'numeroSinistroSeguradora', label: 'Nº Sinistro do Seguradorado', flex: 2,),
              const _Field(id: 'numeroApolice', label: 'Nº Apólice', flex: 2,),
              _Field(
                id: 'dataVigenciaFim',
                label: 'Vigência Final da Apólice',
                flex: 2,
                suffixBuilder: (value) {
                  final status = _statusApolice(value);

                  if (status == StatusApolice.vencida) {
                    return Icon(
                      Icons.error,
                      color: Colors.red,
                    );
                  }

                  if (status == StatusApolice.atencao) {
                    return Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    );
                  }
                  return SizedBox.shrink();
                },
              ),
              _Field(
                id: 'valorGatilho',
                label: 'Valor do Gatilho',
                hint: 'R\$',
                keyboard: TextInputType.number,
                flex: 2,
                inputFormatters: [_criarFormatterMoeda()],
              ),
              _Field(
                id: 'usoAtualApolice',
                label: 'Uso Atual da Apólice',
                hint: 'R\$',
                keyboard: TextInputType.number,
                flex: 2,
                isReadOnly: true,
                inputFormatters: [_criarFormatterMoeda()],
              ),
            ],
            [
              const _Field(id: 'dataSinistro', label: 'Data do Sinistro', hint: 'DD/MM/AAAA', isDate: true, keyboard: TextInputType.number, required: true,flex: 1,),
              const _Field(id: 'horaOcorrencia', label: 'Hora do Sinistro', hint: 'HH:mm', isTime: true, keyboard: TextInputType.number, flex: 1),
              const _Field(id: 'dataAviso', label: 'Data do Aviso', hint: 'DD/MM/AAAA', isDate: true, keyboard: TextInputType.number, flex: 1,),
              const _Field(id: 'tipoPerda', label: 'Tipo de Perda', isDropdown: true, options: ['PARCIAL', 'TOTAL'], flex: 1,),
              const _Field(
                id: 'status',
                label: 'Status',
                isDropdown: true,
                options: [
                  'Aberto',
                  'Vistoria em Andamento',
                  'Aguardando Aprovação',
                  'Aguardando Peças',
                  'Reparo em Andamento',
                  'Concluído',
                ],
                flex: 2,
              ),
              _Field(
                id: 'valor',
                label: 'Valor do Sinistro',
                hint: 'R\$',
                keyboard: TextInputType.number,
                flex: 1,
                inputFormatters: [_criarFormatterMoeda()],
                suffixBuilder: (value) {  // 🆕 ADICIONAR
                  final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>();
                  if (state == null) return SizedBox.shrink();
                  
                  final status = state._statusSinistro(
                    value,
                    state._ctrl['usoAtualApolice']?.text ?? '',
                    state._ctrl['valorGatilho']?.text ?? '',
                  );

                  if (status == StatusSinistro.limite) {
                    return Icon(Icons.error, color: Colors.red);
                  }

                  if (status == StatusSinistro.aviso) {
                    return Icon(Icons.warning_amber_rounded, color: Colors.orange);
                  }
                  return SizedBox.shrink();
                },
              ),
              _Field(
                id: 'slaPrevisto',
                label: 'Dias para Encerramento',
                hint: '0 dias',
                keyboard: TextInputType.number,
                flex: 1,
                suffixBuilder: (_) {
                  return Tooltip(
                    message: 'Tempo padrão previsto para encerramento deste sinistro',
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.help_outline,
                        size: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
        _Group(
          id: 'veiculo',
          title: 'Veículo Segurado',
          icon: Icons.directions_car_outlined,
          color: const Color(0xFF2E7D32),
          rows: [
            // Linha 1: Proprietário Legal
            [
              const _Field(id: 'nomeCondutor', label: 'Nome do Proprietário Legal', flex: 3),
              _Field(id: 'cpfCondutor', label: 'CPF / CNPJ do Proprietário Legal', keyboard: TextInputType.number, flex: 2, inputFormatters: [BRFormatters.cpfCnpjFormatter]),
            ],
            // Linha 2: Placa, Marca/Modelo, Cor
            [
              const _Field(id: 'placaSegurado', label: 'Placa', flex: 1),
              const _Field(id: 'marca', label: 'Marca/Modelo', flex: 2),
              const _Field(id: 'cor', label: 'Cor', flex: 1),
            ],
            // Linha 3: Chassi, Ano, Ano Modelo
            [
              const _Field(id: 'chassi', label: 'Chassi', flex: 2),
              const _Field(id: 'ano', label: 'Ano', keyboard: TextInputType.number, flex: 1),
              const _Field(id: 'anoModelo', label: 'Ano Modelo', keyboard: TextInputType.number, flex: 1),
            ],
            // Linha 4: Checkbox (usando campo placeholder)
            [
              _Field(
                id: '_checkbox_condutor',
                label: '',
                flex: 1,
                isCheckbox: true,
              ),
            ],
            // Linha 5: Condutor Motorista
            [
              const _Field(id: 'nomeCondutorMotorista', label: 'Nome do Condutor do Veículo', flex: 2),
              _Field(id: 'cpfCondutorMotorista', label: 'CPF / CNPJ do Condutor do Veículo', keyboard: TextInputType.number, flex: 2, inputFormatters: [BRFormatters.cpfCnpjFormatter]),
              _Field(id: 'cnhCondutorMotorista', label: 'CNH do Condutor do Veículo', keyboard: TextInputType.number, flex: 2),
            ],
            // Linha 6: Contato do Sinistro
            [
              _Field(id: 'nomeContatoSinistro', label: 'Nome do Contato do Sinistro', flex: 3),
              _Field(id: 'telefoneContatoSinistro', label: 'Telefone de Contato', keyboard: TextInputType.phone, inputFormatters: [BRFormatters.telefoneFormatter], flex: 2),
            ],
          ],
        ),

        // 🆕 GRUPO PARA MÚLTIPLOS TERCEIROS (renderizado como widget customizado)
        _Group(
          id: 'terceiros',
          title: 'Terceiros (Reclamados)',
          icon: Icons.people_outlined,
          color: const Color(0xFF6A1B9A),
          rows: [], // Este grupo será renderizado como widget customizado
        ),

        // 🆕 NOVO GRUPO: DANOS CORPORAIS
        _Group(
          id: 'danoscorporais',
          title: 'Danos Corporais',
          icon: Icons.medical_information_outlined,
          color: const Color(0xFFD32F2F),
          rows: [],
        ),

        // 🆕 NOVO GRUPO: DANOS MATERIAIS
        _Group(
          id: 'danosmateriais',
          title: 'Danos Materiais',
          icon: Icons.construction_outlined,
          color: const Color(0xFFF57F17),
          rows: [],
        ),

        _Group(
          id: 'acomp',
          title: 'Acompanhamento',
          icon: Icons.timeline_outlined,
          color: const Color(0xFFBF360C),
          rows: [
            [
              const _Field(
                id: 'localOcorrencia',
                label: 'Local da Ocorrência',
                hint: 'Buscar no mapa',
                flex: 3,
              ),
            ],
            [
              const _Field(
                id: 'relatoEvento',
                label: 'Relato do Evento',
                isMultiline: true,
                flex: 1,
              ),
            ],
          ],
        ),
    ];

  List<_Group> _buildTransporteGroups() => [
    _Group(
      id: 'transporte',
      title: 'Dados de Transporte',
      icon: Icons.local_shipping_outlined,
      color: const Color(0xFF2E7D32),
      rows: [
        [
          const _Field(id: 'nomeMotorista', label: 'Nome do Condutor', flex: 3),
          const _Field(id: 'cpfMotorista', label: 'CPF / CNPJ do Condutor', flex: 2),
        ],

        [
          const _Field(id: 'placaCavalo', label: 'Placa do Cavalo', isUpperCase: true, required: true, flex: 1,),
          const _Field(id: 'marca', label: 'Marca', flex: 3,),
          const _Field(id: 'modelo', label: 'Modelo', flex: 3,),
          const _Field(id: 'cor', label: 'Cor', flex: 3,),
        ],  

        [
          _Field(
            id: 'ano',
            label: 'Ano Fabr.',
            hint: 'Ex: 2020',
            keyboard: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            flex: 1,
          ),

          _Field(
            id: 'anoModelo',
            label: 'Ano Modelo',
            hint: 'Ex: 2021',
            keyboard: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            flex: 1,
          ),
          const _Field(id: 'chassi', label: 'Chassi', flex: 3,),
        ],

        [
          const _Field(id: 'placaCarreta', label: 'Placa da Carreta', isUpperCase: true, required: true, flex: 1,),
          const _Field(id: 'marcaCarreta', label: 'Marca', flex: 3,),
          const _Field(id: 'modeloCarreta', label: 'Modelo', flex: 3,),
        ],

                [
          _Field(
            id: 'anoCarreta',
            label: 'Ano Fabr.',
            hint: 'Ex: 2020',
            keyboard: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            flex: 1,
          ),

          _Field(
            id: 'anoModeloCarreta',
            label: 'Ano Modelo',
            hint: 'Ex: 2021',
            keyboard: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            flex: 1,
          ),
          const _Field(id: 'chassiCarreta', label: 'Chassi', flex: 3,),
        ],

        [
          const _Field(id: 'reguladora', label: 'Reguladora', flex: 2), //ok
          const _Field(id: 'numeroAverbacao', label: 'Número de Averbação', flex: 2), //ok
          const _Field(id: 'cte', label: 'CTe', flex: 2), //ok
          const _Field(id: 'nfe', label: 'Nota Fiscal', flex: 2), //ok
        ],

      ],
    ),
  ];

  List<_Group> _buildResidencialGroups() => [
    _Group(
      id: 'residencial',
      title: 'Dados do Imóvel',
      icon: Icons.home_outlined,
      color: const Color(0xFFBF360C),
      rows: [
        [
          const _Field(id: 'endereco', label: 'Endereço', flex: 3),
        ],
        [
          const _Field(id: 'tipoImovel', label: 'Tipo de Imóvel', flex: 2),
          const _Field(id: 'valorImovel', label: 'Valor do Imóvel (R\$)', flex: 2),  // ← novo
        ],
      ],
    ),
  ];

  List<_Group> _buildEmpresarialGroups() => [
    _Group(
      id: 'empresarial',
      title: 'Dados da Empresa',
      icon: Icons.business_outlined,
      color: const Color(0xFF424242),
      rows: [
        [
          const _Field(id: 'nomeEmpresa', label: 'Nome da Empresa', flex: 3),
        ],
        [
          const _Field(id: 'cnpjEmpresa', label: 'CNPJ', flex: 2),
          const _Field(id: 'ramoAtividade', label: 'Ramo de Atividade', flex: 2),
        ],
        [
          const _Field(id: 'enderecoEmpresa', label: 'Endereço', flex: 3),
        ],
        [
          const _Field(id: 'areaM2', label: 'Área (m²)', flex: 2),
          const _Field(id: 'tipoEstrutura', label: 'Tipo de Estrutura', flex: 2),
        ],
        [
          const _Field(id: 'numeroAndares', label: 'Número de Andares', flex: 2),
          const _Field(id: 'sistemaSeguranca', label: 'Sistema de Segurança', flex: 2),
        ],
        [
          const _Field(id: 'situacaoImovel', label: 'Situação (Próprio/Alugado)', flex: 3),
        ],
      ],
    ),
  ];

  List<_Group> _buildVidaGroups() => [
    _Group(
      id: 'vida',
      title: 'Segurado',
      icon: Icons.favorite_outline,
      color: const Color(0xFF6A1B9A),
      rows: [
        [
          const _Field(id: 'nomeSegurado', label: 'Nome', flex: 3),
          const _Field(id: 'cpfSegurado', label: 'CPF', flex: 2),
        ],
        [
          const _Field(id: 'idadeSegurado', label: 'Idade', flex: 1),
          const _Field(id: 'parentesco', label: 'Parentesco', flex: 2),
          const _Field(id: 'tipoEvento', label: 'Causa / Tipo de Evento', flex: 3),
        ],
        [
          const _Field(id: 'telefone', label: 'Telefone', flex: 2),
          const _Field(id: 'email', label: 'Email', flex: 3),
        ],
      ],
    ),
  ];

  List<_Group> _buildMaquinasGroups() => [
    _Group(
      id: 'maquinas',
      title: 'Dados da Máquina',
      icon: Icons.settings_outlined,
      color: const Color(0xFFFF6F00),
      rows: [
        [
          const _Field(id: 'descricao', label: 'Descrição', flex: 3),
          const _Field(id: 'numeroSerie', label: 'Número de Série', flex: 2),
          const _Field(id: 'modelo', label: 'Modelo', flex: 2),
        ],
      ],
    ),
  ];

  // -- Função para iniciar os controles de ramos de sinistro
  void _initControllers() {
    // 🔥 LIMPA antes
    for (final c in _ctrl.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }

    _ctrl.clear();
    _focus.clear();

    // recria
    for (final g in _groups) {
      for (final row in g.rows) {
        for (final f in row) {
          _ctrl[f.id] = TextEditingController();
          _focus[f.id] = FocusNode();
          _focus[f.id]!.addListener(() {
            if (!_focus[f.id]!.hasFocus) _scheduleAutosave();
          });
        }
      }
    }

    // 🔥 NOVO: Listener para limpar dados quando o nome do segurado for apagado
    _ctrl['empresaSegurada']?.addListener(() {
      if (_ctrl['empresaSegurada']!.text.trim().isEmpty) {
        // Limpa dados do cliente
        if (_cliente != null || _isNovoCliente) {
          setState(() {
            _cliente = null;
            _isNovoCliente = false;
            _ctrl['cnpjSegurado']!.clear();
            _ctrl['contatoSegurado']?.clear();
            _ctrl['numeroApolice']!.clear();
            _ctrl['dataVigenciaFim']!.clear();
            _ctrl['valorGatilho']!.clear();
            _ctrl['seguradora']!.clear();
            _ctrl['usoAtualApolice']!.clear();
          });
        }
      }
    });
  }

  // Abre picker de ramo ou carrega ramo passado como parâmetro
  Future<void> _openRamoPickerAndLoadRamo() async {
    // Se o ramo já foi passado como parâmetro, use-o
    if (widget.ramoSelecionado != null) {
      _loadRamo(widget.ramoSelecionado!);
      return;
    }
    
    // Caso contrário, volta para tela anterior
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // Carrega o ramo selecionado e ajusta os grupos
  void _loadRamo(String ramo) {
    setState(() {
      _ramoSelecionado = ramo;
      _ramoSelecionadoLabel = _ramoToLabel(ramo);
      
      if (ramo == 'Transporte') {
        _groups = [
          _buildGroups()[0],
          ..._buildTransporteGroups(),
          _buildGroups()[2],
          _buildGroups()[3],
        ];
      } else if (ramo == 'Máquinas') {
        _groups = [
          _buildGroups()[0],
          ..._buildMaquinasGroups(),
          _buildGroups()[3],
        ];
      } else if (ramo == 'Residencial') {
        _groups = [
          _buildGroups()[0],
          ..._buildResidencialGroups(),
          _buildGroups()[3],
        ];
      } else if (ramo == 'Empresarial') {  // ← NOVO
        _groups = [
          _buildGroups()[0],
          ..._buildEmpresarialGroups(),
          _buildGroups()[3],
        ];
      } else if (ramo == 'Vida' || ramo == 'Vidas') {
        _groups = [
          _buildGroups()[0],
          ..._buildVidaGroups(),
          _buildGroups()[3],
        ];
      } else {
        _groups = _buildGroups();
      }
    });
    _initControllers();
    _preencherSlaPrevisto(ramo);
  }

  Future<void> _preencherSlaPrevisto(String ramo) async {
    final dias = await ConfigService().getSlaSinistro(ramo);
    _ctrl['slaPrevisto']?.text = dias.toString();
  }

  String _ramoToLabel(String ramo) {
    switch (ramo) {
      case 'Frota':                   return 'Veículo / Frota';
      case 'Civil Ônibus (RCO)':      return 'Civil Ônibus (RCO)';
      case 'Veículo Individual':      return 'Veículo Individual';
      case 'Transporte':              return 'Transporte';
      case 'Máquinas':                return 'Máquinas e Equipamentos';
      case 'Empresarial':             return 'Empresarial';
      case 'Residencial':             return 'Residencial';
      case 'Vida':
      case 'Vidas': return 'Vidas';   default: return ramo;
    }
  }

  // ── initState — aplica ramo inicial ou mostra picker ────────────────────
  @override
    void initState() {
      super.initState();
      _loadNomeUsuario();
      _carregarSeguradoras();
      _loadConfig();

      // 1. Define os grupos padrão
      _groups = _buildGroups();

      // 2. Inicializa controllers corretamente
      _initControllers();

      // 3. Decide se abre picker ou usa ramo inicial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.ramoInicial == null) {
          _openRamoPickerAndLoadRamo();
        }
      });
    }

  AppConfig _config = AppConfig(id: 'config');

  Future<void> _loadConfig() async {
    final config = await ConfigService().getConfig();
    setState(() {
      _config = config;
    });
  }

  Future<void> _loadNomeUsuario() async {
    final nome = await _authService.getUserName();
    setState(() => _nomeUsuarioLogado = nome);
  }

  // ── Autosave ──────────────────────────────────────────────────────────────
  void _scheduleAutosave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _autoSave);
  }

  Future<void> _autoSave() async {
    if (_cliente == null && !_isNovoCliente) return;
    if (_ctrl['empresaSegurada']!.text.trim().isEmpty) return;

    // 👇 impede autosave antes da primeira criação
    if (!_savedOnce) return;

    await _salvar(silent: true);
  }

  // ── Salvar ────────────────────────────────────────────────────────────────
  Future<void> _salvar({bool silent = false}) async {

    _ctrl.forEach((key, value) {
      debugPrint('$key → ${value.text}');
    });

    if (_isSaving) return;

    final userId = _authService.getUserId();
    final userEmail = _authService.getUserEmail();
    final horaOcorrencia = _ctrl['horaOcorrencia']?.text; // "HH:mm"

    final diasSla = int.tryParse(_ctrl['slaPrevisto']?.text ?? '') ?? 0;
    final slaPrevistoData = DateTime.now().add(Duration(days: diasSla));

    if (userId == null || userId == 'anonymous_user') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text('Erro: Você não está autenticado. Faça login novamente.'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_ctrl['tipoPerda']!.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o Tipo de Perda')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _saveStatus = 'Salvando...';
    });

    try {
      // Cria cliente se necessário
      if (_cliente == null && _isNovoCliente) {
        _cliente = Client(
          nome: _ctrl['empresaSegurada']!.text.trim(),
          cnpjCpf: _ctrl['cnpjSegurado']!.text.trim(),
          contato: _ctrl['contatoSegurado']!.text.trim(),
          email: '',
          dataCadastro: DateTime.now(),
          veiculosSegurados: [],
          apolices: [],
        );
        await _firestoreService.addClient(_cliente!, userId);
      }

      _numeroSinistroGerado ??=
          'SN${DateFormat("yyyyMMddHHmmss").format(DateTime.now())}';

      DateTime _parseData(String id) {
        final raw = _ctrl[id]?.text.trim() ?? '';
        try {
          return DateFormat('dd/MM/yyyy').parse(raw);
        } catch (_) {
          return DateTime.now();
        }
      }

      // Monta o veículo segurado
      final veiculo = Vehicle(
        placa: _ctrl['placaSegurado']?.text.trim().toUpperCase() ?? '',
        nomeCondutor: _ctrl['nomeCondutor']?.text.trim().toUpperCase() ?? '',
        cpfCondutor: _ctrl['cpfCondutor']?.text.trim().toUpperCase() ?? '',
        nomeCondutorMotorista: _ctrl['nomeCondutorMotorista']?.text.trim().toUpperCase() ?? '',
        cpfCondutorMotorista: _ctrl['cpfCondutorMotorista']?.text.trim().toUpperCase() ?? '',
        cnhCondutorMotorista: _ctrl['cnhCondutorMotorista']?.text.trim().toUpperCase() ?? '',
        cor: _ctrl['cor']?.text.trim().toUpperCase() ?? '',
        marca: _ctrl['marca']?.text.trim().split('/').first.trim() ?? '',
        modelo: _ctrl['modelo']?.text.trim().split('/').last.trim() ?? '',
        chassi: _ctrl['chassi']?.text.trim().split('/').last.trim() ?? '',
        ano: int.tryParse(_ctrl['ano']?.text.trim() ?? '0') ?? 0,
        anomodelo: int.tryParse(_ctrl['anoModelo']?.text.trim() ?? '0') ?? 0,
      );

      final veiculoTerceiro = Vehicle(
        placa: _ctrl['placa']?.text.trim().toUpperCase() ?? '',
        marca: '',
        modelo: '',
        ano: 0,
        anomodelo: 0,
        chassi: '',
      );

      // House para Residencial
      final house = House(
        localHouse: _ctrl['endereco']?.text.trim() ?? '',
        tipoImovel: _ctrl['tipoImovel']?.text.trim(),
        valorImovel: double.tryParse(
          _ctrl['valorImovel']?.text.trim().replaceAll(RegExp(r'[^\d,]'), '').replaceAll(',', '.') ?? '0'
        ),
        fotosUrls: [],
        documentosUrls: [],
      );

      // Life para Vidas
      final life = Life(
        localLife: _ctrl['endereco']?.text.trim() ?? '',
        nomeSegurado: _ctrl['nomeSegurado']?.text.trim() ?? '',
        cpfSegurado: _ctrl['cpfSegurado']?.text.trim() ?? '',
        idadeSegurado: int.tryParse(_ctrl['idadeSegurado']?.text.trim() ?? '0') ?? 0,
        telefone: _ctrl['telefone']?.text.trim(),
        email: _ctrl['email']?.text.trim(),
        parentesco: _ctrl['parentesco']?.text.trim(),
        causaMorte: _ctrl['tipoEvento']?.text.trim() ?? '',
        fotosUrls: [],
        documentosUrls: [],
      );

      // Machinery para Máquinas
      final maquinaria = Machinery(
        descricao: _ctrl['descricao']?.text.trim() ?? '',
        numeroSerie: _ctrl['numeroSerie']?.text.trim() ?? '',
        modelo: _ctrl['modelo']?.text.trim() ?? '',
        descricaoSinistro: _ctrl['descricaoSinistro']?.text.trim() ?? '',
        fotosUrls: [],
        documentosUrls: [],
      );

      // 🆕 FAZER UPLOAD DE FOTOS E DOCUMENTOS DOS TERCEIROS
      for (var i = 0; i < _terceiros.length; i++) {
        final terceiro = _terceiros[i];
        
        // Upload de fotos locais
        if ((terceiro['fotosLocais'] as List<XFile>?)?.isNotEmpty ?? false) {
          final fotosComprimidas = await ImageService()
              .compressImages(terceiro['fotosLocais'] as List<XFile>);
          final fotosUrls = await _firestoreService.uploadThirdPartyPhotos(
            _numeroSinistroGerado!,
            'terceiro_$i',
            fotosComprimidas,
          );
          terceiro['fotosUrls'] = fotosUrls;
        }
        
        // Upload de documentos locais
        if ((terceiro['documentosLocais'] as List<PlatformFile>?)?.isNotEmpty ?? false) {
          // 🆕 Converter PlatformFile → XFile
          final xfiles = (terceiro['documentosLocais'] as List<PlatformFile>).map((pf) {
            if (pf.bytes != null) {
              return XFile.fromData(pf.bytes!, name: pf.name);
            } else {
              return XFile(pf.path!, name: pf.name);
            }
          }).toList();
          
          final documentosUrls = await _firestoreService.uploadThirdPartyDocuments(
            _numeroSinistroGerado!,
            'terceiro_$i',
            xfiles,
          );
          terceiro['documentosUrls'] = documentosUrls;
        }
      }

      // 🔴 FAZER UPLOAD DE FOTOS E DOCUMENTOS DOS DANOS CORPORAIS
      for (var i = 0; i < _danoscorporais.length; i++) {
        final dano = _danoscorporais[i];
        
        // Upload de fotos locais
        if ((dano['fotosLocais'] as List<XFile>?)?.isNotEmpty ?? false) {
          final fotosComprimidas = await ImageService()
              .compressImages(dano['fotosLocais'] as List<XFile>);
          
          final fotosUrls = await _firestoreService.uploadThirdPartyPhotos(
            _numeroSinistroGerado!,
            'dano_corporal_$i',
            fotosComprimidas,
          );
          
          dano['fotosUrls'] = fotosUrls;
        }
        
        // Upload de documentos locais
        if ((dano['documentosLocais'] as List<PlatformFile>?)?.isNotEmpty ?? false) {
          final xfiles = (dano['documentosLocais'] as List<PlatformFile>).map((pf) {
            if (pf.bytes != null) {
              return XFile.fromData(pf.bytes!, name: pf.name);
            } else {
              return XFile(pf.path!, name: pf.name);
            }
          }).toList();
          
          final documentosUrls = await _firestoreService.uploadThirdPartyDocuments(
            _numeroSinistroGerado!,
            'dano_corporal_$i',
            xfiles,
          );
          
          dano['documentosUrls'] = documentosUrls;
        }
      }

      // 🟡 FAZER UPLOAD DE FOTOS E DOCUMENTOS DOS DANOS MATERIAIS
      for (var i = 0; i < _danosmateriais.length; i++) {
        final dano = _danosmateriais[i];
        
        print('🔍 DEBUG Dano Material $i - Fotos locais: ${(dano['fotosLocais'] as List<XFile>?)?.length ?? 0}');
        
        // Upload de fotos locais
        if ((dano['fotosLocais'] as List<XFile>?)?.isNotEmpty ?? false) {
          try {
            final fotosComprimidas = await ImageService()
                .compressImages(dano['fotosLocais'] as List<XFile>);
            
            final fotosUrls = await _firestoreService.uploadThirdPartyPhotos(
              _numeroSinistroGerado!,
              'dano_material_$i',
              fotosComprimidas,
            );
            
            print('✅ Upload Foto Dano Material $i OK! URLs: $fotosUrls');
            
            // 🆕 SALVAR AS URLs NO MAP!
            dano['fotosUrls'] = fotosUrls;
            dano.remove('fotosLocais'); // Remove a lista local
            
          } catch (e) {
            print('❌ Erro ao fazer upload de fotos: $e');
          }
        }
        
        // Upload de documentos locais
        if ((dano['documentosLocais'] as List<PlatformFile>?)?.isNotEmpty ?? false) {
          try {
            // Converter PlatformFile → XFile
            final xfiles = (dano['documentosLocais'] as List<PlatformFile>).map((pf) {
              if (pf.bytes != null) {
                return XFile.fromData(pf.bytes!, name: pf.name);
              } else {
                return XFile(pf.path!, name: pf.name);
              }
            }).toList();
            
            final documentosUrls = await _firestoreService.uploadThirdPartyDocuments(
              _numeroSinistroGerado!,
              'dano_material_$i',
              xfiles,
            );
            
            // 🆕 SALVAR AS URLs NO MAP!
            dano['documentosUrls'] = documentosUrls;
            dano.remove('documentosLocais'); // Remove a lista local
            
          } catch (e) {
            print('❌ Erro ao fazer upload de documentos: $e');
          }
        }
      }

      // 🆕 CONVERTER DANOS CORPORAIS (Map) EM OBJETOS BodilyInjury
      final danoscorporaisObj = _danoscorporais.map((t) {
        return BodilyInjury(
          id: t['id'] ?? '',
          nome: t['nome'] ?? '',
          cpfCnpj: t['cpfCnpj'] ?? '',
          endereco: t['endereco'] ?? '',
          telefone: t['telefone'] ?? '',
          numeroSinistro: t['numeroSinistro'] ?? '',
          email: t['email'] ?? '',
          relato: t['relato'] ?? '',
          fotosUrls: t['fotosUrls'] as List<String>?,
          documentosUrls: t['documentosUrls'] as List<String>?,
        );
      }).toList();
      
      final danosmaterialisObj = _danosmateriais.map((d) {
        return MaterialDamage(
          id: d['id'] ?? '',
          nome: d['nome'] ?? '',
          cpfCnpj: d['cpfCnpj'] ?? '',
          endereco: d['endereco'] ?? '',
          telefone: d['telefone'] ?? '',
          numeroSinistro: d['numeroSinistro'] ?? '',
          email: d['email'] ?? '',
          relato: d['relato'] ?? '',
          tipoPatrimonio: d['tipoPatrimonio'] ?? '',
          descricao: d['descricao'] ?? '',
          fotosUrls: (d['fotosUrls'] as List<String>?) ?? [],
          documentosUrls: (d['documentosUrls'] as List<String>?) ?? [],
        );
      }).toList();

      // 🆕 CONVERTER LISTA DE TERCEIROS (Map) EM OBJETOS ThirdParty
      final terceirosObj = _terceiros.map((t) {
        return ThirdParty(
          nome: t['nome'] ?? '',
          cpf: t['cpf'] ?? '',
          contato: t['contato'] ?? '',
          email: t['email'] ?? '',
          veiculo: Vehicle(
            chassi: '',
            marca: t['marca'] ?? '',
            modelo: t['modelo'] ?? '',
            ano: int.tryParse(t['ano'] ?? '0') ?? 0,
            anomodelo: int.tryParse(t['anoModelo'] ?? '0') ?? 0,
          ),
          relato: t['relato'] ?? '',
          placa: (t['placa'] ?? '').toUpperCase(),
          cor: t['cor'] ?? '',
          chassi: t['chassi'] ?? '',
          marcaTerceiro: t['marca'] ?? '',
          modeloTerceiro: t['modelo'] ?? '',
          anoFabricacaoTerceiro: t['ano'] ?? '',
          anoModeloTerceiro: t['anoModelo'] ?? '',
          numeroSinistroTerceiro: t['numeroSinistro'] ?? '',
          enderecoTerceiro: t['endereco'] ?? '',
          fotosUrls: t['fotosUrls'] as List<String>?,
          documentosUrls: t['documentosUrls'] as List<String>?,
          nomeContatoTerceiro: t['nomeContatoTerceiro'] ?? '',
          telefoneContatoTerceiro: t['telefoneContatoTerceiro'] ?? '',
          registroSeguradoraTerceiro: t['registroSeguradoraTerceiro'] ?? '',
        );
      }).toList();

      final transporte = _ramoSelecionado == 'Transporte'
      ? Transport(
          nomeMotorista: _ctrl['nomeMotorista']?.text.trim(),
          cpfMotorista: _ctrl['cpfMotorista']?.text.trim(),

          placaCavalo: _ctrl['placaCavalo']?.text.trim(),
          placaCarreta: _ctrl['placaCarreta']?.text.trim(),

          chassi: _ctrl['chassi']?.text.trim(),
          chassiCarreta: _ctrl['chassiCarreta']?.text.trim(),

          ano: int.tryParse(_ctrl['ano']?.text ?? '0') ?? 0,
          anomodelo: int.tryParse(_ctrl['anoModelo']?.text ?? '0') ?? 0,

          anoCarreta: int.tryParse(_ctrl['anoCarreta']?.text ?? '0') ?? 0,
          anoModeloCarreta: int.tryParse(_ctrl['anoModeloCarreta']?.text ?? '0') ?? 0,

          numeroAverbacao: _ctrl['numeroAverbacao']?.text.trim(),
          reguladora: _ctrl['reguladora']?.text.trim(),
          cte: _ctrl['cte']?.text.trim(),
          nfe: _ctrl['nfe']?.text.trim(),

          cor: _ctrl['cor']?.text.trim(),

          marcaCarreta: '',
          modeloCarreta: '',
          rctrc: '',
          vpo: '',
        )
      : null;

      Business? business;
      if (_ramoSelecionado == 'Empresarial') {
        business = Business(
          id: const Uuid().v4(),
          nomeEmpresa: _ctrl['nomeEmpresa']?.text.trim() ?? '',
          cnpjEmpresa: _ctrl['cnpjEmpresa']?.text.trim() ?? '',
          enderecoEmpresa: _ctrl['enderecoEmpresa']?.text.trim() ?? '',
          ramoAtividade: _ctrl['ramoAtividade']?.text.trim(),
          areaM2: double.tryParse(_ctrl['areaM2']?.text.trim() ?? '') ?? 0.0,
          tipoEstrutura: _ctrl['tipoEstrutura']?.text.trim(),
          numeroAndares: int.tryParse(_ctrl['numeroAndares']?.text.trim() ?? ''),
          sistemaSeguranca: _ctrl['sistemaSeguranca']?.text.trim(),
          situacaoImovel: _ctrl['situacaoImovel']?.text.trim(),
          anexos: [],
        );
      }

      final novoClaim = Claim(
        idCliente: _cliente?.id ?? '',
        responsavelId: userId,
        numeroSinistro: _numeroSinistroGerado!,
        tipoOcorrencia: 'Sinistro',
        ramoSinistro: _ramoSelecionado ?? 'Frota',
        dataOcorrencia: _parseData('dataSinistro'),
        horaOcorrencia: horaOcorrencia,
        dataAviso: _parseData('dataAviso'),
        tipoPerda: _ctrl['tipoPerda']!.text,
        localOcorrencia: _ctrl['localOcorrencia']?.text.trim() ?? _ctrl['enderecoEmpresa']?.text.trim() ?? 'Local não informado',
        enderecoTerceiro: _ctrl['endereco']?.text.trim() ?? '',
        relatoEvento: (_ctrl['relatoEvento']?.text ?? '').trim(),
        requerAprovacaoGerencial: false,
        aprovadoPorGerente: true,
        dataAbertura: DateTime.now(),
        dataUltimaAtualizacao: DateTime.now(),
        historicoStatus: [
          {
            'status': (_ctrl['status']?.text ?? '').isNotEmpty 
                ? _ctrl['status']!.text 
                : 'Aberto',
            'data': Timestamp.now(),
            'responsavel': userId ?? '',
            'responsavelEmail': userEmail ?? '',
            'registrado_por': _nomeUsuarioLogado ?? 'Usuário desconhecido',
          }
        ], // ⚠️ ATENÇÃO: esta vírgula é OBRIGATÓRIA
        terceiros: terceirosObj,
        veiculoSelecionado: veiculo,
        danoscorporais: danoscorporaisObj,
        danosmateriais: danosmaterialisObj,
        transporte: transporte,
        fotosUrls: [],
        arquivosLaudosUrls: [],
        numeroSeguradora: _ctrl['numeroSinistroSeguradora']!.text.trim(),
        seguradora: _ctrl['seguradora']!.text.trim(),
        clientNome: _cliente?.nome ?? _ctrl['empresaSegurada']!.text.trim(),
        clientCnpjCpf: _cliente?.cnpjCpf ?? _ctrl['cnpjSegurado']!.text.trim(),
        valorTotalSinistro: () {
          final raw = _ctrl['valor']!.text;
          final clean = raw.replaceAll(RegExp(r'[^\d,]'), '');
          return double.tryParse(clean.replaceAll(',', '.')) ?? 0.0;
        }(),
        status: (_ctrl['status']?.text ?? '').isNotEmpty ? _ctrl['status']!.text : 'Aberto',
        house: _ramoSelecionado == 'Residencial' ? house : null,
        life: _ramoSelecionado == 'Vidas' ? life : null,
        maquinaria: _ramoSelecionado == 'Máquinas' ? maquinaria : null,
        business: _ramoSelecionado == 'Empresarial' ? business : null,
        nomeContatoSinistro: _ctrl['nomeContatoSinistro']?.text ?? '',
        telefoneContatoSinistro: _ctrl['telefoneContatoSinistro']?.text ?? '',
        slaPrevisto: slaPrevistoData,
        apoliceId: _selectedApoliceId, 
      );

      if (!_savedOnce) {
        // 1. cria sinistro
        final docRef = await _firestoreService
            .getSinistrosCollection()
            .add(novoClaim.toMap());

        _currentClaimId = docRef.id;
        _savedOnce = true;

        // 🆕 ATUALIZAR totalReceita DO CLIENTE
        await _atualizarTotalReceitaCliente(_cliente?.id ?? '');

        setState(() => _isUploadingAnexos = true);

        final anexosUrls =
            await _uploadAnexos(_numeroSinistroGerado!);

        setState(() => _isUploadingAnexos = false);

        if (anexosUrls.isNotEmpty) {
          novoClaim.fotosUrls =
              anexosUrls['Fotos do Sinistro'] ?? [];

          novoClaim.arquivosLaudosUrls = [
            ...?anexosUrls['Documentos do Segurado'],
            ...?anexosUrls['Documentos do Veículo'],
            ...?anexosUrls['Laudos / Boletins'],
          ];
        }

        await _firestoreService
            .getSinistrosCollection()
            .doc(_currentClaimId)
            .update(novoClaim.toMap());

      } else if (_currentClaimId != null) {

        setState(() => _isUploadingAnexos = true);

        final anexosUrls =
            await _uploadAnexos(_numeroSinistroGerado!);

        setState(() => _isUploadingAnexos = false);

        if (anexosUrls.isNotEmpty) {
          novoClaim.fotosUrls =
              anexosUrls['Fotos do Sinistro'] ?? [];

          novoClaim.arquivosLaudosUrls = [
            ...?anexosUrls['Documentos do Segurado'],
            ...?anexosUrls['Documentos do Veículo'],
            ...?anexosUrls['Laudos / Boletins'],
          ];
        }

        await _firestoreService
            .getSinistrosCollection()
            .doc(_currentClaimId)
            .update(novoClaim.toMap());
      }

      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                  'Sinistro ${_numeroSinistroGerado!} registrado.'),
            ]),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e, stack) {
      
        debugPrint('❌ ERRO DETALHADO: $e');
        debugPrint('📍 STACK TRACE: $stack');
      
      if (mounted) setState(() => _saveStatus = 'Erro ao salvar');
      debugPrint('[SpreadsheetClaimScreen] $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Métodos de anexo ─────────────────────────────────────────────────────

  void _adicionarArquivos(
    String categoria,
    List<XFile> arquivos, [
    List<PlatformFile>? platformFiles,
  ]) {
    setState(() {
      _anexos[categoria]!.addAll(arquivos);

      if (platformFiles != null) {
        _platformFiles[categoria] ??= [];
        _platformFiles[categoria]!.addAll(platformFiles);
      }
    });

    _scheduleAutosave();
  }

  // Remove um arquivo de uma categoria
  void _removerArquivo(String categoria, XFile arquivo) {
    setState(() {
      _anexos[categoria]!.remove(arquivo);
      _platformFiles[categoria]?.removeWhere((pf) => pf.name == arquivo.name);
    });
  }

  // Abre o file picker para uma categoria específica
  Future<void> _pickArquivos(String categoria) async {
    final isImagem = categoria == 'Fotos do Sinistro';

    if (isImagem && !kIsWeb) {
      // Mobile/desktop: usa image_picker para fotos
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked.isNotEmpty) _adicionarArquivos(categoria, picked);
      return;
    }

    // Para todas as categorias no web, ou documentos em qualquer plataforma
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: isImagem ? FileType.image : FileType.custom,
      allowedExtensions: isImagem
          ? null
          : ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xls', 'xlsx'],
    );

    if (result != null && result.files.isNotEmpty) {
      if (isImagem) {
        // Imagens: converte para XFile para visualização nas miniaturas
        final xfiles = result.files
            .map((f) => XFile(f.path ?? '', name: f.name))
            .toList();
        _adicionarArquivos(categoria, xfiles);
      } else {
        // Documentos: guarda os PlatformFile originais (têm bytes no web)
        setState(() {
          _platformFiles[categoria] ??= [];
          _platformFiles[categoria]!.addAll(result.files);
          // Adiciona também como XFile para exibição na UI
          final xfiles = result.files
              .map((f) => XFile(f.path ?? '', name: f.name))
              .toList();
          _anexos[categoria]!.addAll(xfiles);
        });
        _scheduleAutosave();
      }
    }
  }

  // Faz upload de todos os anexos pendentes e retorna as URLs agrupadas
  Future<Map<String, List<String>>> _uploadAnexos(String numeroSinistro) async {
    final Map<String, List<String>> urls = {};

    for (final entry in _anexos.entries) {
      if (entry.value.isEmpty) continue;

      final categoria = entry.key;
      final arquivos = entry.value;
      final isImagem = categoria == 'Fotos do Sinistro';

      if (isImagem) {
        final comprimidas = await ImageService().compressImages(arquivos);
        final fUrls = await _firestoreService.uploadSinistroFotos(
            numeroSinistro, comprimidas);
        urls[categoria] = fUrls;
      } else {
        // Usa os PlatformFile originais (com bytes no web) se disponíveis;
        // caso contrário, monta sem bytes (mobile com path válido)
        final platformFiles = _platformFiles[categoria] ??
          await Future.wait(arquivos.map((xf) async {
            if (kIsWeb) {
              final bytes = await xf.readAsBytes();
              return PlatformFile(
                name: xf.name,
                size: bytes.length,
                bytes: bytes,
              );
            } else {
              return PlatformFile(
                name: xf.name,
                path: xf.path,
                size: 0,
              );
            }
          }));
        if (platformFiles.isNotEmpty) {
          final dUrls = await _firestoreService.uploadArquivosLaudos(
              numeroSinistro, platformFiles);
          urls[categoria] = dUrls;
        }
      }
    }
    return urls;
  }

  // Verifica se é imagem pelo nome do arquivo
  bool _isImageFile(String name) {
    final ext = p.extension(name).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp'].contains(ext);
  }

  // ── Busca de cliente ──────────────────────────────────────────────────────
  Future<void> _abrirBuscaCliente() async {
    final result = await showDialog<ClientSearchResult>(
      context: context,
      builder: (_) => ClientSearchDialog(
        initialQuery: _ctrl['empresaSegurada']?.text ?? '',
        onClientSelected: (c) => c != null ? ClientSearchResult.client(c) : null,
      ),
    );
    if (result == null) return;

    if (result.client != null) {
      // 🔥 FILTRA APÓLICES DO RAMO SELECIONADO
      final ramoAtual = _ramoSelecionado ?? '';
      final apolicesDoRamo = result.client!.apolices
          .where((a) => a.ramo == ramoAtual)
          .toList();

      Apolice? apolice;

      if (apolicesDoRamo.isEmpty) {
        // ⚠️ Nenhuma apólice para este ramo, mas preenche dados do cliente
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Cliente não possui apólice para o ramo "$ramoAtual". Preencha manualmente.'),
            backgroundColor: Colors.orange,
          ),
        );
        apolice = null;
      } else if (apolicesDoRamo.length > 1) {
        // 🔥 SE HOUVER MÚLTIPLAS APÓLICES, ABRE MODAL PARA ESCOLHER
        apolice = await showDialog<Apolice>(
          context: context,
          builder: (_) => ApoliceSelectionDialog(
            apolices: apolicesDoRamo,
            ramoSelecionado: ramoAtual,
          ),
        );
      } else {
        // Uma única apólice
        apolice = apolicesDoRamo.first;
      }

      // ✅ PREENCHE OS DADOS DO CLIENTE (SEMPRE)
      setState(() {
        _selectedApoliceId = apolice?.id;
        _cliente = result.client;
        _isNovoCliente = false;
        _ctrl['empresaSegurada']!.text = result.client!.nome;
        _ctrl['cnpjSegurado']!.text = result.client!.cnpjCpf;
        _ctrl['contatoSegurado']?.text = result.client!.contato;

        // ✅ PREENCHE DADOS DA APÓLICE (SE HOUVER)
        if (apolice != null) {
          _ctrl['numeroApolice']!.text = apolice.numeroApolice;
          _ctrl['dataVigenciaFim']!.text = DateFormat('dd/MM/yyyy').format(apolice.dataFim);
          _ctrl['valorGatilho']!.text = _formatarMoeda((apolice.valorGatilho * 100).toInt());

          if (apolice.seguradora.isNotEmpty) {
            _ctrl['seguradora']!.text = apolice.seguradora;
          }
        } else {
          // Limpa campos da apólice se não encontrou
          _ctrl['numeroApolice']!.clear();
          _ctrl['dataVigenciaFim']!.clear();
          _ctrl['valorGatilho']!.clear();
          _ctrl['seguradora']!.clear();
        }
      });

      // 🔥 Atualiza o uso atual da apólice
      _calcularUsoAtualCliente(result.client!.id).then((valor) {
        setState(() {
          _ctrl['usoAtualApolice']!.text = _formatarMoeda((valor * 100).toInt());
        });
      });

    } else if (result.searchText != null && result.searchText!.isNotEmpty) {
      setState(() {
        _cliente = null;
        _isNovoCliente = true;
        _selectedApoliceId = null;
        _ctrl['empresaSegurada']!.text = result.searchText!;
      });
    }
  }
 
  // 🆕 CALCULAR USO ATUAL DA APÓLICE (soma de todos os sinistros)
  Future<double> _calcularUsoAtualCliente(String clienteId) async {
    try {
      if (clienteId.isEmpty) return 0.0;
      
      // Buscar direto do Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('sinistros')
          .where('id_cliente', isEqualTo: clienteId)
          .get();
      
      double total = 0.0;
      
      for (var doc in snapshot.docs) {
        final valor = (doc['valor_total_sinistro'] ?? 0.0).toDouble();
        total += valor;
      }
      
      return total;
    } catch (e) {
      print('Erro ao calcular uso atual: $e');
      return 0.0;
    }
  }

  // 🆕 ATUALIZAR totalReceita DO CLIENTE (soma de todos os sinistros)
  Future<void> _atualizarTotalReceitaCliente(String clienteId) async {
    try {
      if (clienteId.isEmpty) {
        print('❌ clienteId vazio!');
        return;
      }

      print('🔍 Atualizando totalReceita para clienteId: $clienteId');

      // Buscar todos os sinistros do cliente
      final snapshot = await FirebaseFirestore.instance
          .collection('sinistros')
          .where('id_cliente', isEqualTo: clienteId)
          .get();

      print('📊 Sinistros encontrados: ${snapshot.docs.length}');

      // Somar todos os valorTotalSinistro
      double totalReceita = 0.0;
      for (var doc in snapshot.docs) {
        final valor = (doc['valor_total_sinistro'] ?? 0.0).toDouble();
        totalReceita += valor;
        print('  + R\$ $valor');
      }

      print('💰 Total a atualizar: R\$ $totalReceita');

      // Verificar se documento existe
      final docExists = await FirebaseFirestore.instance
          .collection('clientes')
          .doc(clienteId)
          .get();
 
      if (!docExists.exists) {
        print('⚠️  AVISO: Documento NÃO EXISTE em clients/$clienteId');
        
        // Listar todos os clients para debugar
        print('📋 Listando todos os clients:');
        final allClients = await FirebaseFirestore.instance
            .collection('clientes')
            .get();
        
        for (var doc in allClients.docs) {
          print('   - ID: ${doc.id}, Nome: ${doc['nome']}');
        }
        
        return;
      }

      // Atualizar cliente com novo totalReceita
      await FirebaseFirestore.instance
          .collection('clientes')
          .doc(clienteId)
          .update({
            'total_receita': totalReceita,
          });

      print('✅ totalReceita atualizado com sucesso!');
    } catch (e) {
      print('❌ Erro ao atualizar totalReceita: $e');
      print('   ClienteId: $clienteId');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // 🆕 MÉTODOS DE UPLOAD PARA TERCEIROS
  // ═════════════════════════════════════════════════════════════════════════════

  /// Upload de foto individual para um terceiro (armazena localmente)
  Future<void> _uploadFotoTerceiro(int terceiroIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;

      // Converter para XFile
      final xfiles = result.files.map((f) {
        if (f.bytes != null) {
          return XFile.fromData(f.bytes!, name: f.name);
        } else {
          return XFile(f.path!, name: f.name);
        }
      }).toList();

      if (mounted) {
        setState(() {
          // Inicializar lista se não existir
          if (_terceiros[terceiroIndex]['fotosLocais'] == null) {
            _terceiros[terceiroIndex]['fotosLocais'] = <XFile>[];
          }
          // Adicionar fotos localmente
          (_terceiros[terceiroIndex]['fotosLocais'] as List<XFile>).addAll(xfiles);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${xfiles.length} foto(s) adicionada(s) (serão salvas ao criar sinistro)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao adicionar fotos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Upload de documento individual para um terceiro (armazena localmente)
  Future<void> _uploadDocumentoTerceiro(int terceiroIndex) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) return;

      if (!mounted) return;

      if (mounted) {
        setState(() {
          // Inicializar lista se não existir
          if (_terceiros[terceiroIndex]['documentosLocais'] == null) {
            _terceiros[terceiroIndex]['documentosLocais'] = <PlatformFile>[];
          }
          // Adicionar documentos localmente
          (_terceiros[terceiroIndex]['documentosLocais'] as List<PlatformFile>).addAll(result.files);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.files.length} documento(s) adicionado(s) (serão salvos ao criar sinistro)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao adicionar documentos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


// ═════════════════════════════════════════════════════════════════════════════
// 🔴 UPLOAD DE FOTOS - DANOS CORPORAIS
// ═════════════════════════════════════════════════════════════════════════════
 
// 🔴 UPLOAD DE FOTOS - DANOS CORPORAIS
Future<void> _uploadFotoBodilyInjury(int danoIndex) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final xfiles = result.files.map((f) {
      if (f.bytes != null) {
        return XFile.fromData(f.bytes!, name: f.name);
      } else {
        return XFile(f.path!, name: f.name);
      }
    }).toList();

    if (mounted) {
      setState(() {
        if (_danoscorporais[danoIndex]['fotosLocais'] == null) {
          _danoscorporais[danoIndex]['fotosLocais'] = <XFile>[];
        }
        (_danoscorporais[danoIndex]['fotosLocais'] as List<XFile>).addAll(xfiles);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${xfiles.length} foto(s) adicionada(s)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar fotos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 📄 UPLOAD DE DOCUMENTOS - DANOS CORPORAIS
Future<void> _uploadDocumentoBodilyInjury(int danoIndex) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    if (mounted) {
      setState(() {
        if (_danoscorporais[danoIndex]['documentosLocais'] == null) {
          _danoscorporais[danoIndex]['documentosLocais'] = <PlatformFile>[];
        }
        (_danoscorporais[danoIndex]['documentosLocais'] as List<PlatformFile>).addAll(result.files);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result.files.length} documento(s) adicionado(s)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar documentos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 🔴 UPLOAD DE FOTOS - DANOS MATERIAIS
Future<void> _uploadFotoMaterialDamage(int danoIndex) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final xfiles = result.files.map((f) {
      if (f.bytes != null) {
        return XFile.fromData(f.bytes!, name: f.name);
      } else {
        return XFile(f.path!, name: f.name);
      }
    }).toList();

    if (mounted) {
      setState(() {
        if (_danosmateriais[danoIndex]['fotosLocais'] == null) {
          _danosmateriais[danoIndex]['fotosLocais'] = <XFile>[];
        }
        (_danosmateriais[danoIndex]['fotosLocais'] as List<XFile>).addAll(xfiles);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${xfiles.length} foto(s) adicionada(s)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar fotos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// 📄 UPLOAD DE DOCUMENTOS - DANOS MATERIAIS
Future<void> _uploadDocumentoMaterialDamage(int danoIndex) async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    if (mounted) {
      setState(() {
        if (_danosmateriais[danoIndex]['documentosLocais'] == null) {
          _danosmateriais[danoIndex]['documentosLocais'] = <PlatformFile>[];
        }
        (_danosmateriais[danoIndex]['documentosLocais'] as List<PlatformFile>).addAll(result.files);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result.files.length} documento(s) adicionado(s)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erro ao adicionar documentos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  // ── Modal de Auto Preenchimento ────────────────────────────────────────────

  void _abrirAutoFillModal() async {
    final result = await showDialog(
      context: context,
      builder: (_) => _AutoFillModal(),
    );

    if (result != null) {
      _applyAutoFill(result);
    }
  }

  void _applyAutoFill(Map<String, dynamic> data) {
    setState(() {
      final veiculo = data['veiculo'] ?? {};
      final condutor = data['condutor'] ?? {};
      final file = data['crlvFile'];
      final isProprietario = data['condutorEhProprietario'] ?? true;

      // Preenche veículo
      _ctrl['placaSegurado']?.text = veiculo['placa'] ?? '';
      _ctrl['marca']?.text = veiculo['marca'] ?? '';
      _ctrl['modelo']?.text = veiculo['modelo'] ?? '';
      _ctrl['chassi']?.text = veiculo['chassi'] ?? '';
      _ctrl['ano']?.text = veiculo['ano'] ?? '';
      _ctrl['anoModelo']?.text = veiculo['anoModelo'] ?? '';
      _ctrl['cor']?.text = veiculo['cor'] ?? '';

      // Preenche condutor (proprietário)
      if (isProprietario) {
        _ctrl['nomeCondutor']?.text = condutor['nome'] ?? '';
        _ctrl['cpfCondutor']?.text = condutor['cpf'] ?? '';
      } else {
        _ctrl['nomeCondutor']?.text = '';
        _ctrl['cpfCondutor']?.text = '';
      }

      // 🔥 Sincroniza o checkbox da tela principal
      _condutorEhProprietario = isProprietario;

      // 🔥 Copia para os campos de condutor motorista
      if (isProprietario) {
        _ctrl['nomeCondutorMotorista']?.text = condutor['nome'] ?? '';
        _ctrl['cpfCondutorMotorista']?.text = condutor['cpf'] ?? '';
      } else {
        _ctrl['nomeCondutorMotorista']?.text = '';
        _ctrl['cpfCondutorMotorista']?.text = '';
      }

      // Relato
      _ctrl['relatoEvento']?.text = data['relato'] ?? '';

      // Anexo
      if (file != null) {
        _platformFiles['Documentos do Veículo'] ??= [];
        _platformFiles['Documentos do Veículo']!.add(file);
        _anexos['Documentos do Veículo']!.add(
          XFile.fromData(file.bytes!, name: file.name),
        );
      }
    });
  }

  // Auto fill de terceiros
  void _abrirAutoFillTerceiro(int index) async {
    final result = await showDialog(
      context: context,
      builder: (_) => _AutoFillModal(),
    );

    if (result != null) {
      _applyAutoFillTerceiro(index, result);
    }
  }

  void _applyAutoFillTerceiro(int index, Map<String, dynamic> data) {
    setState(() {
      final veiculo = data['veiculo'] ?? {};
      final condutor = data['condutor'] ?? {};
      final isProprietario = data['condutorEhProprietario'] ?? true;
      final file = data['crlvFile'];

      _terceiros[index]['nome'] = isProprietario ? (condutor['nome'] ?? '') : '';
      _terceiros[index]['cpf'] = isProprietario ? (condutor['cpf'] ?? '') : '';
      _terceiros[index]['placa'] = veiculo['placa'] ?? '';
      _terceiros[index]['chassi'] = veiculo['chassi'] ?? '';
      _terceiros[index]['marca'] = veiculo['marca'] ?? '';
      _terceiros[index]['modelo'] = veiculo['modelo'] ?? '';
      _terceiros[index]['ano'] = veiculo['ano'] ?? '';
      _terceiros[index]['cor'] = veiculo['cor'] ?? '';
      _terceiros[index]['anoModelo'] = veiculo['anoModelo'] ?? '';

      if (file != null) {
        _terceiros[index]['documentosLocais'] ??= <PlatformFile>[];

        (_terceiros[index]['documentosLocais'] as List<PlatformFile>).add(file);
      }
    });

    // 🔥 Atualiza controllers depois do setState
    final state = _terceirosKey.currentState;

    if (state != null) {
      final ctrls = state._controllers[index];

      if (ctrls != null) {
        ctrls['nome']?.text = _terceiros[index]['nome'];
        ctrls['cpf']?.text = _terceiros[index]['cpf'];
        ctrls['placa']?.text = _terceiros[index]['placa'];
        ctrls['chassi']?.text = _terceiros[index]['chassi'];
        ctrls['marca']?.text = _terceiros[index]['marca'];
        ctrls['modelo']?.text = _terceiros[index]['modelo'];
        ctrls['ano']?.text = _terceiros[index]['ano'];
        ctrls['cor']?.text = _terceiros[index]['cor'];
        ctrls['anoModelo']?.text = _terceiros[index]['anoModelo'];
      }
    }
  }

  // Modal de Transporte

  void _abrirAutoFillTransporteModal() async {
    final result = await showDialog(
      context: context,
      builder: (_) => _AutoFillTransporteModal(),
    );

    if (result != null) {
      _applyAutoFillTransporte(result);
    }
  }

  void _applyAutoFillTransporte(Map<String, dynamic> data) {
    final cavalo = data['cavalo'] ?? {};
    final carreta = data['carreta'] ?? {};
    final condutor = data['condutor'] ?? {};
    _condutorEhProprietario = data['condutorEhProprietario'] ?? true;
    final fileCavalo = data['crlvCavaloFile'];
    final fileCarreta = data['crlvCarretaFile'];

    setState(() {
      // 🚛 CAVALO
      _ctrl['placaCavalo']?.text = cavalo['placa'] ?? '';
      _ctrl['marca']?.text = cavalo['marca'] ?? '';
      _ctrl['modelo']?.text = cavalo['modelo'] ?? '';
      _ctrl['chassi']?.text = cavalo['chassi'] ?? '';
      _ctrl['ano']?.text = cavalo['ano'] ?? '';
      _ctrl['anoModelo']?.text = cavalo['anoModelo'] ?? '';
      _ctrl['cor']?.text = cavalo['cor'] ?? '';

      // 🚛 CARRETA
      _ctrl['placaCarreta']?.text = carreta['placa'] ?? '';
      _ctrl['marcaCarreta']?.text = carreta['marca'] ?? '';
      _ctrl['modeloCarreta']?.text = carreta['modelo'] ?? '';
      _ctrl['chassiCarreta']?.text = carreta['chassi'] ?? '';
      _ctrl['anoCarreta']?.text = carreta['ano'] ?? '';
      _ctrl['anoModeloCarreta']?.text = carreta['anoModelo'] ?? '';

      // 👤 CONDUTOR
      if (_condutorEhProprietario) {
        _ctrl['nomeMotorista']?.text = condutor['nome'] ?? '';
        _ctrl['cpfMotorista']?.text = condutor['cpf'] ?? '';
      } else {
        _ctrl['nomeMotorista']?.text = '';
        _ctrl['cpfMotorista']?.text = '';
      }

      if (fileCavalo != null) {
        _platformFiles['Documentos do Veículo'] ??= [];
        _platformFiles['Documentos do Veículo']!.add(fileCavalo);

        _anexos['Documentos do Veículo']!.add(
          XFile.fromData(fileCavalo.bytes!, name: fileCavalo.name),
        );
      }

      if (fileCarreta != null) {
        _platformFiles['Documentos do Veículo'] ??= [];
        _platformFiles['Documentos do Veículo']!.add(fileCarreta);

        _anexos['Documentos do Veículo']!.add(
          XFile.fromData(fileCarreta.bytes!, name: fileCarreta.name),
        );
      }
    });
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

  // RELATO GERADO AUTOMATICAMENTE
  void _selecionarRelato(String valor) {
    setState(() {
      _respostasRelato[_stepAtualRelato] = valor;

      if (_stepAtualRelato == RelatoStep.situacao) {
        _stepAtualRelato = RelatoStep.acao;
      } else if (_stepAtualRelato == RelatoStep.acao) {
        _stepAtualRelato = RelatoStep.evento;
      } else if (_stepAtualRelato == RelatoStep.evento) {
        _stepAtualRelato = RelatoStep.impacto; // 🔥 NOVO
      }
    });
  }

  String _formatCpf(String cpf) {
    final digits = cpf.replaceAll(RegExp(r'\D'), '');

    if (digits.length != 11) return cpf;

    return '${digits.substring(0,3)}.${digits.substring(3,6)}.${digits.substring(6,9)}-${digits.substring(9)}';
  }

  String _getDescricaoSegurado() {
    final ramo = _ramoSelecionado ?? '';

    if (ramo == 'Transporte') {
      final cavalo = _ctrl['placaCavalo']?.text ?? '';
      final carreta = _ctrl['placaCarreta']?.text ?? '';
      final motorista = _ctrl['nomeMotorista']?.text ?? '';

      String texto = 'o conjunto veicular';

      if (cavalo.isNotEmpty) {
        texto += ' (cavalo placa $cavalo';
        if (carreta.isNotEmpty) {
          texto += ' e carreta placa $carreta';
        }
        texto += ')';
      }
      if (motorista.isNotEmpty) {
        texto += ', conduzido por $motorista';
      }
      return texto;
    }

    if (ramo == 'Frota' || ramo == 'Veículo Individual' || ramo == 'Civil Ônibus (RCO)') {
      final placa = _ctrl['placaSegurado']?.text ?? '';
      final proprietario = _ctrl['nomeCondutor']?.text ?? '';
      final cpfProprietario = _ctrl['cpfCondutor']?.text ?? '';

      String texto = 'o veículo segurado';

      if (placa.isNotEmpty) {
        texto += ' de placa $placa';
      }

      // Dados do proprietário
      if (proprietario.isNotEmpty) {
        texto += ', de propriedade de $proprietario';
        if (cpfProprietario.isNotEmpty) {
          texto += ' (CPF ${_formatCpf(cpfProprietario)})';
        }
      }

      // Dados do condutor
      if (_condutorEhProprietario) {
        // Proprietário é o condutor
        if (proprietario.isNotEmpty) {
          texto += ', conduzido pelo proprietário';
        } else {
          texto += ', conduzido pelo proprietário (não informado)';
        }
      } else {
        // Condutor é diferente do proprietário
        final motorista = _ctrl['nomeCondutorMotorista']?.text ?? '';
        final cpfMotorista = _ctrl['cpfCondutorMotorista']?.text ?? '';

        if (motorista.isNotEmpty) {
          texto += ', conduzido por $motorista';
          if (cpfMotorista.isNotEmpty) {
            texto += ' (CPF ${_formatCpf(cpfMotorista)})';
          }
        } else {
          texto += ', com condutor não informado';
        }
      }

      return texto;
    }

    if (ramo == 'Vida') {
      final nome = _ctrl['nomeSegurado']?.text ?? '';
      if (nome.isNotEmpty) {
        return 'o segurado $nome';
      }
      return 'o segurado';
    }

    return 'o objeto segurado';
  }

  String _getClassificacaoAcidente() {
    final situacao = _clean(_respostasRelato[RelatoStep.situacao] ?? '');
    final acao = _clean(_respostasRelato[RelatoStep.acao] ?? '');
    final evento = _clean(_respostasRelato[RelatoStep.evento] ?? '');
    final impacto = _clean(_respostasRelato[RelatoStep.impacto] ?? '');

    final qtdTerceiros = _terceiros.length;

    // 🔥 ENGAVETAMENTO (mais preciso)
    if (qtdTerceiros >= 2 &&
        (evento.contains('atingiu') || evento.contains('colidiu'))) {
      return 'engavetamento envolvendo múltiplos veículos';
    }

    // 🔥 COLISÃO TRASEIRA (parado + atingido)
    if (evento.contains('atingido') &&
        (situacao.contains('parado') || situacao.contains('estacionado'))) {
      return 'colisão traseira';
    }

    // 🔥 COLISÃO EM MANOBRA (agora usando ação também)
    if (situacao.contains('manobra') ||
        acao.contains('manobra') ||
        acao.contains('conversão')) {
      return 'colisão durante manobra';
    }

    // 🔥 PERDA DE CONTROLE
    if (evento.contains('perdeu o controle')) {
      return 'perda de controle direcional';
    }

    // 🔥 COLISÃO LATERAL (fallback mais comum)
    if (evento.contains('colidiu')) {
      return 'colisão lateral';
    }

    // 🔥 DESLOCAMENTO + IMPACTO (novo ganho)
    if (acao.contains('deslocamento') && evento.contains('atingiu')) {
      return 'colisão durante deslocamento';
    }

    // 🔥 DANO MATERIAL SIMPLES
    if (impacto.contains('danos materiais')) {
      return 'sinistro com danos materiais';
    }

    return 'sinistro de natureza não especificada';
  }

  String _getResponsabilidade() {
    final situacao = _respostasRelato[RelatoStep.situacao] ?? '';
    final evento = _respostasRelato[RelatoStep.evento] ?? '';

    final qtdTerceiros = _terceiros.length;

    // 🔥 TRASEIRA (quase sempre terceiro culpado)
    if (evento.contains('atingido') && situacao.contains('parado')) {
      return 'não sendo possível imputar responsabilidade ao segurado, havendo indícios de culpa de terceiro';
    }

    // 🔥 SEGURADO ATINGIU
    if (evento.contains('atingiu')) {
      if (qtdTerceiros > 1) {
        return 'indicando possível responsabilidade parcial do segurado, considerando envolvimento de múltiplos veículos';
      }
      return 'indicando possível responsabilidade do segurado';
    }

    // 🔥 PERDA DE CONTROLE
    if (evento.contains('perdeu o controle')) {
      return 'indicando possível responsabilidade do condutor do veículo que perdeu o controle';
    }

    // 🔥 MANOBRA
    if (situacao.contains('manobra')) {
      return 'sinistro ocorrido durante manobra, sendo necessária análise para definição de responsabilidade';
    }

    return 'responsabilidade ainda em apuração';
  }

  String _getTipoImpacto() {
    final impacto = _respostasRelato[RelatoStep.impacto] ?? '';

    if (impacto.contains('grande monta')) {
      return 'com avarias de grande monta';
    }

    if (impacto.contains('múltiplos')) {
      return 'com envolvimento de múltiplos veículos';
    }

    if (impacto.contains('danos materiais')) {
      return 'com danos materiais';
    }

    return '';
  }

  String _montarRelato() {
    final situacao = _respostasRelato[RelatoStep.situacao] ?? '';
    final acao = _respostasRelato[RelatoStep.acao] ?? '';
    final evento = _respostasRelato[RelatoStep.evento] ?? '';
    final impacto = _respostasRelato[RelatoStep.impacto] ?? '';
    final data = _ctrl['dataSinistro']?.text ?? '';

    final classificacao = _getClassificacaoAcidente();
    final responsabilidade = _getResponsabilidade();
    final terceirosTexto = _montarTerceiros();
    final tipoImpacto = _getTipoImpacto();

    String texto = '';

    // 🗓️ Data
    if (data.isNotEmpty) {
      texto += 'Na data de $data, ';
    }

    // 🚛🚗 Segurado (dinâmico por ramo)
    texto += _getDescricaoSegurado();

    // 📍 Situação
    if (situacao.isNotEmpty) {
      texto += ', encontrava-se $situacao';
    }

    // 🔄 Ação
    if (acao.isNotEmpty) {
      texto += ', quando $acao';
    }

    // 💥 Evento
    if (evento.isNotEmpty) {
      texto += ', ocasião em que $evento';
    }

    // 👥 Terceiros (só adiciona se existir)
    if (terceirosTexto.isNotEmpty) {
      if (evento.contains('colidiu') || evento.contains('atingiu')) {
        texto += ' $terceirosTexto';
      } else {
        texto += ' envolvendo $terceirosTexto';
      }
    }

    // 🧩 Impacto (AGORA NO LUGAR CERTO)
    if (impacto.isNotEmpty) {
      texto += ', $impacto';
    }

    if (tipoImpacto.isNotEmpty) {
      texto += ' $tipoImpacto';
    }

    return _finalizarTexto(texto);
  }

  String _finalizarTexto(String texto) {
    return texto
        .replaceAll('quando quando', 'quando')
        .replaceAll('com com', 'com')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(' ,', ',')
        .replaceAll(' .', '.')
        .trim();
  }

  String _montarTerceiros() {
    if (_terceiros.isEmpty) return '';

    final placaSegurado = _ctrl['placaSegurado']?.text ?? '';

    final listaFiltrada = _terceiros
        .where((t) => t['placa'] != placaSegurado)
        .toList();

    if (listaFiltrada.isEmpty) return '';

    if (listaFiltrada.length == 1) {
      final t = listaFiltrada.first;
      return 'o veículo do terceiro ${t['nome'] ?? ''}, de placa ${t['placa'] ?? ''}';
    }

    return listaFiltrada.asMap().entries.map((e) {
      final i = e.key + 1;
      final t = e.value;
      return 'terceiro $i (${t['nome'] ?? ''}, placa ${t['placa'] ?? ''})';
    }).join(', ');
  }

  String _clean(String texto) {
    return texto
        .replaceAll(RegExp(r'\bquando\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bocasião em que\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // --- Copiar dados do cliente para 'Vidas' ---
  void _copiarDadosCliente() {
    if (_cliente == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um cliente primeiro')),
      );
      return;
    }
    setState(() {
      _ctrl['nomeSegurado']?.text = _cliente!.nome;
      _ctrl['cpfSegurado']?.text = _cliente!.cnpjCpf;
      _ctrl['telefone']?.text = _cliente!.contatoTelefone;
      _ctrl['email']?.text = _cliente!.email;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados do cliente copiados para o segurado')),
    );
  }

  Widget _buildResumoRelato() {
    return Wrap(
      spacing: 8,
      children: _respostasRelato.entries.map((e) {
        return Chip(
          label: Text(e.value),
          onDeleted: () {
            setState(() {
              _stepAtualRelato = e.key;
              _respostasRelato.removeWhere((k, v) => k.index >= e.key.index);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildOpcoesRelato() {
    final opcoes = _opcoesRelato[_stepAtualRelato]!;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: opcoes.map((op) {
        return GestureDetector(
          onTap: () => _selecionarRelato(op),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(op),
          ),
        );
      }).toList(),
    );
  }

  // ── Dispose ───────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _ctrl.values) c.dispose();
    for (final f in _focus.values) f.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_ramoSelecionadoLabel,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E))),
            if (_saveStatus.isNotEmpty)
              Text(_saveStatus,
                  style: TextStyle(
                      fontSize: 11,
                      color: _saveStatus.startsWith('Erro')
                          ? Colors.red
                          : Colors.grey.shade600)),
          ],
        ),
        
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
            label: const Text('Salvar e Fechar'),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1565C0)),
            onPressed: _isSaving ? null : () => _salvar(silent: false),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Grupos de campos ─────────────────────────────────────────
            ..._groups.map((g) {
              // 🆕 Se for grupo de terceiros, renderizar widget customizado
              if (g.id == 'terceiros') {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: g.color, width: 4)),
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
                      Row(
                        children: [
                          Icon(g.icon, color: g.color, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            g.title,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _TerceirosListWidget(
                        key: _terceirosKey,
                        terceiros: _terceiros,
                        onAdd: (_) => setState(() => _terceiros.add({})),
                        onRemove: (index) => setState(() => _terceiros.removeAt(index)),
                        onEditField: (index, field, value) {
                          // 📸 Upload de foto
                          if (field == 'adicionarFoto') {
                            _uploadFotoTerceiro(index);

                          // 📄 Upload de documento
                          } else if (field == 'adicionarDocumento') {
                            _uploadDocumentoTerceiro(index);

                          // 🤖 AUTO FILL DO TERCEIRO
                          } else if (field == 'autoFill') {
                            _abrirAutoFillTerceiro(index);

                          // ✏️ Campos normais
                          } else {
                              _terceiros[index][field] = value;
                            }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }
              // 🔴 DANOS CORPORAIS (AGORA FORA DO IF!)
              if (g.id == 'danoscorporais') {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: const Color(0xFFD32F2F), width: 4)),
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
                      Row(
                        children: [
                          Icon(Icons.medical_information_outlined, color: const Color(0xFFD32F2F), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Danos Corporais',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _BodilyInjuryListWidget(
                        danoscorporais: _danoscorporais,
                        onAdd: (novoItem) {
                          setState(() {
                            _danoscorporais.add(novoItem);
                          });
                        },
                        onRemove: (index) {
                          setState(() {
                            _danoscorporais.removeAt(index);
                          });
                        },
                        onEditField: (index, fieldId, value) {
                          setState(() {
                            _danoscorporais[index][fieldId] = value;
                          });
                        },
                        onUploadFoto: _uploadFotoBodilyInjury,
                        onUploadDocumento: _uploadDocumentoBodilyInjury,
                      ),
                    ],
                  ),
                );
              }

              // 🟡 DANOS MATERIAIS (TAMBÉM FORA DO IF!)
              if (g.id == 'danosmateriais') {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: const Color(0xFFF57F17), width: 4)),
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
                      Row(
                        children: [
                          Icon(Icons.home_outlined, color: const Color(0xFFF57F17), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Danos Materiais',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _MaterialDamageListWidget(
                        danosmateriais: _danosmateriais,
                        onAdd: (novoItem) {
                          setState(() {
                            _danosmateriais.add(novoItem);
                          });
                        },
                        onRemove: (index) {
                          setState(() {
                            _danosmateriais.removeAt(index);
                          });
                        },
                        onEditField: (index, fieldId, value) {
                          setState(() {
                            _danosmateriais[index][fieldId] = value;
                          });
                        },
                        onUploadFoto: _uploadFotoMaterialDamage,
                        onUploadDocumento: _uploadDocumentoMaterialDamage,
                      ),
                    ],
                  ),
                );
              }
              // Caso contrário, renderizar normalmente com _GroupCard
              return _GroupCard(
                group: g,
                expanded: _expanded.contains(g.id),
                controllers: _ctrl,
                focusNodes: _focus,
                onToggle: () => setState(() {
                  if (_expanded.contains(g.id)) {
                    _expanded.remove(g.id);
                  } else {
                    _expanded.add(g.id);
                  }
                }),
                onChanged: (_) => _scheduleAutosave(),
                onAutoFill: (g.id == 'veiculo')
                  ? _abrirAutoFillModal
                  : (g.id == 'transporte')
                      ? _abrirAutoFillTransporteModal
                              : (g.id == 'vida')         // ← novo
                              ? _copiarDadosCliente 
                      : null,
              );
            }).toList(),

            // ── Grupo de Anexos ──────────────────────────────────────────
            _AnexosCard(
              anexos: _anexos,
              dragOver: _dragOver,
              isUploading: _isUploadingAnexos,
              expanded: _expanded.contains('anexos'),
              onToggle: () => setState(() {
                if (_expanded.contains('anexos')) {
                  _expanded.remove('anexos');
                } else {
                  _expanded.add('anexos');
                }
              }),
              onAddArquivos: _adicionarArquivos,
              onRemoveArquivo: _removerArquivo,
              onPickArquivos: _pickArquivos,
              onDragEntered: (cat, val) =>
                  setState(() => _dragOver[cat] = val),
              onDragExited: (cat, val) =>
                  setState(() => _dragOver[cat] = val),
              isImageFile: _isImageFile,
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.center,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : () => _salvar(silent: false),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  _isSaving ? 'Salvando...' : 'Concluir e Salvar Sinistro',
                  style: const TextStyle(fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }
}

// ─── Barra de cliente (MELHORADA) ─────────────────────────────────────────────────────────
class _ClientBar extends StatelessWidget {
  const _ClientBar({
    required this.controller,
    required this.cliente,
    required this.isNovo,
    required this.onTap,
  });
  final TextEditingController controller;
  final Client? cliente;
  final bool isNovo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        // 🆕 Gradiente mais chamativo
        gradient: cliente != null
            ? LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  const Color(0xFFFFF3E0),
                  const Color(0xFFFFE0B2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(12),
        // 🆕 Borda colorida e destacada
        border: Border.all(
          color: cliente != null
              ? Colors.blue.shade300
              : const Color(0xFFFF6F00),
          width: 2.5,
        ),
        // 🆕 Sombra 3D
        boxShadow: [
          BoxShadow(
            color: cliente != null
                ? Colors.blue.withOpacity(0.25)
                : Colors.orange.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          splashColor: cliente != null
              ? Colors.blue.withOpacity(0.1)
              : Colors.orange.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                // 🆕 Ícone maior e colorido
                Icon(
                  Icons.business,
                  color: cliente != null
                      ? Colors.blue.shade700
                      : Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: cliente != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🆕 Nome muito maior e bold
                            Text(
                              cliente!.nome,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.blue.shade900,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 🆕 CNPJ/CPF em destaque
                            Row(
                              children: [
                                Icon(
                                  Icons.badge,
                                  size: 12,
                                  color: Colors.blue.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  cliente!.cnpjCpf,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🆕 Texto principal maior
                            Text(
                              controller.text.isNotEmpty
                                  ? controller.text
                                  : '👉 Busque ou crie um cliente...',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: controller.text.isNotEmpty
                                    ? Colors.orange.shade900
                                    : Colors.orange.shade700,
                                fontStyle: controller.text.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // 🆕 Dica abaixo
                            if (controller.text.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 12,
                                      color: Colors.orange.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Clique para vincular ou criar cliente',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.orange.shade700,
                                          fontStyle: FontStyle.italic,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(width: 8),
                // 🆕 Badge maior com cores vibrantes
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cliente != null
                        ? Colors.green.shade500
                        : isNovo
                            ? Colors.orange.shade500
                            : Colors.blue.shade500,
                    borderRadius: BorderRadius.circular(20),
                    // 🆕 Sombra no badge
                    boxShadow: [
                      BoxShadow(
                        color: cliente != null
                            ? Colors.green.withOpacity(0.3)
                            : isNovo
                                ? Colors.orange.withOpacity(0.3)
                                : Colors.blue.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    cliente != null
                        ? '✓ Vinculado'
                        : isNovo
                            ? '+ Novo'
                            : '🔍 Buscar',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 🆕 Ícone maior
                Icon(
                  Icons.search,
                  size: 22,
                  color: cliente != null
                      ? Colors.blue.shade700
                      : Colors.orange.shade700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Card de grupo ────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {

  final VoidCallback? onAutoFill;

  const _GroupCard({
    required this.group,
    required this.expanded,
    required this.controllers,
    required this.focusNodes,
    required this.onToggle,
    required this.onChanged,
    this.onAutoFill,
  });

  final _Group group;
  final bool expanded;
  final Map<String, TextEditingController> controllers;
  final Map<String, FocusNode> focusNodes;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: group.color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // ── Cabeçalho do grupo (clicável para expandir/recolher) ─────────
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(group.icon, color: group.color, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    group.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: group.color,
                      letterSpacing: 0.3,
                    ),
                  ),

                  // 🔥 BOTÃO AQUI
                  if (group.id == 'veiculo' || group.id == 'transporte' || group.id == 'vida')
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: TextButton.icon(
                        onPressed: onAutoFill,
                        icon: Icon(
                          group.id == 'vida' ? Icons.copy_all : Icons.auto_fix_high,
                          size: 14,
                        ),
                        label: Text(group.id == 'vida' ? 'Copiar cliente' : 'Auto'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),

                  const Spacer(),

                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // ── Linhas de campos ─────────────────────────────────────────────
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: group.rows.map((row) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: row.asMap().entries.map((entry) {
                        final i = entry.key;
                        final field = entry.value;
                        return [
                          Expanded(
                            flex: field.flex.toInt(),
                            child: _FieldCell(
                              field: field,
                              controller: controllers[field.id]!,
                              focusNode: focusNodes[field.id]!,
                              onChanged: onChanged,
                              groupColor: group.color,
                            ),
                          ),
                          if (i < row.length - 1)
                            const SizedBox(width: 10),
                        ];
                      }).expand((e) => e).toList(),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Célula de campo individual ───────────────────────────────────────────────
class _FieldCell extends StatefulWidget {
  const _FieldCell({
    required this.field,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.groupColor,
  });

  final _Field field;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final Color groupColor;

  @override
  State<_FieldCell> createState() => _FieldCellState();
  }

  class _FieldCellState extends State<_FieldCell> {
    bool _focused = false;

    @override
    void initState() {
      super.initState();
      
      widget.focusNode.addListener(() {
        if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
      });
      
      // 🆕 Listener para atualizar cores quando valor muda (campo valor)
      if (widget.field.id == 'valor') {
        widget.controller.addListener(() {
          if (mounted) setState(() {});
        });
      }
    }

    @override
    Widget build(BuildContext context) {

        if (widget.field.id == '_checkbox_condutor') {
        final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>();
        if (state == null) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4), // alinha com os outros campos
            Row(
              children: [
                Checkbox(
                  value: state._condutorEhProprietario,
                  onChanged: (value) {
                    state.setState(() {
                      state._condutorEhProprietario = value ?? false;
                      if (state._condutorEhProprietario) {
                        // Copia os dados do proprietário para o condutor motorista
                        state._ctrl['nomeCondutorMotorista']?.text = state._ctrl['nomeCondutor']?.text ?? '';
                        state._ctrl['cpfCondutorMotorista']?.text = state._ctrl['cpfCondutor']?.text ?? '';
                      } else {
                        // Limpa os campos do condutor motorista
                        state._ctrl['nomeCondutorMotorista']?.text = '';
                        state._ctrl['cpfCondutorMotorista']?.text = '';
                      }
                    });
                  },
                ),
                const Text('O condutor é o proprietário do veículo?'),
              ],
            ),
          ],
        );
      }

      if (widget.field.isAutocomplete &&
      widget.field.autocompleteOptions != null) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
          label: widget.field.label,
          required: widget.field.required,
          focused: _focused,
          color: widget.groupColor,
        ),
        const SizedBox(height: 4),

        Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }

            return widget.field.autocompleteOptions!.where((option) {
              return option.toLowerCase().contains(
                textEditingValue.text.toLowerCase(),
              );
            });
          },

          onSelected: (selection) {
            widget.controller.text = selection;
            widget.onChanged(selection);
          },

          fieldViewBuilder:
              (context, autoController, focusNode, onFieldSubmitted) {

            // 🔥 sincroniza controller do sistema
            autoController.text = widget.controller.text;

            return TextFormField(
              controller: autoController,
              focusNode: focusNode,
              decoration: _inputDecoration(
                context,
                widget.groupColor,
                focused: _focused,
                hint: widget.field.hint ?? 'Digite para buscar...',
              ).copyWith(
                prefixIcon: const Icon(Icons.business_outlined),
              ),
              onChanged: (value) {
                widget.controller.text = value;
                widget.onChanged(value);
              },
            );
          },
        ),
      ],
    );
  }
  
  // ── Campo de Hora (Time Picker) ──
  if (widget.field.isTime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
          label: widget.field.label,
          required: widget.field.required,
          focused: _focused,
          color: widget.groupColor,
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          decoration: _inputDecoration(context, widget.groupColor, focused: _focused)
              .copyWith(
                hintText: widget.field.hint ?? 'HH:mm',
                suffixIcon: widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          widget.onChanged('');
                        },
                      )
                    : null,
              ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            LengthLimitingTextInputFormatter(5),
          ],
          onTap: () async {
            // Abre o seletor de hora ao clicar (opcional)
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (picked != null) {
              final hora = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              widget.controller.text = hora;
              widget.onChanged(hora);
            }
          },
        ),
      ],
    );
  }

  // Dropdowns
  if (widget.field.isDropdown && widget.field.options != null) {
    final value = widget.controller.text.isNotEmpty &&
            widget.field.options!.contains(widget.controller.text)
        ? widget.controller.text
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
            label: widget.field.label,
            required: widget.field.required,
            focused: _focused,
            color: widget.groupColor),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          focusNode: widget.focusNode,
          isDense: true,
          decoration: _inputDecoration(context, widget.groupColor,
              focused: _focused),
          hint: Text(widget.field.hint ?? 'Selecione',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade400)),
          items: widget.field.options!
              .map((o) =>
                  DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) {
            widget.controller.text = v ?? '';
            widget.onChanged(v ?? '');
          },
        ),
      ],
    );
  }

  // FORMAT DATE DATA SINISTRO
  if (widget.field.id == 'dataSinistro') {
    final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
          label: widget.field.label,
          required: widget.field.required,
          focused: _focused,
          color: widget.groupColor,
        ),

        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: widget.controller,
              readOnly: false,
              onTap: () async {
                await state!._pickDate('dataSinistro');
              },
              decoration: _inputDecoration(
                context,
                widget.groupColor,
                focused: _focused,
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ).copyWith(right: 70), // 🔥 espaço pro checkbox
              ),
            ),

            Positioned(
              right: 6,
              child: Row(
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: state._usarHoje,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        state.setState(() {
                          state._usarHoje = v ?? false;

                          if (state._usarHoje) {
                            state._ctrl['dataSinistro']?.text =
                                state._formatDate(DateTime.now());
                          }
                        });
                      },
                    ),
                  ),
                  Text(
                    'Hoje',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🆕 FORMAT VALOR DO SINISTRO (com validação de gatilho)
  if (widget.field.id == 'valor') {
    final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>()!;
    final status = state._statusSinistro(
      widget.controller.text,
      state._ctrl['usoAtualApolice']?.text ?? '',
      state._ctrl['valorGatilho']?.text ?? '',
    );

    // 🆕 Cores conforme status
    Color fillColor = const Color(0xFFF8F9FB);  // Normal
    Color borderColor = Colors.grey.shade300;
    
    if (status == StatusSinistro.limite) {
      fillColor = Colors.red.withOpacity(0.1);     // Vermelho claro
      borderColor = Colors.red;
    } else if (status == StatusSinistro.aviso) {
      fillColor = Colors.orange.withOpacity(0.1);  // Laranja claro
      borderColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
          label: widget.field.label,
          required: widget.field.required,
          focused: _focused,
          color: widget.groupColor,
        ),

        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.field.isReadOnly,
          keyboardType: widget.field.keyboard,
          maxLines: 1,
          inputFormatters: widget.field.inputFormatters ?? [],
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(
            context,
            widget.groupColor,
            focused: _focused,
            hint: widget.field.hint,
          ).copyWith(
            fillColor: fillColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: borderColor, width: 0.8),
            ),
            suffixIcon: widget.field.suffixBuilder?.call(widget.controller.text) ?? SizedBox.shrink(),
          ),
          onTap: widget.field.onTap,
          onChanged: (value) {
            widget.onChanged(value);
            // 🆕 Forçar rebuild imediato do pai
            if (mounted) {
              final parentState = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>();
              if (parentState != null && parentState.mounted) {
                parentState.setState(() {});
              }
            }
          },
        ),
      ],
    );
  }

  if (widget.field.id == 'dataAviso') {
    final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
          label: widget.field.label,
          required: widget.field.required,
          focused: _focused,
          color: widget.groupColor,
        ),

        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: widget.controller,
              readOnly: false,
              onTap: () async {
                await state._pickDate('dataAviso');
              },
              decoration: _inputDecoration(
                context,
                widget.groupColor,
                focused: _focused,
              ).copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ).copyWith(right: 70), // espaço pro checkbox
              ),
            ),

            Positioned(
              right: 6,
              child: Row(
                children: [
                  Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: state._usarHojeAviso,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {
                        state.setState(() {
                          state._usarHojeAviso = v ?? false;

                          if (state._usarHojeAviso) {
                            state._ctrl['dataAviso']?.text =
                                state._formatDate(DateTime.now());
                          }
                        });
                      },
                    ),
                  ),
                  Text(
                    'Hoje',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🆕 FORMAT DATA VIGÊNCIA (com validação de apólice)
  if (widget.field.id == 'dataVigenciaFim') {
    final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>()!;
    final status = state._statusApolice(widget.controller.text);

    // 🆕 Cores conforme status
    Color fillColor = const Color(0xFFF8F9FB);  // Normal
    Color borderColor = Colors.grey.shade300;
    
    if (status == StatusApolice.vencida) {
      fillColor = Colors.red.withOpacity(0.1);     // Vermelho claro
      borderColor = Colors.red;
    } else if (status == StatusApolice.atencao) {
      fillColor = Colors.orange.withOpacity(0.1);  // Laranja claro
      borderColor = Colors.orange;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
          label: widget.field.label,
          required: widget.field.required,
          focused: _focused,
          color: widget.groupColor,
        ),

        Stack(
          alignment: Alignment.centerRight,
          children: [
            TextFormField(
              controller: widget.controller,
              readOnly: false,
              onTap: () async {
                await state._pickDate('dataVigenciaFim');
              },
              decoration: _inputDecoration(
                context,
                widget.groupColor,
                focused: _focused,
              ).copyWith(
                // 🆕 Aplicar cores conforme status
                fillColor: fillColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: borderColor, width: 0.8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ).copyWith(right: 40),
              ),
            ),

            // 🆕 Ícone de status à direita
            Positioned(
              right: 10,
              child: widget.field.suffixBuilder?.call(widget.controller.text) ?? 
                const SizedBox.shrink(),
            ),
          ],
        ),
      ],
    );
  }

  // FORMAT CPF / CNPJ
  String _formatCpfCnpj(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length <= 11) {
      // CPF
      return digits
          .replaceAllMapped(RegExp(r'(\d{3})(\d)'), (m) => '${m[1]}.${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{3})(\d)'), (m) => '${m[1]}.${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{3})(\d{1,2})$'), (m) => '${m[1]}-${m[2]}');
    } else {
      // CNPJ
      return digits
          .replaceAllMapped(RegExp(r'(\d{2})(\d)'), (m) => '${m[1]}.${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{3})(\d)'), (m) => '${m[1]}.${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{3})(\d)'), (m) => '${m[1]}/${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{4})(\d{1,2})$'), (m) => '${m[1]}-${m[2]}');
    }
  }

  String _formatTelefone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length <= 10) {
      return digits
          .replaceAllMapped(RegExp(r'(\d{2})(\d)'), (m) => '(${m[1]}) ${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{4})(\d)'), (m) => '${m[1]}-${m[2]}');
    } else {
      return digits
          .replaceAllMapped(RegExp(r'(\d{2})(\d)'), (m) => '(${m[1]}) ${m[2]}')
          .replaceAllMapped(RegExp(r'(\d{5})(\d)'), (m) => '${m[1]}-${m[2]}');
    }
  }

    // Campos de texto (simples, data, multiline)
    final formatters = <TextInputFormatter>[
      if (widget.field.inputFormatters != null)
        ...widget.field.inputFormatters!,
        
      if (widget.field.isUpperCase) _UpperCase(),
      if (widget.field.isDate) _DateFormatter(),
    ];

    if (widget.field.id == 'localOcorrencia') {
    final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>();
  
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 HEADER: Label + Toggle lado a lado
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label (Local da Ocorrência)
            _Label(
              label: widget.field.label,
              required: widget.field.required,
              focused: _focused,
              color: widget.groupColor,
            ),
            const SizedBox(width: 8),  // Espaço entre label e botão
            
            // ✅ Toggle bem ao lado do título
            TextButton.icon(
              onPressed: () {
                state?.setState(() {
                  state._localOcorrenciaManualMode = !state._localOcorrenciaManualMode;
                });
              },
              icon: Icon(
                state?._localOcorrenciaManualMode == true
                    ? Icons.location_on
                    : Icons.edit,
                size: 16,
              ),
              label: Text(
                state?._localOcorrenciaManualMode == true
                    ? 'Usar Mapa'
                    : 'Entrada Manual',
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                backgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
  
        // 🔹 CAMPO
        TextFormField(
          controller: widget.controller,
          readOnly: state?._localOcorrenciaManualMode == false,
          onTap: () async {
            if (state?._localOcorrenciaManualMode == false) {
              final result = await state?._openPlaceSearch();
  
              if (result != null && result.isNotEmpty) {
                widget.controller.text = result;
                widget.onChanged(result);
              }
            }
          },
          onChanged: state?._localOcorrenciaManualMode == true 
              ? (value) => widget.onChanged(value)
              : null,
          decoration: _inputDecoration(
            context,
            widget.groupColor,
            focused: _focused,
            hint: state?._localOcorrenciaManualMode == true
                ? 'Digite o endereço'
                : 'Clique para buscar no mapa',
          ).copyWith(
            suffixIcon: state?._localOcorrenciaManualMode == true
                ? const Icon(Icons.edit_note)
                : const Icon(Icons.location_on),
          ),
        ),
  
        // 🔥 MAP PREVIEW
        if (state?._localOcorrenciaManualMode == false &&
            state?._localOcorrenciaLatLng != null) ...[
          const SizedBox(height: 8),
  
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 160,
              child: Image.network(
                'https://maps.googleapis.com/maps/api/staticmap'
                '?center=${state!._localOcorrenciaLatLng!.latitude},${state._localOcorrenciaLatLng!.longitude}'
                '&zoom=15'
                '&size=600x300'
                '&markers=color:red|${state._localOcorrenciaLatLng!.latitude},${state._localOcorrenciaLatLng!.longitude}'
                '&key=AIzaSyCoE3ZT1_EMmET0RaSmBeFMWQiYwJcl1YE',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ],
    );
  }

    if (widget.field.id == 'relatoEvento') {
      final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(
            label: widget.field.label,
            required: widget.field.required,
            focused: _focused,
            color: widget.groupColor,
          ),

          const SizedBox(height: 8),

          // 🧩 RESUMO (chips)
          state!._buildResumoRelato(),

          const SizedBox(height: 8),

          // 🧩 OPÇÕES
          state._buildOpcoesRelato(),

          const SizedBox(height: 10),

          // ⚡ BOTÃO GERAR
          ElevatedButton.icon(
            onPressed: () {
              final texto = state._montarRelato();

              state.setState(() {
                state._ctrl['relatoEvento']?.text = texto;
              });
            },
            icon: Icon(Icons.auto_awesome),
            label: Text('Gerar Relato'),
          ),

          const SizedBox(height: 10),

          // 📝 CAMPO FINAL
          TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            maxLines: 3,
            decoration: _inputDecoration(
              context,
              widget.groupColor,
              focused: _focused,
            ),
            onChanged: widget.onChanged,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(
            label: widget.field.label,
            required: widget.field.required,
            focused: _focused,
            color: widget.groupColor),
        const SizedBox(height: 4),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          readOnly: widget.field.isReadOnly,
          keyboardType: widget.field.isMultiline
              ? TextInputType.multiline
              : widget.field.keyboard,
          maxLines: widget.field.isMultiline ? 3 : 1,
          inputFormatters: formatters,
          textAlign: widget.field.keyboard == TextInputType.number ? TextAlign.right : TextAlign.left,  // 🆕
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(context, widget.groupColor,
              focused: _focused,
              hint: widget.field.hint),

          onTap: widget.field.onTap,
          onChanged: (value) {
            final state = context.findAncestorStateOfType<_SpreadsheetClaimScreenState>();

            if (state == null) return;

            // 🚫 evita loop infinito
            if (state._isApplyingMask) return;

            final formatter = state._maskMap[widget.field.id];

            if (formatter != null) {
              state._isApplyingMask = true;

              state._applyMask(
                controller: widget.controller,
                newValue: value,
                formatter: formatter,
              );

              state._isApplyingMask = false;
            }

            widget.onChanged(value);
          },

          onFieldSubmitted: (_) {
            widget.focusNode.nextFocus();
          },
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context, Color groupColor,
      {required bool focused, String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(fontSize: 12, color: Colors.grey.shade400),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      filled: true,
      fillColor:
          focused ? groupColor.withOpacity(0.04) : const Color(0xFFF8F9FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide:
            BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide:
            BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: groupColor, width: 1.5),
      ),
    );
  }
}

// ─── Label do campo ───────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  const _Label({
    required this.label,
    required this.required,
    required this.focused,
    required this.color,
  });
  final String label;
  final bool required;
  final bool focused;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: focused ? color : Colors.grey.shade600,
          letterSpacing: 0.2,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: color, fontSize: 11),
            ),
        ],
      ),
    );
  }
}


// ─── Grupo de Anexos (Drag & Drop + File Picker) ─────────────────────────────
//
// Suporta três formas de adicionar arquivos:
//   1. Arrastar do Explorer / WhatsApp Web direto na zona de drop (desktop)
//   2. Clicar na zona para abrir o file picker
//   3. Clicar no botão "+" de cada categoria
//
class _AnexosCard extends StatelessWidget {
  const _AnexosCard({
    required this.anexos,
    required this.dragOver,
    required this.isUploading,
    required this.onAddArquivos,
    required this.onRemoveArquivo,
    required this.onPickArquivos,
    required this.onDragEntered,
    required this.onDragExited,
    required this.isImageFile,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, List<XFile>> anexos;
  final Map<String, bool> dragOver;
  final bool isUploading;
  //final void Function(String, List<XFile>) onAddArquivos;
  final void Function(String, List<XFile>, [List<PlatformFile>?]) onAddArquivos;
  final void Function(String, XFile) onRemoveArquivo;
  final void Function(String) onPickArquivos;
  final void Function(String, bool) onDragEntered;
  final void Function(String, bool) onDragExited;
  final bool Function(String) isImageFile;
  final bool expanded;
  final VoidCallback onToggle;

  static const _color = Color(0xFF00695C);

  static const _categoryIcons = <String, IconData>{
    'Fotos do Sinistro': Icons.photo_library_outlined,
    'Documentos do Segurado': Icons.person_outline,
    'Documentos do Veículo': Icons.directions_car_outlined,
    'Laudos / Boletins': Icons.description_outlined,
  };

  int get _totalAnexos =>
      anexos.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: const Border(
          left: BorderSide(color: _color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho
          InkWell(
            onTap: onToggle,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.attach_file,
                      color: _color, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Anexos e Documentos',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: _color,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_totalAnexos > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_totalAnexos arquivo${_totalAnexos == 1 ? "" : "s"}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _color),
                      ),
                    ),
                  const Spacer(),
                  if (isUploading)
                    const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: _color)),
                  const SizedBox(width: 6),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: anexos.keys.map((categoria) {
                  final arquivos = anexos[categoria]!;
                  final isDragging = dragOver[categoria] ?? false;
                  final icon = _categoryIcons[categoria] ??
                      Icons.folder_outlined;
                  final isImagem = categoria == 'Fotos do Sinistro';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label da categoria
                        Row(
                          children: [
                            Icon(icon,
                                size: 13,
                                color: Colors.grey.shade600),
                            const SizedBox(width: 5),
                            Text(
                              categoria.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const Spacer(),
                            // Botão "+" pequeno
                            InkWell(
                              onTap: () => onPickArquivos(categoria),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: _color.withOpacity(0.4),
                                      width: 0.8),
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add,
                                        size: 12, color: _color),
                                    const SizedBox(width: 3),
                                    Text(
                                      isImagem
                                          ? 'Adicionar fotos'
                                          : 'Adicionar arquivos',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _color),
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
                          onDragEntered: (_) =>
                              onDragEntered(categoria, true),
                          onDragExited: (_) =>
                              onDragExited(categoria, false),
                          onDragDone: (details) async {
                            onDragExited(categoria, false);

                            if (kIsWeb) {
                              final platformFiles = <PlatformFile>[];

                              for (final xf in details.files) {
                                final bytes = await xf.readAsBytes();

                                platformFiles.add(
                                  PlatformFile(
                                    name: xf.name,
                                    size: bytes.length,
                                    bytes: bytes,
                                  ),
                                );
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
                              constraints:
                                  const BoxConstraints(minHeight: 72),
                              decoration: BoxDecoration(
                                color: isDragging
                                    ? _color.withOpacity(0.06)
                                    : const Color(0xFFF8F9FB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDragging
                                      ? _color
                                      : Colors.grey.shade300,
                                  width: isDragging ? 1.5 : 0.8,
                                  style: arquivos.isEmpty
                                      ? BorderStyle.solid
                                      : BorderStyle.solid,
                                ),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: arquivos.isEmpty
                                  ? _DropPlaceholder(
                                      isDragging: isDragging,
                                      isImagem: isImagem,
                                      color: _color,
                                    )
                                  : _ArquivosGrid(
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
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Placeholder quando a zona está vazia ─────────────────────────────────────
class _DropPlaceholder extends StatelessWidget {
  const _DropPlaceholder({
    required this.isDragging,
    required this.isImagem,
    required this.color,
  });
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
              isDragging
                  ? Icons.file_download_outlined
                  : isImagem
                      ? Icons.add_photo_alternate_outlined
                      : Icons.upload_file_outlined,
              size: 22,
              color: isDragging ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              isDragging
                  ? 'Solte aqui para adicionar'
                  : 'Arraste arquivos aqui ou clique para selecionar',
              style: TextStyle(
                fontSize: 11,
                color: isDragging ? color : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Grid de arquivos adicionados ─────────────────────────────────────────────
class _ArquivosGrid extends StatelessWidget {
  const _ArquivosGrid({
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
        final nomeArquivo = arquivo.name.isNotEmpty
            ? arquivo.name
            : arquivo.path.split('/').last;
        final ehImagem = isImageFile(nomeArquivo);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Miniatura (imagem) ou chip (documento)
            ehImagem
                ? _ImagemThumb(arquivo: arquivo, nome: nomeArquivo)
                : _DocChip(nome: nomeArquivo),

            // Botão de remover
            Positioned(
              top: -5,
              right: -5,
              child: GestureDetector(
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Remover anexo'),
                        content: const Text('Tem certeza que deseja excluir este arquivo?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Excluir',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                  if (confirm == true) {
                    onRemove(categoria, arquivo);
                  }
                },
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close,
                      color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Miniatura de imagem ──────────────────────────────────────────────────────
class _ImagemThumb extends StatelessWidget {
  const _ImagemThumb({required this.arquivo, required this.nome});
  final XFile arquivo;
  final String nome;

  @override
  Widget build(BuildContext context) {
    Widget img;

    if (kIsWeb) {
      img = Image.network(arquivo.path,
          width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    } else if (arquivo.path.isNotEmpty) {
      img = Image.file(File(arquivo.path),
          width: 72, height: 72, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image));
    } else {
      img = const Icon(Icons.image_outlined, size: 32);
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(10),
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Container(
                color: Colors.black,
                child: kIsWeb
                    ? Image.network(arquivo.path, fit: BoxFit.contain)
                    : Image.file(File(arquivo.path), fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 72,
          height: 72,
          color: Colors.grey.shade200,
          child: img,
        ),
      ),
    );
  }
}

// ─── Chip de documento (PDF, Word, etc.) ──────────────────────────────────────
class _DocChip extends StatelessWidget {
  const _DocChip({required this.nome});
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
          Icon(_iconForExt(nome),
              size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              nome,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoFillModal extends StatefulWidget {
  @override
  State<_AutoFillModal> createState() => _AutoFillModalState();
}

class _AutoFillTransporteModal extends StatefulWidget {
  @override
  State<_AutoFillTransporteModal> createState() => _AutoFillTransporteModalState();
}

class _AutoFillTransporteModalState extends State<_AutoFillTransporteModal> {
  PlatformFile? crlvCavalo;
  PlatformFile? crlvCarreta;
  bool condutorEhProprietario = true;

  Future<void> _pickFile(Function(PlatformFile) onPick) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      onPick(result.files.first);
      setState(() {});
    }
  }

  String _extractText(PlatformFile file) {
    if (file.bytes == null) return '';
    final pdfDocument = PdfDocument(inputBytes: file.bytes!);
    final text = PdfTextExtractor(pdfDocument).extractText();
    pdfDocument.dispose();
    return text;
  }

  void _processar() {
    final textoCavalo = crlvCavalo != null ? _extractText(crlvCavalo!) : '';
    final textoCarreta = crlvCarreta != null ? _extractText(crlvCarreta!) : '';

    final cavalo = parseCRLV(textoCavalo);
    final carreta = parseCRLV(textoCarreta);
    final condutor = parseCondutorFromCRLV(textoCavalo);

    Navigator.pop(context, {
      "cavalo": cavalo,
      "carreta": carreta,
      "condutor": condutor,
      "condutorEhProprietario": condutorEhProprietario,
      "crlvCavaloFile": crlvCavalo,
      "crlvCarretaFile": crlvCarreta,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 520,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Importar Transporte", style: TextStyle(fontWeight: FontWeight.bold)),

            SizedBox(height: 20),

            _buildUpload("CRLV Cavalo", crlvCavalo, () {
              _pickFile((f) => crlvCavalo = f);
            }),

            _buildUpload("CRLV Carreta", crlvCarreta, () {
              _pickFile((f) => crlvCarreta = f);
            }),

            SizedBox(height: 10),

            Row(
              children: [
                Checkbox(
                  value: condutorEhProprietario,
                  onChanged: (v) {
                    setState(() {
                      condutorEhProprietario = v ?? true;
                    });
                  },
                ),
                Expanded(child: Text("Condutor é proprietário?")),
              ],
            ),

            SizedBox(height: 10),

            ElevatedButton(
              onPressed: _processar,
              child: Text("Processar"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUpload(String label, PlatformFile? file, VoidCallback onTap) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(file?.name ?? "Nenhum arquivo"),
        IconButton(icon: Icon(Icons.upload_file), onPressed: onTap),
      ],
    );
  }

  // 🔥 REUTILIZA SUA LÓGICA (COPIA DO MODAL ORIGINAL)
  Map<String, dynamic> parseCRLV(String text) {
    return _AutoFillModalState().parseCRLV(text);
  }

  Map<String, dynamic> parseCondutorFromCRLV(String text) {
    return _AutoFillModalState().parseCondutorFromCRLV(text);
  }
}

class _AutoFillModalState extends State<_AutoFillModal> {
  PlatformFile? crlv;
  PlatformFile? cnh;
  bool condutorEhProprietario = true;

  void _debugShowExtractedText(String text, String titulo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              text.isEmpty ? 'NENHUM TEXTO ENCONTRADO' : text,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile(Function(PlatformFile) onPick) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      onPick(result.files.first);
      setState(() {});
    }
  }

  String _extractText(PlatformFile file) {
    if (file.bytes == null) return '';
    final pdfDocument = PdfDocument(inputBytes: file.bytes!);
    final text = PdfTextExtractor(pdfDocument).extractText();
    pdfDocument.dispose();
    return text;
  }

  Map<String, dynamic> parseCNH(String text) {
    final linhas = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String nome = '';
    String cpf = '';

    for (int i = 0; i < linhas.length; i++) {
      final linha = linhas[i];

      // 🔥 CPF (padrão confiável)
      if (cpf.isEmpty) {
        final match = RegExp(r'\d{3}\.\d{3}\.\d{3}-\d{2}').firstMatch(linha);
        if (match != null) {
          cpf = match.group(0)!;
        }
      }

      // 🔥 NOME (linha grande, só letras, sem números)
      if (nome.isEmpty) {
        final upper = linha.toUpperCase();

        final isPossivelNome =
            RegExp(r'^[A-ZÇÃÕÁÉÍÓÚÂÊÎÔÛÀ\s]{10,}$').hasMatch(upper);

        final temNumero = RegExp(r'\d').hasMatch(upper);

        final bloqueadas = [
          'BRASIL',
          'REPUBLICA',
          'MINISTERIO',
          'TRANSITO',
          'NACIONAL',
          'VALIDADE',
          'EMISSAO',
          'HABILITACAO'
        ];

        final isBloqueado = bloqueadas.any((b) => upper.contains(b));

        if (isPossivelNome && !temNumero && !isBloqueado) {
          nome = linha.trim();
        }
      }
    }

    return {
      "nome": nome,
      "cpf": cpf,
    };
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

  void _processar() async {
    if (crlv == null && cnh == null) return;

    final textoCRLV = crlv != null ? _extractText(crlv!) : '';
    final textoCNH = cnh != null ? _extractText(cnh!) : '';

    final veiculo = parseCRLV(textoCRLV);

    Map<String, dynamic> condutor = {};

    // 🔥 PRIORIDADE: CNH
    if (textoCNH.isNotEmpty) {
      condutor = parseCNH(textoCNH);
    }

    // 🔥 FALLBACK: CRLV
    if ((condutor['nome'] == null || condutor['nome'].isEmpty) ||
        (condutor['cpf'] == null || condutor['cpf'].isEmpty)) {
      condutor = parseCondutorFromCRLV(textoCRLV);
    }

    print('VEÍCULO PARSED: $veiculo');
    print('CONDUTOR PARSED: $condutor');

    final resultado = {
      "veiculo": veiculo,
      "condutor": condutor,
      "condutorEhProprietario": condutorEhProprietario,
      "crlvFile": crlv,
      "relato": "Dados do evento.",
    };

    Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 520,
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Preenchimento Automático",
                style: TextStyle(fontWeight: FontWeight.bold)),

            SizedBox(height: 10),

            Text(
              "⚠️ Utilize arquivos PDF do app oficial:\n"
              "- CRLV-e (Documento do veículo)",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 20),

            _buildUpload("CRLV-e (PDF)", crlv, () {
              _pickFile((f) => crlv = f);
            }),

            SizedBox(height: 10),

            Row(
              children: [
                Checkbox(
                  value: condutorEhProprietario,
                  onChanged: (v) {
                    setState(() {
                      condutorEhProprietario = v ?? true;
                    });
                  },
                ),
                const Expanded(
                  child: Text(
                    'O condutor é o proprietário do veículo?',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),

            SizedBox(height: 10),

            ElevatedButton(
              onPressed: _processar,
              child: Text("Processar"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUpload(String label, PlatformFile? file, VoidCallback onTap) {
      return Row(
        children: [
          Expanded(child: Text(label)),
          Text(file?.name ?? "Nenhum arquivo"),
          IconButton(
            icon: Icon(Icons.upload_file),
            onPressed: onTap,
          )
        ],
      );
    }
  }

// 🆕 ENUM DE STATUS DA APÓLICE (escopo global)
enum StatusApolice {
  normal,
  atencao,
  vencida,
}

// 📝 WIDGETS CUSTOMIZADOS PARA DANOS CORPORAIS E DANOS MATERIAIS
// ═════════════════════════════════════════════════════════════════════════════
//
// ⚠️ INSTRUÇÃO: Copie esses widgets para o FINAL do arquivo spreadsheet_claim_screen.dart
// (após todas as outras classes e widgets)
//

// ═════════════════════════════════════════════════════════════════════════════
// 🆕 WIDGET PARA LISTA DE DANOS CORPORAIS
// ═════════════════════════════════════════════════════════════════════════════

class _BodilyInjuryListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> danoscorporais;
  final Function(Map<String, dynamic>) onAdd;
  final Function(int) onRemove;
  final Function(int, String, dynamic) onEditField;
  final Function(int)? onUploadFoto;
  final Function(int)? onUploadDocumento;
 
  const _BodilyInjuryListWidget({
    Key? key,
    required this.danoscorporais,
    required this.onAdd,
    required this.onRemove,
    required this.onEditField,
    this.onUploadFoto,
    this.onUploadDocumento,
  }) : super(key: key);
 
  @override
  State<_BodilyInjuryListWidget> createState() => _BodilyInjuryListWidgetState();
}
 
class _BodilyInjuryListWidgetState extends State<_BodilyInjuryListWidget> {
  late Map<int, Map<String, TextEditingController>> _controllers = {};
 
  final MaskTextInputFormatter _cpfCnpjFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
 
  final MaskTextInputFormatter _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
 
  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
 
  void _initializeControllers() {
    for (var map in _controllers.values) {
      for (var c in map.values) {
        c.dispose();
      }
    }
    _controllers.clear();
 
    for (int i = 0; i < widget.danoscorporais.length; i++) {
      _controllers[i] = {
        'nome': TextEditingController(text: widget.danoscorporais[i]['nome'] ?? ''),
        'cpfCnpj': TextEditingController(text: widget.danoscorporais[i]['cpfCnpj'] ?? ''),
        'endereco': TextEditingController(text: widget.danoscorporais[i]['endereco'] ?? ''),
        'telefone': TextEditingController(text: widget.danoscorporais[i]['telefone'] ?? ''),
        'numeroSinistro': TextEditingController(text: widget.danoscorporais[i]['numeroSinistro'] ?? ''),
        'email': TextEditingController(text: widget.danoscorporais[i]['email'] ?? ''),
        'relato': TextEditingController(text: widget.danoscorporais[i]['relato'] ?? ''),
      };
    }
  }
 
  @override
  void didUpdateWidget(_BodilyInjuryListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.danoscorporais.length != oldWidget.danoscorporais.length) {
      _initializeControllers();
    }
  }
 
  @override
  void dispose() {
    for (var controllerMap in _controllers.values) {
      for (var controller in controllerMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
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
 
  void _confirmDeleteFoto(int index, XFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover foto'),
          content: const Text('Tem certeza que deseja excluir esta foto?'),
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
        );
      },
    );
 
    if (confirm == true) {
      setState(() {
        final lista = widget.danoscorporais[index]['fotosLocais'] as List<XFile> ?? [];
        lista.remove(file);
      });
 
      widget.onEditField(index, 'fotosLocais', 
        widget.danoscorporais[index]['fotosLocais']);
    }
  }
 
  void _confirmDeleteDocumento(int index, PlatformFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover documento'),
          content: const Text('Tem certeza que deseja excluir este documento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
 
    if (confirm == true) {
      setState(() {
        final lista = widget.danoscorporais[index]['documentosLocais'] as List<PlatformFile>;
        lista.remove(file);
      });
 
      widget.onEditField(
        index,
        'documentosLocais',
        widget.danoscorporais[index]['documentosLocais'],
      );
    }
  }
 
  Widget _buildField({
    required String label,
    required TextEditingController? controller,
    required void Function(String) onChanged,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        label: Text(label),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.danoscorporais.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    'Nenhum dano corporal adicionado',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                    ElevatedButton.icon(
                        onPressed: () {
                          const uuid = Uuid();
                          widget.onAdd({
                            'id': uuid.v4(),
                            'nome': '',
                            'cpfCnpj': '',
                            'endereco': '',
                            'telefone': '',
                            'numeroSinistro': '',
                            'email': '',
                            'relato': '',
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Adicionar Dano Corporal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD32F2F),
                          foregroundColor: Colors.white,
                        ),
                      ),
                ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.danoscorporais.length,
            itemBuilder: (context, index) {
              final dano = widget.danoscorporais[index];
              final ctrls = _controllers[index] ?? {};
 
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.onUploadFoto != null)
                              IconButton(
                                icon: const Icon(Icons.photo_outlined, color: Color(0xFFD32F2F), size: 18),
                                onPressed: () => widget.onUploadFoto?.call(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Adicionar fotos',
                              ),
                            if (widget.onUploadDocumento != null)
                              IconButton(
                                icon: const Icon(Icons.description_outlined, color: Color(0xFFD32F2F), size: 18),
                                onPressed: () => widget.onUploadDocumento?.call(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Adicionar documentos',
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () => widget.onRemove(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
 
                    // Campos
                    _buildField(
                      label: 'Nome *',
                      controller: ctrls['nome'],
                      onChanged: (val) => widget.onEditField(index, 'nome', val),
                    ),
                    const SizedBox(height: 8),
 
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'CPF/CNPJ',
                            controller: ctrls['cpfCnpj'],
                            inputFormatters: [_cpfCnpjFormatter],
                            onChanged: (val) => widget.onEditField(index, 'cpfCnpj', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildField(
                            label: 'Telefone',
                            controller: ctrls['telefone'],
                            inputFormatters: [_telefoneFormatter],
                            onChanged: (val) => widget.onEditField(index, 'telefone', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
 
                    _buildField(
                      label: 'Endereço',
                      controller: ctrls['endereco'],
                      onChanged: (val) => widget.onEditField(index, 'endereco', val),
                    ),
                    const SizedBox(height: 8),
 
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Nº Sinistro',
                            controller: ctrls['numeroSinistro'],
                            onChanged: (val) => widget.onEditField(index, 'numeroSinistro', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildField(
                            label: 'E-mail',
                            controller: ctrls['email'],
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (val) => widget.onEditField(index, 'email', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
 
                    _buildField(
                      label: 'Relato do Evento',
                      controller: ctrls['relato'],
                      onChanged: (val) => widget.onEditField(index, 'relato', val),
                      maxLines: 3,
                    ),
 
                    // 🆕 FOTOS
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fotos do Dano Corporal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (((dano['fotosUrls'] as List<String>?)?.isEmpty ?? true) &&
                              ((dano['fotosLocais'] as List<XFile>?)?.isEmpty ?? true))
                            Text(
                              'Nenhuma foto',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                // Fotos salvas no Firestore (URLs)
                                ...((dano['fotosUrls'] as List<String>?) ?? []).map((url) {
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
                                          _showImageViewer(NetworkImage(url));
                                        },
                                        child: Image.network(url, fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                // Fotos locais (antes de salvar)
                                ...((dano['fotosLocais'] as List<XFile>?) ?? []).map((xfile) {
                                  return FutureBuilder<Uint8List>(
                                    future: xfile.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          alignment: Alignment.center,
                                          child: const CircularProgressIndicator(strokeWidth: 2),
                                        );
                                      }
 
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              _showImageViewer(MemoryImage(snapshot.data!));
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.memory(
                                                snapshot.data!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -5,
                                            right: -5,
                                            child: GestureDetector(
                                              onTap: () => _confirmDeleteFoto(index, xfile),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
 
                    // 🆕 DOCUMENTOS
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Documentos do Dano Corporal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (((dano['documentosUrls'] as List<String>?)?.isEmpty ?? true) &&
                              ((dano['documentosLocais'] as List<PlatformFile>?)?.isEmpty ?? true))
                            Text(
                              'Nenhum documento',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Documentos salvos no Firestore (URLs)
                                ...((dano['documentosUrls'] as List<String>?) ?? []).map((url) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            url.split('/').last,
                                            style: const TextStyle(fontSize: 9),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // Documentos locais (antes de salvar)
                                ...((dano['documentosLocais'] as List<PlatformFile>?) ?? []).map((file) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.cloud_upload, size: 14, color: Colors.orange),
                                            const SizedBox(width: 5),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 120),
                                              child: Text(
                                                file.name,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: GestureDetector(
                                          onTap: () => _confirmDeleteDocumento(index, file),
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
 
        const SizedBox(height: 16),
        if (widget.danoscorporais.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                const uuid = Uuid();
                widget.onAdd({
                  'id': uuid.v4(),
                  'nome': '',
                  'cpfCnpj': '',
                  'endereco': '',
                  'telefone': '',
                  'numeroSinistro': '',
                  'email': '',
                  'relato': '',
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Outro Dano Corporal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
 
// ═════════════════════════════════════════════════════════════════════════════
// 🆕 WIDGET PARA LISTA DE DANOS MATERIAIS
// ═════════════════════════════════════════════════════════════════════════════
 
class _MaterialDamageListWidget extends StatefulWidget {
  final List<Map<String, dynamic>> danosmateriais;
  final Function(Map<String, dynamic>) onAdd;
  final Function(int) onRemove;
  final Function(int, String, dynamic) onEditField;
  final Function(int)? onUploadFoto;
  final Function(int)? onUploadDocumento;
 
  const _MaterialDamageListWidget({
    Key? key,
    required this.danosmateriais,
    required this.onAdd,
    required this.onRemove,
    required this.onEditField,
    this.onUploadFoto,
    this.onUploadDocumento,
  }) : super(key: key);
 
  @override
  State<_MaterialDamageListWidget> createState() => _MaterialDamageListWidgetState();
}
 
class _MaterialDamageListWidgetState extends State<_MaterialDamageListWidget> {
  late Map<int, Map<String, TextEditingController>> _controllers = {};
 
  final MaskTextInputFormatter _cpfCnpjFormatter = MaskTextInputFormatter(
    mask: '###.###.###-##',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
 
  final MaskTextInputFormatter _telefoneFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );
 
  final List<String> _tiposPatrimonio = ['Casa', 'Estabelecimento', 'Veículo', 'Outros'];
 
  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }
 
  void _initializeControllers() {
    for (var map in _controllers.values) {
      for (var c in map.values) {
        c.dispose();
      }
    }
    _controllers.clear();
 
    for (int i = 0; i < widget.danosmateriais.length; i++) {
      _controllers[i] = {
        'nome': TextEditingController(text: widget.danosmateriais[i]['nome'] ?? ''),
        'cpfCnpj': TextEditingController(text: widget.danosmateriais[i]['cpfCnpj'] ?? ''),
        'endereco': TextEditingController(text: widget.danosmateriais[i]['endereco'] ?? ''),
        'telefone': TextEditingController(text: widget.danosmateriais[i]['telefone'] ?? ''),
        'numeroSinistro': TextEditingController(text: widget.danosmateriais[i]['numeroSinistro'] ?? ''),
        'email': TextEditingController(text: widget.danosmateriais[i]['email'] ?? ''),
        'descricao': TextEditingController(text: widget.danosmateriais[i]['descricao'] ?? ''),
        'relato': TextEditingController(text: widget.danosmateriais[i]['relato'] ?? ''),
      };
    }
  }
 
  @override
  void didUpdateWidget(_MaterialDamageListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.danosmateriais.length != oldWidget.danosmateriais.length) {
      _initializeControllers();
    }
  }
 
  @override
  void dispose() {
    for (var controllerMap in _controllers.values) {
      for (var controller in controllerMap.values) {
        controller.dispose();
      }
    }
    super.dispose();
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
 
  void _confirmDeleteFoto(int index, XFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover foto'),
          content: const Text('Tem certeza que deseja excluir esta foto?'),
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
        );
      },
    );
 
    if (confirm == true) {
      setState(() {
        final lista = widget.danosmateriais[index]['fotosLocais'] as List<XFile> ?? [];
        lista.remove(file);
      });
 
      widget.onEditField(index, 'fotosLocais', 
        widget.danosmateriais[index]['fotosLocais']);
    }
  }
 
  void _confirmDeleteDocumento(int index, PlatformFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remover documento'),
          content: const Text('Tem certeza que deseja excluir este documento?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
 
    if (confirm == true) {
      setState(() {
        final lista = widget.danosmateriais[index]['documentosLocais'] as List<PlatformFile>;
        lista.remove(file);
      });
 
      widget.onEditField(
        index,
        'documentosLocais',
        widget.danosmateriais[index]['documentosLocais'],
      );
    }
  }
 
  Widget _buildField({
    required String label,
    required TextEditingController? controller,
    required void Function(String) onChanged,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        label: Text(label),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.danosmateriais.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Text(
                    'Nenhum dano material adicionado',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      const uuid = Uuid();
                      widget.onAdd({
                        'id': uuid.v4(),
                        'nome': '',
                        'cpfCnpj': '',
                        'endereco': '',
                        'telefone': '',
                        'numeroSinistro': '',
                        'email': '',
                        'relato': '',
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar Dano Material'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                  ),
                ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.danosmateriais.length,
            itemBuilder: (context, index) {
              final dano = widget.danosmateriais[index];
              final ctrls = _controllers[index] ?? {};
 
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF57F17),
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.onUploadFoto != null)
                              IconButton(
                                icon: const Icon(Icons.photo_outlined, color: Color(0xFFF57F17), size: 18),
                                onPressed: () => widget.onUploadFoto?.call(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Adicionar fotos',
                              ),
                            if (widget.onUploadDocumento != null)
                              IconButton(
                                icon: const Icon(Icons.description_outlined, color: Color(0xFFF57F17), size: 18),
                                onPressed: () => widget.onUploadDocumento?.call(index),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Adicionar documentos',
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () => widget.onRemove(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
 
                    // Campos
                    _buildField(
                      label: 'Nome *',
                      controller: ctrls['nome'],
                      onChanged: (val) => widget.onEditField(index, 'nome', val),
                    ),
                    const SizedBox(height: 8),
 
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'CPF/CNPJ',
                            controller: ctrls['cpfCnpj'],
                            inputFormatters: [_cpfCnpjFormatter],
                            onChanged: (val) => widget.onEditField(index, 'cpfCnpj', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildField(
                            label: 'Telefone',
                            controller: ctrls['telefone'],
                            inputFormatters: [_telefoneFormatter],
                            onChanged: (val) => widget.onEditField(index, 'telefone', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
 
                    _buildField(
                      label: 'Endereço',
                      controller: ctrls['endereco'],
                      onChanged: (val) => widget.onEditField(index, 'endereco', val),
                    ),
                    const SizedBox(height: 8),
 
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Nº Sinistro',
                            controller: ctrls['numeroSinistro'],
                            onChanged: (val) => widget.onEditField(index, 'numeroSinistro', val),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildField(
                            label: 'E-mail',
                            controller: ctrls['email'],
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (val) => widget.onEditField(index, 'email', val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
 
                    _buildField(
                      label: 'Relato do Evento',
                      controller: ctrls['relato'],
                      onChanged: (val) => widget.onEditField(index, 'relato', val),
                      maxLines: 3,
                    ),
 
                    // 🆕 FOTOS
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fotos do Dano Corporal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (((dano['fotosUrls'] as List<String>?)?.isEmpty ?? true) &&
                              ((dano['fotosLocais'] as List<XFile>?)?.isEmpty ?? true))
                            Text(
                              'Nenhuma foto',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                // Fotos salvas no Firestore (URLs)
                                ...((dano['fotosUrls'] as List<String>?) ?? []).map((url) {
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
                                          _showImageViewer(NetworkImage(url));
                                        },
                                        child: Image.network(url, fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                // Fotos locais (antes de salvar)
                                ...((dano['fotosLocais'] as List<XFile>?) ?? []).map((xfile) {
                                  return FutureBuilder<Uint8List>(
                                    future: xfile.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Container(
                                          width: 60,
                                          height: 60,
                                          alignment: Alignment.center,
                                          child: const CircularProgressIndicator(strokeWidth: 2),
                                        );
                                      }
 
                                      return Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              _showImageViewer(MemoryImage(snapshot.data!));
                                            },
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.memory(
                                                snapshot.data!,
                                                width: 60,
                                                height: 60,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: -5,
                                            right: -5,
                                            child: GestureDetector(
                                              onTap: () => _confirmDeleteFoto(index, xfile),
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
 
                    // 🆕 DOCUMENTOS
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Documentos do Dano Corporal',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (((dano['documentosUrls'] as List<String>?)?.isEmpty ?? true) &&
                              ((dano['documentosLocais'] as List<PlatformFile>?)?.isEmpty ?? true))
                            Text(
                              'Nenhum documento',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Documentos salvos no Firestore (URLs)
                                ...((dano['documentosUrls'] as List<String>?) ?? []).map((url) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            url.split('/').last,
                                            style: const TextStyle(fontSize: 9),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                // Documentos locais (antes de salvar)
                                ...((dano['documentosLocais'] as List<PlatformFile>?) ?? []).map((file) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.grey.shade300, width: 0.8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.cloud_upload, size: 14, color: Colors.orange),
                                            const SizedBox(width: 5),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 120),
                                              child: Text(
                                                file.name,
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: GestureDetector(
                                          onTap: () => _confirmDeleteDocumento(index, file),
                                          child: Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
 
        const SizedBox(height: 16),
        if (widget.danosmateriais.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: () {
                const uuid = Uuid();
                widget.onAdd({
                  'id': uuid.v4(),
                  'nome': '',
                  'cpfCnpj': '',
                  'endereco': '',
                  'telefone': '',
                  'numeroSinistro': '',
                  'email': '',
                  'relato': '',
                });
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Outro Dano Corporal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}