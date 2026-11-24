// lib/admin/modulos_corretora_dialog.dart — Etapa 23 (módulos) · Etapa 24 (plano completo)
//
// Portal → Corretoras → (corretora) → "Plano da corretora":
//   • Tudo ligado    todos os módulos (fundadoras)
//   • Plano-modelo   um dos planos da aba Planos (preço, franquias e módulos dele)
//   • Personalizado  módulos, preço e franquias só desta corretora
// + cortesia (com validade opcional) e um motivo para o histórico.
// Grava pela Function "plataforma" (histórico + auditoria).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/utils/modulos.dart';

import 'editor_plano.dart';
import 'plataforma_api.dart';

const _kVermelho = Color(0xFFC62828);

/// true = salvou.
Future<bool> abrirPlanoDaCorretora(BuildContext context, CorretoraPlataforma c) async {
  final r = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _PlanoDialog(c));
  return r == true;
}

class _PlanoDialog extends StatefulWidget {
  final CorretoraPlataforma c;
  const _PlanoDialog(this.c);
  @override
  State<_PlanoDialog> createState() => _PlanoDialogState();
}

class _PlanoDialogState extends State<_PlanoDialog> {
  ContaPlataforma get _conta => widget.c.conta!;
  late String _tipo = switch (_conta.planoTipo) { 'modelo' => 'modelo', 'personalizado' => 'personalizado', _ => 'tudo_ligado' };
  late String? _planoId = _conta.planoId.isEmpty ? null : _conta.planoId;
  late Set<String> _modulos = _conta.modulos == null ? Modulos.todos : Modulos.efetivos(_conta.modulos!);
  late final _preco = PrecoFranquiasCtrl(
    precoCentavos: _conta.planoTipo == 'personalizado' ? _conta.precoCentavos : 0,
    franquias: _conta.planoTipo == 'personalizado' ? _conta.franquias : const {},
  );
  late bool _cortesia = _conta.cortesia;
  late DateTime? _cortesiaAte = _conta.cortesiaAte;
  final _motivo = TextEditingController();

  List<PlanoModelo>? _planos;
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    PlataformaApi.planos().then((p) {
      if (mounted) setState(() => _planos = p);
    }).catchError((Object e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    });
  }

  @override
  void dispose() {
    _preco.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _cortesiaAte ?? DateTime(hoje.year, hoje.month + 3, hoje.day),
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: DateTime(hoje.year + 5),
    );
    if (d != null) setState(() => _cortesiaAte = d);
  }

  Future<void> _salvar() async {
    setState(() => _erro = null);
    int? preco;
    Map<String, Franquia>? franquias;
    if (_tipo == 'modelo' && _planoId == null) return setState(() => _erro = 'Escolha o plano.');
    if (_tipo == 'personalizado') {
      try {
        final v = _preco.ler();
        preco = v.precoCentavos;
        franquias = v.franquias;
      } on FormatException catch (e) {
        return setState(() => _erro = e.message);
      }
    }
    setState(() => _salvando = true);
    try {
      await PlataformaApi.contaDefinirPlano(
        widget.c.id,
        tipo: _tipo,
        planoId: _tipo == 'modelo' ? _planoId : null,
        modulos: _tipo == 'personalizado' ? (_modulos.toList()..sort()) : null,
        precoCentavos: preco,
        franquias: franquias,
        cortesia: _cortesia,
        cortesiaAte: _cortesia && _cortesiaAte != null ? DateFormat('yyyy-MM-dd').format(_cortesiaAte!) : null,
        motivo: _motivo.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _opcao(String valor, String titulo, String subtitulo) => RadioListTile<String>(
        value: valor,
        groupValue: _tipo,
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12)),
        onChanged: (v) => setState(() => _tipo = v!),
      );

  @override
  Widget build(BuildContext context) {
    final planos = _planos;
    final escolhido = planos?.where((p) => p.id == _planoId).firstOrNull;
    // Plano desativado só aparece se a corretora já está nele.
    final opcoes = planos?.where((p) => p.ativo || p.id == _conta.planoId).toList() ?? const <PlanoModelo>[];
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Plano — ${widget.c.nome}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _opcao('tudo_ligado', 'Tudo ligado', 'Todos os módulos, inclusive os que forem criados depois. Sem preço (fundadoras).'),
            _opcao('modelo', 'Plano da lista', 'Um dos planos da aba Planos: preço, franquias e módulos vêm dele.'),
            if (_tipo == 'modelo')
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: planos == null
                    ? const LinearProgressIndicator()
                    : opcoes.isEmpty
                        ? Text('Nenhum plano criado ainda — crie na aba Planos.', style: TextStyle(color: Colors.grey.shade700))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            DropdownButton<String>(
                              value: opcoes.any((p) => p.id == _planoId) ? _planoId : null,
                              hint: const Text('Escolha o plano'),
                              isExpanded: true,
                              items: [
                                for (final p in opcoes)
                                  DropdownMenuItem(
                                    value: p.id,
                                    child: Text('${p.nome} — ${Planos.resumo(p.precoCentavos, p.franquias)}${p.ativo ? '' : ' (desativado)'}'),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _planoId = v),
                            ),
                            if (escolhido != null)
                              Text(
                                Modulos.efetivos(escolhido.modulos).length == Modulos.catalogo.length
                                    ? 'Todos os módulos'
                                    : 'Módulos: ${Modulos.catalogo.where((m) => escolhido.modulos.contains(m.id)).map((m) => m.nome).join(', ')}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                          ]),
              ),
            _opcao('personalizado', 'Personalizado', 'Módulos, preço e franquias só desta corretora.'),
            if (_tipo == 'personalizado')
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CamposPrecoFranquias(ctrl: _preco, onChanged: () => setState(() {})),
                  const SizedBox(height: 14),
                  const Text('Módulos', style: TextStyle(fontWeight: FontWeight.w700)),
                  SeletorModulos(marcados: _modulos, onChanged: (m) => setState(() => _modulos = m)),
                ]),
              ),
            const Divider(height: 24),
            Row(children: [
              Checkbox(value: _cortesia, onChanged: (v) => setState(() => _cortesia = v == true)),
              const Text('Cortesia (não cobrar)'),
              if (_cortesia) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _escolherData,
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_cortesiaAte == null ? 'sem data de fim' : 'até ${DateFormat('dd/MM/yyyy').format(_cortesiaAte!)}'),
                ),
                if (_cortesiaAte != null)
                  IconButton(tooltip: 'Tirar a data', icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _cortesiaAte = null)),
              ],
            ]),
            TextField(controller: _motivo, decoration: const InputDecoration(labelText: 'Motivo (vai para o histórico, opcional)', isDense: true)),
            if (_erro != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erro!, style: const TextStyle(color: _kVermelho))),
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
