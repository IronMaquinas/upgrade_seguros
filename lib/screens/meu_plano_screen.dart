// lib/screens/meu_plano_screen.dart — Etapa 23
//
//   • MeuPlanoScreen   situação, plano e o que está ligado / fora do plano
//   • ModuloBloqueado  o que aparece no lugar de uma tela fora do plano
//   • abrirMeuPlano    atalho

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/services/plano_atual.dart';
import 'package:upgrade_seguros/utils/modulos.dart';

const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);

Future<void> abrirMeuPlano(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeuPlanoScreen()));

String rotuloSituacaoConta(String s) => switch (s) {
      'teste' => 'Em teste',
      'teste_encerrado' => 'Teste terminou',
      'ativa' => 'Ativa',
      'inadimplente' => 'Pagamento pendente',
      'suspensa' => 'Suspensa',
      'cancelada' => 'Cancelada',
      _ => 'Ativa',
    };

class MeuPlanoScreen extends StatelessWidget {
  const MeuPlanoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy');
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Meu plano'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: PlanoAtual.versao,
        builder: (context, _, __) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                const Icon(Icons.workspace_premium_outlined, color: _kAzul, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(PlanoAtual.nomePlano, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        rotuloSituacaoConta(PlanoAtual.situacao),
                        if (PlanoAtual.cortesia) 'cortesia',
                        if (PlanoAtual.testeAte != null) 'teste até ${f.format(PlanoAtual.testeAte!)}',
                      ].join(' · '),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Sempre incluído: Início, Sinistros, Clientes e apólices, Configurações e Usuários.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            for (final area in Modulos.areas) ...[
              const SizedBox(height: 18),
              Text(area, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              for (final m in Modulos.catalogo.where((m) => m.area == area))
                Card(
                  color: Colors.white,
                  surfaceTintColor: Colors.transparent,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(
                      PlanoAtual.tem(m.id) ? Icons.check_circle : Icons.lock_outline,
                      color: PlanoAtual.tem(m.id) ? _kVerde : Colors.grey.shade500,
                    ),
                    title: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(m.descricao, style: const TextStyle(fontSize: 12.5)),
                    trailing: Text(PlanoAtual.tem(m.id) ? 'Incluído' : 'Fora do plano',
                        style: TextStyle(fontSize: 12, color: PlanoAtual.tem(m.id) ? _kVerde : Colors.grey.shade600)),
                  ),
                ),
            ],
            const SizedBox(height: 18),
            Text('Para mudar o plano, fale com o suporte da plataforma.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

/// No lugar de uma tela cujo módulo está fora do plano.
class ModuloBloqueado extends StatelessWidget {
  final String modulo;
  /// true = ocupa a tela toda (menu); false = cartão dentro de outra tela.
  final bool telaInteira;
  const ModuloBloqueado(this.modulo, {super.key, this.telaInteira = true});

  @override
  Widget build(BuildContext context) {
    final m = Modulos.porId(modulo);
    final conteudo = Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.lock_outline, size: telaInteira ? 44 : 28, color: Colors.grey.shade500),
      const SizedBox(height: 10),
      Text('"${m?.nome ?? modulo}" não está no seu plano', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
      if (m != null) ...[
        const SizedBox(height: 4),
        Text(m.descricao, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
      ],
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => abrirMeuPlano(context),
        icon: const Icon(Icons.workspace_premium_outlined, size: 18),
        label: const Text('Ver meu plano'),
      ),
    ]);
    if (!telaInteira) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
        child: conteudo,
      );
    }
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: conteudo)));
  }
}

/// Mensagem padrão para botão de um módulo fora do plano.
void avisarForaDoPlano(BuildContext context, String modulo) {
  final m = Modulos.porId(modulo);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text('"${m?.nome ?? modulo}" não está no seu plano.'),
    action: SnackBarAction(label: 'Ver meu plano', onPressed: () => abrirMeuPlano(context)),
  ));
}
