// test/modelos_plataforma_test.dart — Etapa 21: dados do portal da plataforma (22: catálogo)
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/admin/modelos_plataforma.dart';

void main() {
  final json = {
    'id': 'C1',
    'nome': 'Upgrade Seguros',
    'cnpj': '54.885.154/0001-37',
    'criadaEm': '2025-03-01T12:00:00.000Z',
    'usuarios': 4,
    'sinistros': 120,
    'assistencias': 30,
    'clientes': 160,
    'conta': {'situacao': 'ativa', 'plano': {'tipo': 'tudo_ligado', 'nome': 'Tudo ligado'}, 'cortesia': true, 'testeAte': null},
  };

  test('corretora a partir do JSON da Function', () {
    final c = CorretoraPlataforma.deJson(json);
    expect(c.nome, 'Upgrade Seguros');
    expect(c.sinistros, 120);
    expect(c.criadaEm!.year, 2025);
    expect(c.conta!.situacao, 'ativa');
    expect(c.conta!.planoNome, 'Tudo ligado');
    expect(c.conta!.cortesia, true);
    expect(c.conta!.testeAte, null);
  });

  test('corretora sem conta e com contagem que falhou (null)', () {
    final c = CorretoraPlataforma.deJson({'id': 'C2', 'nome': '(sem cadastro)', 'usuarios': null, 'conta': null});
    expect(c.conta, null);
    expect(c.usuarios, null);
    expect(c.cnpj, '');
  });

  test('resumo da visão geral', () {
    final r = ResumoPlataforma.de([
      CorretoraPlataforma.deJson(json),
      CorretoraPlataforma.deJson({'id': 'C2', 'nome': 'X', 'usuarios': 2, 'sinistros': 5, 'assistencias': null}),
      CorretoraPlataforma.deJson({'id': 'C3', 'nome': 'Y', 'conta': {'situacao': 'teste'}}),
    ]);
    expect(r.corretoras, 3);
    expect(r.semConta, 1);
    expect(r.porSituacao.length, 2);
    expect(r.porSituacao['ativa'], 1);
    expect(r.porSituacao['teste'], 1);
    expect(r.usuarios, 6);
    expect(r.atendimentos, 155);
  });

  test('rótulos', () {
    expect(rotuloSituacao('teste_encerrado'), 'Teste terminou');
    expect(rotuloSituacao(''), 'Sem conta');
    expect(rotuloAcao('contas_criadas'), 'Criou contas que faltavam');
    expect(rotuloAcao('outra'), 'outra');
  });

  test('auditoria a partir do JSON', () {
    final a = AcaoAuditoria.deJson({'em': '2026-11-24T03:00:00.000Z', 'email': 'adm@x.com', 'acao': 'entrada', 'detalhes': {'ids': ['C1']}});
    expect(a.em!.isUtc, false);
    expect(a.detalhes['ids'], ['C1']);
  });

  test('Etapa 22: seguradora do catálogo a partir do JSON', () {
    final s = SeguradoraCatalogo.deJson({
      'id': 'x',
      'nome': 'MAPFRE',
      'cnpj': '61.223.088/0001-03',
      'apelidos': ['MAPFRE SEGUROS'],
      'situacao': 'pendente',
      'criadaPor': {'empresaId': 'C1', 'email': 'a@b.com', 'corretora': 'Upgrade'},
      'criadaEm': '2026-11-24T10:00:00.000Z',
    });
    expect(s.pendente, true);
    expect(s.viva, false);
    expect(s.criadaPorCorretora, 'Upgrade');
    expect(s.apelidos.length, 1);
    expect(SeguradoraCatalogo.deJson({'id': 'y', 'nome': 'AXA', 'situacao': 'inativa'}).viva, true);
    expect(rotuloSituacaoSeguradora('juntada'), 'Juntada');
    expect(rotuloAcao('seguradoras_juntadas'), 'Juntou seguradoras');
  });

  test('Etapa 22: apelidos digitados', () {
    final a = lerApelidos('AXA SEGUROS, axa seguros,\n  Axa Brasil ,, ');
    expect(a.length, 2);
    expect(a.first, 'AXA SEGUROS');
    expect(a.last, 'Axa Brasil');
  });
}
