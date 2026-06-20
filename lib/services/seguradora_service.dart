import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/seguradora_model.dart';

class SeguradoraService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'seguradoras';

  /// 📝 CRIAR nova seguradora (com TODOS os campos)
  Future<Seguradora> criar(Seguradora seguradora) async {
    try {
      // Verificar se já existe com esse nome
      final existe = await _nomeJaExiste(seguradora.nome);
      if (existe) {
        throw Exception('Já existe uma seguradora com esse nome!');
      }

      final docRef = await _firestore.collection(_collection).add(
        seguradora.toMap(),
      );

      // ✅ IMPORTANTE: Atualizar o ID do documento no Firestore
      // Isso garante que o campo 'id' dentro do documento = ID do documento Firestore
      await _firestore.collection(_collection).doc(docRef.id).update({
        'id': docRef.id,
      });

      print('✅ Seguradora criada com sucesso! ID: ${docRef.id}');

      return Seguradora(
        id: docRef.id,
        nome: seguradora.nome,
        telefone: seguradora.telefone,
        email: seguradora.email,
        contato: seguradora.contato,
        ativa: seguradora.ativa,
        dataCriacao: DateTime.now(),
      );
    } catch (e) {
      print('❌ Erro ao criar seguradora: $e');
      rethrow;
    }
  }

  /// 📖 LISTAR todas as seguradoras (ativas e inativas)
  Future<List<Seguradora>> listarTodas() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('nome')
          .get();

      return snapshot.docs
          .map((doc) => Seguradora.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Erro ao listar seguradoras: $e');
      rethrow;
    }
  }

  /// 📖 LISTAR apenas as ativas
  Future<List<Seguradora>> listarAtivas() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('ativa', isEqualTo: true)
          .orderBy('nome')
          .get();

      return snapshot.docs
          .map((doc) => Seguradora.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Erro ao listar seguradoras ativas: $e');
      rethrow;
    }
  }

  /// 🔍 BUSCAR por ID
  Future<Seguradora?> buscarPorId(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();

      if (!doc.exists) return null;

      return Seguradora.fromFirestore(doc);
    } catch (e) {
      print('❌ Erro ao buscar seguradora: $e');
      return null;
    }
  }

  /// ✏️ EDITAR seguradora (com TODOS os campos)
  Future<void> editar(String id, Seguradora seguradora) async {
    try {
      // Verificar se o novo nome já existe (excluindo o atual)
      if (seguradora.nome != (await buscarPorId(id))?.nome) {
        final existe = await _nomeJaExiste(seguradora.nome, excluirId: id);
        if (existe) {
          throw Exception('Já existe uma seguradora com esse nome!');
        }
      }

      await _firestore.collection(_collection).doc(id).update(
        seguradora.toMap(),
      );

      print('✅ Seguradora editada com sucesso!');
    } catch (e) {
      print('❌ Erro ao editar seguradora: $e');
      rethrow;
    }
  }

  /// ❌ DESATIVAR seguradora (soft delete)
  Future<void> desativar(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'ativa': false,
      });

      print('✅ Seguradora desativada com sucesso!');
    } catch (e) {
      print('❌ Erro ao desativar seguradora: $e');
      rethrow;
    }
  }

  /// ✅ REATIVAR seguradora
  Future<void> reativar(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).update({
        'ativa': true,
      });

      print('✅ Seguradora reativada com sucesso!');
    } catch (e) {
      print('❌ Erro ao reativar seguradora: $e');
      rethrow;
    }
  }

  /// 🔎 Verificar se nome já existe
  Future<bool> _nomeJaExiste(String nome, {String? excluirId}) async {
    try {
      var query = _firestore
          .collection(_collection)
          .where('nome', isEqualTo: nome);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) return false;

      // Se tem excluirId, verifica se é diferente
      if (excluirId != null) {
        return snapshot.docs.any((doc) => doc.id != excluirId);
      }

      return true;
    } catch (e) {
      print('❌ Erro ao verificar nome: $e');
      return false;
    }
  }

  /// 🔄 STREAM para atualização em tempo real
  Stream<List<Seguradora>> streamTodas() {
    return _firestore
        .collection(_collection)
        .orderBy('nome')
        .snapshots()
        .map((snapshot) {
          final seguradoras = snapshot.docs
              .map((doc) {
                return Seguradora.fromFirestore(doc);
              })
              .toList();
          return seguradoras;
        });
  }

  /// 🔄 STREAM apenas ativas
  Stream<List<Seguradora>> streamAtivas() {
    return _firestore
        .collection(_collection)
        .where('ativa', isEqualTo: true)
        .orderBy('nome')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Seguradora.fromFirestore(doc))
            .toList());
  }
}