// lib/admin/editor_plano.dart — Etapa 24
//
// Peças do portal para montar um plano:
//   • SeletorModulos       caixas por área (marcar NPS marca Assistências etc.)
//   • PrecoFranquiasCtrl   + CamposPrecoFranquias: preço mensal e franquias
//   • abrirEditorPlano     criar / editar um plano-modelo (aba Planos)

import 'package:flutter/material.dart';
import 'package:upgrade_seguros/utils/modulos.dart';

import 'plataforma_api.dart';

const _kVermelho = Color(0xFFC62828);

class SeletorModulos extends StatelessWidget {
  final Set<String> marcados;
  final ValueChanged<Set<String>> onChanged;
  const SeletorModulos({super.key, required this.marcados, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('Sempre incluído: Início, Sinistros, Clientes e apólices, Configurações e Usuários.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ),
        TextButton(onPressed: () => onChanged(Modulos.todos), child: const Text('Marcar todos')),
        TextButton(onPressed: () => onChanged(<String>{}), child: const Text('Nenhum')),
      ]),
      for (final area in Modulos.areas) ...[
        const SizedBox(height: 8),
        Text(area, style: const TextStyle(fontWeight: FontWeight.w700)),
        for (final m in Modulos.catalogo.where((m) => m.area == area))
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: marcados.contains(m.id),
            title: Text(m.nome),
            subtitle: Text(
              m.dependeDe.isEmpty ? m.descricao : '${m.descricao} (exige ${m.dependeDe.map((d) => Modulos.porId(d)!.nome).join(', ')})',
              style: const TextStyle(fontSize: 11.5),
            ),
            onChanged: (v) => onChanged(v == true ? Modulos.marcar(marcados, m.id) : Modulos.desmarcar(marcados, m.id)),
          ),
      ],
    ]);
  }
}

/// Campos de preço e franquias (texto) e a leitura para centavos/quantidades.
class PrecoFranquiasCtrl {
  final TextEditingController preco;
  final Map<String, TextEditingController> incluido = {};
  final Map<String, TextEditingController> extra = {};
  final Map<String, bool> semLimite = {};

  PrecoFranquiasCtrl({int precoCentavos = 0, Map<String, Franquia> franquias = const {}})
      : preco = TextEditingController(text: precoCentavos == 0 ? '' : Planos.textoDosCentavos(precoCentavos)) {
    for (final m in Planos.metricas) {
      final f = franquias[m.id] ?? const Franquia();
      semLimite[m.id] = f.semLimite;
      incluido[m.id] = TextEditingController(text: f.incluido?.toString() ?? '');
      extra[m.id] = TextEditingController(text: f.extraCentavos == 0 ? '' : Planos.textoDosCentavos(f.extraCentavos));
    }
  }

  void dispose() {
    preco.dispose();
    for (final c in [...incluido.values, ...extra.values]) {
      c.dispose();
    }
  }

  /// Lança [FormatException] com a mensagem para o usuário.
  ({int precoCentavos, Map<String, Franquia> franquias}) ler() {
    final p = Planos.centavosDoTexto(preco.text);
    if (p == null) throw const FormatException('Preço mensal inválido (ex.: 199,90).');
    final f = <String, Franquia>{};
    for (final m in Planos.metricas) {
      if (semLimite[m.id] == true) {
        f[m.id] = const Franquia();
        continue;
      }
      final n = int.tryParse(incluido[m.id]!.text.trim());
      if (n == null || n < 0) throw FormatException('${m.nome}: informe a quantidade incluída ou marque "sem limite".');
      final e = Planos.centavosDoTexto(extra[m.id]!.text);
      if (e == null) throw FormatException('${m.nome}: valor do excedente inválido.');
      f[m.id] = Franquia(incluido: n, extraCentavos: e);
    }
    return (precoCentavos: p, franquias: f);
  }
}

class CamposPrecoFranquias extends StatelessWidget {
  final PrecoFranquiasCtrl ctrl;
  final VoidCallback onChanged;
  const CamposPrecoFranquias({super.key, required this.ctrl, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 200,
        child: TextField(
          controller: ctrl.preco,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Preço mensal', prefixText: 'R\$ ', hintText: '0,00', isDense: true),
        ),
      ),
      const SizedBox(height: 14),
      const Text('Franquias', style: TextStyle(fontWeight: FontWeight.w700)),
      Text('O que o plano inclui e quanto custa cada unidade a mais. A medição de GB e vídeos entra numa próxima etapa.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      for (final m in Planos.metricas)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: 170, child: Text(m.nome, style: const TextStyle(fontSize: 13))),
            SizedBox(
              width: 120,
              child: CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: ctrl.semLimite[m.id],
                title: const Text('sem limite', style: TextStyle(fontSize: 12)),
                onChanged: (v) {
                  ctrl.semLimite[m.id] = v == true;
                  onChanged();
                },
              ),
            ),
            if (ctrl.semLimite[m.id] != true) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: ctrl.incluido[m.id],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: m.id == 'usuarios' ? 'Incluídos' : 'GB incluídos', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: ctrl.extra[m.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Por ${m.unidade} a mais', prefixText: 'R\$ ', isDense: true),
                ),
              ),
            ],
          ]),
        ),
    ]);
  }
}

/// Criar ([plano] null) ou editar um plano-modelo. true = salvou.
Future<bool> abrirEditorPlano(BuildContext context, {PlanoModelo? plano}) async {
  final r = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => _EditorPlano(plano));
  return r == true;
}

class _EditorPlano extends StatefulWidget {
  final PlanoModelo? plano;
  const _EditorPlano(this.plano);
  @override
  State<_EditorPlano> createState() => _EditorPlanoState();
}

class _EditorPlanoState extends State<_EditorPlano> {
  late final _nome = TextEditingController(text: widget.plano?.nome ?? '');
  late final _descricao = TextEditingController(text: widget.plano?.descricao ?? '');
  late bool _ativo = widget.plano?.ativo ?? true;
  late Set<String> _modulos = widget.plano == null ? Modulos.todos : Modulos.efetivos(widget.plano!.modulos);
  late final _preco = PrecoFranquiasCtrl(
    precoCentavos: widget.plano?.precoCentavos ?? 0,
    franquias: widget.plano?.franquias ?? const {},
  );
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    _preco.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return setState(() => _erro = 'Informe o nome do plano.');
    final ({int precoCentavos, Map<String, Franquia> franquias}) v;
    try {
      v = _preco.ler();
    } on FormatException catch (e) {
      return setState(() => _erro = e.message);
    }
    final emUso = widget.plano?.corretoras ?? 0;
    if (emUso > 0) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('Plano em uso'),
          content: Text('$emUso corretora(s) estão neste plano. Preço, franquias e módulos mudam para elas também '
              '(fica no histórico de cada uma).'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salvar mesmo assim')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final n = await PlataformaApi.planoSalvar(
        id: widget.plano?.id,
        nome: nome,
        descricao: _descricao.text.trim(),
        ativo: _ativo,
        modulos: _modulos.toList()..sort(),
        precoCentavos: v.precoCentavos,
        franquias: v.franquias,
      );
      if (!mounted) return;
      if (n > 0) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n corretora(s) atualizada(s).')));
      Navigator.pop(context, true);
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
      title: Text(widget.plano == null ? 'Novo plano' : 'Plano — ${widget.plano!.nome}'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: TextField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome do plano', isDense: true))),
              const SizedBox(width: 12),
              SizedBox(
                width: 150,
                child: SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _ativo,
                  title: Text(_ativo ? 'Ativo' : 'Desativado'),
                  onChanged: (v) => setState(() => _ativo = v),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _descricao, decoration: const InputDecoration(labelText: 'Descrição (aparece em Meu plano)', isDense: true)),
            if (!_ativo)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Desativado: não pode ser escolhido para novas corretoras; quem já está nele continua.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              ),
            const SizedBox(height: 16),
            CamposPrecoFranquias(ctrl: _preco, onChanged: () => setState(() {})),
            const SizedBox(height: 16),
            const Text('Módulos', style: TextStyle(fontWeight: FontWeight.w700)),
            SeletorModulos(marcados: _modulos, onChanged: (m) => setState(() => _modulos = m)),
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
