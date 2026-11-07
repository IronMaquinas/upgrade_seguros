// lib/services/corretora_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:upgrade_seguros/models/corretora_model.dart';

class CorretoraService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _collection = 'corretoras';

  /// Obtém a corretora do usuário logado
  Future<Corretora?> getCorretoraLogada() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      // Busca o usuário para pegar o empresaId
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final empresaId = userDoc.data()?['empresaId'] as String?;

      if (empresaId == null || empresaId.isEmpty) return null;

      // Busca a corretora
      final doc = await _db.collection(_collection).doc(empresaId).get();
      if (!doc.exists) return null;

      return Corretora.fromFirestore(doc);
    } catch (e) {
      print('Erro ao buscar corretora logada: $e');
      return null;
    }
  }

  /// Busca uma corretora pelo ID
  Future<Corretora?> getCorretoraById(String id) async {
    try {
      final doc = await _db.collection(_collection).doc(id).get();
      if (!doc.exists) return null;
      return Corretora.fromFirestore(doc);
    } catch (e) {
      print('Erro ao buscar corretora: $e');
      return null;
    }
  }

  /// Salva/atualiza dados da corretora
  Future<void> saveCorretora(Corretora corretora) async {
    try {
      await _db
          .collection(_collection)
          .doc(corretora.id)
          .set(corretora.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Erro ao salvar corretora: $e');
      rethrow;
    }
  }

  /// Atualiza apenas nome, telefone e email da corretora
  Future<void> updateContactInfo(
    String corretoraId,
    String nome,
    String telefone,
    String email,
  ) async {
    try {
      await _db.collection(_collection).doc(corretoraId).update({
        'nome': nome,
        'telefone': telefone,
        'email': email,
      });
    } catch (e) {
      print('Erro ao atualizar dados de contato: $e');
      rethrow;
    }
  }
}
