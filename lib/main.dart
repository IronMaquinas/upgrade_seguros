// upgrade-seguros.web.app

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:upgrade_seguros/services/notification_service.dart';
import 'package:upgrade_seguros/services/sla_monitor_service.dart';
import 'firebase_options.dart';
import 'package:intl/date_symbol_data_local.dart';

// Serviços
import 'services/auth_service.dart';
import 'services/biometric_service.dart';

// Telas
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/nps_response_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
    // ✅ Inicializa locale pt_BR
  await initializeDateFormatting('pt_BR', null);

  try {
    debugPrint('🔍 Inicializando Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase inicializado com sucesso');
  } catch (e, s) {
    debugPrint('❌ Erro ao inicializar Firebase: $e\n$s');
  }

  runApp(const MyApp());
}

// ─────────────────────────────────────────────────────────────
// HELPER: extrai parâmetros do link NPS
//
// Suporta os dois modos de Flutter Web:
//   Hash routing  → https://app.web.app/#/nps?os=X&token=Y
//   Path routing  → https://app.web.app/nps?os=X&token=Y
// ─────────────────────────────────────────────────────────────
({String claimId, String token})? _extrairParamsNps() {
  if (!kIsWeb) return null;
  final uri = Uri.base;

  // 1) Tenta obter claim/token da query string normal (path routing)
  if (uri.path.contains('/nps')) {
    final claim = uri.queryParameters['claim'] ?? '';
    final token = uri.queryParameters['token'] ?? '';
    if (claim.isNotEmpty && token.isNotEmpty) {
      return (claimId: claim, token: token);
    }
  }

  // 2) Tenta obter do fragmento (hash routing)
  final fragment = uri.fragment;
  if (fragment.contains('/nps')) {
    // Remove o '#' inicial se existir
    String withoutHash = fragment.startsWith('#') ? fragment.substring(1) : fragment;
    // Separa o caminho da query string dentro do fragmento
    final questionIndex = withoutHash.indexOf('?');
    if (questionIndex != -1) {
      final queryString = withoutHash.substring(questionIndex + 1);
      final params = Uri.splitQueryString(queryString);
      final claim = params['claim'] ?? '';
      final token = params['token'] ?? '';
      if (claim.isNotEmpty && token.isNotEmpty) {
        return (claimId: claim, token: token);
      }
    } else {
      // Fragmento sem interrogação → não tem parâmetros
      return null;
    }
  }

  return null;
}

  class MyApp extends StatelessWidget {
    // 🔥 1. Declare a chave como estática
    static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
      // 🔥 2. Atribua ao serviço ANTES de usar o MaterialApp
      NotificationService.navigatorKey = navigatorKey;

      final npsParams = _extrairParamsNps();
      print('🔍 NPS Params extraídos: $npsParams');
      
      return MaterialApp(
        navigatorKey: navigatorKey,  // 🔥 3. Use a mesma chave
        title: 'Upgrade Corretora',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(backgroundColor: Colors.blueAccent),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.blueAccent,
          ),
        ),
        home: npsParams != null
            ? NpsResponseScreen(
                claimId: npsParams.claimId,
                token: npsParams.token,
              )
            : const AuthOrDashboardRedirect(),
      );
    }
  }

class AuthOrDashboardRedirect extends StatefulWidget {
  const AuthOrDashboardRedirect({super.key});

  @override
  State<AuthOrDashboardRedirect> createState() => _AuthOrDashboardRedirectState();
}

class _AuthOrDashboardRedirectState extends State<AuthOrDashboardRedirect> {
  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    debugPrint('🔍 Verificando estado de autenticação...');

    try {
      final user = _authService.getCurrentUser();

      if (user == null || user.isAnonymous) {
        debugPrint('👤 Usuário não autenticado');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
              );
            }
          });
        }
        return;
      }

      debugPrint('🔐 Usuário autenticado: ${user.email}');
      bool isAuthenticated = false;

      try {
        isAuthenticated = await _biometricService.authenticateWithBiometrics();
        debugPrint('✅ Biometria: $isAuthenticated');
      } catch (e, s) {
        debugPrint('❌ Erro na biometria: $e\n$s');
      }

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            SlaMonitorService().startMonitoring();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => isAuthenticated
                    ? const DashboardScreen()
                    : const AuthScreen(),
              ),
            );
          }
        });
      }
    } catch (e, s) {
      debugPrint('❌ Erro no _checkAuthState: $e\n$s');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('lib/assets/logo_upgrade.png', height: 120),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 10),
            const Text('Iniciando...'),
          ],
        ),
      ),
    );
  }
}