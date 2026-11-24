// lib/admin/modelos_plataforma.dart — Etapa 21
//
// Dados que a Function "plataforma" devolve ao portal, rótulos e o resumo da
// Visão geral. Sem Firebase: testado em test/modelos_plataforma_test.dart.

class ContaPlataforma {
  final String situacao;
  final String planoNome;
  final String planoTipo;
  final bool cortesia;
  final String observacao;
  final DateTime? testeAte;

  const ContaPlataforma({
    required this.situacao,
    required this.planoNome,
    required this.planoTipo,
    this.cortesia = false,
    this.observacao = '',
    this.testeAte,
  });

  factory ContaPlataforma.deJson(Map<String, dynamic> j) {
    final plano = (j['plano'] is Map) ? Map<String, dynamic>.from(j['plano'] as Map) : const <String, dynamic>{};
    return ContaPlataforma(
      situacao: (j['situacao'] ?? '') as String,
      planoNome: (plano['nome'] ?? '') as String,
      planoTipo: (plano['tipo'] ?? '') as String,
      cortesia: j['cortesia'] == true,
      observacao: (j['observacao'] ?? '') as String,
      testeAte: DateTime.tryParse((j['testeAte'] ?? '') as String),
    );
  }
}

class CorretoraPlataforma {
  final String id;
  final String nome;
  final String razaoSocial;
  final String cnpj;
  final String email;
  final String telefone;
  final DateTime? criadaEm;
  final int? usuarios;
  final int? sinistros;
  final int? assistencias;
  final int? clientes;
  final ContaPlataforma? conta;

  const CorretoraPlataforma({
    required this.id,
    required this.nome,
    this.razaoSocial = '',
    this.cnpj = '',
    this.email = '',
    this.telefone = '',
    this.criadaEm,
    this.usuarios,
    this.sinistros,
    this.assistencias,
    this.clientes,
    this.conta,
  });

  factory CorretoraPlataforma.deJson(Map<String, dynamic> j) => CorretoraPlataforma(
        id: (j['id'] ?? '') as String,
        nome: (j['nome'] ?? '') as String,
        razaoSocial: (j['razaoSocial'] ?? '') as String,
        cnpj: (j['cnpj'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        telefone: (j['telefone'] ?? '') as String,
        criadaEm: DateTime.tryParse((j['criadaEm'] ?? '') as String),
        usuarios: (j['usuarios'] as num?)?.toInt(),
        sinistros: (j['sinistros'] as num?)?.toInt(),
        assistencias: (j['assistencias'] as num?)?.toInt(),
        clientes: (j['clientes'] as num?)?.toInt(),
        conta: j['conta'] is Map ? ContaPlataforma.deJson(Map<String, dynamic>.from(j['conta'] as Map)) : null,
      );
}

class AcaoAuditoria {
  final DateTime? em;
  final String email;
  final String acao;
  final String alvoTipo;
  final String alvoId;
  final Map<String, dynamic> detalhes;

  const AcaoAuditoria({this.em, this.email = '', this.acao = '', this.alvoTipo = '', this.alvoId = '', this.detalhes = const {}});

  factory AcaoAuditoria.deJson(Map<String, dynamic> j) => AcaoAuditoria(
        em: DateTime.tryParse((j['em'] ?? '') as String)?.toLocal(),
        email: (j['email'] ?? '') as String,
        acao: (j['acao'] ?? '') as String,
        alvoTipo: (j['alvoTipo'] ?? '') as String,
        alvoId: (j['alvoId'] ?? '') as String,
        detalhes: j['detalhes'] is Map ? Map<String, dynamic>.from(j['detalhes'] as Map) : const {},
      );
}

/// Rótulos e cores das situações (as mesmas de functions/plataforma.js).
String rotuloSituacao(String s) => switch (s) {
      'teste' => 'Em teste',
      'teste_encerrado' => 'Teste terminou',
      'ativa' => 'Ativa',
      'inadimplente' => 'Inadimplente',
      'suspensa' => 'Suspensa',
      'cancelada' => 'Cancelada',
      '' => 'Sem conta',
      _ => s,
    };

String rotuloAcao(String a) => switch (a) {
      'entrada' => 'Entrou no portal',
      'contas_criadas' => 'Criou contas que faltavam',
      'admin_adicionado' => 'Admin adicionado',
      'admin_removido' => 'Admin removido',
      _ => a,
    };

/// Resumo para a Visão geral.
class ResumoPlataforma {
  final int corretoras;
  final int semConta;
  final Map<String, int> porSituacao;
  final int usuarios;
  final int atendimentos;

  const ResumoPlataforma({
    required this.corretoras,
    required this.semConta,
    required this.porSituacao,
    required this.usuarios,
    required this.atendimentos,
  });

  factory ResumoPlataforma.de(List<CorretoraPlataforma> lista) {
    final por = <String, int>{};
    var sem = 0, usu = 0, atd = 0;
    for (final c in lista) {
      if (c.conta == null) {
        sem++;
      } else {
        por[c.conta!.situacao] = (por[c.conta!.situacao] ?? 0) + 1;
      }
      usu += c.usuarios ?? 0;
      atd += (c.sinistros ?? 0) + (c.assistencias ?? 0);
    }
    return ResumoPlataforma(corretoras: lista.length, semConta: sem, porSituacao: por, usuarios: usu, atendimentos: atd);
  }
}
