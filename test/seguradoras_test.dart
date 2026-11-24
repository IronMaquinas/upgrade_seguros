// test/seguradoras_test.dart — Etapa 20: seguradora só do cadastro + correção dos nomes antigos
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/seguradoras.dart';

void main() {
  const cad = ['Allianz', 'AXA', 'BANESTES', 'Bradesco Seguros', 'Chubb', 'ESSOR', 'EZZE', 'Liberty', 'Porto Seguro', 'Tokio Marine'];

  group('resolverSeguradora', () {
    test('igual, caixa, espaços e acento', () {
      expect(resolverSeguradora('AXA', cad), 'AXA');
      expect(resolverSeguradora('chubb', cad), 'Chubb');
      expect(resolverSeguradora('  ESSOR ', cad), 'ESSOR');
      expect(resolverSeguradora('allianz', cad), 'Allianz');
    });
    test('"Seguros" / "S.A." no fim', () {
      expect(resolverSeguradora('AXA SEGUROS', cad), 'AXA');
      expect(resolverSeguradora('Ezze Seguros', cad), 'EZZE');
      expect(resolverSeguradora('BRADESCO', cad), 'Bradesco Seguros');
      expect(resolverSeguradora('Tokio Marine Seguradora S.A.', cad), 'Tokio Marine');
    });
    test('fora do cadastro e vazio', () {
      expect(resolverSeguradora('Mapfre', cad), null);
      expect(resolverSeguradora('AXA SEGURUROS', cad), null);
      expect(resolverSeguradora('', cad), null);
      expect(resolverSeguradora('Porto', cad), null);
    });
  });

  group('sugestoesSeguradora', () {
    test('começa com vem antes de contém; sem acento/caixa', () {
      expect(sugestoesSeguradora('ma', cad), ['Tokio Marine']);
      expect(sugestoesSeguradora('b', cad).take(2).toList(), ['BANESTES', 'Bradesco Seguros']);
      expect(sugestoesSeguradora('seguro', cad), ['Bradesco Seguros', 'Porto Seguro']);
    });
    test('vazio = todas, em ordem', () {
      expect(sugestoesSeguradora('', cad).length, cad.length);
      expect(sugestoesSeguradora('', ['b', 'A']).first, 'A');
    });
  });

  group('correspondenteProvavel', () {
    test('erros de digitação conhecidos', () {
      expect(correspondenteProvavel('AXA SEGURUROS', cad), 'AXA');
      expect(correspondenteProvavel('EZZER', cad), 'EZZE');
      expect(correspondenteProvavel('CHUBB', cad), 'Chubb');
      expect(correspondenteProvavel('Libertty', cad), 'Liberty');
    });
    test('sem palpite quando não há um candidato claro', () {
      expect(correspondenteProvavel('Mapfre', cad), null);
      expect(correspondenteProvavel('XYZ', cad), null);
      expect(correspondenteProvavel('ABC', ['ABD', 'ABE']), null);
    });
  });

  test('agruparGrafias: só as fora do cadastro, mais usadas primeiro', () {
    final g = agruparGrafias({
      'sinistros': ['AXA', 'AXA SEGURUROS', 'AXA SEGURUROS', 'CHUBB', ''],
      'assistencias': ['CHUBB', 'Chubb'],
      'apolices': ['AXA SEGURUROS', 'Mapfre'],
    }, cad);
    expect(g.map((x) => x.nome).toList(), ['AXA SEGURUROS', 'CHUBB', 'Mapfre']);
    expect(g[0].sinistros, 2);
    expect(g[0].apolices, 1);
    expect(g[0].total, 3);
    expect(g[0].sugestao, 'AXA');
    expect(g[1].sugestao, 'Chubb');
    expect(g[2].sugestao, null);
  });

  test('trocarSeguradoraNasApolices', () {
    final apolices = [
      {'numero': '1', 'seguradora': 'AXA SEGURUROS'},
      {'numero': '2', 'seguradora': 'Chubb'},
    ];
    final nova = trocarSeguradoraNasApolices(apolices, {'AXA SEGURUROS': 'AXA'})!;
    expect(nova[0]['seguradora'], 'AXA');
    expect(nova[0]['numero'], '1');
    expect(nova[1]['seguradora'], 'Chubb');
    expect(apolices[0]['seguradora'], 'AXA SEGURUROS'); // original intacto
    expect(trocarSeguradoraNasApolices(apolices, {'Mapfre': 'AXA'}), null);
    expect(trocarSeguradoraNasApolices(null, {'a': 'b'}), null);
  });
}
