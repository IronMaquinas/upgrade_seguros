// lib/admin/modulos_corretora_dialog.dart — Etapa 23
//
// Portal → Corretoras → (corretora) → "Módulos do plano": "Tudo ligado" ou
// escolher módulo a módulo. Marcar um módulo marca o que ele exige (NPS →
// Assistências); desmarcar tira o que dependia dele. Grava pela Function
// "plataforma" (histórico + auditoria).

import 'package:flutter/material.dart';
import 'package:upgrade_seguros/utils/modulos.dart';

import 'plataforma_api.dart';

/// true = salvou.
Future<bool> abrirModulosDaCorretora(BuildContext context, CorretoraPlataforma c) async {
  final r = await showDialog<bool>(context: context, builder: (_) => _ModulosDialog(c));
  return r == true;
}

class _ModulosDialog extends StatefulWidget {
  final CorretoraPlataforma c;
  const _ModulosDialog(this.c);
  @override
  State<_ModulosDialog> createState() => _ModulosDialogState();
}

class _ModulosDialogState extends State<_ModulosDialog> {
  late bool _tudo = widget.c.conta?.modulos == null;
  late Set<String> _marcados = widget.c.conta?.modulos == null ? Modulos.todos : Modulos.efetivos(widget.c.conta!.modulos!);
  bool _salvando = false;
  String? _erro;

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await PlataformaApi.contaDefinirModulos(widget.c.id, _tudo ? null : (_marcados.toList()..sort()));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Módulos — ${widget.c.nome}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            RadioListTile<bool>(
              value: true,
              groupValue: _tudo,
              contentPadding: EdgeInsets.zero,
              title: const Text('Tudo ligado'),
              subtitle: const Text('Todos os módulos, inclusive os que forem criados depois.'),
              onChanged: (v) => setState(() => _tudo = true),
            ),
            RadioListTile<bool>(
              value: false,
              groupValue: _tudo,
              contentPadding: EdgeInsets.zero,
              title: const Text('Escolher os módulos'),
              onChanged: (v) => setState(() => _tudo = false),
            ),
            if (!_tudo) ...[
              Text('Sempre incluído: Início, Sinistros, Clientes e apólices, Configurações e Usuários.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              for (final area in Modulos.areas) ...[
                const SizedBox(height: 10),
                Text(area, style: const TextStyle(fontWeight: FontWeight.w700)),
                for (final m in Modulos.catalogo.where((m) => m.area == area))
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _marcados.contains(m.id),
                    title: Text(m.nome),
                    subtitle: Text(
                      m.dependeDe.isEmpty ? m.descricao : '${m.descricao} (exige ${m.dependeDe.map((d) => Modulos.porId(d)!.nome).join(', ')})',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onChanged: (v) => setState(() => _marcados = v == true ? Modulos.marcar(_marcados, m.id) : Modulos.desmarcar(_marcados, m.id)),
                  ),
              ],
            ],
            if (_erro != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erro!, style: const TextStyle(color: Color(0xFFC62828)))),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _salvando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _salvar, child: Text(_salvando ? 'Salvando…' : 'Salvar')),
      ],
    );
  }
}
