// lib/admin/aba_beta_portal.dart — Etapa 28: portal → Beta
//
// Uso da assistente no mês: perguntas, quantas precisaram da IA, tokens, custo
// (US$ e R$ pelo câmbio digitado aqui) e teto por corretora; e a lista de
// perguntas que a Beta não soube responder — é dela que saem as próximas
// intenções. O módulo 'beta' é ligado no plano (aba Planos / Plano da corretora).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'plataforma_api.dart';

const _kRoxo = Color(0xFF5E35B1);
const _kVermelho = Color(0xFFC62828);

class AbaBetaPortal extends StatefulWidget {
  const AbaBetaPortal({super.key});
  @override
  State<AbaBetaPortal> createState() => _AbaBetaPortalState();
}

class _AbaBetaPortalState extends State<AbaBetaPortal> {
  Map<String, dynamic>? _r;
  String? _erro;
  bool _verVistas = false;
  final _cambio = TextEditingController(text: '5,50');

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _cambio.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final r = await PlataformaApi.betaResumo();
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  double get _cambioValor => double.tryParse(_cambio.text.replaceAll(',', '.')) ?? 0;
  String _usd(num v) => 'US\$ ${v.toStringAsFixed(v < 1 ? 4 : 2)}';
  String _brl(num v) => Planos.reais((v * _cambioValor * 100).round());

  Future<void> _teto(Map c) async {
    final ctrl = TextEditingController(text: '${c['tetoUsd']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Teto mensal da Beta — ${c['nome']}'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Teto em US\$ por mês', prefixText: 'US\$ ')),
            const SizedBox(height: 8),
            Text('Ao chegar no teto, a Beta para de usar a IA no mês e continua respondendo as perguntas diretas.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salvar')),
        ],
      ),
    );
    final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
    ctrl.dispose();
    if (ok != true || v == null) return;
    try {
      await PlataformaApi.contaDefinirTetoBeta('${c['empresaId']}', v);
      await _carregar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (r == null) {
      return Center(child: _erro == null ? const CircularProgressIndicator() : Text(_erro!, style: const TextStyle(color: _kVermelho)));
    }
    final corretoras = [for (final c in (r['corretoras'] as List? ?? const [])) Map<String, dynamic>.from(c as Map)];
    final perguntas = [for (final p in (r['perguntas'] as List? ?? const [])) Map<String, dynamic>.from(p as Map)]
        .where((p) => _verVistas || p['visto'] != true)
        .toList();
    final nomes = {for (final c in corretoras) '${c['empresaId']}': '${c['nome']}'};
    num soma(String k) => corretoras.fold<num>(0, (s, c) => s + ((c[k] as num?) ?? 0));
    final total = soma('perguntas');
    final comIa = soma('comIa');
    final custo = soma('custoUsd');
    final f = DateFormat('dd/MM HH:mm');

    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Icon(Icons.auto_awesome, color: _kRoxo),
        const SizedBox(width: 8),
        Text('Beta — ${r['mes']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        SizedBox(
          width: 130,
          child: TextField(
            controller: _cambio,
            decoration: const InputDecoration(labelText: 'Câmbio R\$/US\$', isDense: true),
            onChanged: (_) => setState(() {}),
          ),
        ),
        IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _carregar),
      ]),
      const SizedBox(height: 4),
      Text('Modelo ${r['modelo']} · US\$ ${r['precoEntrada']} por milhão de tokens de entrada e US\$ ${r['precoSaida']} de saída '
          '(conferir na tabela da Anthropic) · teto padrão US\$ ${r['tetoPadraoUsd']} por corretora/mês.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _cartao('Perguntas no mês', '$total', Icons.forum_outlined),
        _cartao('Respondidas sem IA', total == 0 ? '–' : '${((total - comIa) / total * 100).round()}%', Icons.bolt),
        _cartao('Custo da IA', '${_usd(custo)}\n${_brl(custo)}', Icons.payments_outlined),
        _cartao('Custo por pergunta', total == 0 ? '–' : _brl(custo / total), Icons.calculate_outlined),
      ]),
      const SizedBox(height: 22),
      const Text('Por corretora', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      if (corretoras.isEmpty) Text('Ninguém usou a Beta neste mês ainda.', style: TextStyle(color: Colors.grey.shade600)),
      if (corretoras.isNotEmpty)
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 22,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Colors.black87),
              dataTextStyle: const TextStyle(fontSize: 12.5, color: Colors.black87),
              columns: const [
                DataColumn(label: Text('Corretora')),
                DataColumn(label: Text('Perguntas'), numeric: true),
                DataColumn(label: Text('Com IA'), numeric: true),
                DataColumn(label: Text('Sem resposta'), numeric: true),
                DataColumn(label: Text('Tokens (entrada/saída)'), numeric: true),
                DataColumn(label: Text('Custo'), numeric: true),
                DataColumn(label: Text('Teto')),
              ],
              rows: [
                for (final c in corretoras)
                  DataRow(cells: [
                    DataCell(Text('${c['nome']}')),
                    DataCell(Text('${c['perguntas']}')),
                    DataCell(Text('${c['comIa']}')),
                    DataCell(Text('${c['semResposta']}')),
                    DataCell(Text('${c['tokensEntrada']} / ${c['tokensSaida']}')),
                    DataCell(Text('${_usd((c['custoUsd'] as num?) ?? 0)} · ${_brl((c['custoUsd'] as num?) ?? 0)}')),
                    DataCell(TextButton(
                      onPressed: () => _teto(c),
                      child: Text('US\$ ${c['tetoUsd']}${((c['custoUsd'] as num?) ?? 0) >= ((c['tetoUsd'] as num?) ?? 0) ? ' ⚠ atingido' : ''}'),
                    )),
                  ]),
              ],
            ),
          ),
        ),
      const SizedBox(height: 22),
      Row(children: [
        const Expanded(child: Text('Perguntas sem resposta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        FilterChip(label: const Text('Mostrar as já vistas'), selected: _verVistas, onSelected: (v) => setState(() => _verVistas = v)),
      ]),
      Text('Fora do escopo ou não encontrado. Mande as frequentes para virar uma intenção nova.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
      const SizedBox(height: 6),
      if (perguntas.isEmpty) Text('Nenhuma.', style: TextStyle(color: Colors.grey.shade600)),
      for (final p in perguntas)
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: SelectableText('${p['pergunta']}'),
            subtitle: Text([
              nomes['${p['empresaId']}'] ?? '${p['empresaId']}',
              '${p['email']}',
              switch ('${p['motivo']}') { 'nao_encontrado' => 'não encontrado', 'sem_assunto' => 'faltou o número', _ => 'fora do escopo' },
              if (p['criadoEm'] != null) f.format(DateTime.parse('${p['criadoEm']}').toLocal()),
            ].join(' · ')),
            trailing: p['visto'] == true
                ? const Icon(Icons.check, color: Colors.grey)
                : TextButton(
                    onPressed: () async {
                      await PlataformaApi.betaPerguntaVista('${p['id']}');
                      await _carregar();
                    },
                    child: const Text('Vista'),
                  ),
          ),
        ),
    ]);
  }

  Widget _cartao(String titulo, String valor, IconData icone) => Container(
        width: 230,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Icon(icone, color: _kRoxo, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valor, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ]),
          ),
        ]),
      );
}
