import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // Para Uint8List (web)
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http; // Adicione esta linha
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, kDebugMode;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:upgrade_seguros/models/workshop_model.dart';
import 'package:uuid/uuid.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';
import '../models/vehicle_model.dart';
import '../models/claim_task_model.dart';
import '../models/third_party_model.dart'; // Adicionado, se estiver faltando
import '../models/transport_model.dart'; // Adicionado, se estiver faltando
import 'package:upgrade_seguros/models/assist_sla_config_model.dart';


const String _cloudFunctionUrl = 'https://uploadfile-hwtlk2s4qq-uc.a.run.app';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<Client>? _cachedClients;
  DateTime? _lastCacheUpdate;

  /// --- COLEÇÕES ---

  // Coleção pública: clientes
  CollectionReference<Map<String, dynamic>> getClientesCollection() {
    return _db.collection('clientes');
  }

  // FUNÇÃO HELPER
  CollectionReference<Map<String, dynamic>> getColecaoPorTipo(String tipo) {
    if (tipo == 'assistencia') {
      return _db.collection('assistencias');
    }
    return _db.collection('sinistros');
  }

  // Coleção pública: sinistros
  CollectionReference<Map<String, dynamic>> getSinistrosCollection() {
    return _db.collection('sinistros');
  }

    // ✅ ESTÁ AQUI: Coleção de tarefas de nível superior. Todas as tarefas devem ser salvas e lidas a partir daqui.
  CollectionReference<Map<String, dynamic>> getTasksCollection() {
    return _db.collection('tasks');
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

  // NOVA FUNÇÃO PARA POPUP DE PESQUISA DE CLIENTES
  Future<List<Client>> searchClients(String query) async {
    if (query.isEmpty) return [];
    
    final queryLower = query.toLowerCase();
    
    try {
      // Busca TODOS os clientes primeiro (sempre client-side)
      final todosClientesSnapshot = await getClientesCollection().get();
      final todosClientes = todosClientesSnapshot.docs.map((doc) {
        return Client.fromMap(doc.data() as Map<String, dynamic>)..id = doc.id;
      }).toList();

      // Filtra localmente por qualquer trecho do texto
      return todosClientes.where((client) {
        return client.nome.toLowerCase().contains(queryLower) ||
              client.cnpjCpf.toLowerCase().contains(queryLower) ||
              (client.email != null && client.email!.toLowerCase().contains(queryLower));
      }).toList();
      
    } catch (e) {
      print('Erro na busca de clientes: $e');
      return [];
    }
  }

  Future<void> updateClient(Client client, String userId) async { // Adicionado userId
    await getClientesCollection().doc(client.id).update(client.toMap());
  }

  /// --- SINISTROS ---

  Future<String> addClaim(Claim claim) async {
    final colecao = getColecaoPorTipo(claim.tipo);  // ← Use tipo!
    final docRef = await colecao.add(claim.toMap());
    return docRef.id;
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
    if (claim.id.isEmpty) {
      throw Exception('Claim ID não pode estar vazio');
    }
    
    final colecao = getColecaoPorTipo(claim.tipo);
    await colecao.doc(claim.id).update(claim.toMap());
  }

  Future<void> deleteClient(String clientId) async {
    try {
      await _db.collection('clientes').doc(clientId).delete();
    } catch (e) {
      rethrow; // Propaga o erro para ser tratado na tela
    }
  }

  // Excluir Sinistros
  Future<void> deleteClaim(String claimId, String numeroSinistro) async {
    try {
      DocumentSnapshot docSnapshot;
      CollectionReference colecao;

      final snapSinistro = await _db.collection('sinistros').doc(claimId).get();
      if (snapSinistro.exists) {
        docSnapshot = snapSinistro;
        colecao = _db.collection('sinistros');
      } else {
        final snapAssist = await _db.collection('assistencias').doc(claimId).get();
        docSnapshot = snapAssist;
        colecao = _db.collection('assistencias');
      }

      if (!docSnapshot.exists) return;

      final data = docSnapshot.data() as Map<String, dynamic>;
      await _deleteAllClaimFiles(numeroSinistro, data);
      await colecao.doc(claimId).delete();

    } catch (e) {
      print('Erro ao excluir sinistro: $e');
      rethrow;
    }
  }

  // ✅ Método para excluir todos os arquivos do sinistro no Storage
  Future<void> _deleteAllClaimFiles(String numeroSinistro, Map<String, dynamic> claimData) async {
    try {
      // Lista de todos os caminhos de arquivos para excluir
      final List<String> filePaths = [];

      // ✅ Fotos da ocorrência
      final fotosUrls = (claimData['fotos_urls'] as List<dynamic>?)?.cast<String>() ?? [];
      for (String url in fotosUrls) {
        final path = _extractFilePathFromUrl(url);
        if (path != null) filePaths.add(path);
      }

      // ✅ Arquivos/laudos
      final arquivosUrls = (claimData['arquivos_laudos_urls'] as List<dynamic>?)?.cast<String>() ?? [];
      for (String url in arquivosUrls) {
        final path = _extractFilePathFromUrl(url);
        if (path != null) filePaths.add(path);
      }

      // ✅ Documentos de terceiros
      final terceiros = (claimData['terceiros'] as List<dynamic>?) ?? [];
      for (var terceiro in terceiros) {
        final documentosTerceiro = (terceiro['documentos_urls'] as List<dynamic>?)?.cast<String>() ?? [];
        for (String url in documentosTerceiro) {
          final path = _extractFilePathFromUrl(url);
          if (path != null) filePaths.add(path);
        }
        
        final fotosTerceiro = (terceiro['fotos_urls'] as List<dynamic>?)?.cast<String>() ?? [];
        for (String url in fotosTerceiro) {
          final path = _extractFilePathFromUrl(url);
          if (path != null) filePaths.add(path);
        }
      }

      // ✅ Oficinas (documentos)
      final oficinas = (claimData['oficinas'] as List<dynamic>?) ?? [];
      for (var oficina in oficinas) {
        final documentosOficina = (oficina['documentos_urls'] as List<dynamic>?)?.cast<String>() ?? [];
        for (String url in documentosOficina) {
          final path = _extractFilePathFromUrl(url);
          if (path != null) filePaths.add(path);
        }
      }

      // ✅ Excluir todos os arquivos encontrados
      if (filePaths.isNotEmpty) {
        await _deleteFilesFromStorage(filePaths);
      }

    } catch (e) {
      print('Erro ao excluir arquivos do sinistro: $e');
      // Não lançar exceção aqui para não impedir a exclusão do documento
    }
  }

  /// Verifica se já existe cliente com este CNPJ/CPF (normalizado)
  // 🆕 Verificar se existe CNPJ/CPF duplicado
  // Funciona com clientes antigos (sem cnpj_cpf_normalizado) e novos
  Future<bool> verificarCnpjCpfDuplicado(
    String cnpjCpfNormalizado, {
    String? clienteIdExcluir,
  }) async {
    try {
      print('🔍 Verificando duplicata para: $cnpjCpfNormalizado');
      
      // Busca TODOS os clientes
      final snapshot = await getClientesCollection().get();

      for (var doc in snapshot.docs) {
        final clientData = doc.data();
        
        // Tenta primeiro o campo normalizado (clientes novos)
        var cnpjCpfNormalizadoArmazenado = clientData['cnpj_cpf_normalizado'] as String?;
        
        // Se não encontrou, normaliza o campo existente (clientes antigos)
        if (cnpjCpfNormalizadoArmazenado == null || cnpjCpfNormalizadoArmazenado.isEmpty) {
          final cnpjCpfArmazenado = clientData['cnpj_cpf'] as String?;
          cnpjCpfNormalizadoArmazenado = _normalizarCnpjCpf(cnpjCpfArmazenado ?? '');
        }
        
        // Compara
        if (cnpjCpfNormalizadoArmazenado == cnpjCpfNormalizado) {
          // Se estamos editando, ignora o cliente atual
          if (clienteIdExcluir != null && doc.id == clienteIdExcluir) {
            print('✅ Encontrou o cliente sendo editado, ignorando...');
            continue;
          }
          
          print('❌ Encontrado DUPLICADO: ${doc.id} com CNPJ/CPF: $cnpjCpfNormalizadoArmazenado');
          return true;
        }
      }
      
      print('✅ Nenhum duplicado encontrado');
      return false;
    } catch (e) {
      print('❌ ERRO ao verificar CNPJ/CPF duplicado: $e');
      return false;
    }
  }

  // 🆕 Helper: Normalizar CNPJ/CPF (remove símbolos)
  String _normalizarCnpjCpf(String valor) {
    if (valor.isEmpty) return '';
    return valor.replaceAll(RegExp(r'[^\d]'), '');
  }

  // ✅ Extrai o caminho do arquivo a partir da URL
  String? _extractFilePathFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      
      if (uri.host == 'storage.googleapis.com') {
        // Remove o nome do bucket do caminho
        final pathSegments = uri.pathSegments;
        if (pathSegments.length >= 2) {
          // Pula o primeiro segmento (nome do bucket) e junta o resto
          return pathSegments.sublist(1).join('/');
        }
      }
      
      // Para URLs antigas ou outros formatos, tenta extrair de outra forma
      return uri.path;
    } catch (e) {
      print('Erro ao extrair caminho da URL: $e');
      return null;
    }
  }

  // FUNÇÃO AUXILIAR PARA EXCLUIR ARQUIVOS EM CLAIM EDIT
  String _extractPathFromUrl(String url) {
    final uri = Uri.parse(url);

    final fullPath = uri.pathSegments
        .skipWhile((e) => e != 'o')
        .skip(1)
        .join('/');

    return Uri.decodeComponent(fullPath);
  }

  // DELETE BY URL
  Future<void> deleteFileByUrl(String url) async {
    final path = _extractPathFromUrl(url);
    await _deleteFilesFromStorage([path]);
  }

  // ✅ Função para excluir arquivos do Storage via Cloud Function
  Future<void> _deleteFilesFromStorage(List<String> filePaths) async {
    try {
      final response = await http.post(
        Uri.parse('https://us-central1-upgrade-seguros.cloudfunctions.net/deleteFiles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'filePaths': filePaths}),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao excluir arquivos: ${response.body}');
      }
    } catch (e) {
      print('Erro ao chamar Cloud Function para excluir arquivos: $e');
    }
  }

  Future<void> updateClaimStatus(
    String claimId,
    String newStatus,
    String userId,
    String userEmail,
    String nomeUsuarioLogado,
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
          'registrado_por': nomeUsuarioLogado,
        }
      ]),
    });
  }

  /// --- LISTA DE TAREFAS (REFATORADO) ---
  
  // ✅ NOVO: Retorna um stream de todas as tarefas da coleção de nível superior
  Stream<QuerySnapshot<Map<String, dynamic>>> getAllTasksStream() {
    return getTasksCollection().orderBy('prazo').snapshots();
  }
  
  // ✅ NOVO: Adiciona uma tarefa à coleção de nível superior
  Future<String> addTask(ClaimTask task) async {
    final doc = await getTasksCollection().add(task.toMap());
    return doc.id;
  }

  // ATUALIZA A TASK AUTOMATICAMENTE
  Future<void> updateTaskStatus(String taskId, String newStatus) async {
    await getTasksCollection().doc(taskId).update({
      'status': newStatus,
    });
  }

  // ✅ NOVO: Atualiza uma tarefa na coleção de nível superior
  Future<void> updateTask(ClaimTask task) async {
    await getTasksCollection().doc(task.id).update(task.toMap());
  }
  
  // ✅ NOVO: Exclui uma tarefa da coleção de nível superior
  Future<void> deleteTask(String taskId) async {
    await getTasksCollection().doc(taskId).delete();
  }

  // FUNÇÃO PARA ARMAZENAR O NÚMERO DO SINISTRO
  Future<Claim?> getClaimByNumeroSinistro(String numeroSinistro) async {
    try {
      // Tenta em sinistros primeiro
      final sinistroSnap = await _db
          .collection('sinistros')
          .where('numero_sinistro', isEqualTo: numeroSinistro)
          .limit(1)
          .get();

      if (sinistroSnap.docs.isNotEmpty) {
        final doc = sinistroSnap.docs.first;
        final claim = Claim.fromMap(doc.data());
        claim.id = doc.id;
        return claim;
      }

      // Tenta em assistencias
      final assistSnap = await _db
          .collection('assistencias')
          .where('numero_sinistro', isEqualTo: numeroSinistro)
          .limit(1)
          .get();

      if (assistSnap.docs.isNotEmpty) {
        final doc = assistSnap.docs.first;
        final claim = Claim.fromMap(doc.data());
        claim.id = doc.id;
        return claim;
      }

      return null;
    } catch (e) {
      debugPrint('Erro ao buscar atendimento por número: $e');
      return null;
    }
  }
  
  // FUNÇÃO PARA FOTOS DE VEÍCULOS SEGURADOS
  Future<List<String>> uploadSinistroFotos(String numeroSinistro, List<XFile> fotos) async {
    if (fotos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${fotos.length} fotos para o sinistro $numeroSinistro através da Cloud Function.');

    List<String> downloadUrls = [];
    for (var i = 0; i < fotos.length; i++) {
      try {
        final bytes = await fotos[i].readAsBytes();
        final nome = fotos[i].name
          .replaceAll(RegExp(r'[#?&%\s]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
        
        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': 'sinistros/$numeroSinistro/fotos/$nome', // Caminho completo no Storage
        };

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload da foto $i concluído, URL: $url');
        } else {
          throw Exception('Falha no upload: ${response.statusCode}, Erro: ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ ERRO ao fazer upload da foto $i: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO PARA ARQUIVOS DE VEÍCULOS SEGURADOS
  Future<List<String>> uploadArquivosLaudos(String numeroSinistro, List<PlatformFile> arquivos) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} arquivos de laudo para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var i = 0; i < arquivos.length; i++) {
      try {
        final file = arquivos[i];
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();

        String nome = file.name.trim()
          .replaceAll(RegExp(r'[#?&%\s]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

        if (nome.isEmpty || nome.length < 3) {
          debugPrint('⚠️ Nome do arquivo inválido. Gerando nome padrão.');
          nome = 'documento_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }

        final String filePath = 'sinistros/$numeroSinistro/laudos/$nome';

        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': filePath,
        };

        if (kDebugMode) {
          debugPrint('📤 Enviando body para a Cloud Function:');
          debugPrint('  - fileName: ${requestBody['fileName']}');
          debugPrint('  - filePath: ${requestBody['filePath']}');
          debugPrint('  - file size (base64): ${requestBody['file'].length} bytes');
        }

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload do laudo concluído, URL: $url');
        } else {
          throw Exception('Falha no upload do laudo: ${response.statusCode} - ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload do laudo: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de laudos concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO PARA ARQUIVOS DE RTERCEIROS - uploadArquivosTerceiros
  Future<List<String>> uploadArquivosTerceiros(String numeroSinistro, List<PlatformFile> arquivos) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} arquivos de terceiro para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var i = 0; i < arquivos.length; i++) {
      try {
        final file = arquivos[i];
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();

        String nome = file.name.trim();
        if (nome.isEmpty || nome.length < 3) {
          debugPrint('⚠️ Nome do arquivo inválido. Gerando nome padrão.');
          nome = 'documento_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }

        // A única diferença é o caminho: 'terceiros' em vez de 'laudos'
        final String filePath = 'sinistros/$numeroSinistro/terceiros/$nome';

        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': filePath,
        };

        if (kDebugMode) {
          debugPrint('📤 Enviando body para a Cloud Function:');
          debugPrint('  - fileName: ${requestBody['fileName']}');
          debugPrint('  - filePath: ${requestBody['filePath']}');
          debugPrint('  - file size (base64): ${requestBody['file'].length} bytes');
        }

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload do documento de terceiro concluído, URL: $url');
        } else {
          throw Exception('Falha no upload do documento de terceiro: ${response.statusCode} - ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload do documento de terceiro: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de documentos de terceiro concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO PARA FOTOS DE TERCEIROS - uploadThirdPartyPhotos
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
        final nome = '${const Uuid().v4()}.jpg';
        
        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': 'sinistros/$claimId/terceiros/$thirdPartyId/$nome',
          'contentType': 'image/jpeg',
        };

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload da foto de terceiro concluído, URL: $url');
        } else {
          throw Exception('Falha no upload da foto de terceiro: ${response.statusCode}, Erro: ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ ERRO ao fazer upload da foto de terceiro: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de fotos de terceiros concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO ATUALIZADA - uploadTransportFotos
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

        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': 'sinistros/$numeroSinistro/transporte/fotos/$nome',
          'contentType': 'image/jpeg',
        };

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload da foto de transporte concluído, URL: $url');
        } else {
          throw Exception('Falha no upload da foto de transporte: ${response.statusCode}, Erro: ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload de foto de transporte: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de fotos de transporte concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO ATUALIZADA - uploadTransportDocuments
  Future<List<String>> uploadTransportDocuments(
    String numeroSinistro,
    List<XFile> arquivos,
  ) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} documentos de transporte para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var arquivo in arquivos) {
      try {
        // ✅ 1. Lê os bytes
        final Uint8List bytes = await arquivo.readAsBytes();

        // ✅ 2. Extrai o nome original ou gera um seguro
        String originalName = arquivo.name;
        if (originalName.isEmpty) {
          // Se não houver nome, tenta extrair do path
          originalName = arquivo.path.split('/').last.split('\\').last;
        }

        // ✅ 3. Determina a extensão
        String extension = '';
        if (originalName.contains('.')) {
          extension = originalName.split('.').last.toLowerCase();
        } else {
          // Se não tiver extensão, tenta inferir pelo mimeType
          if (arquivo.mimeType?.startsWith('application/pdf') == true) {
            extension = 'pdf';
          } else if (arquivo.mimeType?.startsWith('application/msword') == true) {
            extension = 'doc';
          } else if (arquivo.mimeType?.startsWith('application/vnd.openxmlformats-officedocument') == true) {
            extension = 'docx';
          } else {
            extension = 'bin'; // genérico
          }
        }

        // ✅ 4. Gera um nome único com extensão correta
        final String fileName = '${const Uuid().v4()}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        final String filePath = 'sinistros/$numeroSinistro/transporte/documentos/$fileName';

        // ✅ 5. Define o contentType com base na extensão
        String contentType = 'application/octet-stream';
        switch (extension) {
          case 'pdf':
            contentType = 'application/pdf';
            break;
          case 'doc':
            contentType = 'application/msword';
            break;
          case 'docx':
            contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
            break;
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'png':
            contentType = 'image/png';
            break;
        }

        // ✅ 6. Prepara o corpo da requisição
        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': fileName,
          'filePath': filePath,
          'contentType': contentType,
        };

        debugPrint('📤 Enviando documento: $fileName, $contentType, tamanho: ${bytes.length} bytes');

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload do documento de transporte concluído, URL: $url');
        } else {
          throw Exception('Falha no upload do documento de transporte: ${response.statusCode}, Erro: ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload de documento de transporte: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de documentos de transporte concluídos. Total de URLs: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO NOVA - uploadThirdPartyDocuments
  Future<List<String>> uploadThirdPartyDocuments(
    String numeroSinistro,
    String terceiroId,
    List<XFile> arquivos,
  ) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} documentos de terceiro ($terceiroId) para o sinistro $numeroSinistro');

    List<String> downloadUrls = [];
    for (var arquivo in arquivos) {
      try {
        // ✅ 1. Lê os bytes
        final Uint8List bytes = await arquivo.readAsBytes();

        // ✅ 2. Extrai o nome original do arquivo (igual à uploadArquivosLaudos)
        String nome = arquivo.name.trim();
        if (nome.isEmpty || nome.length < 3) {
          debugPrint('⚠️ Nome do arquivo inválido. Gerando nome padrão.');
          nome = 'documento_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }

        // ✅ 3. Define o caminho do arquivo mantendo o nome original
        final String filePath = 'sinistros/$numeroSinistro/terceiros/$terceiroId/documentos/$nome';

        // ✅ 4. Prepara o corpo da requisição (igual à uploadArquivosLaudos)
        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': filePath,
        };

        if (kDebugMode) {
          debugPrint('📤 Enviando documento de terceiro:');
          debugPrint('  - fileName: ${requestBody['fileName']}');
          debugPrint('  - filePath: ${requestBody['filePath']}');
          debugPrint('  - file size (base64): ${requestBody['file'].length} bytes');
        }

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload do documento de terceiro concluído, URL: $url');
        } else {
          throw Exception('Falha no upload do documento de terceiro: ${response.statusCode} - ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload de documento de terceiro: $e\n$s');
        rethrow; // Mantém o comportamento de parar em caso de erro
      }
    }

    debugPrint('✅ Todos os uploads de documentos de terceiro concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  // FUNÇÃO PARA UPLOAD DE CRLV DE BENS SEGURADOS
  Future<List<String>> uploadCRLV(
    String clientId,
    String apoliceId,
    String bemId,
    List<PlatformFile> arquivos,
  ) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} CRLV(s) para bem $bemId da apólice $apoliceId');

    List<String> downloadUrls = [];
    for (var i = 0; i < arquivos.length; i++) {
      try {
        final file = arquivos[i];
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();

        String nome = file.name.trim()
          .replaceAll(RegExp(r'[#?&%\s]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

        if (nome.isEmpty || nome.length < 3) {
          debugPrint('⚠️ Nome do arquivo inválido. Gerando nome padrão.');
          nome = 'crlv_${DateTime.now().millisecondsSinceEpoch}.pdf';
        }

        // Caminho: clientes/{clientId}/apolices/{apoliceId}/bens/{bemId}/crlv/{fileName}
        final String filePath = 'clientes/$clientId/apolices/$apoliceId/bens/$bemId/crlv/$nome';

        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': filePath,
        };

        if (kDebugMode) {
          debugPrint('📤 Enviando CRLV para Cloud Function:');
          debugPrint('  - fileName: ${requestBody['fileName']}');
          debugPrint('  - filePath: ${requestBody['filePath']}');
          debugPrint('  - file size (base64): ${requestBody['file'].length} bytes');
        }

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload do CRLV concluído, URL: $url');
        } else {
          throw Exception('Falha no upload do CRLV: ${response.statusCode} - ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload do CRLV: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de CRLV concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  // NOVO MÉTODO PARA DOCUMENTOS DE BENS (Residencial, Vida, etc.)
  Future<List<String>> uploadDocumentosBem(
    String clientId,
    String apoliceId,
    String bemId,
    List<PlatformFile> arquivos,
  ) async {
    if (arquivos.isEmpty) return [];

    debugPrint('☁️ Iniciando upload de ${arquivos.length} documento(s) para bem $bemId da apólice $apoliceId');

    List<String> downloadUrls = [];
    for (var i = 0; i < arquivos.length; i++) {
      try {
        final file = arquivos[i];
        final bytes = file.bytes ?? await File(file.path!).readAsBytes();

        String nome = file.name.trim()
            .replaceAll(RegExp(r'[#?&%\s]'), '_')
            .replaceAll(RegExp(r'_+'), '_');

        if (nome.isEmpty || nome.length < 3) {
          debugPrint('⚠️ Nome do arquivo inválido. Gerando nome padrão.');
          nome = 'documento_${DateTime.now().millisecondsSinceEpoch}.${file.extension ?? "bin"}';
        }

        // Caminho: clientes/{clientId}/apolices/{apoliceId}/bens/{bemId}/documentos/{fileName}
        final String filePath = 'clientes/$clientId/apolices/$apoliceId/bens/$bemId/documentos/$nome';

        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': filePath,
        };

        if (kDebugMode) {
          debugPrint('📤 Enviando documento para Cloud Function:');
          debugPrint('  - fileName: ${requestBody['fileName']}');
          debugPrint('  - filePath: ${requestBody['filePath']}');
          debugPrint('  - file size (base64): ${requestBody['file'].length} bytes');
        }

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Upload do documento concluído, URL: $url');
        } else {
          throw Exception('Falha no upload do documento: ${response.statusCode} - ${response.body}');
        }
      } catch (e, s) {
        debugPrint('❌ Erro ao fazer upload do documento: $e\n$s');
        rethrow;
      }
    }

    debugPrint('✅ Todos os uploads de documentos concluídos. Total: ${downloadUrls.length}');
    return downloadUrls;
  }

  /// Retorna apenas SINISTROS (filtra por tipo)
  Future<List<Claim>> getClaimsOfType(String tipoAtendimento) async {
    try {
      final query = _db
          .collection('assistencias')
          .where('tipo', isEqualTo: tipoAtendimento)
          .orderBy('data_abertura', descending: true);
  
      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Claim.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Erro ao buscar claims por tipo: $e');
      rethrow;
    }
  }
  
  /// Retorna apenas SINISTROS
  Future<List<Claim>> getAllSinistros() async {
    return getClaimsOfType('sinistro');
  }
  
  /// Retorna apenas ASSISTÊNCIAS
  Future<List<Claim>> getAllAssistencias() async {
    return getClaimsOfType('assistencia');
  }
  
  /// Retorna ASSISTÊNCIAS com SLA próximo de exceder ou já excedido
  Stream<List<Claim>> streamAssistWithAlerts() {
    try {
      return _db
          .collection('assistencias')
          .where('tipo', isEqualTo: 'assistencia')
          .where('sla_excedido', isEqualTo: false)
          .orderBy('sla_previsto')
          .snapshots()
          .map((snapshot) => snapshot.docs.map((doc) => Claim.fromFirestore(doc)).toList());
    } catch (e) {
      debugPrint('Erro ao criar stream de assistências com alertas: $e');
      return Stream.value([]);
    }
  }
  
  /// Atualiza o flag sla_excedido de uma assistência
  Future<void> updateAssistSlaExceeded(String claimId, bool excedido) async {
    try {
      await _db.collection('assistencias').doc(claimId).update({
        'sla_excedido': excedido,
        if (excedido)
          'sla_alertado_em': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Erro ao atualizar SLA excedido: $e');
      rethrow;
    }
  }
  
  /// Retorna configurações de SLA
  Future<List<AssistSlaConfig>> getSlaConfigs() async {
    try {
      final snapshot = await _db.collection('sla_configs').get();
      return snapshot.docs
          .map((doc) => AssistSlaConfig.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar SLA configs: $e');
      return [];
    }
  }
  
  /// Retorna configuração de SLA para um tipo específico
  Future<AssistSlaConfig?> getSlaConfigForType(String tipoAssistencia) async {
    try {
      final query = await _db
          .collection('sla_configs')
          .where('tipo_assistencia', isEqualTo: tipoAssistencia)
          .limit(1)
          .get();
  
      if (query.docs.isNotEmpty) {
        return AssistSlaConfig.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Erro ao buscar SLA config para tipo: $e');
      return null;
    }
  }
  
  /// Salva ou atualiza configuração de SLA
  Future<void> setSlaConfig(AssistSlaConfig config) async {
    try {
      if (config.id.isEmpty) {
        // Novo documento
        await _db.collection('sla_configs').doc(config.tipoAssistencia).set(
              config.toMap(),
            );
      } else {
        // Atualizar documento existente
        await _db
            .collection('sla_configs')
            .doc(config.id)
            .update(config.toMap());
      }
    } catch (e) {
      debugPrint('Erro ao salvar SLA config: $e');
      rethrow;
    }
  }
  
  /// Deleta configuração de SLA
  Future<void> deleteSlaConfig(String configId) async {
    try {
      await _db.collection('sla_configs').doc(configId).delete();
    } catch (e) {
      debugPrint('Erro ao deletar SLA config: $e');
      rethrow;
    }
  }

  Future<void> _initializeSlaConfigs() async {
    try {
      final existing = await _db.collection('sla_configs').get();
      if (existing.docs.isEmpty) {
        // Criar configurações padrão
        for (final config in AssistSlaDefaults.getAll()) {
          await setSlaConfig(config);
        }
        debugPrint('✅ Configurações de SLA inicializadas');
      }
    } catch (e) {
      debugPrint('Erro ao inicializar SLA configs: $e');
    }
  }

  // Adicionar oficina ao sinistro
  Future<void> addOficinaToClaim(String claimId, Workshop oficina) async {
    try {
      await _db.collection('sinistros').doc(claimId).update({
        'oficinas': FieldValue.arrayUnion([oficina.toMap()])
      });
    } catch (e) {
      throw Exception('Erro ao adicionar oficina: $e');
    }
  }

  // Remover oficina do sinistro
  Future<void> removeOficinaFromClaim(String claimId, Workshop oficina) async {
    try {
      await _db.collection('sinistros').doc(claimId).update({
        'oficinas': FieldValue.arrayRemove([oficina.toMap()])
      });
    } catch (e) {
      throw Exception('Erro ao remover oficina: $e');
    }
  }

  // Atualizar oficina no sinistro
  Future<void> updateOficinaInClaim(String claimId, Workshop oficina) async {
    try {
      final doc = await _db.collection('sinistros').doc(claimId).get();
      if (doc.exists) {
        final List<dynamic> oficinasData = doc.data()?['oficinas'] ?? [];
        final List<Workshop> oficinas = oficinasData
            .map((data) => Workshop.fromMap(data))
            .where((o) => o.id != oficina.id)
            .toList();
        
        oficinas.add(oficina);
        
        await _db.collection('sinistros').doc(claimId).update({
          'oficinas': oficinas.map((o) => o.toMap()).toList()
        });
      }
    } catch (e) {
      throw Exception('Erro ao atualizar oficina: $e');
    }
  }

  // Fórmula para avaliar data de vencimento das apólices
  Future<List<Client>> getAllClients() async {
    final snapshot = await _db.collection('clientes').get();
    return snapshot.docs
        .map((doc) => Client.fromMap(doc.data())..id = doc.id)
        .toList();
  }

  // Pesquisa por Nome
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
  Future<void> addAnotacao(String claimId, String texto, String nomeAutor) async {
    final anotacao = {
      'texto': texto,
      'data': Timestamp.now(),
      'autor': nomeAutor,
      'responsavelEmail': nomeAutor,
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
  // Procura em assistências primeiro
    var doc = await _db.collection('assistencias').doc(claimId).get();
    
    if (!doc.exists) {
      // Se não encontrar, procura em sinistros
      doc = await _db.collection('sinistros').doc(claimId).get();
    }
    
    if (!doc.exists) return null;

    final data = doc.data()!;
    final claim = Claim.fromMap(data);
    
    claim.id = doc.id; // 🔥 CRÍTICO! Você estava certo!

    return claim;
  }

  // Obetém todos os sinistros e assistências
  Future<List<Claim>> getAllClaims() async {
    try {
      // Buscar sinistros
      final sinistrosSnapshot = await _db.collection('sinistros').get();
      final sinistros = sinistrosSnapshot.docs.map((doc) {
        final claim = Claim.fromMap(doc.data());
        claim.id = doc.id;
        return claim;
      }).toList();

      // Buscar assistências
      final assistenciasSnapshot = await _db.collection('assistencias').get();
      final assistencias = assistenciasSnapshot.docs.map((doc) {
        final claim = Claim.fromMap(doc.data());
        claim.id = doc.id;
        return claim;
      }).toList();

      // Combinar (assistências primeiro, depois sinistros)
      final todos = [...assistencias, ...sinistros];
      todos.sort((a, b) => b.dataAbertura.compareTo(a.dataAbertura));
      
      return todos;
    } catch (e) {
      print('Erro ao buscar claims: $e');
      return [];
    }
  }

// Busca de todas as tarefas
  Future<List<Map<String, dynamic>>> getAllTasksWithClaims() async {
    final tasksSnapshot = await getTasksCollection().get();
    List<Map<String, dynamic>> allTasks = [];

    final Set<String> claimIds = tasksSnapshot.docs
        .map((doc) => doc.data()['claimId'] as String)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (claimIds.isEmpty) return [];

    final claimIdsList = claimIds.toList();
    final Map<String, Map<String, dynamic>> claimsData = {};

    // ✅ Dividir em chunks de 30 (limite do Firestore whereIn)
    const chunkSize = 30;
    for (int i = 0; i < claimIdsList.length; i += chunkSize) {
      final end = (i + chunkSize > claimIdsList.length)
          ? claimIdsList.length
          : i + chunkSize;
      final chunk = claimIdsList.sublist(i, end);

      // Busca nas duas coleções em paralelo
      final results = await Future.wait([
        getSinistrosCollection()
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
        _db.collection('assistencias')
            .where(FieldPath.documentId, whereIn: chunk)
            .get(),
      ]);

      // Adiciona aos dados
      for (var doc in results[0].docs) {
        claimsData[doc.id] = doc.data();
      }
      for (var doc in results[1].docs) {
        claimsData[doc.id] = doc.data();
      }
    }

    for (var taskDoc in tasksSnapshot.docs) {
      final data = taskDoc.data();
      final claimId = data['claimId'] as String?;
      if (claimId == null) continue;
      final claimData = claimsData[claimId];
      if (claimData == null) continue;

      allTasks.add({
        'taskId': taskDoc.id,
        'descricao': data['descricao'],
        'status': data['status'],
        'prazo': (data['prazo'] as Timestamp).toDate(),
        'criadoEm': (data['criado_em'] as Timestamp?)?.toDate(),
        'claimId': claimId,
        'responsavelEmail': data['responsavelEmail'] ?? '',
        'clientNome': claimData['client_nome'] ?? '',
        'clientCnpjCpf': claimData['client_cnpj_cpf'] ?? '',
        'numeroSinistro': claimData['numero_sinistro'] ?? '',
        'tipo': claimData['tipo'] ?? 'sinistro',  // ← para navegar certo
      });
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

  // --- OBTER NOME DO USUÁRIO ---
  Future<List<QueryDocumentSnapshot>> getFuncionarios() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs;
  }

  // CARREGAR FOTOS DOS VEÍCULOS DO SEGURADO
  Future<List<String>> uploadVehiclePhotos(
    String clientId,
    String vehiclePlaca,
    List<XFile> fotos,
  ) async {
    if (fotos.isEmpty) return [];
    List<String> downloadUrls = [];

    for (final foto in fotos) {
      try {
        final bytes = await foto.readAsBytes();
        final nome = '${const Uuid().v4()}.jpg';
        final String filePath = 'clientes/$clientId/veiculos/$vehiclePlaca/$nome';

        final Map<String, dynamic> requestBody = {
          'file': base64Encode(bytes),
          'fileName': nome,
          'filePath': filePath,
          'contentType': 'image/jpeg',
        };

        final http.Response response = await http.post(
          Uri.parse(_cloudFunctionUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          final String url = responseData['url'];
          downloadUrls.add(url);
          debugPrint('✅ Foto do veículo enviada: $url');
        } else {
          throw Exception('Falha no upload: ${response.statusCode}, ${response.body}');
        }
      } catch (e) {
        debugPrint('❌ Erro ao fazer upload da foto do veículo: $e');
        rethrow;
      }
    }

    return downloadUrls;
  }

  // ATUALIZAR VEÍCULOS DOS SEGURADOS
  Future<void> updateClientVehicle(String clientId, String vehiclePlaca, List<String> fotosUrls) async {
    try {
      final clientDoc = await getClientesCollection().doc(clientId).get();
      if (!clientDoc.exists) return;

      final data = clientDoc.data()!;
      final List<dynamic> veiculos = data['veiculosSegurados'] ?? [];

      for (var i = 0; i < veiculos.length; i++) {
        final veiculo = veiculos[i] as Map<String, dynamic>;
        if (veiculo['placa'] == vehiclePlaca) {
          veiculos[i] = {
            ...veiculo,
            'fotosUrls': fotosUrls,
          };
          break;
        }
      }

      await getClientesCollection().doc(clientId).update({'veiculosSegurados': veiculos});
    } catch (e) {
      debugPrint('Erro ao atualizar fotos do veículo: $e');
      rethrow;
    }
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

  // Atualiza Status do Sinistro
  Future<void> addStatusHistory(
    String claimId,
    String status,
    String userId,
    String? userEmail, {
    String nomeUsuario = 'Desconhecido', // ✨ ADICIONE PARÂMETRO
  }) async {
    final docRef = getSinistrosCollection().doc(claimId);
  
    final historyEntry = {
      'status': status,
      'data': Timestamp.now(),
      'responsavelId': userId,
      'responsavelEmail': userEmail ?? 'desconhecido@dominio.com',
      'registrado_por': nomeUsuario, // ✨ SALVE O NOME!
    };
  
    await docRef.update({
      'historico_status': FieldValue.arrayUnion([historyEntry]),
    });
  }

  /// Coleção de corretoras
  CollectionReference<Map<String, dynamic>> getCorretorasCollection() {
    return _db.collection('corretoras');
  }
 
  /// Busca corretora por ID
  Future<Map<String, dynamic>?> getCorretoraById(String corretoraId) async {
    try {
      final doc = await getCorretorasCollection().doc(corretoraId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Erro ao buscar corretora: $e');
      return null;
    }
  }
 
  /// Salva/atualiza dados da corretora
  Future<void> saveCorretora({
    required String corretoraId,
    required String nome,
    required String telefone,
    required String email,
    String? cnpj,
    String? endereco,
    String? logo,
  }) async {
    try {
      await getCorretorasCollection().doc(corretoraId).set({
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'cnpj': cnpj,
        'endereco': endereco,
        'logo': logo,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅ Corretora atualizada: $corretoraId');
    } catch (e) {
      debugPrint('❌ Erro ao salvar corretora: $e');
      rethrow;
    }
  }
 
  /// Atualiza apenas nome, telefone e email da corretora
  Future<void> updateCorretoraContactInfo({
    required String corretoraId,
    required String nome,
    required String telefone,
    required String email,
  }) async {
    try {
      await getCorretorasCollection().doc(corretoraId).update({
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Dados de contato da corretora atualizados');
    } catch (e) {
      debugPrint('❌ Erro ao atualizar contato da corretora: $e');
      rethrow;
    }
  }
 
  /// Cria uma nova corretora (para onboarding de novo cliente SaaS)
  Future<String> createCorretora({
    required String nome,
    required String telefone,
    required String email,
    String? cnpj,
    String? endereco,
  }) async {
    try {
      final docRef = await getCorretorasCollection().add({
        'nome': nome,
        'telefone': telefone,
        'email': email,
        'cnpj': cnpj,
        'endereco': endereco,
        'ativa': true,
        'dataCriacao': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Nova corretora criada: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Erro ao criar corretora: $e');
      rethrow;
    }
  }

}