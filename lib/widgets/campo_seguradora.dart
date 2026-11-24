// lib/widgets/campo_seguradora.dart
//
// Etapa 20: campo único de Seguradora (abertura de sinistro, assistências,
// apólice, detalhe do sinistro). Antes, cada tela tinha um Autocomplete próprio
// que não sugeria nada (a lista chegava depois de o campo ser montado) e
// gravava qualquer texto digitado.
//
// Agora:
//   • sugere as seguradoras cadastradas enquanto se digita (sem acento/caixa);
//   • a seta abre a lista completa;
//   • ao sair do campo, o texto vira o nome cadastrado (chubb → Chubb); se não
//     corresponder a nenhuma, o campo é limpo e mostra o aviso;
//   • texto vindo de outro lugar (ex.: apólice antiga) e fora do cadastro
//     aparece com aviso em vermelho até ser trocado.
// Etapa 22: a lista vem do catálogo único; valem os apelidos do catálogo; as
// pendentes aparecem com "(aguardando aprovação)"; e, com o catálogo montado,
// "Cadastrar nova seguradora pelo CNPJ" no fim da lista.

import 'package:flutter/material.dart';
import 'package:upgrade_seguros/services/seguradoras_cadastradas.dart';
import 'package:upgrade_seguros/utils/seguradoras.dart';
import 'package:upgrade_seguros/widgets/nova_seguradora_dialog.dart';

/// Opção especial da lista: abre o cadastro pelo CNPJ.
const _kNova = '\u0000nova';

class CampoSeguradora extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const CampoSeguradora({
    super.key,
    required this.controller,
    this.decoration,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<CampoSeguradora> createState() => _CampoSeguradoraState();
}

class _CampoSeguradoraState extends State<CampoSeguradora> {
  final _foco = FocusNode();
  List<String> _nomes = SeguradorasCadastradas.emMemoria;
  bool _carregou = SeguradorasCadastradas.emMemoria.isNotEmpty;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _foco.addListener(() {
      if (!_foco.hasFocus) _confirmar(digitado: true);
    });
    // Preenchido por outro lugar (ex.: escolheu a apólice): confere sem limpar.
    widget.controller.addListener(_textoMudou);
    SeguradorasCadastradas.nomes().then((l) {
      if (!mounted) return;
      setState(() {
        _nomes = l;
        _carregou = true;
      });
      _confirmar(digitado: false);
    }).catchError((_) {});
  }

  void _textoMudou() {
    if (_foco.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _confirmar(digitado: false));
  }

  @override
  void didUpdateWidget(CampoSeguradora old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_textoMudou);
      widget.controller.addListener(_textoMudou);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_textoMudou);
    _foco.dispose();
    super.dispose();
  }

  void _definir(String nome) {
    if (widget.controller.text != nome) {
      widget.controller.value = TextEditingValue(text: nome, selection: TextSelection.collapsed(offset: nome.length));
    }
    widget.onChanged?.call(nome);
  }

  /// [digitado]: o usuário acabou de sair do campo (limpa se não existir).
  void _confirmar({required bool digitado}) {
    if (!_carregou || !mounted) return;
    final t = widget.controller.text.trim();
    if (t.isEmpty) {
      if (_aviso != null) setState(() => _aviso = null);
      return;
    }
    final certo = SeguradorasCadastradas.resolver(t) ?? resolverSeguradora(t, _nomes);
    if (certo != null) {
      if (certo != widget.controller.text) _definir(certo);
      if (_aviso != null) setState(() => _aviso = null);
      return;
    }
    if (digitado) {
      _definir('');
      setState(() => _aviso = '"$t" não está no cadastro — escolha da lista');
    } else {
      setState(() => _aviso = 'Fora do cadastro — escolha da lista');
    }
  }

  Future<void> _abrirLista() async {
    final escolhida = await showDialog<String>(
      context: context,
      builder: (ctx) => _ListaSeguradorasDialog(nomes: _nomes, podeCadastrar: SeguradorasCadastradas.usaCatalogo),
    );
    if (escolhida == _kNova) return _novaPeloCnpj();
    if (escolhida != null) {
      _definir(escolhida);
      setState(() => _aviso = null);
    }
  }

  /// Etapa 22: cadastra pelo CNPJ e já escolhe.
  Future<void> _novaPeloCnpj() async {
    _foco.unfocus();
    final nome = await abrirNovaSeguradora(context);
    if (nome == null || !mounted) return;
    SeguradorasCadastradas.invalidar();
    final lista = await SeguradorasCadastradas.nomes();
    if (!mounted) return;
    setState(() {
      _nomes = lista;
      _aviso = null;
    });
    _definir(nome);
  }

  List<String> _opcoes(String texto) {
    if (!_foco.hasFocus) return const <String>[];
    final s = sugestoesSeguradora(texto, _nomes);
    final apelido = SeguradorasCadastradas.resolver(texto);
    if (apelido != null && !s.contains(apelido)) s.insert(0, apelido);
    if (SeguradorasCadastradas.usaCatalogo && texto.trim().length >= 2) s.add(_kNova);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.decoration ?? const InputDecoration(labelText: 'Seguradora');
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _foco,
      optionsBuilder: (v) => _opcoes(v.text),
      displayStringForOption: (o) => o == _kNova ? widget.controller.text : o,
      onSelected: (s) {
        if (s == _kNova) {
          _novaPeloCnpj();
          return;
        }
        _definir(s);
        setState(() => _aviso = null);
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: widget.enabled,
        decoration: base.copyWith(
          hintText: base.hintText ?? (_carregou && _nomes.isEmpty ? 'Nenhuma seguradora cadastrada' : 'Digite para buscar…'),
          prefixIcon: base.prefixIcon ?? const Icon(Icons.business_outlined),
          errorText: _aviso,
          errorMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: 'Ver todas',
            icon: const Icon(Icons.arrow_drop_down),
            onPressed: widget.enabled && _nomes.isNotEmpty ? _abrirLista : null,
          ),
        ),
        onChanged: (v) {
          if (_aviso != null) setState(() => _aviso = null);
          widget.onChanged?.call(v);
        },
        onFieldSubmitted: (_) {
          final s = _opcoes(controller.text)..remove(_kNova);
          if (s.length == 1) {
            _definir(s.first);
            setState(() => _aviso = null);
          }
          onSubmitted();
        },
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.white,
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final o = options.elementAt(i);
                if (o == _kNova) {
                  return InkWell(
                    onTap: () => onSelected(o),
                    child: Container(
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: const Row(children: [
                        Icon(Icons.add_business_outlined, size: 16, color: Color(0xFF1565C0)),
                        SizedBox(width: 6),
                        Text('Não achou? Cadastrar pelo CNPJ', style: TextStyle(fontSize: 13, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  );
                }
                return InkWell(
                  onTap: () => onSelected(o),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Text.rich(TextSpan(text: o, style: const TextStyle(fontSize: 13), children: [
                      if (SeguradorasCadastradas.ehPendente(o))
                        TextSpan(text: '  (aguardando aprovação)', style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                    ])),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ListaSeguradorasDialog extends StatefulWidget {
  final List<String> nomes;
  final bool podeCadastrar; // Etapa 22
  const _ListaSeguradorasDialog({required this.nomes, this.podeCadastrar = false});
  @override
  State<_ListaSeguradorasDialog> createState() => _ListaSeguradorasDialogState();
}

class _ListaSeguradorasDialogState extends State<_ListaSeguradorasDialog> {
  String _busca = '';
  @override
  Widget build(BuildContext context) {
    final lista = sugestoesSeguradora(_busca, widget.nomes);
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Seguradora'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 380,
        height: 420,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar', isDense: true),
            onChanged: (v) => setState(() => _busca = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: lista.isEmpty
                ? Center(child: Text('Nenhuma encontrada', style: TextStyle(color: Colors.grey.shade600)))
                : ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (_, i) => ListTile(
                      dense: true,
                      title: Text(lista[i]),
                      subtitle: SeguradorasCadastradas.ehPendente(lista[i])
                          ? Text('aguardando aprovação', style: TextStyle(fontSize: 11, color: Colors.orange.shade800))
                          : null,
                      onTap: () => Navigator.pop(context, lista[i]),
                    ),
                  ),
          ),
        ]),
      ),
      actions: [
        if (widget.podeCadastrar)
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _kNova),
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Não achou? Cadastrar pelo CNPJ'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ],
    );
  }
}
