// lib/admin/financeiro.dart — Etapa 26: contas do painel financeiro do portal
//
// Sem Firebase (testado em test/financeiro_test.dart). Tudo é calculado a partir
// da lista de corretoras que o portal já carrega (conta + plano + nº de usuários):
//
//   mensalidade  = preço do plano + usuários acima da franquia × preço do excedente
//                  (GB e vídeos entram quando houver medição — Etapa 27)
//   cobrável     = situação efetiva "ativa" ou "inadimplente" e sem cortesia valendo
//   MRR          = soma das mensalidades cobráveis (inadimplente entra; o valor em
//                  atraso aparece à parte)
//   cortesia     = vale até cortesiaAte (sem data = sem fim)
//   testes       = potencial: quanto as corretoras em teste pagariam no plano atual

import 'package:upgrade_seguros/utils/planos.dart';

import 'modelos_plataforma.dart';

class LinhaFinanceira {
  final String id;
  final String corretora;
  final String situacao; // efetiva
  final String plano;
  final int baseCentavos;
  final int usuarios;
  final int? usuariosIncluidos; // null = sem limite
  final int usuariosExtras;
  final int extrasCentavos;
  final bool cortesia; // cortesia valendo hoje
  final DateTime? cortesiaAte;
  final DateTime? testeAte;

  const LinhaFinanceira({
    required this.id,
    required this.corretora,
    required this.situacao,
    required this.plano,
    required this.baseCentavos,
    required this.usuarios,
    required this.usuariosIncluidos,
    required this.usuariosExtras,
    required this.extrasCentavos,
    required this.cortesia,
    this.cortesiaAte,
    this.testeAte,
  });

  int get totalCentavos => baseCentavos + extrasCentavos;

  bool get cobravel => !cortesia && (situacao == 'ativa' || situacao == 'inadimplente');
  bool get emTeste => situacao == 'teste';
  bool get testeTerminado => situacao == 'teste_encerrado';
}

class ResumoFinanceiro {
  final List<LinhaFinanceira> linhas;
  final DateTime agora;
  const ResumoFinanceiro(this.linhas, this.agora);

  factory ResumoFinanceiro.de(List<CorretoraPlataforma> corretoras, {DateTime? agora}) {
    final a = agora ?? DateTime.now();
    final linhas = <LinhaFinanceira>[];
    for (final c in corretoras) {
      final conta = c.conta;
      if (conta == null) continue;
      final tudoLigado = conta.planoTipo.isEmpty || conta.planoTipo == 'tudo_ligado';
      final base = tudoLigado ? 0 : conta.precoCentavos;
      final f = tudoLigado ? const Franquia() : (conta.franquias['usuarios'] ?? const Franquia());
      final usuarios = c.usuarios ?? 0;
      final extras = f.semLimite ? 0 : (usuarios - f.incluido!).clamp(0, 1 << 30);
      final cortesiaValendo = conta.cortesia && (conta.cortesiaAte == null || conta.cortesiaAte!.isAfter(a));
      linhas.add(LinhaFinanceira(
        id: c.id,
        corretora: c.nome,
        situacao: conta.situacaoEfetiva,
        plano: conta.planoNome.isEmpty ? 'Tudo ligado' : conta.planoNome,
        baseCentavos: base,
        usuarios: usuarios,
        usuariosIncluidos: f.incluido,
        usuariosExtras: extras,
        extrasCentavos: extras * f.extraCentavos,
        cortesia: cortesiaValendo,
        cortesiaAte: conta.cortesiaAte,
        testeAte: conta.testeAte,
      ));
    }
    linhas.sort((x, y) => y.totalCentavos.compareTo(x.totalCentavos) != 0
        ? y.totalCentavos.compareTo(x.totalCentavos)
        : x.corretora.compareTo(y.corretora));
    return ResumoFinanceiro(linhas, a);
  }

  Iterable<LinhaFinanceira> get pagantes => linhas.where((l) => l.cobravel && l.totalCentavos > 0);

  /// Receita recorrente do mês (estimada pelo plano).
  int get mrrCentavos => pagantes.fold(0, (s, l) => s + l.totalCentavos);

  int get ticketMedioCentavos => pagantes.isEmpty ? 0 : mrrCentavos ~/ pagantes.length;

  Iterable<LinhaFinanceira> get inadimplentes => linhas.where((l) => l.situacao == 'inadimplente' && !l.cortesia);
  int get emAtrasoCentavos => inadimplentes.fold(0, (s, l) => s + l.totalCentavos);

  /// Parte do MRR que vem de usuários acima da franquia.
  int get extrasCentavos => pagantes.fold(0, (s, l) => s + l.extrasCentavos);

  Iterable<LinhaFinanceira> get cortesias => linhas.where((l) => l.cortesia);
  /// Quanto as cortesias pagariam pelo plano (o que deixa de entrar).
  int get cortesiasCentavos => cortesias.fold(0, (s, l) => s + l.totalCentavos);
  Iterable<LinhaFinanceira> get cortesiasVencendo =>
      cortesias.where((l) => l.cortesiaAte != null && l.cortesiaAte!.difference(agora).inDays < 30);

  Iterable<LinhaFinanceira> get testes => linhas.where((l) => l.emTeste);
  Iterable<LinhaFinanceira> get testesAcabando =>
      testes.where((l) => l.testeAte != null && l.testeAte!.difference(agora).inHours < 72);
  Iterable<LinhaFinanceira> get testesTerminados => linhas.where((l) => l.testeTerminado);
  /// Quanto entraria por mês se as corretoras em teste (ou que acabaram de testar) contratassem o plano atual.
  int get potencialTestesCentavos =>
      [...testes, ...testesTerminados].fold(0, (s, l) => s + l.totalCentavos);

  Iterable<LinhaFinanceira> get paradas => linhas.where((l) => l.situacao == 'suspensa' || l.situacao == 'cancelada');

  /// Tabela para colar no Excel / Planilhas (separada por tabulação).
  String tabela() {
    String r(int c) => Planos.reais(c).replaceAll('R\$ ', '');
    final b = StringBuffer('Corretora\tSituação\tPlano\tPreço do plano\tUsuários\tIncluídos\tExtras\tValor extras\tTotal/mês\tCortesia\tCobrável\n');
    for (final l in linhas) {
      b.writeln([
        l.corretora,
        rotuloSituacao(l.situacao),
        l.plano,
        r(l.baseCentavos),
        l.usuarios,
        l.usuariosIncluidos ?? 'sem limite',
        l.usuariosExtras,
        r(l.extrasCentavos),
        r(l.totalCentavos),
        l.cortesia ? 'sim' : 'não',
        l.cobravel ? 'sim' : 'não',
      ].join('\t'));
    }
    return b.toString();
  }
}
