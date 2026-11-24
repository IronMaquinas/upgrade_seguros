// lib/screens/meu_plano_screen.dart — Etapa 23 · Etapa 24: preço, franquias, cortesia
//
//   • BotaoMeuPlano    atalho na barra do topo (com o nome do plano)
//   • Etapa 25: situação efetiva (teste vencido), planos disponíveis e
//     "Quero este plano" (gestor) → pedido para o portal (Function minhaConta)
//   • MeuPlanoScreen   situação, plano e o que está ligado / fora do plano
//   • ModuloBloqueado  o que aparece no lugar de uma tela fora do plano
//   • abrirMeuPlano    atalho

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/services/auth_service.dart';
import 'package:upgrade_seguros/services/funcoes_nuvem.dart';
import 'package:upgrade_seguros/services/plano_atual.dart';
import 'package:upgrade_seguros/utils/modulos.dart';
import 'package:upgrade_seguros/utils/planos.dart';

const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);

Future<void> abrirMeuPlano(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeuPlanoScreen()));

/// Etapa 24: na barra do topo — botão com o nome do plano (no celular, só o ícone).
class BotaoMeuPlano extends StatelessWidget {
  final bool compacto;
  const BotaoMeuPlano({super.key, this.compacto = false});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PlanoAtual.versao,
      builder: (context, _, __) {
        if (compacto) {
          return IconButton(
            icon: const Icon(Icons.workspace_premium_outlined, color: _kAzul, size: 24),
            tooltip: 'Meu plano: ${PlanoAtual.nomePlano}',
            onPressed: () => abrirMeuPlano(context),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: OutlinedButton.icon(
            onPressed: () => abrirMeuPlano(context),
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            label: Text('Plano: ${PlanoAtual.nomePlano}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _kAzul,
              side: BorderSide(color: _kAzul.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        );
      },
    );
  }
}

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
                        rotuloSituacaoConta(PlanoAtual.situacaoEfetiva), // Etapa 25: teste vencido aparece como terminado
                        if (PlanoAtual.cortesia)
                          PlanoAtual.cortesiaAte == null ? 'cortesia' : 'cortesia até ${f.format(PlanoAtual.cortesiaAte!)}',
                        if (PlanoAtual.testeAte != null) 'teste até ${f.format(PlanoAtual.testeAte!)}',
                      ].join(' · '),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    if (PlanoAtual.descricao.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(PlanoAtual.descricao, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                    ],
                  ]),
                ),
                // Etapa 24: preço
                if (PlanoAtual.precoCentavos > 0)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Planos.reais(PlanoAtual.precoCentavos),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: PlanoAtual.cortesia ? Colors.grey.shade500 : _kAzul,
                          decoration: PlanoAtual.cortesia ? TextDecoration.lineThrough : null,
                        )),
                    Text(PlanoAtual.cortesia ? 'por mês · cortesia' : 'por mês', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ]),
              ]),
            ),
            // Etapa 24: franquias (só as que têm limite)
            if (Planos.metricas.any((m) => !(PlanoAtual.franquias[m.id]?.semLimite ?? true))) ...[
              const SizedBox(height: 18),
              const Text('O plano inclui', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(children: [
                  for (final m in Planos.metricas)
                    if (!(PlanoAtual.franquias[m.id]?.semLimite ?? true))
                      ListTile(
                        dense: true,
                        leading: Icon(
                          switch (m.id) { 'usuarios' => Icons.people_outline, 'gb_video' => Icons.videocam_outlined, _ => Icons.cloud_outlined },
                          color: _kAzul,
                        ),
                        title: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(Planos.descreverFranquia(m, PlanoAtual.franquias[m.id]!)),
                      ),
                ]),
              ),
            ],
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
            // Etapa 25: planos disponíveis + pedido (só o gestor)
            const _PlanosDisponiveis(),
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

// ── Etapa 25: planos disponíveis e "Quero este plano" ────────────────────────

class _PlanosDisponiveis extends StatefulWidget {
  const _PlanosDisponiveis();
  @override
  State<_PlanosDisponiveis> createState() => _PlanosDisponiveisState();
}

class _PlanosDisponiveisState extends State<_PlanosDisponiveis> {
  bool? _gestor;
  List<Map<String, dynamic>>? _planos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final gestor = await AuthService().isAdmin();
    if (!mounted) return;
    setState(() => _gestor = gestor);
    if (!gestor) return;
    try {
      final r = await FuncoesNuvem.post('minhaConta', {'acao': 'planos'});
      if (r.statusCode != 200) throw Exception(FuncoesNuvem.erro(r));
      final j = jsonDecode(r.body) as Map;
      if (mounted) setState(() => _planos = [for (final p in (j['planos'] as List)) Map<String, dynamic>.from(p as Map)]);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _pedir({String? planoId, String? nome}) async {
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(nome == null ? 'Falar sobre o meu plano' : 'Quero o plano $nome'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: msg,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Mensagem (opcional)', hintText: 'Ex.: melhor horário para contato, dúvidas…'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enviar pedido')),
        ],
      ),
    );
    final texto = msg.text.trim();
    msg.dispose();
    if (ok != true || !mounted) return;
    try {
      final r = await FuncoesNuvem.post('minhaConta', {'acao': 'pedirPlano', 'planoId': planoId ?? '', 'mensagem': texto});
      if (r.statusCode != 200) throw Exception(FuncoesNuvem.erro(r));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pedido enviado. Vamos entrar em contato pelo seu e-mail.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível enviar: ${'$e'.replaceFirst('Exception: ', '')}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rodape = Text(
      _gestor == true ? 'Dúvidas sobre o plano? Use "Falar sobre o meu plano".' : 'Para mudar o plano, fale com o gestor da sua corretora.',
      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
    );
    if (_gestor != true) return Padding(padding: const EdgeInsets.only(top: 18), child: rodape);
    final planos = _planos;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(child: Text('Planos disponíveis', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)))),
        TextButton.icon(
          onPressed: () => _pedir(),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: const Text('Falar sobre o meu plano'),
        ),
      ]),
      const SizedBox(height: 6),
      if (_erro != null) Text(_erro!, style: const TextStyle(color: Color(0xFFC62828), fontSize: 12.5)),
      if (planos == null && _erro == null) const LinearProgressIndicator(),
      if (planos != null && planos.isEmpty) Text('Nenhum plano publicado ainda.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
      if (planos != null)
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (final p in planos) _cartaoPlano(p),
        ]),
      const SizedBox(height: 14),
      rodape,
    ]);
  }

  Widget _cartaoPlano(Map<String, dynamic> p) {
    final id = '${p['id'] ?? ''}';
    final atual = PlanoAtual.tipo == 'modelo' && PlanoAtual.planoId == id;
    final preco = (p['precoCentavos'] as num?)?.toInt() ?? 0;
    final f = Planos.franquiasDe(p['franquias']);
    final mods = Modulos.efetivos([for (final m in (p['modulos'] as List? ?? const [])) '$m']);
    return Container(
      width: 300,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: atual ? _kAzul : Colors.grey.shade200, width: atual ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${p['nome'] ?? ''}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if ('${p['descricao'] ?? ''}'.isNotEmpty) Text('${p['descricao']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        Text(preco > 0 ? '${Planos.reais(preco)}/mês' : 'Sem mensalidade', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _kAzul)),
        const SizedBox(height: 4),
        for (final m in Planos.metricas)
          if (!(f[m.id]?.semLimite ?? true)) Text('${m.nome}: ${Planos.descreverFranquia(m, f[m.id]!)}', style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          mods.length == Modulos.catalogo.length
              ? 'Todos os módulos'
              : mods.isEmpty
                  ? 'Só o básico'
                  : Modulos.catalogo.where((m) => mods.contains(m.id)).map((m) => m.nome).join(', '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: atual
              ? const Text('Seu plano atual', style: TextStyle(color: _kAzul, fontWeight: FontWeight.w600))
              : FilledButton(onPressed: () => _pedir(planoId: id, nome: '${p['nome']}'), child: const Text('Quero este plano')),
        ),
      ]),
    );
  }
}
