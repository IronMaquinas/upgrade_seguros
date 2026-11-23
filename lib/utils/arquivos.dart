// lib/utils/arquivos.dart
//
// Etapa 16c: leitura dos links de arquivos do Storage.
//
// O app grava dois formatos de link:
//  • antigo (até a 16b, via Cloud Function + arquivo público):
//      https://storage.googleapis.com/{bucket}/sinistros/123/fotos/a.jpg
//  • novo (16c em diante, link com chave de acesso — "token"):
//      https://firebasestorage.googleapis.com/v0/b/{bucket}/o/corretoras%2F{id}%2Fsinistros%2F123%2Ffotos%2Fa.jpg?alt=media&token=…
//
// Vários lugares tiravam o nome do arquivo com `url.split('/').last`, o que no
// formato novo devolve "corretoras%2F…%2Fa.jpg?alt=media&token=…". Estas funções
// entendem os dois formatos (e também um caminho simples, sem https://).

class Arquivos {
  Arquivos._();

  /// Caminho do arquivo dentro do bucket, já decodificado
  /// ("corretoras/x/sinistros/123/fotos/a.jpg"). `null` se não der para ler.
  static String? caminhoDoArquivo(String? url) {
    final s = (url ?? '').trim();
    if (s.isEmpty) return null;
    if (!s.contains('://')) {
      final semBarra = s.replaceFirst(RegExp(r'^/+'), '');
      return semBarra.isEmpty ? null : _decodificar(semBarra);
    }
    final Uri uri;
    try {
      uri = Uri.parse(s);
    } catch (_) {
      return null;
    }
    final segs = uri.pathSegments; // já decodificados pelo Dart
    if (uri.host == 'firebasestorage.googleapis.com') {
      final i = segs.indexOf('o');
      if (i < 0 || i + 1 >= segs.length) return null;
      final c = segs.sublist(i + 1).join('/');
      return c.isEmpty ? null : c;
    }
    if (uri.host == 'storage.googleapis.com') {
      if (segs.length < 2) return null;
      return segs.sublist(1).join('/');
    }
    // {bucket}.storage.googleapis.com/caminho
    if (uri.host.endsWith('.storage.googleapis.com')) {
      return segs.isEmpty ? null : segs.join('/');
    }
    return null;
  }

  /// Só o nome do arquivo ("a.jpg"), sem pastas, sem "?alt=media&token=…".
  /// Se não reconhecer o link, devolve o último pedaço do endereço sem a parte
  /// depois de "?" (nunca devolve vazio: no pior caso, "arquivo").
  static String nomeDoArquivo(String? url) {
    final c = caminhoDoArquivo(url);
    String nome;
    if (c != null) {
      nome = c.split('/').last;
    } else {
      final semQuery = (url ?? '').split('?').first.split('#').first;
      nome = _decodificar(semQuery.split('/').last);
      if (nome.contains('/')) nome = nome.split('/').last;
    }
    return nome.isEmpty ? 'arquivo' : nome;
  }

  /// Extensão em minúsculas, sem o ponto ("pdf"); '' se não tiver.
  /// (No link novo, `url.split('.').last` devolvia "pdf?alt=media&token=…".)
  static String extensao(String? url) {
    final n = nomeDoArquivo(url);
    final i = n.lastIndexOf('.');
    return i < 0 || i == n.length - 1 ? '' : n.substring(i + 1).toLowerCase();
  }

  /// Nome cortado em [max] caracteres + "…" (sem quebrar nomes curtos).
  static String abreviado(String? url, int max) {
    final n = nomeDoArquivo(url);
    return n.length > max ? '${n.substring(0, max)}…' : n;
  }

  static String _decodificar(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }
}
