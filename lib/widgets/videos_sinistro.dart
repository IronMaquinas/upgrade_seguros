// lib/widgets/videos_sinistro.dart
//
// Etapa 12: vídeos do sinistro — escolher, conferir (tocar sem sair da tela),
// enviar com progresso e mostrar no detalhe.
//  • escolherVideos(...)        → abre o seletor e aplica os limites.
//  • mostrarPlayerVideo(...)    → janela com o vídeo tocando (play/pausa, tempo, som).
//  • PainelVideosAbertura       → bloco "Vídeos do Sinistro" na abertura (planilha).
//  • GaleriaVideosSinistro      → bloco "Vídeos" no detalhe do sinistro.
// Regras (formatos, limites, caminho) em lib/utils/videos.dart; envio em
// lib/services/video_service.dart.

import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

import '../services/video_service.dart';
import '../utils/videos.dart';

const _corVideos = Color(0xFF00695C);

// ── Seletor ─────────────────────────────────────────────────────────────────

Future<List<VideoSelecionado>> escolherVideos(
  BuildContext context, {
  required LimitesVideo limites,
  required int jaExistentes,
}) async {
  if (jaExistentes >= limites.maxPorSinistro) {
    _avisar(context, ['Este sinistro já tem o máximo de ${limites.maxPorSinistro} vídeos.']);
    return const [];
  }
  final resultado = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: kIsWeb,
    type: FileType.custom,
    allowedExtensions: Videos.extensoes,
  );
  if (resultado == null || resultado.files.isEmpty) return const [];

  final r = Videos.validar<PlatformFile>(
    resultado.files,
    nome: (f) => f.name,
    bytes: (f) => f.size,
    jaExistentes: jaExistentes,
    limites: limites,
  );
  if (r.recusas.isNotEmpty && context.mounted) _avisar(context, r.recusas);
  return [
    for (final f in r.aceitos)
      VideoSelecionado(nome: f.name, tamanhoBytes: f.size, bytes: f.bytes, caminhoLocal: kIsWeb ? null : f.path),
  ];
}

void _avisar(BuildContext context, List<String> mensagens) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Alguns vídeos não foram adicionados'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final m in mensagens) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $m'))],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
    ),
  );
}

// ── Player ──────────────────────────────────────────────────────────────────

/// Toca o vídeo numa janela sobre a tela atual. Passe [url] (já enviado) ou
/// [local] (escolhido, ainda não enviado — para conferir antes de salvar).
Future<void> mostrarPlayerVideo(BuildContext context, {String? url, VideoSelecionado? local, required String nome}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PlayerDialog(url: url, local: local, nome: nome),
  );
}

class _PlayerDialog extends StatefulWidget {
  final String? url;
  final VideoSelecionado? local;
  final String nome;
  const _PlayerDialog({this.url, this.local, required this.nome});

  @override
  State<_PlayerDialog> createState() => _PlayerDialogState();
}

class _PlayerDialogState extends State<_PlayerDialog> {
  VideoPlayerController? _c;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      final VideoPlayerController c;
      final local = widget.local;
      if (widget.url != null) {
        c = VideoPlayerController.networkUrl(Uri.parse(widget.url!));
      } else if (local != null && local.bytes != null && kIsWeb) {
        // No navegador, os bytes viram um endereço "blob:" temporário.
        final blob = XFile.fromData(local.bytes!, mimeType: Videos.contentType(local.nome), name: local.nome);
        c = VideoPlayerController.networkUrl(Uri.parse(blob.path));
      } else if (local != null && local.caminhoLocal != null && !kIsWeb) {
        c = VideoPlayerController.file(File(local.caminhoLocal!));
      } else {
        throw Exception('arquivo indisponível');
      }
      _c = c;
      await c.initialize();
      c.addListener(_atualizar);
      await c.play();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _erro = Videos.podeNaoTocarNoNavegador(widget.nome)
            ? 'Este formato (${Videos.extensao(widget.nome).toUpperCase()}, comum no iPhone) não toca neste navegador '
                'antes da conversão. Depois de salvo, o sistema converte para MP4 em alguns minutos e ele passa a tocar.'
            : 'Não foi possível reproduzir este vídeo ($e).');
      }
    }
  }

  void _atualizar() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_atualizar);
    _c?.dispose();
    super.dispose();
  }

  String _tempo(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final pronto = c != null && c.value.isInitialized;
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Barra de título
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
              child: Row(
                children: [
                  const Icon(Icons.movie_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.nome,
                        style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                  IconButton(
                    tooltip: 'Fechar',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _erro != null
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_erro!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                      )
                    : !pronto
                        ? const SizedBox(
                            height: 240, child: Center(child: CircularProgressIndicator(color: Colors.white)))
                        : AspectRatio(
                            aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
                            child: GestureDetector(
                              onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                              child: VideoPlayer(c),
                            ),
                          ),
              ),
            ),
            if (pronto && _erro == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: c.value.isPlaying ? 'Pausar' : 'Tocar',
                      icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
                    ),
                    Expanded(
                      child: VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(playedColor: Colors.tealAccent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${_tempo(c.value.position)} / ${_tempo(c.value.duration)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    IconButton(
                      tooltip: c.value.volume == 0 ? 'Ligar som' : 'Tirar som',
                      icon: Icon(c.value.volume == 0 ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                      onPressed: () => c.setVolume(c.value.volume == 0 ? 1 : 0),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Miniatura ───────────────────────────────────────────────────────────────

class _MiniaturaVideo extends StatelessWidget {
  final String nome;
  final int tamanhoBytes;
  final bool pendente;
  final double? progresso;
  final VoidCallback onTocar;
  final VoidCallback? onRemover;
  const _MiniaturaVideo({
    required this.nome,
    required this.tamanhoBytes,
    required this.onTocar,
    this.pendente = false,
    this.progresso,
    this.onRemover,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              InkWell(
                onTap: progresso == null ? onTocar : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFF263238),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: progresso != null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                    value: progresso, color: Colors.tealAccent, strokeWidth: 3),
                              ),
                              const SizedBox(height: 6),
                              Text('${((progresso ?? 0) * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          )
                        : const Icon(Icons.play_circle_fill, color: Colors.white, size: 40),
                  ),
                ),
              ),
              if (pendente)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(10)),
                    child: const Text('a enviar', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              if (onRemover != null && progresso == null)
                Positioned(
                  right: 2,
                  top: 2,
                  child: IconButton(
                    tooltip: 'Remover',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, color: Colors.white, size: 18),
                    onPressed: onRemover,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(nome, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
          Text(Videos.tamanho(tamanhoBytes), style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ── Abertura (planilha) ─────────────────────────────────────────────────────

/// Bloco "Vídeos do Sinistro" da abertura. Os vídeos escolhidos ficam
/// "a enviar" e sobem quando o sinistro é salvo (com progresso em [progresso]).
class PainelVideosAbertura extends StatelessWidget {
  final List<VideoAnexo> enviados;
  final List<VideoSelecionado> pendentes;
  final Map<VideoSelecionado, double> progresso;
  final LimitesVideo limites;
  final VoidCallback onAdicionar;
  final void Function(VideoSelecionado) onRemoverPendente;
  final void Function(VideoAnexo) onRemoverEnviado;

  const PainelVideosAbertura({
    super.key,
    required this.enviados,
    required this.pendentes,
    required this.progresso,
    required this.limites,
    required this.onAdicionar,
    required this.onRemoverPendente,
    required this.onRemoverEnviado,
  });

  @override
  Widget build(BuildContext context) {
    final total = enviados.length + pendentes.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.videocam_outlined, size: 16, color: _corVideos),
            const SizedBox(width: 6),
            const Text('Vídeos do Sinistro',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _corVideos)),
            const SizedBox(width: 8),
            Text('$total de ${limites.maxPorSinistro} · até ${limites.maxMb} MB cada',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const Spacer(),
            TextButton.icon(
              onPressed: total >= limites.maxPorSinistro ? null : onAdicionar,
              icon: const Icon(Icons.video_call_outlined, size: 18),
              label: const Text('Adicionar vídeo'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (total == 0)
          Text('MP4, MOV, M4V, 3GP ou WEBM. Clique no vídeo para conferir antes de salvar.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final v in enviados)
                _MiniaturaVideo(
                  nome: v.nome,
                  tamanhoBytes: v.tamanhoBytes,
                  onTocar: () => mostrarPlayerVideo(context, url: v.url, nome: v.nome),
                  onRemover: () => onRemoverEnviado(v),
                ),
              for (final v in pendentes)
                _MiniaturaVideo(
                  nome: v.nome,
                  tamanhoBytes: v.tamanhoBytes,
                  pendente: true,
                  progresso: progresso[v],
                  onTocar: () => mostrarPlayerVideo(context, local: v, nome: v.nome),
                  onRemover: () => onRemoverPendente(v),
                ),
            ],
          ),
      ],
    );
  }
}

// ── Detalhe do sinistro ─────────────────────────────────────────────────────

/// Bloco "Vídeos" do detalhe: toca sem sair da tela; no modo edição, adiciona
/// (envia na hora, com progresso) e remove (apaga do Storage). Grava direto no
/// documento do sinistro.
class GaleriaVideosSinistro extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? documento;
  final String numeroSinistro;
  final List<VideoAnexo> videos;
  final LimitesVideo limites;
  final bool editando;
  final String enviadoPor;
  final void Function(List<VideoAnexo>) onAlterado;

  const GaleriaVideosSinistro({
    super.key,
    required this.documento,
    required this.numeroSinistro,
    required this.videos,
    required this.limites,
    required this.editando,
    required this.enviadoPor,
    required this.onAlterado,
  });

  @override
  State<GaleriaVideosSinistro> createState() => _GaleriaVideosSinistroState();
}

class _GaleriaVideosSinistroState extends State<GaleriaVideosSinistro> {
  final _servico = VideoService();
  final Map<VideoSelecionado, double> _enviando = {};

  Future<void> _adicionar() async {
    final doc = widget.documento;
    if (doc == null) return;
    final escolhidos = await escolherVideos(
      context,
      limites: widget.limites,
      jaExistentes: widget.videos.length + _enviando.length,
    );
    for (final v in escolhidos) {
      setState(() => _enviando[v] = 0);
      try {
        final anexo = await _servico.enviar(
          numeroSinistro: widget.numeroSinistro,
          video: v,
          enviadoPor: widget.enviadoPor,
          aoProgredir: (p) {
            if (mounted) setState(() => _enviando[v] = p);
          },
        );
        await _servico.adicionarNoSinistro(doc, anexo);
        widget.onAlterado([...widget.videos, anexo]);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao enviar ${v.nome}: $e')));
        }
      } finally {
        if (mounted) setState(() => _enviando.remove(v));
      }
    }
  }

  Future<void> _remover(VideoAnexo v) async {
    final doc = widget.documento;
    if (doc == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir vídeo?'),
        content: Text('"${v.nome}" será apagado do sinistro e do armazenamento. Não dá para desfazer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _servico.removerDoSinistro(doc, v);
      widget.onAlterado(widget.videos.where((x) => x.caminho != v.caminho || x.url != v.url).toList());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.videos.length + _enviando.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Vídeos da Ocorrência:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text('$total de ${widget.limites.maxPorSinistro}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        const SizedBox(height: 8),
        if (total == 0)
          Text('Nenhum vídeo.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final v in widget.videos)
                _MiniaturaVideo(
                  nome: v.nome,
                  tamanhoBytes: v.tamanhoBytes,
                  onTocar: () => mostrarPlayerVideo(context, url: v.url, nome: v.nome),
                  onRemover: widget.editando ? () => _remover(v) : null,
                ),
              for (final e in _enviando.entries)
                _MiniaturaVideo(
                  nome: e.key.nome,
                  tamanhoBytes: e.key.tamanhoBytes,
                  pendente: true,
                  progresso: e.value,
                  onTocar: () {},
                ),
            ],
          ),
        if (widget.editando) ...[
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: total >= widget.limites.maxPorSinistro || widget.documento == null ? null : _adicionar,
            icon: const Icon(Icons.video_call),
            label: Text('Adicionar Vídeo (até ${widget.limites.maxMb} MB)'),
          ),
        ],
      ],
    );
  }
}
