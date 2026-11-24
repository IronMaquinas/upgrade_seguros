// lib/utils/seguradoras.dart
//
// Etapa 20: a seguradora de um sinistro / assistência / apólice tem que ser uma
// das cadastradas em Configurações → Seguradoras. Funções puras (sem Firebase),
// testadas em test/seguradoras_test.dart:
//   • resolverSeguradora — o nome cadastrado que corresponde ao digitado
//     (CHUBB → Chubb; "AXA SEGUROS" → AXA), ou null;
//   • sugestoesSeguradora — a lista do campo enquanto se digita;
//   • correspondenteProvavel — palpite para grafias erradas antigas
//     ("AXA SEGURUROS" → AXA, "EZZER" → EZZE), usado só na correção, com
//     confirmação de quem corrige;
//   • GrafiaSeguradora / agruparGrafias — o levantamento da correção;
//   • trocarSeguradoraNasApolices — a troca dentro da lista de apólices do cliente.

import 'relatorio_modelo.dart' show chaveSeguradora;

String _simples(String s) {
  const de = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇáàâãäéèêëíìîïóòôõöúùûüç';
  const para = 'AAAAAEEEEIIIIOOOOOUUUUCaaaaaeeeeiiiiooooouuuuc';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString().toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// O nome CADASTRADO que corresponde a [digitado]; null se não houver.
/// Vazio → null (quem chama decide se a seguradora é obrigatória).
String? resolverSeguradora(String digitado, Iterable<String> cadastradas) {
  final t = digitado.trim();
  if (t.isEmpty) return null;
  for (final c in cadastradas) {
    if (c == t) return c;
  }
  final s = _simples(t);
  for (final c in cadastradas) {
    if (_simples(c) == s) return c;
  }
  final k = chaveSeguradora(t);
  final achadas = [for (final c in cadastradas) if (chaveSeguradora(c) == k) c];
  return achadas.length == 1 ? achadas.first : null;
}

/// Etapa 22: apelidos do catálogo (ex.: "AXA SEGUROS" → AXA, nome antigo de uma
/// seguradora renomeada). Monta o mapa texto → nome cadastrado, pela forma
/// simples (sem acento/caixa) e pela chave. Apelido que aponta para duas
/// seguradoras diferentes é ignorado.
Map<String, String> mapaDeApelidos(Map<String, List<String>> apelidosPorNome) {
  final m = <String, String>{};
  final ambiguos = <String>{};
  void por(String k, String nome) {
    if (k.isEmpty || ambiguos.contains(k)) return;
    final antes = m[k];
    if (antes != null && antes != nome) {
      m.remove(k);
      ambiguos.add(k);
    } else {
      m[k] = nome;
    }
  }

  apelidosPorNome.forEach((nome, apelidos) {
    for (final a in apelidos) {
      por('s:${_simples(a)}', nome);
      por('k:${chaveSeguradora(a)}', nome);
    }
  });
  return m;
}

/// Como [resolverSeguradora], e se não achar, procura nos apelidos do catálogo.
String? resolverComApelidos(String digitado, Iterable<String> cadastradas, Map<String, String> apelidos) {
  final direto = resolverSeguradora(digitado, cadastradas);
  if (direto != null || apelidos.isEmpty) return direto;
  final t = digitado.trim();
  if (t.isEmpty) return null;
  final nome = apelidos['s:${_simples(t)}'] ?? apelidos['k:${chaveSeguradora(t)}'];
  return nome != null && cadastradas.contains(nome) ? nome : null;
}

/// Sugestões do campo: as que contêm o texto (sem acento/caixa), primeiro as
/// que começam com ele. Texto vazio → todas.
List<String> sugestoesSeguradora(String texto, Iterable<String> cadastradas) {
  final q = _simples(texto);
  final todas = cadastradas.toList()..sort((a, b) => _simples(a).compareTo(_simples(b)));
  if (q.isEmpty) return todas;
  final comeca = <String>[], contem = <String>[];
  for (final c in todas) {
    final s = _simples(c);
    if (s.startsWith(q)) {
      comeca.add(c);
    } else if (s.contains(q)) {
      contem.add(c);
    }
  }
  return [...comeca, ...contem];
}

int _distancia(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var ant = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final atual = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final custo = a[i - 1] == b[j - 1] ? 0 : 1;
      atual[j] = [ant[j] + 1, atual[j - 1] + 1, ant[j - 1] + custo].reduce((x, y) => x < y ? x : y);
    }
    ant = atual;
  }
  return ant[b.length];
}

/// Palpite para uma grafia antiga: igual pela chave; ou a cadastrada é o
/// começo dela por palavras ("AXA SEGURUROS" → AXA); ou difere por 1–2 letras
/// ("EZZER" → EZZE). Só devolve se houver UM candidato claro.
String? correspondenteProvavel(String nome, Iterable<String> cadastradas) {
  final direto = resolverSeguradora(nome, cadastradas);
  if (direto != null) return direto;
  final k = chaveSeguradora(nome);
  if (k.isEmpty) return null;

  final porPrefixo = [
    for (final c in cadastradas)
      if (chaveSeguradora(c).isNotEmpty && (k.startsWith('${chaveSeguradora(c)} ') || chaveSeguradora(c).startsWith('$k ')))
        c,
  ];
  if (porPrefixo.length == 1) return porPrefixo.first;

  String? melhor;
  var melhorD = 99, empate = false;
  for (final c in cadastradas) {
    final kc = chaveSeguradora(c);
    final limite = (k.length < kc.length ? k.length : kc.length) >= 6 ? 2 : 1;
    final d = _distancia(k, kc);
    if (d > limite) continue;
    if (d < melhorD) {
      melhor = c;
      melhorD = d;
      empate = false;
    } else if (d == melhorD) {
      empate = true;
    }
  }
  return empate ? null : melhor;
}

/// Uma grafia encontrada nos registros que NÃO é um nome cadastrado.
class GrafiaSeguradora {
  final String nome;
  final int sinistros;
  final int assistencias;
  final int apolices;
  final String? sugestao;
  const GrafiaSeguradora(this.nome, {this.sinistros = 0, this.assistencias = 0, this.apolices = 0, this.sugestao});
  int get total => sinistros + assistencias + apolices;
}

/// [nomes]: por coleção ('sinistros' / 'assistencias' / 'apolices'), o nome de
/// cada registro. Devolve só as grafias fora do cadastro, mais usadas primeiro.
List<GrafiaSeguradora> agruparGrafias(Map<String, Iterable<String>> nomes, Iterable<String> cadastradas) {
  final cad = cadastradas.toSet();
  final cont = <String, Map<String, int>>{};
  nomes.forEach((colecao, lista) {
    for (final n in lista) {
      if (n.trim().isEmpty || cad.contains(n)) continue;
      final m = cont.putIfAbsent(n, () => {});
      m[colecao] = (m[colecao] ?? 0) + 1;
    }
  });
  final r = [
    for (final e in cont.entries)
      GrafiaSeguradora(
        e.key,
        sinistros: e.value['sinistros'] ?? 0,
        assistencias: e.value['assistencias'] ?? 0,
        apolices: e.value['apolices'] ?? 0,
        sugestao: correspondenteProvavel(e.key, cadastradas),
      ),
  ]..sort((a, b) => b.total != a.total ? b.total.compareTo(a.total) : a.nome.compareTo(b.nome));
  return r;
}

/// Lista de apólices (como está no documento do cliente) com a seguradora
/// trocada conforme [troca] (grafia antiga → nome cadastrado). null se nada mudou.
List<Map<String, dynamic>>? trocarSeguradoraNasApolices(List<dynamic>? apolices, Map<String, String> troca) {
  if (apolices == null || apolices.isEmpty) return null;
  var mudou = false;
  final nova = <Map<String, dynamic>>[];
  for (final a in apolices) {
    final m = Map<String, dynamic>.from(a as Map);
    final atual = (m['seguradora'] ?? '') as String;
    final novo = troca[atual];
    if (novo != null && novo != atual) {
      m['seguradora'] = novo;
      mudou = true;
    }
    nova.add(m);
  }
  return mudou ? nova : null;
}
