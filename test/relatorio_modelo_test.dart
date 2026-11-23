// test/relatorio_modelo_test.dart — Etapa 19b
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/utils/relatorio_modelo.dart';

RegistroRelatorio reg(String id, DateTime abertura,
        {String tipo = 'assistencia',
        String status = 'Concluído',
        String cliente = 'AB',
        String tipoAt = 'Guincho',
        double valor = 0,
        String placa = 'ABC1D23'}) =>
    RegistroRelatorio(
      id: id,
      tipo: tipo,
      dataAbertura: abertura,
      dataOcorrencia: abertura.subtract(const Duration(days: 1)),
      status: status,
      clienteId: cliente,
      clienteNome: 'Cliente $cliente',
      tipoAtendimento: tipoAt,
      valores: {
        'numero': id,
        'data_abertura': abertura,
        'placa': placa,
        'tipo_atendimento': tipoAt,
        'valor_total': valor,
        'houve_terceiro': false,
        'terceiros_nomes': ['João', '', 'Maria'],
        'qtd_lancamentos': 2,
      },
    );

void main() {
  group('catálogo e modelo', () {
    test('campos por tipo: assistência não tem terceiros; sinistro não tem destino', () {
      final a = CatalogoRelatorio.paraTipo('assistencia').map((c) => c.id).toSet();
      final s = CatalogoRelatorio.paraTipo('sinistro').map((c) => c.id).toSet();
      expect(a.contains('destino'), true);
      expect(a.contains('houve_terceiro'), false);
      expect(s.contains('houve_terceiro'), true);
      expect(s.contains('destino'), false);
      expect(CatalogoRelatorio.porSecao('assistencia').containsKey('Terceiros'), false);
    });
    test('ids únicos', () {
      final ids = CatalogoRelatorio.todos.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });
    test('modelo ignora campo de outro tipo ou que não existe; valida', () {
      const m = ModeloRelatorio(nome: 'X', tipo: 'assistencia', campos: ['numero', 'houve_terceiro', 'nao_existe', 'valor_total']);
      expect(m.camposValidos.map((c) => c.id).toList(), ['numero', 'valor_total']);
      expect(m.validar(), null);
      expect(const ModeloRelatorio(nome: ' ', tipo: 'sinistro', campos: ['numero']).validar() != null, true);
      expect(const ModeloRelatorio(nome: 'A', tipo: 'sinistro', campos: []).validar() != null, true);
    });
    test('toMap / fromMap', () {
      const m = ModeloRelatorio(nome: 'Águia Branca', tipo: 'assistencia', campos: ['numero', 'placa']);
      final de = ModeloRelatorio.fromMap('id1', m.toMap());
      expect(de.id, 'id1');
      expect(de.nome, 'Águia Branca');
      expect(de.campos, ['numero', 'placa']);
    });
  });

  group('largura do PDF', () {
    List<CampoRelatorio> campos(List<String> ids) => [for (final i in ids) CatalogoRelatorio.porId(i)!];
    test('modelo simples cabe em tabela', () {
      expect(OcupacaoPdf.de(campos(CatalogoRelatorio.padrao('assistencia'))).layout, LayoutPdf.tabela);
    });
    test('muitos campos → ficha', () {
      final todos = CatalogoRelatorio.paraTipo('sinistro');
      expect(OcupacaoPdf.de(todos).layout, LayoutPdf.ficha);
      expect(OcupacaoPdf.de(todos).percentual > 100, true);
    });
    test('faixa intermediária → tabela compacta', () {
      expect(const OcupacaoPdf(14).layout, LayoutPdf.tabelaCompacta);
      expect(const OcupacaoPdf(13).layout, LayoutPdf.tabela);
      expect(const OcupacaoPdf(16.1).layout, LayoutPdf.ficha);
    });
  });

  group('filtro e montagem', () {
    const modelo = ModeloRelatorio(
      nome: 'Mensal',
      tipo: 'assistencia',
      campos: ['numero', 'data_abertura', 'placa', 'tipo_atendimento', 'valor_total'],
    );
    final todos = [
      reg('A3', DateTime(2026, 11, 20, 14, 5), valor: 430),
      reg('A1', DateTime(2026, 11, 2, 8, 0), valor: 350, tipoAt: 'Vidro'),
      reg('A2', DateTime(2026, 10, 31, 23, 0), valor: 999), // outubro
      reg('A4', DateTime(2026, 11, 10), valor: 100, cliente: 'XY'),
      reg('S1', DateTime(2026, 11, 5), tipo: 'sinistro', valor: 5000),
    ];

    test('mês, cliente e tipo: filtra, ordena pela data e soma', () {
      final r = RelatorioMontado.montar(
        modelo,
        todos,
        FiltroRelatorio(de: DateTime(2026, 11, 1), ate: DateTime(2026, 11, 30), clienteId: 'AB'),
      );
      expect(r.registros.map((x) => x.id).toList(), ['A1', 'A3']);
      expect(r.totais['valor_total'], 780);
      expect(r.linhas[0], ['A1', '02/11/2026 08:00', 'ABC1D23', 'Vidro', 'R\$ 350,00']);
      expect(r.linhaTotal, ['TOTAL (2)', '', '', '', 'R\$ 780,00']);
    });

    test('inclui o último dia do período inteiro', () {
      final r = RelatorioMontado.montar(modelo, todos, FiltroRelatorio(de: DateTime(2026, 10, 31), ate: DateTime(2026, 10, 31)));
      expect(r.registros.map((x) => x.id).toList(), ['A2']);
    });

    test('status e tipo de atendimento', () {
      final lista = [...todos, reg('A5', DateTime(2026, 11, 3), status: 'Cancelado', valor: 50)];
      final r = RelatorioMontado.montar(modelo, lista, const FiltroRelatorio(status: {'Cancelado'}));
      expect(r.registros.single.id, 'A5');
      final r2 = RelatorioMontado.montar(modelo, todos, const FiltroRelatorio(tipoAtendimento: 'Vidro'));
      expect(r2.registros.single.id, 'A1');
    });

    test('data da ocorrência × abertura', () {
      // A1: abertura 02/11, ocorrência 01/11
      final pelaAbertura = RelatorioMontado.montar(modelo, todos, FiltroRelatorio(de: DateTime(2026, 11, 1), ate: DateTime(2026, 11, 1)));
      final pelaOcorrencia = RelatorioMontado.montar(modelo, todos,
          FiltroRelatorio(de: DateTime(2026, 11, 1), ate: DateTime(2026, 11, 1), pelaOcorrencia: true));
      expect(pelaAbertura.quantidade, 0);
      expect(pelaOcorrencia.registros.single.id, 'A1');
    });

    test('CSV: ; , BOM, valor em número e linha de total', () {
      final r = RelatorioMontado.montar(
          modelo, todos, FiltroRelatorio(de: DateTime(2026, 11, 1), ate: DateTime(2026, 11, 30), clienteId: 'AB'));
      final csv = r.paraCsv();
      expect(csv.startsWith('﻿'), true);
      final linhas = csv.substring(1).trim().split('\n');
      expect(linhas[0], 'Nº da ocorrência;Abertura (data e hora);Placa;Tipo;Valor total');
      expect(linhas[1], 'A1;02/11/2026 08:00;ABC1D23;Vidro;350,00');
      expect(linhas.last, 'TOTAL (2);;;;780,00');
    });

    test('descrição do filtro', () {
      final f = FiltroRelatorio(de: DateTime(2026, 11, 1), ate: DateTime(2026, 11, 30), clienteId: 'AB', status: const {'Concluído'});
      expect(f.descrever(nomeCliente: 'Águia Branca'), 'Abertura: 01/11/2026 a 30/11/2026 · Cliente: Águia Branca · Status: Concluído');
    });
  });

  group('formatação', () {
    CampoRelatorio c(String id) => CatalogoRelatorio.porId(id)!;
    test('moeda, sim/não, listas', () {
      expect(RelatorioMontado.moeda(1234567.891), 'R\$ 1.234.567,89');
      expect(RelatorioMontado.moeda(0), 'R\$ 0,00');
      expect(RelatorioMontado.formatar(c('houve_terceiro'), true), 'Sim');
      expect(RelatorioMontado.formatar(c('terceiros_nomes'), ['João', '', 'Maria']), 'João; Maria');
      expect(RelatorioMontado.formatar(c('qtd_lancamentos'), 2), '2');
      expect(RelatorioMontado.formatar(c('placa'), null), '');
    });
    test('tipo de assistência', () {
      expect(rotuloTipoAssistencia('guincho'), 'Guincho');
      expect(rotuloTipoAssistencia('vidro:para_brisa,lateral'), 'Vidro (para-brisa, lateral)');
      expect(rotuloTipoAssistencia('outro', outro: 'Chave presa'), 'Outro: Chave presa');
      expect(rotuloTipoAssistencia('reparo_equipamentos'), 'Reparo de equipamentos');
      expect(rotuloTipoAssistencia('algo_novo'), 'Algo novo');
      expect(rotuloTipoAssistencia(''), '');
    });
  });

  group('19b.1: cliente e nome do arquivo', () {
    const clientes = [
      ClienteDoRelatorio('1', 'Águia Branca Transportes', '12.345.678/0001-90'),
      ClienteDoRelatorio('2', 'JPC LOG LTDA', '98765432000110'),
      ClienteDoRelatorio('3', 'Aguiar Comércio', ''),
    ];
    test('busca por nome sem acento e sem maiúscula', () {
      expect(ClienteDoRelatorio.buscar(clientes, 'aguia br').map((c) => c.id).toList(), ['1']);
      expect(ClienteDoRelatorio.buscar(clientes, 'AGUI').map((c) => c.id).toList(), ['1', '3']);
      expect(ClienteDoRelatorio.buscar(clientes, 'log').single.id, '2');
    });
    test('busca pelo CNPJ com ou sem pontuação', () {
      expect(ClienteDoRelatorio.buscar(clientes, '12345678').single.id, '1');
      expect(ClienteDoRelatorio.buscar(clientes, '98.765').single.id, '2');
      expect(ClienteDoRelatorio.buscar(clientes, '').isEmpty, true);
    });
    test('nome do arquivo: cliente - modelo - data', () {
      expect(nomeDoRelatorio(cliente: 'Águia Branca', modelo: 'Mensal ', quando: DateTime(2026, 11, 3)),
          'Águia Branca - Mensal - 2026-11-03');
      expect(nomeDoRelatorio(modelo: 'Mensal', quando: DateTime(2026, 11, 3)), 'Todos os clientes - Mensal - 2026-11-03');
    });
    test('descrição sem o cliente quando ele vai em linha própria', () {
      final f = FiltroRelatorio(de: DateTime(2026, 11, 1), ate: DateTime(2026, 11, 30), clienteId: 'AB');
      expect(f.descrever(incluirCliente: false), 'Abertura: 01/11/2026 a 30/11/2026');
    });
  });
}
