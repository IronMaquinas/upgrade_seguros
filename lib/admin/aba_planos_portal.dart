// lib/admin/aba_planos_portal.dart — Etapa 24: portal → Planos
//
// Planos-modelo (nome, preço, franquias, módulos). Uma corretora entra num
// plano-modelo pelo detalhe dela (Corretoras → corretora → Plano da corretora).
// Editar um plano em uso atualiza as corretoras que estão nele.

import 'package:flutter/material.dart';
import 'package:upgrade_seguros/utils/modulos.dart';

import 'editor_plano.dart';
import 'plataforma_api.dart';

const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);
const _kVermelho = Color(0xFFC62828);

class AbaPlanosPortal extends StatefulWidget {
  const AbaPlanosPortal({super.key});
  @override
  State<AbaPlanosPortal> createState() => _AbaPlanosPortalState();
}

class _AbaPlanosPortalState extends State<AbaPlanosPortal> {
  List<PlanoModelo>? _planos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final p = await PlataformaApi.planos();
      if (mounted) setState(() => _planos = p);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _editar([PlanoModelo? p]) async {
    if (await abrirEditorPlano(context, plano: p)) await _carregar();
  }

  Future<void> _excluir(PlanoModelo p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Excluir "${p.nome}"?'),
        content: const Text('O plano sai da lista. Fica registrado na auditoria.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _kVermelho), onPressed: () => Navigator.pop(d, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await PlataformaApi.planoExcluir(p.id);
      await _carregar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _planos;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Text('Planos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _carregar),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () => _editar(), icon: const Icon(Icons.add, size: 18), label: const Text('Novo plano')),
      ]),
      const SizedBox(height: 6),
      Text('Modelos de plano com preço, franquias e módulos. Para pôr uma corretora num plano: Corretoras → corretora → Plano da corretora. '
          'Além dos modelos, cada corretora pode ficar em "Tudo ligado" ou num plano personalizado só dela.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
      const SizedBox(height: 16),
      if (l == null && _erro == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      if (_erro != null)
        Column(children: [
          Text(_erro!, style: const TextStyle(color: _kVermelho)),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _carregar, child: const Text('Tentar de novo')),
        ]),
      if (l != null && l.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Text('Nenhum plano ainda. Crie o primeiro em "Novo plano" (ex.: Essencial — R\$ 199,00, 5 usuários, R\$ 49,00 por usuário a mais).',
              style: TextStyle(color: Colors.grey.shade700)),
        ),
      if (l != null)
        Wrap(spacing: 14, runSpacing: 14, children: [for (final p in l) _CartaoPlano(p, onEditar: () => _editar(p), onExcluir: () => _excluir(p))]),
    ]);
  }
}

class _CartaoPlano extends StatelessWidget {
  final PlanoModelo p;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;
  const _CartaoPlano(this.p, {required this.onEditar, required this.onExcluir});

  @override
  Widget build(BuildContext context) {
    final mods = Modulos.efetivos(p.modulos);
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.ativo ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p.nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          if (!p.ativo)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              child: const Text('Desativado', style: TextStyle(fontSize: 11)),
            ),
        ]),
        if (p.descricao.isNotEmpty) Text(p.descricao, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
        const SizedBox(height: 10),
        Text(p.precoCentavos > 0 ? '${Planos.reais(p.precoCentavos)}/mês' : 'Sem mensalidade',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _kAzul)),
        const SizedBox(height: 8),
        for (final m in Planos.metricas)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('${m.nome}: ${Planos.descreverFranquia(m, p.franquias[m.id] ?? const Franquia())}', style: const TextStyle(fontSize: 12.5)),
          ),
        const SizedBox(height: 8),
        Text(
          mods.length == Modulos.catalogo.length
              ? 'Todos os módulos'
              : mods.isEmpty
                  ? 'Só o básico'
                  : Modulos.catalogo.where((m) => mods.contains(m.id)).map((m) => m.nome).join(', '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.business, size: 16, color: p.corretoras > 0 ? _kVerde : Colors.grey.shade500),
          const SizedBox(width: 4),
          Text('${p.corretoras} corretora(s)', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800)),
          const Spacer(),
          if (p.corretoras == 0) IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline, size: 20), onPressed: onExcluir),
          TextButton.icon(onPressed: onEditar, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Editar')),
        ]),
      ]),
    );
  }
}
