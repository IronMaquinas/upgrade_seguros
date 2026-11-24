// lib/widgets/identificacao_atendimento.dart
//
// Etapa 19b.4: no topo do detalhe do sinistro / da assistência, o que mais se
// procura e se copia:
//   • RamoChip — o ramo (Frota, Veículo Individual, Residencial…) em evidência;
//   • NumeroRegistro — o nosso número de registro (SN…/AS…) com botão copiar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RamoChip extends StatelessWidget {
  final String ramo;
  const RamoChip(this.ramo, {super.key});

  static (IconData, Color) _visual(String r) {
    final t = r.toLowerCase();
    if (t.contains('ônibus') || t.contains('onibus') || t.contains('rco')) return (Icons.directions_bus_outlined, const Color(0xFF6A1B9A));
    if (t.contains('frota')) return (Icons.local_shipping_outlined, const Color(0xFF1565C0));
    if (t.contains('veículo') || t.contains('veiculo') || t == 'assistência') return (Icons.directions_car_outlined, const Color(0xFF1565C0));
    if (t.contains('residencial')) return (Icons.home_outlined, const Color(0xFF2E7D32));
    if (t.contains('vida')) return (Icons.favorite_border, const Color(0xFFC62828));
    if (t.contains('máquina') || t.contains('maquina')) return (Icons.precision_manufacturing_outlined, const Color(0xFFEF6C00));
    if (t.contains('transporte')) return (Icons.inventory_2_outlined, const Color(0xFF00838F));
    if (t.contains('empresarial')) return (Icons.business_outlined, const Color(0xFF4E342E));
    return (Icons.category_outlined, const Color(0xFF455A64));
  }

  @override
  Widget build(BuildContext context) {
    final r = ramo.trim();
    final (icone, cor) = r.isEmpty ? (Icons.help_outline, Colors.grey.shade600) : _visual(r);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: 5),
        Text(
          r.isEmpty ? 'Ramo não informado' : r,
          style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 12),
        ),
      ]),
    );
  }
}

class NumeroRegistro extends StatelessWidget {
  final String numero;
  final String rotulo;
  const NumeroRegistro(this.numero, {super.key, this.rotulo = 'Nº do registro'});

  @override
  Widget build(BuildContext context) {
    if (numero.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(rotulo, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          SelectableText(numero, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        ]),
        IconButton(
          tooltip: 'Copiar número',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.copy, size: 17),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: numero));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Número $numero copiado'), duration: const Duration(seconds: 2)),
              );
            }
          },
        ),
      ]),
    );
  }
}
