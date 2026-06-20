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
    final firestore = FirebaseFirestore.instance;

    // 🔹 se for email → login direto
    if (login.contains('@')) {
      return await auth.signInWithEmailAndPassword(
        email: login,
        password: password,
      );
    }

    // 🔍 busca username
    var query = await firestore
        .collection('users')
        .where('username', isEqualTo: login)
        .limit(1)
        .get();

    // 🔍 se não achou → matrícula
    if (query.docs.isEmpty) {
      query = await firestore
          .collection('users')
          .where('matricula', isEqualTo: login)
          .limit(1)
          .get();
    }

    if (query.docs.isEmpty) {
      throw Exception('Usuário não encontrado');
    }

    final data = query.docs.first.data();
    final email = data['email'];

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

      // 🔥 novo bloco
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'email': user.email,
          'lastLogin': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login - Upgrade Corretora de Seguros'),
        automaticallyImplyLeading: false, // Remove botão de voltar
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Se for web ou tablet, limita a largura
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
                    ],
                    const SizedBox(height: 16.0),
                    // Links
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: const Text('Não tem conta? Cadastre-se'),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Funcionalidade em desenvolvimento.'),
                          ),
                        );
                      },
                      child: const Text('Esqueci minha senha'),
                    ),
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