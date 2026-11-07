// lib/widgets/assist_tipo_picker.dart
//
// Modal padrão "Tipo de Assistência" (Veicular / Residencial), usado pelo
// Dashboard ("Novo Registro" → Assistência) e pelo botão laranja
// "Nova Assistência" da lista de Assistências (Etapa 06). Um componente só,
// para os dois lugares nunca ficarem diferentes.

import 'package:flutter/material.dart';

import 'option_picker_dialog.dart';

/// Cor padrão das assistências no SaaS (botão "Nova Assistência").
final Color corAssistencia = Colors.orange.shade600;

const _tiposAssistencia = [
  PickerOption(
    label: 'Veicular',
    value: 'veiculo',
    icon: Icons.directions_car_outlined,
    color: Color(0xFFFF6F00),
    description: 'Guincho, vidro, combustível...',
  ),
  PickerOption(
    label: 'Residencial',
    value: 'residencial',
    icon: Icons.home_outlined,
    color: Color(0xFF6A1B9A),
    description: 'Eletricista, encanador, chaveiro...',
  ),
];

/// Abre o modal e devolve `'veiculo'`, `'residencial'` ou `null` (cancelado).
///
/// [onVoltar]: quando informado, mostra o botão "Voltar" (o Dashboard usa para
/// reabrir o modal anterior "Novo Registro").
Future<String?> mostrarSeletorTipoAssistencia(
  BuildContext context, {
  VoidCallback? onVoltar,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tipo de Assistência',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecione o tipo de atendimento',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 18),
              ..._tiposAssistencia.map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Navigator.of(ctx).pop(opt.value),
                        child: Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200, width: 0.8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: opt.color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(opt.icon, color: opt.color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      opt.label,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      opt.description ?? '',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (onVoltar != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onVoltar();
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                        child: const Text('Voltar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Cancelar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
