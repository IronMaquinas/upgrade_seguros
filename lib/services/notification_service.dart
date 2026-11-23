import 'dart:async';

import 'package:flutter/material.dart';

class NotificationService {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _currentEntry; // para evitar múltiplas notificações

static void showFloatingNotification(
  String title,
  String message, {
  Color backgroundColor = Colors.orange,
  Duration duration = const Duration(seconds: 10),
  VoidCallback? onTap, // Etapa 18.1: clique abre o atendimento/tarefa
}) {
  // Remove a notificação anterior se existir
  _currentEntry?.remove();
  _currentEntry = null;

  final overlayState = navigatorKey.currentState?.overlay;
  if (overlayState == null) return;

  // Define a cor de fundo com base no título (Vencido → vermelho)
  final bgColor = title.toLowerCase().contains('vencid') ? Colors.red : backgroundColor;

  late final OverlayEntry entry;
  void fechar() {
    if (entry.mounted) entry.remove();
    if (_currentEntry == entry) _currentEntry = null;
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 60,
      right: 16,
      child: Material(
        color: Colors.transparent,
        // Etapa 18.1: antes o cartão não respondia ao clique.
        child: MouseRegion(
          cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
          onTap: onTap == null
              ? null
              : () {
                  fechar();
                  onTap();
                },
          child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor, // ← usa a cor calculada
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Icon(
                title.toLowerCase().contains('vencid') ? Icons.warning : Icons.timer,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    if (onTap != null)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Clique para abrir',
                            style: TextStyle(color: Colors.white, fontSize: 11, decoration: TextDecoration.underline, decorationColor: Colors.white)),
                      ),
                  ],
                ),
              ),
              // Etapa 18.1: fechar sem esperar os 10 segundos
              IconButton(
                tooltip: 'Fechar',
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: fechar,
              ),
            ],
          ),
        ),
        ),
        ),
      ),
    ),
  );

  overlayState.insert(entry);
  _currentEntry = entry;

  Timer(duration, fechar);
}
}