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
}) {
  // Remove a notificação anterior se existir
  _currentEntry?.remove();
  _currentEntry = null;

  final overlayState = navigatorKey.currentState?.overlay;
  if (overlayState == null) return;

  // Define a cor de fundo com base no título (Vencido → vermelho)
  final bgColor = title.toLowerCase().contains('vencid') ? Colors.red : backgroundColor;

  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 60,
      right: 16,
      child: Material(
        color: Colors.transparent,
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  overlayState.insert(entry);
  _currentEntry = entry;

  Timer(duration, () {
    if (entry.mounted) {
      entry.remove();
      if (_currentEntry == entry) _currentEntry = null;
    }
  });
}
}