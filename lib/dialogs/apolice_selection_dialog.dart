// lib/dialogs/apolice_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/models/apolice_model.dart';
import 'package:upgrade_seguros/utils/formatters.dart';

class ApoliceSelectionDialog extends StatefulWidget {
  final List<Apolice> apolices;
  final String ramoSelecionado;

  const ApoliceSelectionDialog({
    Key? key,
    required this.apolices,
    required this.ramoSelecionado,
  }) : super(key: key);

  @override
  State<ApoliceSelectionDialog> createState() => _ApoliceSelectionDialogState();
}

class _ApoliceSelectionDialogState extends State<ApoliceSelectionDialog> {
  late Apolice _selectedApolice;

  @override
  void initState() {
    super.initState();
    _selectedApolice = widget.apolices.first;
  }

  String _getEmojiRamo(String ramo) {
    switch (ramo.toLowerCase()) {
      case 'veículo':
        return '🚗';
      case 'imóvel':
        return '🏠';
      case 'vida':
        return '❤️';
      case 'responsabilidade civil':
        return '⚖️';
      case 'transporte':
        return '🚚';
      case 'máquinas':
        return '⚙️';
      default:
        return '📋';
    }
  }

  Color _getCorRamo(String ramo) {
    switch (ramo.toLowerCase()) {
      case 'veículo':
        return Colors.blue;
      case 'imóvel':
        return Colors.orange;
      case 'vida':
        return Colors.red;
      case 'responsabilidade civil':
        return Colors.purple;
      case 'transporte':
        return Colors.green;
      case 'máquinas':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final apolicesDoRamo = widget.apolices;

    if (apolicesDoRamo.length == 1) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Apólice Selecionada'),
        content: Text('Apólice de ${apolicesDoRamo.first.ramo} automaticamente selecionada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, apolicesDoRamo.first),
            child: const Text('OK'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        'Selecione a Apólice',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: apolicesDoRamo.asMap().entries.map((entry) {
            final apolice = entry.value;
            final emoji = _getEmojiRamo(apolice.ramo);
            final cor = _getCorRamo(apolice.ramo);
            final isSelected = _selectedApolice.numeroApolice == apolice.numeroApolice;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? cor : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedApolice = apolice;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$emoji ${apolice.ramo} • ${apolice.numeroApolice}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: cor,
                              ),
                            ),
                            const Spacer(),
                            Radio<String>(
                              value: apolice.numeroApolice,
                              groupValue: _selectedApolice.numeroApolice,
                              onChanged: (value) {
                                setState(() {
                                  _selectedApolice = apolice;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              apolice.seguradora,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                            Text(
                              BRFormatters.formatarMoeda(apolice.valorApolice.toInt()),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(apolice.dataInicio)} até ${DateFormat('dd/MM/yyyy').format(apolice.dataFim)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selectedApolice),
          child: const Text('Selecionar'),
        ),
      ],
    );
  }
}