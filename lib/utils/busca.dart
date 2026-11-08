// lib/utils/busca.dart
//
// Etapa 11: busca de texto tolerante, usada na lista de Sinistros (Dart puro,
// testado em test/busca_test.dart).
//  • Sem diferença de maiúsculas e acentos: "joao" acha "João".
//  • Várias palavras: todas precisam aparecer (em qualquer campo e ordem):
//    "silva joao" acha "João da Silva".
//  • Números (telefone, CPF, placa, nº de registro): a partir de 4 dígitos,
//    compara só os dígitos — "99863-8469" acha "(27) 99863 8469".

class Busca {
  static const _de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  static const _para = 'aaaaaeeeeiiiiooooouuuucn';

  static String normalizar(String texto) {
    final minusculo = texto.toLowerCase();
    final b = StringBuffer();
    for (final ch in minusculo.split('')) {
      final i = _de.indexOf(ch);
      b.write(i >= 0 ? _para[i] : ch);
    }
    return b.toString();
  }

  static String _digitos(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// true se [consulta] combina com algum dos [campos] (nulos e vazios são ignorados).
  static bool corresponde(String consulta, Iterable<String?> campos) {
    final q = normalizar(consulta.trim());
    if (q.isEmpty) return true;
    final textos = [
      for (final c in campos)
        if (c != null && c.trim().isNotEmpty) normalizar(c),
    ];
    if (textos.isEmpty) return false;

    final juntos = textos.join(' | ');
    final palavras = q.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (palavras.every(juntos.contains)) return true;

    final qd = _digitos(q);
    if (qd.length >= 4) {
      return textos.any((t) => _digitos(t).contains(qd));
    }
    return false;
  }
}
