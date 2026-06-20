// storage_services.dart

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Gera um caminho único para cada foto/anexo
  Future<String> uploadImage(XFile image, String folderPath) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('$folderPath/$fileName');
      await ref.putFile(File(image.path));
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Erro ao fazer upload da imagem: $e');
    }
  }

  // Faz upload de múltiplas imagens
  Future<List<String>> uploadImages(List<XFile> images, String folderPath) async {
    final List<String> urls = [];
    for (var image in images) {
      final url = await uploadImage(image, folderPath);
      urls.add(url);
    }
    return urls;
  }

  // Faz upload de documentos/laudos (PDF, DOCX, etc.)
  Future<String> uploadDocument(File file, String folderPath, String fileName) async {
    try {
      final ref = _storage.ref().child('$folderPath/$fileName');
      await ref.putFile(file);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Erro ao fazer upload do documento: $e');
    }
  }

  // Baixa uma imagem pelo caminho
  Future<String> getDownloadUrl(String path) async {
    try {
      final ref = _storage.ref().child(path);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Erro ao obter URL de download: $e');
    }
  }

  // Deleta um arquivo do storage
  Future<void> deleteFile(String filePath) async {
    try {
      final ref = _storage.ref().child(filePath);
      await ref.delete();
    } catch (e) {
      throw Exception('Erro ao deletar arquivo: $e');
    }
  }

  // Retorna uma lista de URLs de todas as fotos em um diretório
  Future<List<String>> getFilesInFolder(String folderPath) async {
    try {
      final listResult = await _storage.ref().child(folderPath).listAll();
      final urls = <String>[];
      for (var item in listResult.items) {
        final url = await item.getDownloadURL();
        urls.add(url);
      }
      return urls;
    } catch (e) {
      throw Exception('Erro ao listar arquivos na pasta: $e');
    }
  }
}