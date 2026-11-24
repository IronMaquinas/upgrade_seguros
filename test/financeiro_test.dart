// test/financeiro_test.dart — Etapa 26: contas do painel financeiro
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/admin/financeiro.dart';
import 'package:upgrade_seguros/admin/modelos_plataforma.dart';
import 'package:upgrade_seguros/utils/planos.dart';

final agora = DateTime(2026, 11, 24, 15);

CorretoraPlataforma c(String nome, {int usuarios = 0, ContaPlataforma? conta}) =>
    CorretoraPlataforma(id: nome, nome: nome, usuarios: usuarios, conta: conta);

ContaPlataforma plano(String situacao,
        {int preco = 19900, int? incluidos = 5, int extra = 4900, bool cortesia = false, DateTime? cortesiaAte, DateTime? testeAte, String tipo = 'modelo'}) =>
    ContaPlataforma(
      situacao: situacao,
      situacaoEfetiva: situacao,
      planoNome: tipo == 'tudo_ligado' ? 'Tudo ligado' : 'Essencial',
      planoTipo: tipo,
      precoCentavos: preco,
      franquias: {'usuarios': Franquia(incluido: incluidos, extraCentavos: extra)},
      cortesia: cortesia,
      cortesiaAte: cortesiaAte,
      testeAte: testeAte,
    );

void main() {
  test('mensalidade = preço + usuários acima da franquia', () {
    final r = ResumoFinanceiro.de([c('A', usuarios: 7, conta: plano('ativa'))], agora: agora);
    final l = r.linhas.single;
    expect(l.usuariosExtras, 2);
    expect(l.extrasCentavos, 9800);
    expect(l.totalCentavos, 29700);
    expect(r.mrrCentavos, 29700);
    expect(r.extrasCentavos, 9800);
  });

  test('sem limite e dentro da franquia não têm extra; Tudo ligado não tem preço', () {
    final r = ResumoFinanceiro.de([
      c('A', usuarios: 50, conta: plano('ativa', incluidos: null)),
      c('B', usuarios: 3, conta: plano('ativa')),
      c('C', usuarios: 9, conta: plano('ativa', tipo: 'tudo_ligado', cortesia: true)),
    ], agora: agora);
    expect(r.linhas.firstWhere((l) => l.id == 'A').extrasCentavos, 0);
    expect(r.linhas.firstWhere((l) => l.id == 'B').extrasCentavos, 0);
    expect(r.linhas.firstWhere((l) => l.id == 'C').totalCentavos, 0);
    expect(r.mrrCentavos, 39800);
    expect(r.pagantes.length, 2);
    expect(r.ticketMedioCentavos, 19900);
  });

  test('cortesia valendo não entra no MRR; vencida entra', () {
    final r = ResumoFinanceiro.de([
      c('A', conta: plano('ativa', cortesia: true)),
      c('B', conta: plano('ativa', cortesia: true, cortesiaAte: DateTime(2026, 12, 10))),
      c('C', conta: plano('ativa', cortesia: true, cortesiaAte: DateTime(2026, 11, 1))),
    ], agora: agora);
    expect(r.mrrCentavos, 19900); // só a C (cortesia vencida)
    expect(r.cortesias.length, 2);
    expect(r.cortesiasCentavos, 39800);
    expect(r.cortesiasVencendo.map((l) => l.id).toList(), ['B']);
  });

  test('situações: inadimplente entra no MRR e no atraso; testes viram potencial; suspensa fica fora', () {
    final r = ResumoFinanceiro.de([
      c('A', conta: plano('inadimplente')),
      c('B', conta: plano('teste', testeAte: DateTime(2026, 11, 25, 23))),
      c('C', conta: plano('teste', testeAte: DateTime(2026, 12, 8))),
      c('D', conta: plano('teste_encerrado')),
      c('E', conta: plano('suspensa')),
      c('F'), // sem conta: fora
    ], agora: agora);
    expect(r.linhas.length, 5);
    expect(r.mrrCentavos, 19900);
    expect(r.emAtrasoCentavos, 19900);
    expect(r.testesAcabando.map((l) => l.id).toList(), ['B']);
    expect(r.potencialTestesCentavos, 3 * 19900);
    expect(r.paradas.map((l) => l.id).toList(), ['E']);
  });

  test('tabela para o Excel', () {
    final t = ResumoFinanceiro.de([c('Nova', usuarios: 6, conta: plano('ativa'))], agora: agora).tabela().split('\n');
    expect(t.first.split('\t').length, 11);
    expect(t[1], 'Nova\tAtiva\tEssencial\t199,00\t6\t5\t1\t49,00\t248,00\tnão\tsim');
  });
}
