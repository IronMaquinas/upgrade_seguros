// lib/services/video_service.dart
//
// Etapa 12: envio e exclusão dos vídeos do sinistro.
//
// Por que não usa a Cloud Function `uploadFile` (como fotos e documentos)?
// Ela recebe o arquivo em base64 dentro de uma requisição HTTP, que tem limite
// de ~10 MB (e o base64 aumenta o arquivo em 33%): vídeo passaria de 7 MB e
// falharia. Aqui o envio vai DIRETO para o Firebase Storage pelo SDK (com
// login, retomável e com progresso). As regras do Storage (`storage.rules`)
// conferem no servidor: só vídeo, só logado, até 100 MB (teto de qualquer plano).
//
// Depois do envio, a Cloud Function `converterVideo` converte para MP4 720p no
// mesmo caminho — o link (com token) gravado no sinistro continua valendo.

import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb, Uint8List;

import '../utils/videos.dart';

/// Vídeo escolhido no aparelho, ainda não enviado.
class VideoSelecionado {
  final String nome;
  final int tamanhoBytes;
  final Uint8List? bytes; // web
  final String? caminhoLocal; // celular/desktop
  const VideoSelecionado({required this.nome, required this.tamanhoBytes, this.bytes, this.caminhoLocal});
}

class VideoService {
  final FirebaseStorage _storage;
  // Etapa 12: bucket explícito (ver Videos.bucket).
  VideoService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instanceFor(bucket: 'gs://${Videos.bucket}');

  /// Envia um vídeo e devolve o registro para gravar no sinistro.
  /// [aoProgredir] recebe de 0.0 a 1.0.
  Future<VideoAnexo> enviar({
    required String numeroSinistro,
    required VideoSelecionado video,
    required String enviadoPor,
    void Function(double progresso)? aoProgredir,
  }) async {
    final agora = DateTime.now();
    final caminho = Videos.caminho(numeroSinistro, video.nome, agora);
    final ref = _storage.ref(caminho);
    final metadados = SettableMetadata(
      contentType: Videos.contentType(video.nome),
      customMetadata: {
        'sinistro': numeroSinistro,
        'nomeOriginal': video.nome,
        'tamanhoOriginal': '${video.tamanhoBytes}',
        'enviadoPor': enviadoPor,
      },
    );

    final UploadTask tarefa;
    if (video.bytes != null) {
      tarefa = ref.putData(video.bytes!, metadados);
    } else if (!kIsWeb && video.caminhoLocal != null) {
      tarefa = ref.putFile(File(video.caminhoLocal!), metadados);
    } else {
      throw Exception('Não consegui ler o arquivo ${video.nome}.');
    }

    final assinatura = tarefa.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) aoProgredir?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await tarefa;
    } finally {
      await assinatura.cancel();
    }
    aoProgredir?.call(1);

    return VideoAnexo(
      url: await ref.getDownloadURL(),
      caminho: caminho,
      nome: video.nome,
      tamanhoBytes: video.tamanhoBytes,
      enviadoEm: agora,
      enviadoPor: enviadoPor,
    );
  }

  /// Apaga o arquivo do Storage (se ainda existir).
  Future<void> excluirArquivo(VideoAnexo video) async {
    if (video.caminho.isEmpty) return;
    try {
      await _storage.ref(video.caminho).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }

  /// No detalhe do sinistro: grava/remove direto no documento (sem depender do
  /// "Salvar" da edição), para não deixar vídeo órfão no Storage.
  Future<void> adicionarNoSinistro(DocumentReference<Map<String, dynamic>> doc, VideoAnexo video) =>
      doc.update({'videos': FieldValue.arrayUnion([video.toMap()])});

  Future<void> removerDoSinistro(DocumentReference<Map<String, dynamic>> doc, VideoAnexo video) async {
    await doc.update({'videos': FieldValue.arrayRemove([video.toMap()])});
    await excluirArquivo(video);
  }
}
