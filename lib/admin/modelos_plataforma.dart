// lib/admin/modelos_plataforma.dart — Etapa 21
//
// Dados que a Function "plataforma" devolve ao portal, rótulos e o resumo da
// Visão geral. Sem Firebase: testado em test/modelos_plataforma_test.dart.

import 'package:upgrade_seguros/utils/planos.dart';

class ContaPlataforma {
  final String situacao;
  final String planoNome;
  final String planoTipo;
  final bool cortesia;
  final String observacao;
  final DateTime? testeAte;
  /// Etapa 23: módulos ligados (null = tudo ligado).
  final List<String>? modulos;
  // Etapa 24: plano-modelo (planoTipo 'modelo'), preço, franquias, cortesia com validade
  final String planoId;
  final int precoCentavos;
  final Map<String, Franquia> franquias;
  final DateTime? cortesiaAte;
  /// Etapa 25: teste vencido = 'teste_encerrado' (calculado no servidor).
  final String situacaoEfetiva;
  /// Etapa 27: uso medido (null = nunca medido).
  final UsoConta? uso;

  const ContaPlataforma({
    required this.situacao,
    required this.planoNome,
    required this.planoTipo,
    this.cortesia = false,
    this.observacao = '',
    this.testeAte,
    this.modulos,
    this.planoId = '',
    this.precoCentavos = 0,
    this.franquias = const {},
    this.cortesiaAte,
    String? situacaoEfetiva,
    this.uso,
  }) : situacaoEfetiva = situacaoEfetiva ?? situacao;

  factory ContaPlataforma.deJson(Map<String, dynamic> j) {
    final plano = (j['plano'] is Map) ? Map<String, dynamic>.from(j['plano'] as Map) : const <String, dynamic>{};
    return ContaPlataforma(
      situacao: (j['situacao'] ?? '') as String,
      planoNome: (plano['nome'] ?? '') as String,
      planoTipo: (plano['tipo'] ?? '') as String,
      cortesia: j['cortesia'] == true,
      observacao: (j['observacao'] ?? '') as String,
      testeAte: DateTime.tryParse((j['testeAte'] ?? '') as String),
      modulos: j['modulos'] is List ? [for (final m in j['modulos'] as List) '$m'] : null,
      planoId: (plano['planoId'] ?? '') as String,
      precoCentavos: (plano['precoCentavos'] as num?)?.toInt() ?? 0,
      franquias: Planos.franquiasDe(plano['franquias']),
      cortesiaAte: DateTime.tryParse((j['cortesiaAte'] ?? '') as String)?.toLocal(),
      situacaoEfetiva: (j['situacaoEfetiva'] ?? j['situacao'] ?? '') as String,
      uso: UsoConta.deMapa(j['uso']),
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
      'catalogo_importado' => 'Importou o catálogo de seguradoras',
      'modulos_definidos' => 'Definiu os módulos de uma corretora',
      'plano_criado' => 'Criou plano',
      'plano_editado' => 'Editou plano',
      'plano_excluido' => 'Excluiu plano',
      'plano_da_corretora' => 'Definiu o plano de uma corretora',
      'cadastro_aprovado' => 'Aprovou cadastro de corretora',
      'pedido_recusado' => 'Recusou pedido',
      'pedido_atendido' => 'Atendeu pedido de plano',
      'situacao_definida' => 'Mudou a situação de uma corretora',
      'uso_medido' => 'Mediu o uso das corretoras',
      'seguradora_criada' => 'Criou seguradora',
      'seguradora_aprovada' => 'Aprovou seguradora',
      'seguradora_editada' => 'Editou seguradora',
      'seguradoras_juntadas' => 'Juntou seguradoras',
      'seguradora_recusada' => 'Recusou seguradora',
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
        // Etapa 25: pela situação efetiva (teste vencido aparece como "Teste terminou")
        por[c.conta!.situacaoEfetiva] = (por[c.conta!.situacaoEfetiva] ?? 0) + 1;
      }
      usu += c.usuarios ?? 0;
      atd += (c.sinistros ?? 0) + (c.assistencias ?? 0);
    }
    return ResumoPlataforma(corretoras: lista.length, semConta: sem, porSituacao: por, usuarios: usu, atendimentos: atd);
  }
}

// ── Etapa 24: planos-modelo ──────────────────────────────────────────────────

class PlanoModelo {
  final String id;
  final String nome;
  final String descricao;
  final bool ativo;
  final List<String> modulos;
  final int precoCentavos;
  final Map<String, Franquia> franquias;
  /// Quantas corretoras estão neste plano.
  final int corretoras;

  const PlanoModelo({
    this.id = '',
    required this.nome,
    this.descricao = '',
    this.ativo = true,
    this.modulos = const [],
    this.precoCentavos = 0,
    this.franquias = const {},
    this.corretoras = 0,
  });

  factory PlanoModelo.deJson(Map<String, dynamic> j) => PlanoModelo(
        id: (j['id'] ?? '') as String,
        nome: (j['nome'] ?? '') as String,
        descricao: (j['descricao'] ?? '') as String,
        ativo: j['ativo'] != false,
        modulos: j['modulos'] is List ? [for (final m in j['modulos'] as List) '$m'] : const [],
        precoCentavos: (j['precoCentavos'] as num?)?.toInt() ?? 0,
        franquias: Planos.franquiasDe(j['franquias']),
        corretoras: (j['corretoras'] as num?)?.toInt() ?? 0,
      );
}

// ── Etapa 25: pedidos (autocadastro e contratação) ───────────────────────────

class PedidoPlataforma {
  final String id;
  final String tipo; // cadastro · contratacao
  final String situacao; // pendente · aprovado · recusado · atendido
  final String cnpj;
  final String nomeCorretora;
  final String responsavel;
  final String email;
  final String telefone;
  final String susep;
  final String razaoSocial;
  final String nomeFantasia;
  final String situacaoReceita;
  final String empresaId;
  final String planoNome;
  final String mensagem;
  final String motivo;
  final DateTime? criadoEm;
  final DateTime? resolvidoEm;
  final String resolvidoPor;

  const PedidoPlataforma({
    required this.id,
    required this.tipo,
    required this.situacao,
    this.cnpj = '',
    this.nomeCorretora = '',
    this.responsavel = '',
    this.email = '',
    this.telefone = '',
    this.susep = '',
    this.razaoSocial = '',
    this.nomeFantasia = '',
    this.situacaoReceita = '',
    this.empresaId = '',
    this.planoNome = '',
    this.mensagem = '',
    this.motivo = '',
    this.criadoEm,
    this.resolvidoEm,
    this.resolvidoPor = '',
  });

  bool get pendente => situacao == 'pendente';
  bool get cadastro => tipo == 'cadastro';

  factory PedidoPlataforma.deJson(Map<String, dynamic> j) {
    final r = j['receita'] is Map ? Map<String, dynamic>.from(j['receita'] as Map) : const <String, dynamic>{};
    String s(String k) => (j[k] ?? '') as String;
    return PedidoPlataforma(
      id: s('id'),
      tipo: s('tipo'),
      situacao: s('situacao'),
      cnpj: s('cnpj'),
      nomeCorretora: s('nomeCorretora'),
      responsavel: s('responsavel'),
      email: s('email'),
      telefone: s('telefone'),
      susep: s('susep'),
      razaoSocial: (r['razaoSocial'] ?? '') as String,
      nomeFantasia: (r['nomeFantasia'] ?? '') as String,
      situacaoReceita: (r['situacao'] ?? '') as String,
      empresaId: s('empresaId'),
      planoNome: s('planoNome'),
      mensagem: s('mensagem'),
      motivo: s('motivo'),
      criadoEm: DateTime.tryParse(s('criadoEm'))?.toLocal(),
      resolvidoEm: DateTime.tryParse(s('resolvidoEm'))?.toLocal(),
      resolvidoPor: s('resolvidoPor'),
    );
  }
}

// ── Etapa 22: catálogo global de seguradoras ─────────────────────────────────

class SeguradoraCatalogo {
  final String id;
  final String nome;
  final String cnpj;
  final String razaoSocial;
  final String susep;
  final List<String> apelidos;
  final String situacao; // aprovada · pendente · inativa · juntada · recusada
  final String origem;
  final String situacaoReceita;
  /// 22.1: 'servidor' (conferida pelo servidor) ou 'navegador' (consultada no app)
  final String dadosReceita;
  final String criadaPorCorretora;
  final String criadaPorEmail;
  final DateTime? criadaEm;
  final String juntadaCom;
  final String motivo;

  const SeguradoraCatalogo({
    required this.id,
    required this.nome,
    this.cnpj = '',
    this.razaoSocial = '',
    this.susep = '',
    this.apelidos = const [],
    this.situacao = '',
    this.origem = '',
    this.situacaoReceita = '',
    this.dadosReceita = '',
    this.criadaPorCorretora = '',
    this.criadaPorEmail = '',
    this.criadaEm,
    this.juntadaCom = '',
    this.motivo = '',
  });

  bool get pendente => situacao == 'pendente';
  bool get viva => situacao == 'aprovada' || situacao == 'inativa';

  factory SeguradoraCatalogo.deJson(Map<String, dynamic> j) {
    final por = j['criadaPor'] is Map ? Map<String, dynamic>.from(j['criadaPor'] as Map) : const <String, dynamic>{};
    return SeguradoraCatalogo(
      id: (j['id'] ?? '') as String,
      nome: (j['nome'] ?? '') as String,
      cnpj: (j['cnpj'] ?? '') as String,
      razaoSocial: (j['razaoSocial'] ?? '') as String,
      susep: (j['susep'] ?? '') as String,
      apelidos: [for (final a in (j['apelidos'] as List? ?? const [])) '$a'],
      situacao: (j['situacao'] ?? '') as String,
      origem: (j['origem'] ?? '') as String,
      situacaoReceita: (j['situacaoReceita'] ?? '') as String,
      dadosReceita: (j['dadosReceita'] ?? '') as String,
      criadaPorCorretora: (por['corretora'] ?? '') as String,
      criadaPorEmail: (por['email'] ?? '') as String,
      criadaEm: DateTime.tryParse((j['criadaEm'] ?? '') as String)?.toLocal(),
      juntadaCom: (j['juntadaCom'] ?? '') as String,
      motivo: (j['motivo'] ?? '') as String,
    );
  }
}

/// Apelidos digitados separados por vírgula ou linha → lista limpa, sem repetir.
List<String> lerApelidos(String texto) {
  final vistos = <String>{};
  final r = <String>[];
  for (final p in texto.split(RegExp(r'[,\n]'))) {
    final t = p.trim();
    if (t.isEmpty || !vistos.add(t.toUpperCase())) continue;
    r.add(t);
  }
  return r;
}

String rotuloSituacaoSeguradora(String s) => switch (s) {
      'aprovada' => 'Aprovada',
      'pendente' => 'Aguardando aprovação',
      'inativa' => 'Inativa',
      'juntada' => 'Juntada',
      'recusada' => 'Recusada',
      _ => s,
    };
