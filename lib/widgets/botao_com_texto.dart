// lib/widgets/botao_com_texto.dart
//
// Etapa 10: ícone + texto com contorno, para ações na barra superior (usado como
// `child` de PopupMenuButton — o menu cuida do clique). Antes ficava dentro da
// lista de clientes (Etapa 09); agora também na lista de tarefas.

import 'package:flutter/material.dart';

class BotaoComTexto extends StatelessWidget {
  final IconData icone;
  final String texto;
  const BotaoComTexto({super.key, required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    final cor = IconTheme.of(context).color ?? const Color(0xFF1A1A2E);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 20, color: cor),
            const SizedBox(width: 6),
            Text(texto, style: TextStyle(color: cor, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
