// lib/utils/videos.dart
//
// Etapa 12: regras dos VÍDEOS do sinistro (Dart puro, testado em
// test/videos_test.dart).
//
//  • Formatos aceitos: mp4, mov, m4v, 3gp, webm (o que celular e WhatsApp geram).
//  • Limites vêm das Configurações (`app_config/config`): tamanho máximo por
//    vídeo (padrão 20 MB — o vídeo do WhatsApp tem até 16 MB) e quantidade por
//    sinistro (padrão 5). Pensados para variar por plano contratado no futuro.
//  • Caminho no Storage: videos/sinistros/{nº do sinistro}/{data}_{nome}.
//    O prefixo "videos/" é o que permite a regra de ciclo de vida (Coldline
//    depois de 180 dias) e a regra de segurança só para vídeos.
//  • Depois do envio, a Cloud Function `converterVideo` converte para MP4 720p
//    (H.264) no mesmo endereço — o link salvo no sinistro continua valendo.

class LimitesVideo {
  final int maxMb;
  final int maxPorSinistro;
  const LimitesVideo({this.maxMb = padraoMaxMb, this.maxPorSinistro = padraoMaxPorSinistro});

  static const padraoMaxMb = 100;
  static const padraoMaxPorSinistro = 5;

  /// Teto absoluto (o mesmo das regras do Storage): nenhum plano passa disso.
  static const tetoMb = 100;

  int get maxBytes => maxMb * 1024 * 1024;

  static int normalizarMb(num? v) {
    final n = (v ?? padraoMaxMb).round();
    if (n < 1) return padraoMaxMb;
    return n > tetoMb ? tetoMb : n;
  }

  static int normalizarQuantidade(num? v) {
    final n = (v ?? padraoMaxPorSinistro).round();
    return n < 1 ? padraoMaxPorSinistro : n;
  }
}

/// Vídeo já enviado, como fica gravado no sinistro (campo `videos`).
class VideoAnexo {
  final String url;
  final String caminho; // caminho no Storage (para excluir)
  final String nome; // nome original do arquivo
  final int tamanhoBytes; // tamanho enviado (antes da conversão)
  final DateTime enviadoEm;
  final String enviadoPor;

  const VideoAnexo({
    required this.url,
    required this.caminho,
    required this.nome,
    required this.tamanhoBytes,
    required this.enviadoEm,
    this.enviadoPor = '',
  });

  Map<String, dynamic> toMap() => {
        'url': url,
        'caminho': caminho,
        'nome': nome,
        'tamanho_bytes': tamanhoBytes,
        'enviado_em': enviadoEm.millisecondsSinceEpoch,
        'enviado_por': enviadoPor,
      };

  factory VideoAnexo.fromMap(Map<String, dynamic> m) => VideoAnexo(
        url: m['url'] as String? ?? '',
        caminho: m['caminho'] as String? ?? '',
        nome: m['nome'] as String? ?? 'video',
        tamanhoBytes: (m['tamanho_bytes'] as num?)?.toInt() ?? 0,
        enviadoEm: DateTime.fromMillisecondsSinceEpoch((m['enviado_em'] as num?)?.toInt() ?? 0),
        enviadoPor: m['enviado_por'] as String? ?? '',
      );

  static List<VideoAnexo> listaDe(dynamic valor) {
    if (valor is! List) return const [];
    return [
      for (final v in valor)
        if (v is Map) VideoAnexo.fromMap(Map<String, dynamic>.from(v)),
    ].where((v) => v.url.isNotEmpty).toList();
  }
}

class Videos {
  /// Bucket padrão do projeto (Console → Storage). O `firebase_options.dart`
  /// ainda aponta para `upgrade-seguros.appspot.com` (nome antigo), mas as
  /// fotos e a Cloud Function usam este — os vídeos vão para o mesmo lugar.
  static const bucket = 'upgrade-seguros.firebasestorage.app';

  static const extensoes = ['mp4', 'mov', 'm4v', '3gp', 'webm'];

  static String extensao(String nome) {
    final i = nome.lastIndexOf('.');
    return i < 0 ? '' : nome.substring(i + 1).toLowerCase();
  }

  static bool ehVideo(String nome) => extensoes.contains(extensao(nome));

  static String contentType(String nome) {
    switch (extensao(nome)) {
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case '3gp':
        return 'video/3gpp';
      case 'webm':
        return 'video/webm';
      default:
        return 'video/mp4';
    }
  }

  /// .mov (iPhone, geralmente HEVC) e .3gp podem não tocar no navegador antes
  /// da conversão para MP4.
  static bool podeNaoTocarNoNavegador(String nome) => const ['mov', '3gp'].contains(extensao(nome));

  static String nomeSeguro(String nome) {
    final limpo = nome.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'_+'), '_');
    return limpo.isEmpty ? 'video.mp4' : limpo;
  }

  static String caminho(String numeroSinistro, String nome, DateTime quando) =>
      'videos/sinistros/${nomeSeguro(numeroSinistro)}/${quando.millisecondsSinceEpoch}_${nomeSeguro(nome)}';

  /// "12,4 MB" / "850 KB"
  static String tamanho(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
    }
    return '${(bytes / 1024).ceil()} KB';
  }

  /// Confere uma seleção. Devolve os aceitos e a lista de recusas com o motivo.
  static ({List<T> aceitos, List<String> recusas}) validar<T>(
    List<T> selecionados, {
    required String Function(T) nome,
    required int Function(T) bytes,
    required int jaExistentes,
    required LimitesVideo limites,
  }) {
    final aceitos = <T>[];
    final recusas = <String>[];
    for (final s in selecionados) {
      final n = nome(s);
      if (!ehVideo(n)) {
        recusas.add('$n: formato não aceito (use ${extensoes.join(', ')})');
      } else if (bytes(s) > limites.maxBytes) {
        recusas.add('$n: ${tamanho(bytes(s))} — o limite é ${limites.maxMb} MB por vídeo');
      } else if (jaExistentes + aceitos.length >= limites.maxPorSinistro) {
        recusas.add('$n: o sinistro já tem o máximo de ${limites.maxPorSinistro} vídeos');
      } else {
        aceitos.add(s);
      }
    }
    return (aceitos: aceitos, recusas: recusas);
  }
}
