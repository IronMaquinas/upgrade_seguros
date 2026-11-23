// test/rankings_clientes_test.dart — Etapa 18
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/rankings_clientes.dart';

void main() {
  group('Top 10 por valor de sinistros', () {
    const a = ClienteRanking(id: 'a', nome: 'Alfa', qtdApolices: 2);
    const b = ClienteRanking(id: 'b', nome: 'Beta');
    const c = ClienteRanking(id: 'c', nome: 'Gama');

    test('soma por cliente, sem Cancelado/Negado e sem assistência', () {
      final r = RankingsClientes.porValorSinistros([a, b, c], const [
        SinistroRanking(idCliente: 'a', tipo: 'sinistro', status: 'Em análise', valor: 100),
        SinistroRanking(idCliente: 'a', tipo: 'sinistro', status: 'Concluído', valor: 50),
        SinistroRanking(idCliente: 'a', tipo: 'sinistro', status: 'Cancelado', valor: 9999),
        SinistroRanking(idCliente: 'b', tipo: 'sinistro', status: 'Negado', valor: 9999),
        SinistroRanking(idCliente: 'b', tipo: 'sinistro', status: 'Aberto', valor: 50),
        SinistroRanking(idCliente: 'c', tipo: 'assistencia', status: 'Aberto', valor: 9999),
      ]);
      expect(r.map((i) => i.cliente.nome).toList(), ['Alfa', 'Beta']);
      expect(r[0].valor, 150);
      expect(r[0].qtdSinistros, 2);
      expect(r[0].percentual, 75);
      expect(r[1].percentual, 25);
    });

    test('cliente sem sinistro que conta fica de fora; limite de 10', () {
      final clientes = [for (var i = 0; i < 15; i++) ClienteRanking(id: '$i', nome: 'C$i')];
      final sinistros = [for (var i = 0; i < 15; i++) SinistroRanking(idCliente: '$i', tipo: 'sinistro', status: 'Aberto', valor: i * 10.0)];
      final r = RankingsClientes.porValorSinistros(clientes, sinistros);
      expect(r.length, 10);
      expect(r.first.cliente.nome, 'C14');
      expect(r.any((i) => i.cliente.nome == 'C0'), false); // valor 0
    });
  });

  group('Maiores apólices vigentes', () {
    final hoje = DateTime(2026, 11, 23);
    ApoliceRanking ap(String n, double v, {DateTime? ini, DateTime? fim}) => ApoliceRanking(
          clienteNome: 'Cli $n',
          numero: n,
          ramo: 'Frota',
          inicio: ini ?? DateTime(2026, 1, 1),
          fim: fim ?? DateTime(2026, 12, 31),
          valor: v,
        );

    test('só vigentes hoje, da maior para a menor', () {
      final r = RankingsClientes.maioresApolicesVigentes([
        ap('1', 100000),
        ap('2', 300000),
        ap('vencida', 900000, fim: DateTime(2026, 11, 22)),
        ap('futura', 800000, ini: DateTime(2026, 11, 24)),
        ap('vence hoje', 200000, fim: hoje),
      ], hoje);
      expect(r.map((i) => i.apolice.numero).toList(), ['2', 'vence hoje', '1']);
      expect(r.any((i) => i.suspeita), false);
    });

    test('valor muito acima das demais é marcado (ex.: R\$ 10 bilhões)', () {
      final r = RankingsClientes.maioresApolicesVigentes([
        for (var i = 0; i < 6; i++) ap('n$i', 100000 + i * 1000.0),
        ap('erro', 10000000000),
      ], hoje);
      expect(r.first.apolice.numero, 'erro');
      expect(r.first.suspeita, true);
      expect(r.skip(1).any((i) => i.suspeita), false);
    });

    test('com poucas apólices não marca nada', () {
      final r = RankingsClientes.maioresApolicesVigentes([ap('a', 100000), ap('b', 50000000)], hoje);
      expect(r.any((i) => i.suspeita), false);
    });

    test('mediana', () {
      expect(RankingsClientes.mediana([3, 1, 2]), 2);
      expect(RankingsClientes.mediana([4, 1, 2, 3]), 2.5);
      expect(RankingsClientes.mediana([]), 0);
    });
  });
}
