// widget_test.dart
// ignore: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Importe as telas e o app
import 'package:upgrade_seguros/screens/auth_screen.dart';
import 'package:upgrade_seguros/main.dart'; // Isso importa MyApp

void main() {
  testWidgets('Tela de login carrega corretamente', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verifica se a tela inicial (AuthOrDashboardRedirect) carrega
    await tester.pump(); // Processa a navegação assíncrona

    // Verifica se a tela de login aparece
    expect(find.byType(AuthScreen), findsOneWidget);

    // Verifica se o texto do login está visível
    expect(find.text('Login Upgrade Corretora de Seguros'), findsOneWidget);
  });
}