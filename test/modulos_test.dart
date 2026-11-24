// test/modulos_test.dart — Etapa 23: catálogo de módulos
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/modulos.dart';

void main() {
  test('catálogo: ids únicos, dependências existem, áreas conhecidas', () {
    final ids = Modulos.catalogo.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final m in Modulos.catalogo) {
      expect(Modulos.areas.contains(m.area), true);
      for (final d in m.dependeDe) {
        expect(Modulos.porId(d) != null, true);
      }
    }
  });

  test('sem conta ou tudo ligado = null (tudo liberado)', () {
    expect(Modulos.ligadosDaConta(null), null);
    expect(Modulos.ligadosDaConta({'plano': {'tipo': 'tudo_ligado'}}), null);
    expect(Modulos.ligadosDaConta({'situacao': 'ativa'}), null);
  });

  test('personalizado: só os válidos e com dependência', () {
    final l = Modulos.ligadosDaConta({
      'plano': {'tipo': 'personalizado'},
      'modulos': ['tarefas', 'nps', 'xyz'],
    })!;
    expect(l.contains('tarefas'), true);
    expect(l.contains('nps'), false); // exige assistências
    expect(l.contains('xyz'), false);
    expect(Modulos.ligadosDaConta({'plano': {'tipo': 'personalizado'}})!.isEmpty, true);
  });

  test('marcar puxa a dependência; desmarcar tira quem dependia', () {
    final a = Modulos.marcar(<String>{}, 'nps');
    expect(a.contains('assistencias') && a.contains('nps'), true);
    final b = Modulos.desmarcar({'assistencias', 'nps', 'telegram', 'tarefas'}, 'assistencias');
    expect(b.length, 1);
    expect(b.contains('tarefas'), true);
  });
}
