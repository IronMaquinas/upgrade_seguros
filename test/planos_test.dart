// test/planos_test.dart — Etapa 24: preço e franquias
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/planos.dart';

void main() {
  test('reais: centavos para texto', () {
    expect(Planos.reais(19900), 'R\$ 199,00');
    expect(Planos.reais(4905), 'R\$ 49,05');
    expect(Planos.reais(123456789), 'R\$ 1.234.567,89');
    expect(Planos.reais(0), 'R\$ 0,00');
  });

  test('centavosDoTexto: aceita vírgula, ponto e milhar', () {
    expect(Planos.centavosDoTexto('199,90'), 19990);
    expect(Planos.centavosDoTexto('199.9'), 19990);
    expect(Planos.centavosDoTexto('R\$ 1.234,5'), 123450);
    expect(Planos.centavosDoTexto('1.234'), 123400);
    expect(Planos.centavosDoTexto('49'), 4900);
    expect(Planos.centavosDoTexto(''), 0);
    expect(Planos.centavosDoTexto('abc'), null);
    expect(Planos.centavosDoTexto('1,234'), null);
    expect(Planos.centavosDoTexto(Planos.textoDosCentavos(19905)), 19905);
  });

  test('franquias: sem dado = sem limite; ida e volta', () {
    final f = Planos.franquiasDe({'usuarios': {'incluido': 5, 'extraCentavos': 4900}});
    expect(f['usuarios']!.incluido, 5);
    expect(f['gb']!.semLimite, true);
    expect(Planos.franquiasDe(null)['gb_video']!.semLimite, true);
    final m = Planos.franquiasParaMapa(f);
    expect(Planos.franquiasDe(m)['usuarios']!.extraCentavos, 4900);
    expect(m.keys.toList(), ['usuarios', 'gb', 'gb_video']);
  });

  test('textos de franquia e resumo', () {
    final u = Planos.metricas.first;
    expect(Planos.descreverFranquia(u, const Franquia(incluido: 5, extraCentavos: 4900)), 'Até 5 usuários · R\$ 49,00 por usuário a mais');
    expect(Planos.descreverFranquia(u, const Franquia(incluido: 1)), 'Até 1 usuário');
    expect(Planos.descreverFranquia(Planos.metricas[1], const Franquia(incluido: 10)), 'Até 10 GB');
    expect(Planos.descreverFranquia(u, const Franquia()), 'Sem limite');
    expect(
      Planos.resumo(19900, {'usuarios': const Franquia(incluido: 5), 'gb_video': const Franquia(incluido: 2)}),
      'R\$ 199,00/mês · 5 usuários · 2 GB de vídeo',
    );
    expect(Planos.resumo(0, const {}), 'Sem mensalidade');
  });
}
