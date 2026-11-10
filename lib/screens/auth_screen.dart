// ignore_for_file: unused_field

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/register_screen.dart';
import '../screens/dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final AuthService _authService = AuthService();
  final BiometricService _biometricService = BiometricService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoading = false;
  String _errorMessage = '';

  // MÉTODO PARA LOGIN SMART POR EMAIL, CADASTRO OU MATRICULA
  Future<UserCredential> _signInSmart(
    String login,
    String password,
  ) async {
    final auth = FirebaseAuth.instance;
    // 🔹 se for email → login direto
    if (login.contains('@')) {
      return await auth.signInWithEmailAndPassword(
        email: login,
        password: password,
      );
    }

    // 🔍 usuário ou matrícula → e-mail.
    // Etapa 15: quem procura é o servidor (Function apoioLogin), que devolve só
    // o e-mail; antes o app lia a coleção users sem login (banco aberto).
    final email = await AuthService.emailDoLogin(login);

    return await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _signInSmart(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Etapa 15: registrar o último login não pode impedir a entrada (as
        // regras recusam se a conta não tiver cadastro ou estiver desativada).
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'email': user.email,
            'lastLogin': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('lastLogin não gravado: $e');
        }
      }

      await _secureStorage.write(key: 'email', value: _emailController.text.trim());
      await _secureStorage.write(key: 'password', value: _passwordController.text);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = 'Erro de login: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocorreu um erro: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithBiometrics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authenticated = await _biometricService.authenticateWithBiometrics();
    if (authenticated) {
      try {
        final email = await _secureStorage.read(key: 'email');
        final password = await _secureStorage.read(key: 'password');

        if (email != null && password != null) {
          await _signInSmart(email, password);

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardScreen()),
            );
          }
        } else {
          setState(() {
            _errorMessage = 'Credenciais não encontradas. Faça login manualmente.';
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Erro ao autenticar com biometria: $e';
        });
      }
    } else {
      setState(() {
        _errorMessage = 'Autenticação biométrica falhou.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // 🔥 NOVO: Método para redefinir senha
  Future<void> _resetPassword() async {
    final emailController = TextEditingController();
    bool isLoading = false;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Redefinir Senha'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Digite o e-mail cadastrado para receber o link de redefinição de senha.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Informe um e-mail válido.')),
                          );
                          return;
                        }
                        setStateDialog(() => isLoading = true);
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('E-mail de redefinição enviado!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          setStateDialog(() => isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erro: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - Upgrade Corretora de Seguros'),
        automaticallyImplyLeading: false,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth > 600;
          final maxWidth = isLargeScreen ? 400.0 : double.infinity;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding: const EdgeInsets.all(24.0),
                decoration: isLargeScreen
                    ? BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      )
                    : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo
                    Image.asset(
                      'lib/assets/logo_upgrade.png',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32.0),

                    // Email
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'E-mail, usuário ou matrícula',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16.0),

                    // Senha
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        isDense: true,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16.0),

                    // Mensagem de erro
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red, fontSize: 14.0),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Botão Entrar
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Entrar',
                                style: TextStyle(fontSize: 18.0),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    if (!kIsWeb) ...[
                      // Biometria
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Entrar com Biometria'),
                          onPressed: _isLoading ? null : _signInWithBiometrics,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16.0),
                    ],

                    // 🔥 Esqueci minha senha (agora funcional)
                    TextButton(
                      onPressed: _resetPassword,
                      child: const Text('Esqueci minha senha'),
                    ),
                    // ❌ Link "Não tem conta? Cadastre-se" removido

                    // 🔥 Rodapé com navegadores recomendados
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, width: 0.5),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Navegadores recomendados: Safari, FireFox ou Edge. O Chrome pode apresentar instabilidade e dificuldades de visualizações de imagens.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}