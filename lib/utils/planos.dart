// lib/utils/planos.dart — Etapa 24: preço e franquias de um plano
//
// Usado pelo portal (planos-modelo, plano da corretora) e pelo app (Meu plano).
// Os dados vêm de functions/planos.js; os valores são em centavos (inteiros).
// Franquia com incluido == null = sem limite.

class MetricaPlano {
  final String id;
  final String nome;
  final String unidade; // singular
  final String unidadePlural;
  const MetricaPlano(this.id, this.nome, this.unidade, this.unidadePlural);
}

class Franquia {
  final int? incluido;
  final int extraCentavos;
  const Franquia({this.incluido, this.extraCentavos = 0});

  bool get semLimite => incluido == null;

  factory Franquia.deMapa(Object? m) {
    if (m is! Map) return const Franquia();
    final inc = m['incluido'];
    return Franquia(
      incluido: inc is num ? inc.toInt() : null,
      extraCentavos: (m['extraCentavos'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> paraMapa() => {'incluido': incluido, 'extraCentavos': extraCentavos};
}

class Planos {
  Planos._();

  /// Mesma ordem e ids de METRICAS em functions/planos.js.
  static const metricas = [
    MetricaPlano('usuarios', 'Usuários', 'usuário', 'usuários'),
    MetricaPlano('gb', 'Armazenamento de arquivos', 'GB', 'GB'),
    MetricaPlano('gb_video', 'Armazenamento de vídeos', 'GB', 'GB'),
  ];

  static Map<String, Franquia> franquiasDe(Object? m) => {
        for (final x in metricas) x.id: Franquia.deMapa(m is Map ? m[x.id] : null),
      };

  static Map<String, dynamic> franquiasParaMapa(Map<String, Franquia> f) => {
        for (final x in metricas) x.id: (f[x.id] ?? const Franquia()).paraMapa(),
      };

  /// 19900 → "R$ 199,00"
  static String reais(int centavos) {
    final neg = centavos < 0;
    final c = centavos.abs();
    final inteiro = (c ~/ 100).toString();
    final buf = StringBuffer();
    for (var i = 0; i < inteiro.length; i++) {
      if (i > 0 && (inteiro.length - i) % 3 == 0) buf.write('.');
      buf.write(inteiro[i]);
    }
    return '${neg ? '-' : ''}R\$ $buf,${(c % 100).toString().padLeft(2, '0')}';
  }

  /// "199,90" / "199.90" / "R$ 1.234,5" → centavos; null se não for um valor.
  static int? centavosDoTexto(String texto) {
    var t = texto.replaceAll('R\$', '').replaceAll(' ', '').trim();
    if (t.isEmpty) return 0;
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
    final partes = t.split('.');
    final dec = partes.length > 1 ? partes[1].padRight(2, '0') : '00';
    return int.parse(partes[0]) * 100 + int.parse(dec);
  }

  /// centavos → "199,90" (para o campo de texto)
  static String textoDosCentavos(int c) => '${c ~/ 100},${(c % 100).toString().padLeft(2, '0')}';

  /// "Até 5 usuários · R$ 49,00 por usuário a mais"
  static String descreverFranquia(MetricaPlano m, Franquia f) {
    if (f.semLimite) return 'Sem limite';
    final n = f.incluido!;
    final qtd = m.id == 'usuarios' ? '$n ${n == 1 ? m.unidade : m.unidadePlural}' : '$n ${m.unidade}';
    final extra = f.extraCentavos > 0 ? ' · ${reais(f.extraCentavos)} por ${m.unidade} a mais' : '';
    return 'Até $qtd$extra';
  }

  /// Resumo de uma linha: "R$ 199,00/mês · 5 usuários · 10 GB".
  static String resumo(int precoCentavos, Map<String, Franquia> f) {
    final partes = <String>[precoCentavos > 0 ? '${reais(precoCentavos)}/mês' : 'Sem mensalidade'];
    for (final m in metricas) {
      final x = f[m.id];
      if (x == null || x.semLimite) continue;
      partes.add(m.id == 'usuarios' ? '${x.incluido} ${x.incluido == 1 ? m.unidade : m.unidadePlural}' : '${x.incluido} GB${m.id == 'gb_video' ? ' de vídeo' : ''}');
    }
    return partes.join(' · ');
  }
}

// ── Etapa 27: uso medido (plataforma_contas/{e}.uso, functions/uso.js) ──────

class UsoConta {
  static const _gb = 1024 * 1024 * 1024;

  final int bytesArquivos;
  final int arquivos;
  final int bytesVideos;
  final int videos;
  final int? usuarios;
  final DateTime? medidoEm;

  const UsoConta({this.bytesArquivos = 0, this.arquivos = 0, this.bytesVideos = 0, this.videos = 0, this.usuarios, this.medidoEm});

  /// [m]: mapa da conta (medidoEm como Timestamp do Firestore ou texto ISO). null = nunca medido.
  static UsoConta? deMapa(Object? m) {
    if (m is! Map) return null;
    final quando = m['medidoEm'];
    DateTime? em;
    if (quando is String) {
      em = DateTime.tryParse(quando)?.toLocal();
    } else if (quando != null) {
      try {
        em = (quando as dynamic).toDate() as DateTime;
      } catch (_) {}
    }
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    return UsoConta(
      bytesArquivos: n(m['bytesArquivos']),
      arquivos: n(m['arquivos']),
      bytesVideos: n(m['bytesVideos']),
      videos: n(m['videos']),
      usuarios: (m['usuarios'] as num?)?.toInt(),
      medidoEm: em,
    );
  }

  double get gbArquivos => bytesArquivos / _gb;
  double get gbVideos => bytesVideos / _gb;

  /// GB da métrica da franquia ('gb' = arquivos, 'gb_video' = vídeos).
  double gbDe(String metrica) => metrica == 'gb_video' ? gbVideos : gbArquivos;

  /// 1536 MB → "1,5 GB"; abaixo de 1 GB mostra em MB.
  static String texto(int bytes) {
    if (bytes < _gb) {
      final mb = bytes / (1024 * 1024);
      return '${mb < 10 ? mb.toStringAsFixed(1) : mb.toStringAsFixed(0)} MB'.replaceAll('.', ',');
    }
    final g = bytes / _gb;
    return '${g < 100 ? g.toStringAsFixed(1) : g.toStringAsFixed(0)} GB'.replaceAll('.', ',');
  }

  /// GB inteiros acima da franquia (arredonda para cima: 10,2 GB com 10 incluídos = 1).
  static int gbAcima(double usados, Franquia f) {
    if (f.semLimite) return 0;
    final x = usados - f.incluido!;
    return x <= 0 ? 0 : x.ceil();
  }
}
