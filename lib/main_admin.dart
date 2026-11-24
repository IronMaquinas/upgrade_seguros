// lib/main_admin.dart — Etapa 21: ponto de entrada do PORTAL DA PLATAFORMA
//
// Site separado do app das corretoras (mesmo projeto Firebase, outro endereço):
//   flutter build web -t lib/main_admin.dart   → copiado para build/admin
//   firebase deploy --only hosting:admin
// Nada daqui vai no app dos clientes (lib/main.dart não importa lib/admin/).

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'admin/portal_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const _PortalApp());
}

class _PortalApp extends StatelessWidget {
  const _PortalApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portal da plataforma',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF263238),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: const PortaoPlataforma(),
    );
  }
}
