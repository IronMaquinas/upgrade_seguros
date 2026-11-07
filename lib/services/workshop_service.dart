// lib/services/workshop_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:upgrade_seguros/models/workshop_model.dart';

class WorkshopService {
  final _firestore = FirebaseFirestore.instance;

  // ─ Criar oficina
  Future<String> criarOfficina(Workshop workshop) async {
    try {
      final docRef = await _firestore
          .collection('workshops')
          .add({
            ...workshop.toMap(),
            'ativo': true,
          });
      return docRef.id;
    } catch (e) {
      throw Exception('Erro ao criar oficina: $e');
    }
  }

  // ─ Obter todas as oficinas (stream)
  Stream<List<Workshop>> obterOfficinas() {
    return _firestore
        .collection('workshops')
        .orderBy('nome')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Workshop.fromMap({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // ─ Obter uma oficina pelo ID
  Future<Workshop?> obterOfficinaPorId(String id) async {
    try {
      final doc = await _firestore.collection('workshops').doc(id).get();
      if (doc.exists) {
        return Workshop.fromMap({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      throw Exception('Erro ao obter oficina: $e');
    }
  }

  // ─ Atualizar oficina
  Future<void> atualizarOfficina(String id, Workshop workshop) async {
    try {
      await _firestore
          .collection('workshops')
          .doc(id)
          .update(workshop.toMap());
    } catch (e) {
      throw Exception('Erro ao atualizar oficina: $e');
    }
  }

  // ─ Deletar oficina
  Future<void> deletarOfficina(String id) async {
    try {
      await _firestore.collection('workshops').doc(id).delete();
    } catch (e) {
      throw Exception('Erro ao deletar oficina: $e');
    }
  }

  // ─ Buscar oficinas por nome (para autocomplete)
  Future<List<Workshop>> buscarOfficinas(String termo) async {
    try {
      final snapshot = await _firestore
          .collection('workshops')
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .get();

      return snapshot.docs
          .map((doc) => Workshop.fromMap({...doc.data(), 'id': doc.id}))
          .where((w) => w.nome.toLowerCase().contains(termo.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Erro ao buscar oficinas: $e');
    }
  }

  // ─ Contar oficinas
  Future<int> contarOfficinas() async {
    try {
      final snapshot = await _firestore.collection('workshops').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Erro ao contar oficinas: $e');
    }
  }
}
