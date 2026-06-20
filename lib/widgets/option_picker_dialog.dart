import 'package:flutter/material.dart';

/// Modelo para opções do picker
class PickerOption {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? description;

  const PickerOption({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.description,
  });
}

/// Dialog reutilizável para seleção de opções
class OptionPickerDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<PickerOption> options;
  final double? maxWidth;

  const OptionPickerDialog({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),

              // Subtítulo
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 18),

              // Opções
              ...options.map((opt) => _buildOptionCard(opt, context)),
              const SizedBox(height: 16),
              // Botão Cancelar
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(PickerOption opt, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).pop(opt.value),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200, width: 0.8),
            ),
            child: Row(
              children: [
                // Ícone com background colorido
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

                // Label e descrição
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
                      if (opt.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          opt.description!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Chevron indicador
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey.shade300,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
