//firestore_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data'; // Para Uint8List (web)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';
import '../models/vehicle_model.dart';
import '../models/claim_task_model.dart';
import '../models/third_party_model.dart'; // Adicionado, se estiver faltando
import '../models/transport_model.dart'; // Adicionado, se estiver faltando

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  // Removido _firestore = FirebaseFirestore.instance; pois _db já existe e é usado.


  /// --- COLEÇÕES ---

  // Coleção pública: clientes
  CollectionReference<Map<String, dynamic>> getClientesCollection() {
    return _db.collection('clientes');
  }

  // Coleção pública: sinistros
  CollectionReference<Map<String, dynamic>> getSinistrosCollection() {
    return _db.collection('sinistros');
  }

  /// --- CLIENTES ---

  Future<Client> addClient(Client client, String userId) async { // Adicionado userId
    final docRef = await getClientesCollection().add(client.toMap());
    client.id = docRef.id;
    return client;
  }

  Future<List<Client>> getClients(String currentUserId) async {
    final snapshot = await getClientesCollection().get();
    return snapshot.docs
        .map((doc) => Client.fromMap(doc.data())..id = doc.id)
        .toList();
  }

  Future<Client?> getClientById(String clientId) async {
    final snapshot = await getClientesCollection().doc(clientId).get();
    if (snapshot.exists) {
      return Client.fromMap(snapshot.data()!)..id = snapshot.id;
    }
    return null;
  }

  Future<Client?> getClientByCnpjCpf(String cnpjCpf) async {
    final querySnapshot = await getClientesCollection()
        .where('cnpj_cpf', isEqualTo: cnpjCpf)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return Client.fromMap(querySnapshot.docs.first.data())
        ..id = querySnapshot.docs.first.id;
    }
    return null;
  }

  Future<void> updateClient(Client client, String userId) async { // Adicionado userId
    await getClientesCollection().doc(client.id).update(client.toMap());
  }

  /// --- SINISTROS ---

  Future<void> addClaim(Claim claim) async {
    await getSinistrosCollection().add(claim.toMap());
  }

  Future<List<Claim>> getClaims() async {
    final snapshot = await getSinistrosCollection()
        .orderBy('data_abertura', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Claim.fromMap(doc.data())..id = doc.id)
        .toList();
  }

  Future<void> updateClaim(Claim claim) async {
    await getSinistrosCollection().doc(claim.id).update(claim.toMap());
  }

  Future<void> deleteClient(String clientId) async {
    try {
      await _db.collection('clients').doc(clientId).delete();
    } catch (e) {
      rethrow; // Propaga o erro para ser tratado na tela
    }
  }

  Future<void> deleteClaim(String claimId) async {
    await getSinistrosCollection().doc(claimId).delete();
  }

  Future<void> updateClaimStatus(
    String claimId,
    String newStatus,
    String userId,
    String userEmail,
  ) async {
    await getSinistrosCollection().doc(claimId).update({
      'status_atual': newStatus,
      'data_ultima_atualizacao': Timestamp.now(),
      'historico_status': FieldValue.arrayUnion([
        {
          'status': newStatus,
          'data': Timestamp.now(),
          'responsavelId': userId,
          'responsavelEmail': userEmail,
        }
      ]),
    });
  }

  // LISTA DE TAREFAS DO SINISTRO

  Stream<List<ClaimTask>> getTasks(String claimId) {
    return getSinistrosCollection()
      .doc(claimId)
      .collection('tasks')
      .orderBy('prazo')
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => ClaimTask.fromMap(doc.data(), doc.id))
        .toList());
  }

  Future<void> addTask(String claimId, ClaimTask task) async {
    await getSinistrosCollection()
      .doc(claimId)
      .collection('tasks')
      .add(task.toMap());
  }

  Future<void> updateTask(String claimId, ClaimTask task) async {
    await getSinistrosCollection()
      .doc(claimId)
      .collection('tasks')
      .doc(task.id)
      .update(task.toMap());
  }

  Future<void> deleteTask(String claimId, String taskId) async {
    await getSinistrosCollection()
      .doc(claimId)
      .collection('tasks')
      .doc(taskId)
      .delete();
  }
  
  Future<List<String>> uploadSinistroFotos(String numeroSinistro, List<XFile> fotos) async {
    if (fotos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${fotos.length} fotos para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var i = 0; i < fotos.length; i++) {
      try {
        final bytes = await fotos[i].readAsBytes();
        debugPrint('📤 Upload da foto $i: ${fotos[i].name}, tamanho: ${bytes.length} bytes');

        final nome = 'foto_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('sinistros/$numeroSinistro/fotos/$nome');
        debugPrint('📁 Caminho no Storage: sinistros/$numeroSinistro/fotos/$nome');

        final uploadTask = ref.putData(bytes);
        final completer = Completer<TaskSnapshot>();

        // ✅ Escuta apenas o sucesso
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.state == TaskState.success && !completer.isCompleted) {
              completer.complete(snapshot);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        // ✅ Espera o Completer
        final snapshot = await completer.future;
        debugPrint('✅ Upload da foto $i concluído');

        final url = await snapshot.ref.getDownloadURL();
        debugPrint('🔗 URL gerada: $url');

        downloadUrls.add(url);
      } catch (e, s) {
        debugPrint('❌ ERRO ao fazer upload da foto $i: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  Future<List<String>> uploadArquivosLaudos(String numeroSinistro, List<XFile> arquivos) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} arquivos de laudo para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var arquivo in arquivos) {
      try {
        final bytes = await arquivo.readAsBytes();
        final nome = arquivo.name;
        final ref = _storage.ref().child('sinistros/$numeroSinistro/laudos/$nome');
        final metadata = SettableMetadata(contentType: 'application/pdf');

        final uploadTask = ref.putData(bytes, metadata);

        // ✅ Usa Completer para funcionar no web
        final completer = Completer<TaskSnapshot>();
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.state == TaskState.success && !completer.isCompleted) {
              completer.complete(snapshot);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        final snapshot = await completer.future;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e, s) {
        debugPrint('❌ ERRO ao fazer upload do laudo: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de laudos concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  Future<List<String>> uploadThirdPartyPhotos(
    String claimId,
    String thirdPartyId,
    List<XFile> photos,
  ) async {
    if (photos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${photos.length} fotos de terceiro $thirdPartyId para o sinistro $claimId');

    List<String> downloadUrls = [];
    for (final photo in photos) {
      try {
        final bytes = await photo.readAsBytes();
        debugPrint('📤 Upload da foto de terceiro: ${photo.name}, tamanho: ${bytes.length} bytes');

        final nome = '${const Uuid().v4()}.jpg';
        final ref = _storage.ref().child('sinistros/$claimId/terceiros/$thirdPartyId/$nome');

        final metadata = SettableMetadata(contentType: 'image/jpeg');
        final uploadTask = ref.putData(bytes, metadata);

        // ✅ Usa Completer
        final completer = Completer<TaskSnapshot>();
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.state == TaskState.success && !completer.isCompleted) {
              completer.complete(snapshot);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        final snapshot = await completer.future;
        debugPrint('✅ Upload da foto de terceiro concluído');

        final url = await snapshot.ref.getDownloadURL();
        debugPrint('🔗 URL gerada: $url');

        downloadUrls.add(url);
      } catch (e, s) {
        debugPrint('❌ ERRO ao fazer upload da foto de terceiro: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de fotos de terceiros concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  // Upload das fotos do transporte
  Future<List<String>> uploadTransportFotos(
    String numeroSinistro,
    List<XFile> fotos,
  ) async {
    if (fotos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${fotos.length} fotos de transporte para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (final foto in fotos) {
      try {
        final bytes = await foto.readAsBytes();
        final nome = 'foto_${const Uuid().v4()}.jpg';
        final ref = _storage.ref().child('sinistros/$numeroSinistro/transporte/fotos/$nome');

        final metadata = SettableMetadata(contentType: 'image/jpeg');
        final uploadTask = ref.putData(bytes, metadata);
        debugPrint('📤 Upload da foto de transporte: $nome, tamanho: ${bytes.length} bytes');

        // ✅ Usa Completer
        final completer = Completer<TaskSnapshot>();
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.state == TaskState.success && !completer.isCompleted) {
              completer.complete(snapshot);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        final snapshot = await completer.future;
        final url = await snapshot.ref.getDownloadURL();
        debugPrint('🔗 URL gerada: $url');

        downloadUrls.add(url);
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload de foto de transporte: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de fotos de transporte concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  // Upload dos documentos do transporte
  Future<List<String>> uploadTransportDocuments(
    String numeroSinistro,
    List<XFile> arquivos,
  ) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} documentos de transporte para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var arquivo in arquivos) {
      try {
        final bytes = await arquivo.readAsBytes();
        final nome = '${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final ref = _storage.ref().child('sinistros/$numeroSinistro/transporte/documentos/$nome');
        final metadata = SettableMetadata(contentType: 'application/pdf');

        final uploadTask = ref.putData(bytes, metadata);

        final completer = Completer<TaskSnapshot>();
        uploadTask.snapshotEvents.listen(
          (snapshot) {
            if (snapshot.state == TaskState.success && !completer.isCompleted) {
              completer.complete(snapshot);
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
            }
          },
        );

        final snapshot = await completer.future;
        final url = await snapshot.ref.getDownloadURL();
        downloadUrls.add(url);
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload de documento de transporte: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de documentos de transporte concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  // Fórmula para avaliar data de vencimento das apólices
  Future<List<Client>> getAllClients() async {
    final snapshot = await _db.collection('clientes').get();
    return snapshot.docs
        .map((doc) => Client.fromMap(doc.data())..id = doc.id)
        .toList();
  }

  // Pesquisa por nome e CPF/CNPJ
  Future<Client?> getClientByNome(String nome) async {
    final querySnapshot = await getClientesCollection()
        .where('nome', isEqualTo: nome)
        .limit(1)
        .get();
    if (querySnapshot.docs.isNotEmpty) {
      return Client.fromMap(querySnapshot.docs.first.data())
        ..id = querySnapshot.docs.first.id;
    }
    return null;
  }

  // Adiciona Anotações
  Future<void> addAnotacao(String claimId, String texto, String responsavelEmail) async {
    final anotacao = {
      'texto': texto,
      'data': Timestamp.now(),
      'responsavelEmail': responsavelEmail,
    };
    await getSinistrosCollection().doc(claimId).update({
      'anotacoes': FieldValue.arrayUnion([anotacao])
    });
  }

  // Excluir Anotações
  Future<void> deleteAnotacao(String claimId, Map<String, dynamic> anotacao) async {
    await getSinistrosCollection().doc(claimId).update({
      'anotacoes': FieldValue.arrayRemove([anotacao])
    });
  }

  Future<Claim?> getClaimById(String claimId) async {
    final doc = await getSinistrosCollection().doc(claimId).get();
    if (doc.exists) {
      return Claim.fromMap(doc.data()!); // ou como for seu fromMap / fromFirestore
    }
    return null;
  }

  // Obetém todos os sinistros
  Future<List<Claim>> getAllClaims() async {
    try {
      final snapshot = await _db.collection('sinistros').get();

      return snapshot.docs.map((doc) {
        final claim = Claim.fromMap(doc.data());
        claim.id = doc.id; // garante que o ID do documento esteja no objeto
        return claim;
      }).toList();
    } catch (e) {
      print('Erro ao buscar sinistros: $e');
      return [];
    }
  }

  // Busca de todas as tarefas
  Future<List<Map<String, dynamic>>> getAllTasksWithClaims() async {
    final sinistrosSnapshot = await getSinistrosCollection().get();

    List<Map<String, dynamic>> allTasks = [];

    for (var sinistroDoc in sinistrosSnapshot.docs) {
      final claimData = sinistroDoc.data();

      final tasksSnapshot = await sinistroDoc.reference.collection('tarefas').get();

      for (var taskDoc in tasksSnapshot.docs) {
        final data = taskDoc.data();

        allTasks.add({
          'taskId': taskDoc.id,
          'descricao': data['descricao'],
          'status': data['status'],
          'prazo': (data['prazo'] as Timestamp).toDate(),
          'criadoEm': (data['criado_em'] as Timestamp?)?.toDate(),
          'claimId': sinistroDoc.id,
          'responsavelEmail': data['responsavelEmail'] ?? '',
          'clientNome': claimData['client_nome'] ?? '',
          'clientCnpjCpf': claimData['client_cnpj_cpf'] ?? '',
          'numeroSinistro': claimData['numero_sinistro'] ?? '', // **INCLUIR ESSA LINHA**
        });
      }
    }
    return allTasks;
  }

  // --- AJUSTES E ATUALIZAÇÕES ---
  Future<void> atualizarRecomendacaoManutencao(String clientId) async {
    final clientDoc = await getClientesCollection().doc(clientId).get();
    if (!clientDoc.exists) throw Exception('Cliente não encontrado.');

    final client = Client.fromMap(clientDoc.data()!)..id = clientDoc.id;
    final valorApoliceTotal = client.valorTotalApolicesAtivas;  // ← MUDA
    if (valorApoliceTotal <= 0) return;

    final sinistrosSnapshot = await getSinistrosCollection()
        .where('id_cliente', isEqualTo: clientId)
        .get();

    double soma = sinistrosSnapshot.docs.fold<double>(
      0.0,
      (total, doc) => total + (doc.data()['valor_total_sinistro'] ?? 0.0).toDouble(),
    );

    final percentual = soma / valorApoliceTotal;  // ← MUDA
    String recomendacao;
    if (percentual >= 1.0) {
      recomendacao = 'Crítico';
    } else if (percentual >= 0.75) {
      recomendacao = 'Atenção';
    } else if (percentual >= 0.5) {
      recomendacao = 'Bom';
    } else {
      recomendacao = 'Ótimo';
    }

    await getClientesCollection().doc(clientId).update({
      'recomendacao_manutencao': recomendacao,
    });
  }

  Future<void> atualizarVeiculoNosSinistros(Vehicle veiculoAtualizado, String idCliente) async {
    final snapshot = await getSinistrosCollection()
        .where('id_cliente', isEqualTo: idCliente)
        .get();

    for (final doc in snapshot.docs) {
      final veiculoMap = doc.data()['veiculoSelecionado'] as Map<String, dynamic>?;
      if (veiculoMap != null && veiculoMap['chassi'] == veiculoAtualizado.chassi) {
        await doc.reference.update({
          'veiculoSelecionado': veiculoAtualizado.toMap(),
          'data_ultima_atualizacao': Timestamp.now(),
        });
      }
    }
  }
}