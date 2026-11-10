import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:upgrade_seguros/services/funcoes_nuvem.dart'; // Etapa 15

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Retorna o usuário atual (se autenticado)
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Retorna o UID do usuário ou fallback se não estiver autenticado
  String getUserId() {
    return _auth.currentUser?.uid ?? 'anonymous_user';
  }

  // Retorna o e-mail do usuário ou fallback
  String getUserEmail() {
    return _auth.currentUser?.email ?? 'desconhecido';
  }

  Future<String> getUserName() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Desconhecido';
 
      // 1️⃣ PRIORIDADE 1: Busca o nome em Firestore (collection: users ou employees)
      try {
        // Tenta buscar em 'users' collection
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
 
        if (userDoc.exists) {
          final nome = userDoc.data()?['nome'] ?? userDoc.data()?['name'];
          if (nome != null && nome.toString().isNotEmpty) {
            return nome.toString();
          }
        }
      } catch (e) {
        print('Erro ao buscar em users collection: $e');
      }
 
      // Se não achou em 'users', tenta buscar em 'employees' (by email)
      try {
        final employeeDoc = await _firestore
            .collection('employees')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
 
        if (employeeDoc.docs.isNotEmpty) {
          final nome = employeeDoc.docs.first.data()['nome'] ?? 
                       employeeDoc.docs.first.data()['name'];
          if (nome != null && nome.toString().isNotEmpty) {
            return nome.toString();
          }
        }
      } catch (e) {
        print('Erro ao buscar em employees collection: $e');
      }
 
      // 2️⃣ PRIORIDADE 2: Se não encontrou nome, usa displayName do Firebase
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        return user.displayName!;
      }
 
      // 3️⃣ PRIORIDADE 3: Como último recurso, retorna "Desconhecido" (NÃO o email!)
      // Isto evita expor emails pessoais de funcionários
      return 'Desconhecido';
    } catch (e) {
      print('❌ Erro ao obter nome do usuário: $e');
      return 'Desconhecido';
    }
  }

  // Faz logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Login com e-mail e senha
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
        try {
          final credential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Registra o último login. Etapa 15: não impede a entrada se as
          // regras recusarem (conta sem cadastro ou desativada).
          try {
            await _firestore.collection('users').doc(credential.user!.uid).set({
              'email': credential.user!.email,
              'lastLogin': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('lastLogin não gravado: $e');
          }

                  return credential;
                } catch (e) {
                  rethrow;
                }
      }

  // Registro com e-mail e senha
  Future<UserCredential> registerWithEmailAndPassword(
      String email,
      String password,
      String matricula,
    ) async {
      try {
        final username = email.split('@').first;

        // 🔒 validar username
        final existsUsername = await _firestore
            .collection('users')
            .where('username', isEqualTo: username)
            .get();

        if (existsUsername.docs.isNotEmpty) {
          throw Exception('Username já existe');
        }

        // 🔒 validar matrícula
        final existsMatricula = await _firestore
            .collection('users')
            .where('matricula', isEqualTo: matricula)
            .get();

        if (existsMatricula.docs.isNotEmpty) {
          throw Exception('Matrícula já cadastrada');
        }

        // 🔥 cria no Auth
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // 💾 salva no Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'email': credential.user!.email,
          'role': 'user',

          'username': username,
          'matricula': matricula, // ✅ correto agora

          'empresaId': 'default',
          'ativo': true,

          'createdAt': FieldValue.serverTimestamp(),
        });

        return credential;
      } catch (e) {
        rethrow;
      }
  }

  /// Etapa 15: "usuário" ou "matrícula" → e-mail, pela Function apoioLogin
  /// (sem login). Lança Exception('Usuário não encontrado') se não existir.
  static Future<String> emailDoLogin(String login) async {
    final r = await FuncoesNuvem.post('apoioLogin', {'login': login}, comLogin: false);
    if (r.statusCode == 404) throw Exception('Usuário não encontrado');
    if (r.statusCode != 200) throw Exception(FuncoesNuvem.erro(r));
    final email = (jsonDecode(r.body) as Map)['email'] as String? ?? '';
    if (email.isEmpty) throw Exception('Usuário sem email válido');
    return email;
  }

  // Verifica se o usuário atual é admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  // Busca o role do usuário atual no Firestore
  Future<String> getUserRole() async {
    final user = _auth.currentUser;
    print('Usuário atual no getUserRole: ${user?.uid}');
    if (user == null) return 'user';

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return 'user';

    final role = doc.data()?['role'] as String?;
    return role ?? 'user';
  }

  // Envia e-mail de redefinição de senha
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

   // LOGIN PARA DIFERENTES CREDENCIAIS
  Future<UserCredential> signInSmart(
    String login,
    String password,
  ) async {
    try {
      // 🔹 se for email → login direto
      if (login.contains('@')) {
        return await signInWithEmailAndPassword(login, password);
      }

      // 🔍 usuário ou matrícula → e-mail (Etapa 15: pelo servidor)
      final email = await emailDoLogin(login);

      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

    } catch (e) {
      rethrow;
    }
  }

}