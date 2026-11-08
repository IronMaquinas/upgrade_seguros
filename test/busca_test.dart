// Testes da busca tolerante (Etapa 11).
// Rodar no Mac: flutter test test/busca_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/busca.dart';

void main() {
  const campos = [
    'SN20261104180734',
    'VIACAO FLECHA BRANCA LTDA',
    'João da Silva', // condutor do segurado
    '(27) 99863 8469', // contato do terceiro
    'Liberty 31.69.2026.0488237', // registro na seguradora do terceiro
    null,
    '',
  ];

  test('sem acento e sem maiúscula', () {
    expect(Busca.corresponde('joao', campos), true);
    expect(Busca.corresponde('VIAÇÃO flecha', campos), true);
  });

  test('várias palavras em qualquer ordem', () {
    expect(Busca.corresponde('silva joao', campos), true);
    expect(Busca.corresponde('silva maria', campos), false);
  });

  test('telefone com ou sem máscara', () {
    expect(Busca.corresponde('99863-8469', campos), true);
    expect(Busca.corresponde('27998638469', campos), true);
  });

  test('número de registro só com dígitos', () {
    expect(Busca.corresponde('3169202604882', campos), true);
  });

  test('menos de 4 dígitos não usa a comparação por dígitos', () {
    expect(Busca.corresponde('9-9', campos), false);
  });

  test('consulta vazia mostra tudo; campos vazios não casam', () {
    expect(Busca.corresponde('  ', campos), true);
    expect(Busca.corresponde('x', const [null, '']), false);
  });
}
