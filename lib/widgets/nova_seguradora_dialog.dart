// lib/widgets/nova_seguradora_dialog.dart — Etapa 22
//
// "Não achou a seguradora? Cadastre pelo CNPJ." O servidor consulta a Receita e
// devolve o nome oficial (nome fantasia ou razão social — a pessoa escolhe qual,
// não digita). Se já existir no catálogo, usa a existente. Se não, entra como
// pendente: esta corretora já pode usar, e a plataforma aprova depois.
//
// abrirNovaSeguradora(context) → nome que ficou no catálogo, ou null.

import 'package:flutter/material.dart';
import 'package:upgrade_seguros/services/catalogo_seguradoras_service.dart';
import 'package:upgrade_seguros/utils/perfil_corretora.dart';

Future<String?> abrirNovaSeguradora(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _NovaSeguradoraDialog(),
  );
}

class _NovaSeguradoraDialog extends StatefulWidget {
  const _NovaSeguradoraDialog();
  @override
  State<_NovaSeguradoraDialog> createState() => _NovaSeguradoraDialogState();
}

class _NovaSeguradoraDialogState extends State<_NovaSeguradoraDialog> {
  final _cnpj = TextEditingController();
  bool _ocupado = false;
  String? _erro;
  ResultadoCnpj? _resultado;
  String? _nomeEscolhido;

  @override
  void dispose() {
    _cnpj.dispose();
    super.dispose();
  }

  Future<void> _consultar() async {
    final c = _cnpj.text.replaceAll(RegExp(r'\D'), '');
    if (!PerfilCorretora.cnpjValido(c)) {
      setState(() => _erro = 'CNPJ inválido — confira os 14 dígitos.');
      return;
    }
    setState(() {
      _ocupado = true;
      _erro = null;
      _resultado = null;
    });
    try {
      final r = await CatalogoSeguradorasService.consultarCnpj(c);
      setState(() {
        _resultado = r;
        _cnpj.text = r.cnpj.isNotEmpty ? r.cnpj : PerfilCorretora.formatarCnpj(c);
        _nomeEscolhido = r.nomeFantasia.isNotEmpty ? r.nomeFantasia : r.razaoSocial;
      });
    } catch (e) {
      setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _adicionar() async {
    final nome = _nomeEscolhido;
    if (nome == null) return;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      final r = await CatalogoSeguradorasService.sugerir(_cnpj.text, nome);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(r.existente
            ? '"${r.nome}" já estava na lista.'
            : '"${r.nome}" adicionada. Já pode usar — fica aguardando a aprovação da plataforma.'),
      ));
      Navigator.pop(context, r.nome);
    } catch (e) {
      setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    final opcoes = r == null ? const <String>[] : {r.nomeFantasia, r.razaoSocial}.where((x) => x.isNotEmpty).toList();
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Nova seguradora pelo CNPJ'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'A lista de seguradoras é a mesma para todas as corretoras. Informe o CNPJ: '
            'o nome vem da Receita Federal.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _cnpj,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CNPJ da seguradora', border: OutlineInputBorder(), isDense: true),
                onSubmitted: (_) => _ocupado ? null : _consultar(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(onPressed: _ocupado ? null : _consultar, child: const Text('Consultar')),
          ]),
          if (_ocupado) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (_erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_erro!, style: const TextStyle(color: Color(0xFFC62828)))),
          if (r != null && r.existenteNome != null) ...[
            const SizedBox(height: 14),
            Text('Essa seguradora já está na lista como "${r.existenteNome}".', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (r != null && r.existenteNome == null) ...[
            const SizedBox(height: 14),
            if (!r.ativaNaReceita)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('⚠️ Situação na Receita: ${r.situacaoReceita}. Confira o CNPJ.', style: const TextStyle(color: Color(0xFFEF6C00))),
              ),
            const Text('Nome que vai aparecer na lista:', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final o in opcoes)
              RadioListTile<String>(
                value: o,
                groupValue: _nomeEscolhido,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(o),
                subtitle: Text(o == r.nomeFantasia ? 'nome fantasia' : 'razão social', style: const TextStyle(fontSize: 11)),
                onChanged: (v) => setState(() => _nomeEscolhido = v),
              ),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _ocupado ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        if (r != null && r.existenteNome != null)
          FilledButton(onPressed: () => Navigator.pop(context, r.existenteNome), child: const Text('Usar esta')),
        if (r != null && r.existenteNome == null)
          FilledButton(onPressed: _ocupado || _nomeEscolhido == null ? null : _adicionar, child: const Text('Adicionar')),
      ],
    );
  }
}
