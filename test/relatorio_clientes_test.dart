// Testes do relatório de clientes (Etapa 08).
// Rodar no Mac: flutter test test/relatorio_clientes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/relatorio_clientes.dart';

ClienteEntrada cliente(
  String nome, {
  List<double> apolices = const [],
  List<AtendimentoResumo> atendimentos = const [],
}) =>
    ClienteEntrada(
      nome: nome,
      documento: '00.000.000/0001-00',
      apolices: [
        for (var i = 0; i < apolices.length; i++) ApoliceResumo(numero: 'AP-$nome-$i', valor: apolices[i]),
      ],
      atendimentos: atendimentos,
    );

AtendimentoResumo sinistro(double valor, [String status = 'Aberto']) =>
    AtendimentoResumo(tipo: 'sinistro', status: status, valor: valor);
const assistencia = AtendimentoResumo(tipo: 'assistencia', status: 'Concluído', valor: 0);

void main() {
  group('Linhas', () {
    test('ordena pelo valor total das apólices, maior primeiro', () {
      final r = RelatorioClientes.montar([
        cliente('B', apolices: [100]),
        cliente('A', apolices: [5000, 1000]),
        cliente('C'),
      ]);
      expect(r.linhas.map((l) => l.nome).toList(), ['A', 'B', 'C']);
      expect(r.linhas.first.valorApolices, 6000);
      expect(r.linhas.first.qtdApolices, 2);
    });

    test('maior apólice aponta o valor fora da curva', () {
      final r = RelatorioClientes.montar([cliente('X', apolices: [120000.10, 1200001.00, 50000])]);
      expect(r.linhas.single.maiorApoliceValor, 1200001.00);
      expect(r.linhas.single.maiorApoliceNumero, 'AP-X-1');
    });

    test('valor utilizado ignora cancelado e negado, mas a contagem inclui', () {
      final r = RelatorioClientes.montar([
        cliente('X', apolices: [1000], atendimentos: [
          sinistro(100),
          sinistro(50, 'Concluído'),
          sinistro(999, 'Cancelado'),
          sinistro(888, 'Negado'),
          assistencia,
          assistencia,
        ]),
      ]);
      final l = r.linhas.single;
      expect(l.qtdSinistros, 4);
      expect(l.valorUtilizado, 150);
      expect(l.qtdAssistencias, 2);
      expect(l.percentualUsado, closeTo(15, 0.0001));
    });

    test('sem valor de apólice não calcula percentual', () {
      final r = RelatorioClientes.montar([cliente('X', atendimentos: [sinistro(100)])]);
      expect(r.linhas.single.percentualUsado, isNull);
      expect(r.percentualTotal, isNull);
    });
  });

  group('CSV', () {
    test('cabeçalho, número com vírgula, total no final', () {
      final csv = RelatorioClientes.montar([
        cliente('A', apolices: [1234567.891], atendimentos: [sinistro(1000.5)]),
      ]).paraCsv();
      final linhas = csv.split('\r\n');
      expect(linhas[0].startsWith('﻿Cliente;CNPJ/CPF;'), isTrue);
      expect(linhas[1], 'A;00.000.000/0001-00;;;;;;1234567,89;1;AP-A-0;1234567,89;1;1000,50;0,08;0');
      expect(linhas[2].startsWith('TOTAL (1 clientes);;;;;;;1234567,89;1;;;1;1000,50;'), isTrue);
    });

    test('protege ponto e vírgula, aspas e fórmula', () {
      final csv = RelatorioClientes.montar([
        ClienteEntrada(nome: 'Silva; "Filhos"', documento: '=1+1', apolices: const [], atendimentos: const []),
      ]).paraCsv();
      expect(csv.split('\r\n')[1].startsWith('"Silva; ""Filhos""";\'=1+1;'), isTrue);
    });
  });

  test('Etapa 10: recomendação, uso do gatilho e contato vão para o CSV', () {
    final csv = RelatorioClientes.montar([
      const ClienteEntrada(
        nome: 'IURY',
        documento: '04.156.577/0001-48',
        apolices: [ApoliceResumo(numero: 'X', valor: 1000)],
        atendimentos: [],
        recomendacao: 'Não recomendado',
        usoGatilho: 283.4,
        contato: 'Iury',
        telefone: '(27) 99999-0000',
        email: 'iury@ex.com',
      ),
      const ClienteEntrada(nome: 'SEM', documento: '', apolices: [], atendimentos: [], recomendacao: 'Sem apólice vigente'),
    ]).paraCsv();
    final linhas = csv.split('\r\n');
    expect(linhas[1].startsWith('IURY;04.156.577/0001-48;Não recomendado;283,40;Iury;(27) 99999-0000;iury@ex.com;1000,00;'), isTrue);
    expect(linhas[2].startsWith('SEM;;Sem apólice vigente;;;;;0,00;0;'), isTrue);
  });
}
