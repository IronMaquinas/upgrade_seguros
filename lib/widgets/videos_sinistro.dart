// lib/widgets/videos_sinistro.dart
//
// Etapa 12: vídeos do sinistro — escolher, conferir (tocar sem sair da tela),
// enviar com progresso e mostrar no detalhe.
//  • escolherVideos(...)        → abre o seletor e aplica os limites.
//  • mostrarPlayerVideo(...)    → janela com o vídeo tocando (play/pausa, tempo, som).
//  • videosSoltos(...)          → vídeos arrastados para a caixa (Etapa 13).
//  • PainelVideosAbertura       → bloco "Vídeos do Sinistro" na abertura (planilha),
//                                 no desenho das categorias de Anexos (Etapa 13).
//  • GaleriaVideosSinistro      → bloco "Vídeos" no detalhe do sinistro.
// Regras (formatos, limites, caminho) em lib/utils/videos.dart; envio em
// lib/services/video_service.dart.

import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:desktop_drop/desktop_drop.dart';
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

/// Etapa 13: vídeos arrastados para a caixa — mesmos limites do seletor.
Future<List<VideoSelecionado>> videosSoltos(
  BuildContext context,
  List<XFile> arquivos, {
  required LimitesVideo limites,
  required int jaExistentes,
}) async {
  final comTamanho = <({XFile arquivo, int bytes})>[];
  for (final a in arquivos) {
    comTamanho.add((arquivo: a, bytes: await a.length()));
  }
  final r = Videos.validar<({XFile arquivo, int bytes})>(
    comTamanho,
    nome: (x) => x.arquivo.name,
    bytes: (x) => x.bytes,
    jaExistentes: jaExistentes,
    limites: limites,
  );
  if (r.recusas.isNotEmpty && context.mounted) _avisar(context, r.recusas);
  final saida = <VideoSelecionado>[];
  for (final x in r.aceitos) {
    saida.add(VideoSelecionado(
      nome: x.arquivo.name,
      tamanhoBytes: x.bytes,
      bytes: kIsWeb ? await x.arquivo.readAsBytes() : null,
      caminhoLocal: kIsWeb ? null : x.arquivo.path,
    ));
  }
  return saida;
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

/// Bloco "Vídeos do Sinistro" da abertura, no mesmo desenho das categorias de
/// "Anexos e Documentos" (Etapa 13): rótulo cinza em maiúsculas + botão
/// "+ Adicionar vídeos" com contorno + caixa cinza onde dá para arrastar ou
/// clicar. Os vídeos escolhidos ficam "a enviar" e sobem quando o sinistro é
/// salvo (com progresso em [progresso]).
class PainelVideosAbertura extends StatefulWidget {
  final List<VideoAnexo> enviados;
  final List<VideoSelecionado> pendentes;
  final Map<VideoSelecionado, double> progresso;
  final LimitesVideo limites;
  final VoidCallback onAdicionar;
  /// Etapa 13: vídeos soltos na caixa (arrastar e soltar), já validados.
  final void Function(List<VideoSelecionado>)? onSoltar;
  final void Function(VideoSelecionado) onRemoverPendente;
  final void Function(VideoAnexo) onRemoverEnviado;

  const PainelVideosAbertura({
    super.key,
    required this.enviados,
    required this.pendentes,
    required this.progresso,
    required this.limites,
    required this.onAdicionar,
    this.onSoltar,
    required this.onRemoverPendente,
    required this.onRemoverEnviado,
  });

  @override
  State<PainelVideosAbertura> createState() => _PainelVideosAberturaState();
}

class _PainelVideosAberturaState extends State<PainelVideosAbertura> {
  bool _arrastando = false;

  int get _total => widget.enviados.length + widget.pendentes.length;
  bool get _cheio => _total >= widget.limites.maxPorSinistro;

  Future<void> _soltou(List<XFile> arquivos) async {
    setState(() => _arrastando = false);
    final onSoltar = widget.onSoltar;
    if (onSoltar == null || arquivos.isEmpty) return;
    final escolhidos = await videosSoltos(
      context,
      arquivos,
      limites: widget.limites,
      jaExistentes: _total,
    );
    if (escolhidos.isNotEmpty) onSoltar(escolhidos);
  }

  @override
  Widget build(BuildContext context) {
    final limites = widget.limites;
    final vazio = _total == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rótulo da categoria (igual a "FOTOS DO SINISTRO", "LAUDOS / BOLETINS"…)
          Row(
            children: [
              Icon(Icons.videocam_outlined, size: 13, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                'VÍDEOS DO SINISTRO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$_total de ${limites.maxPorSinistro}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
              const Spacer(),
              _BotaoAdicionarVideos(onTap: _cheio ? null : widget.onAdicionar),
            ],
          ),
          const SizedBox(height: 6),

          // Caixa: arrastar e soltar ou clicar para escolher
          DropTarget(
            enable: !_cheio && widget.onSoltar != null,
            onDragEntered: (_) => setState(() => _arrastando = true),
            onDragExited: (_) => setState(() => _arrastando = false),
            onDragDone: (detalhes) => _soltou(detalhes.files),
            child: GestureDetector(
              onTap: vazio && !_cheio ? widget.onAdicionar : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 72),
                decoration: BoxDecoration(
                  color: _arrastando ? _corVideos.withOpacity(0.06) : const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _arrastando ? _corVideos : Colors.grey.shade300,
                    width: _arrastando ? 1.5 : 0.8,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: vazio
                    ? _PlaceholderVideos(arrastando: _arrastando)
                    : Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final v in widget.enviados)
                            _MiniaturaVideo(
                              nome: v.nome,
                              tamanhoBytes: v.tamanhoBytes,
                              onTocar: () => mostrarPlayerVideo(context, url: v.url, nome: v.nome),
                              onRemover: () => widget.onRemoverEnviado(v),
                            ),
                          for (final v in widget.pendentes)
                            _MiniaturaVideo(
                              nome: v.nome,
                              tamanhoBytes: v.tamanhoBytes,
                              pendente: true,
                              progresso: widget.progresso[v],
                              onTocar: () => mostrarPlayerVideo(context, local: v, nome: v.nome),
                              onRemover: () => widget.onRemoverPendente(v),
                            ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${Videos.extensoes.map((e) => e.toUpperCase()).join(', ')} · até ${limites.maxMb} MB cada'
            ' · máximo ${limites.maxPorSinistro} por sinistro. Clique no vídeo para conferir.',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

/// Botão pequeno com contorno, igual ao "+ Adicionar arquivos" das categorias.
class _BotaoAdicionarVideos extends StatelessWidget {
  final VoidCallback? onTap;
  const _BotaoAdicionarVideos({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cor = onTap == null ? Colors.grey.shade400 : _corVideos;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: cor.withOpacity(0.4), width: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 12, color: cor),
            const SizedBox(width: 3),
            Text('Adicionar vídeos', style: TextStyle(fontSize: 11, color: cor)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderVideos extends StatelessWidget {
  final bool arrastando;
  const _PlaceholderVideos({required this.arrastando});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              arrastando ? Icons.file_download_outlined : Icons.video_call_outlined,
              size: 22,
              color: arrastando ? _corVideos : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              arrastando ? 'Solte aqui para adicionar' : 'Arraste vídeos aqui ou clique para selecionar',
              style: TextStyle(fontSize: 11, color: arrastando ? _corVideos : Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
