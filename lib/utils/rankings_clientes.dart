// lib/utils/rankings_clientes.dart
//
// Etapa 18: rankings da seção CLIENTES dos Relatórios. Regra em Dart puro,
// testada em test/rankings_clientes_test.dart.
//
// • Top 10 clientes por VALOR DE SINISTROS. Antes o card se chamava "Top 10
//   Clientes por Receita" e lia o campo total_receita do cliente, que:
//     – é soma de sinistros (não é receita da corretora);
//     – só era atualizado ao salvar um sinistro pela planilha de abertura
//       (ficava velho);
//     – contava sinistros Cancelados e Negados.
//   Agora soma na hora o valor total dos sinistros do cliente, sem
//   Cancelado/Negado — a mesma regra do "Valor utilizado" do relatório de
//   clientes (lib/utils/relatorio_clientes.dart).
// • Maiores apólices vigentes: as 10 de maior valor, com aviso nas que destoam
//   muito das demais (valor digitado errado, ex.: R$ 10 bilhões).

import 'relatorio_clientes.dart' show RelatorioClientes;

class ClienteRanking {
  final String id;
  final String nome;
  final int qtdApolices;
  const ClienteRanking({required this.id, required this.nome, this.qtdApolices = 0});
}

class SinistroRanking {
  final String idCliente;
  final String tipo; // 'sinistro' ou 'assistencia'
  final String status;
  final double valor;
  const SinistroRanking({required this.idCliente, required this.tipo, required this.status, required this.valor});
}

class ItemRankingSinistros {
  final ClienteRanking cliente;
  final double valor;
  final int qtdSinistros;
  /// % do valor de todos os sinistros (que contam) da carteira.
  final double percentual;
  const ItemRankingSinistros(this.cliente, this.valor, this.qtdSinistros, this.percentual);
}

class ApoliceRanking {
  final String clienteNome;
  final String numero;
  final String ramo;
  final DateTime inicio;
  final DateTime fim;
  final double valor;
  const ApoliceRanking({
    required this.clienteNome,
    required this.numero,
    required this.ramo,
    required this.inicio,
    required this.fim,
    required this.valor,
  });
}

class ItemMaiorApolice {
  final ApoliceRanking apolice;
  /// Valor muito acima das outras apólices vigentes: conferir se foi digitado certo.
  final bool suspeita;
  const ItemMaiorApolice(this.apolice, this.suspeita);
}

class RankingsClientes {
  RankingsClientes._();

  /// Valor que marca "confira": pelo menos [vezesMediana] × a mediana das
  /// apólices vigentes E pelo menos [minimoSuspeito] reais.
  static const vezesMediana = 50.0;
  static const minimoSuspeito = 1000000.0;

  static List<ItemRankingSinistros> porValorSinistros(
    List<ClienteRanking> clientes,
    List<SinistroRanking> sinistros, {
    int limite = 10,
  }) {
    final valor = <String, double>{};
    final qtd = <String, int>{};
    var total = 0.0;
    for (final s in sinistros) {
      if (s.tipo == 'assistencia') continue;
      if (RelatorioClientes.statusQueNaoContam.contains(s.status)) continue;
      if (s.idCliente.isEmpty || s.valor <= 0) continue;
      valor[s.idCliente] = (valor[s.idCliente] ?? 0) + s.valor;
      qtd[s.idCliente] = (qtd[s.idCliente] ?? 0) + 1;
      total += s.valor;
    }
    final lista = [
      for (final c in clientes)
        if ((valor[c.id] ?? 0) > 0)
          ItemRankingSinistros(c, valor[c.id]!, qtd[c.id] ?? 0, total > 0 ? valor[c.id]! / total * 100 : 0),
    ]..sort((a, b) {
        final v = b.valor.compareTo(a.valor);
        return v != 0 ? v : a.cliente.nome.compareTo(b.cliente.nome);
      });
    return lista.take(limite).toList();
  }

  /// Apólices vigentes em [hoje] (início ≤ hoje ≤ fim), da maior para a menor.
  static List<ItemMaiorApolice> maioresApolicesVigentes(
    List<ApoliceRanking> apolices,
    DateTime hoje, {
    int limite = 10,
  }) {
    final dia = DateTime(hoje.year, hoje.month, hoje.day);
    final vigentes = apolices
        .where((a) =>
            a.valor > 0 &&
            !DateTime(a.inicio.year, a.inicio.month, a.inicio.day).isAfter(dia) &&
            !DateTime(a.fim.year, a.fim.month, a.fim.day).isBefore(dia))
        .toList()
      ..sort((a, b) => b.valor.compareTo(a.valor));
    final med = mediana(vigentes.map((a) => a.valor).toList());
    return [
      for (final a in vigentes.take(limite)) ItemMaiorApolice(a, valorSuspeito(a.valor, med, vigentes.length)),
    ];
  }

  static bool valorSuspeito(double valor, double mediana, int quantidade) =>
      quantidade >= 5 && mediana > 0 && valor >= minimoSuspeito && valor >= mediana * vezesMediana;

  static double mediana(List<double> valores) {
    if (valores.isEmpty) return 0;
    final v = [...valores]..sort();
    final m = v.length ~/ 2;
    return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
  }
}
