import '../models/seguradora_model.dart';
import 'package:upgrade_seguros/services/empresa_atual.dart'; // Etapa 16
import 'package:upgrade_seguros/services/seguradoras_cadastradas.dart'; // Etapa 20
import 'package:upgrade_seguros/utils/seguradoras.dart'; // Etapa 20
import 'package:cloud_firestore/cloud_firestore.dart'; // Etapa 22: Timestamp, SetOptions

class SeguradoraService {
  final String _collection = 'seguradoras';

  /// 📝 CRIAR nova seguradora (com TODOS os campos)
  Future<Seguradora> criar(Seguradora seguradora) async {
    try {
      // Etapa 20: barra também nome parecido (Chubb × CHUBB, AXA × AXA Seguros)
      final parecida = await _nomeParecido(seguradora.nome);
      if (parecida != null) {
        throw Exception('Já existe a seguradora "$parecida" — use essa.');
      }

      final docRef = await EmpresaAtual.col(_collection).add(
        seguradora.toMap(),
      );

      // ✅ IMPORTANTE: Atualizar o ID do documento no Firestore
      // Isso garante que o campo 'id' dentro do documento = ID do documento Firestore
      await EmpresaAtual.col(_collection).doc(docRef.id).update({
        'id': docRef.id,
      });

      SeguradorasCadastradas.invalidar(); // Etapa 20
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
      final snapshot = await EmpresaAtual.col(_collection)
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
      final snapshot = await EmpresaAtual.col(_collection)
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
      final doc = await EmpresaAtual.col(_collection).doc(id).get();

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
        final parecida = await _nomeParecido(seguradora.nome, excluirId: id);
        if (parecida != null) {
          throw Exception('Já existe a seguradora "$parecida" — use essa.');
        }
      }

      await EmpresaAtual.col(_collection).doc(id).update(
        seguradora.toMap(),
      );

      SeguradorasCadastradas.invalidar(); // Etapa 20
      print('✅ Seguradora editada com sucesso!');
    } catch (e) {
      print('❌ Erro ao editar seguradora: $e');
      rethrow;
    }
  }

  /// ❌ DESATIVAR seguradora (soft delete)
  Future<void> desativar(String id) async {
    try {
      await EmpresaAtual.col(_collection).doc(id).update({
        'ativa': false,
      });

      SeguradorasCadastradas.invalidar(); // Etapa 20
      print('✅ Seguradora desativada com sucesso!');
    } catch (e) {
      print('❌ Erro ao desativar seguradora: $e');
      rethrow;
    }
  }

  /// ✅ REATIVAR seguradora
  Future<void> reativar(String id) async {
    try {
      await EmpresaAtual.col(_collection).doc(id).update({
        'ativa': true,
      });

      SeguradorasCadastradas.invalidar(); // Etapa 20
      print('✅ Seguradora reativada com sucesso!');
    } catch (e) {
      print('❌ Erro ao reativar seguradora: $e');
      rethrow;
    }
  }

  /// Etapa 22: grava só o que é DESTA corretora para uma seguradora do catálogo
  /// (telefone, e-mail, contato, ativa). Cria o documento se ainda não existe.
  /// O nome vem do catálogo; não passa pela checagem de nome parecido.
  Future<void> salvarDadosDaCorretora(Seguradora s) async {
    final dados = <String, dynamic>{
      'nome': s.nome,
      'telefone': s.telefone,
      'email': s.email,
      'contato': s.contato,
      'ativa': s.ativa,
      if (s.catalogoId.isNotEmpty) 'catalogoId': s.catalogoId,
    };
    if (s.id.isEmpty) {
      await EmpresaAtual.col(_collection).add({...dados, 'data_criacao': Timestamp.fromDate(DateTime.now())});
    } else {
      await EmpresaAtual.col(_collection).doc(s.id).set(dados, SetOptions(merge: true));
    }
    SeguradorasCadastradas.invalidar();
  }

  /// 🔎 Etapa 20: nome igual OU parecido já cadastrado (sem acento/caixa e sem
  /// "Seguros"/"S.A." no fim). Antes só barrava nome exatamente igual e, se a
  /// consulta falhasse, deixava passar.
  Future<String?> _nomeParecido(String nome, {String? excluirId}) async {
    final snapshot = await EmpresaAtual.col(_collection).get();
    final outros = [
      for (final d in snapshot.docs)
        if (d.id != excluirId) ((d.data()['nome'] ?? '') as String),
    ];
    return resolverSeguradora(nome, outros);
  }

  /// 🔄 STREAM para atualização em tempo real
  Stream<List<Seguradora>> streamTodas() {
    return EmpresaAtual.col(_collection)
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
    return EmpresaAtual.col(_collection)
        .where('ativa', isEqualTo: true)
        .orderBy('nome')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Seguradora.fromFirestore(doc))
            .toList());
  }
}