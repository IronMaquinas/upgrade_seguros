// lib/utils/situacao_conta.dart — Etapa 25: situação da conta da corretora
//
// Mesma conta de functions/conta.js (situacaoEfetiva) e das regras
// (contaGrava): "teste" com a data vencida conta como "teste_encerrado"; teste
// encerrado, suspensa e cancelada só leem.

class SituacaoConta {
  SituacaoConta._();

  static const soLeitura = ['teste_encerrado', 'suspensa', 'cancelada'];

  static String efetiva(String situacao, DateTime? testeAte, {DateTime? agora}) {
    final s = situacao.isEmpty ? 'ativa' : situacao;
    if (s == 'teste' && testeAte != null && testeAte.isBefore(agora ?? DateTime.now())) return 'teste_encerrado';
    return s;
  }

  static bool somenteLeitura(String efetiva) => soLeitura.contains(efetiva);

  /// Dias de teste que faltam depois de hoje (último dia = 0; vencido = 0).
  static int diasRestantes(DateTime testeAte, {DateTime? agora}) {
    final a = agora ?? DateTime.now();
    if (!testeAte.isAfter(a)) return 0;
    final fim = DateTime(testeAte.year, testeAte.month, testeAte.day);
    final hoje = DateTime(a.year, a.month, a.day);
    return fim.difference(hoje).inDays;
  }

  /// Texto do aviso no topo do app ('' = sem aviso).
  static String aviso(String efetiva, DateTime? testeAte, {DateTime? agora}) {
    switch (efetiva) {
      case 'teste':
        if (testeAte == null) return 'Período de teste grátis.';
        final d = diasRestantes(testeAte, agora: agora);
        return d == 0 ? 'Teste grátis: hoje é o último dia.' : d == 1 ? 'Teste grátis: termina amanhã.' : 'Teste grátis: faltam $d dias.';
      case 'teste_encerrado':
        return 'O período de teste terminou. O app está em modo só leitura: dá para consultar, mas não para criar ou alterar.';
      case 'suspensa':
        return 'Conta suspensa. O app está em modo só leitura.';
      case 'cancelada':
        return 'Conta cancelada. O app está em modo só leitura.';
      case 'inadimplente':
        return 'Há um pagamento pendente. Regularize para evitar a suspensão.';
      default:
        return '';
    }
  }
}
