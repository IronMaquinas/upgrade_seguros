// lib/widgets/corrigir_seguradoras_dialog.dart
//
// Etapa 20: Configurações → Seguradoras → "Corrigir nomes nos registros".
// Procura, em sinistros, assistências e apólices dos clientes, os nomes de
// seguradora que NÃO são do cadastro (CHUBB, AXA SEGURUROS, EZZER…), sugere o
// cadastrado correspondente e, depois de o gestor conferir, troca em lote.
//
// Nada muda sem o gestor revisar e confirmar. "Não mudar" deixa a grafia como
// está (ex.: seguradora que ainda precisa ser cadastrada — cadastre e rode de novo).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/services/empresa_atual.dart';
import 'package:upgrade_seguros/services/seguradoras_cadastradas.dart';
import 'package:upgrade_seguros/utils/seguradoras.dart';

Future<void> abrirCorrecaoSeguradoras(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CorrecaoSeguradorasDialog(),
  );
}

enum _Fase { carregando, revisao, aplicando, pronto, erro }

class _CorrecaoSeguradorasDialog extends StatefulWidget {
  const _CorrecaoSeguradorasDialog();
  @override
  State<_CorrecaoSeguradorasDialog> createState() => _CorrecaoSeguradorasDialogState();
}

class _CorrecaoSeguradorasDialogState extends State<_CorrecaoSeguradorasDialog> {
  _Fase _fase = _Fase.carregando;
  String _mensagem = '';
  List<String> _cadastradas = [];
  List<GrafiaSeguradora> _grafias = [];
  final Map<String, String?> _escolha = {};
  int _semSeguradora = 0;

  // Documentos lidos: (id, nome) e, nos clientes, a lista de apólices.
  List<(String, String)> _sinistros = [];
  List<(String, String)> _assistencias = [];
  List<(String, List<dynamic>)> _clientes = [];

  int _feitos = 0, _totalOps = 0;
  String _resultado = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _fase = _Fase.carregando;
      _mensagem = 'Lendo o cadastro e os registros…';
    });
    try {
      SeguradorasCadastradas.invalidar();
      _cadastradas = await SeguradorasCadastradas.nomes();
      final r = await Future.wait([
        EmpresaAtual.col('sinistros').get(),
        EmpresaAtual.col('assistencias').get(),
        EmpresaAtual.col('clientes').get(),
      ]);
      String nome(QueryDocumentSnapshot<Map<String, dynamic>> d) => ((d.data()['seguradora'] ?? '') as Object).toString();
      _sinistros = [for (final d in r[0].docs) (d.id, nome(d))];
      _assistencias = [for (final d in r[1].docs) (d.id, nome(d))];
      _clientes = [
        for (final d in r[2].docs)
          if (d.data()['apolices'] is List && (d.data()['apolices'] as List).isNotEmpty) (d.id, d.data()['apolices'] as List<dynamic>),
      ];
      final apolices = [
        for (final c in _clientes)
          for (final a in c.$2)
            if (a is Map) ((a['seguradora'] ?? '') as Object).toString(),
      ];
      _semSeguradora = [..._sinistros, ..._assistencias].where((x) => x.$2.trim().isEmpty).length;
      _grafias = agruparGrafias({
        'sinistros': _sinistros.map((x) => x.$2),
        'assistencias': _assistencias.map((x) => x.$2),
        'apolices': apolices,
      }, _cadastradas);
      _escolha
        ..clear()
        ..addAll({for (final g in _grafias) g.nome: g.sugestao});
      setState(() => _fase = _Fase.revisao);
    } catch (e) {
      setState(() {
        _fase = _Fase.erro;
        _mensagem = 'Não consegui ler os registros: $e';
      });
    }
  }

  Map<String, String> get _troca => {
        for (final e in _escolha.entries)
          if (e.value != null && e.value != e.key) e.key: e.value!,
      };

  int get _registrosATrocar => _grafias.where((g) => _troca.containsKey(g.nome)).fold(0, (s, g) => s + g.total);

  Future<void> _confirmarEAplicar() async {
    final troca = _troca;
    if (troca.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Confirmar correção'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Vou trocar o nome da seguradora em $_registrosATrocar registro(s):'),
              const SizedBox(height: 8),
              for (final e in troca.entries) Text('• ${e.key}  →  ${e.value}', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              Text('Não dá para desfazer automaticamente.', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Corrigir')),
        ],
      ),
    );
    if (ok == true) await _aplicar(troca);
  }

  Future<void> _aplicar(Map<String, String> troca) async {
    final ops = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
    var nSin = 0, nAss = 0, nCli = 0;
    for (final (id, nome) in _sinistros) {
      final novo = troca[nome];
      if (novo != null) {
        ops.add((EmpresaAtual.col('sinistros').doc(id), {'seguradora': novo}));
        nSin++;
      }
    }
    for (final (id, nome) in _assistencias) {
      final novo = troca[nome];
      if (novo != null) {
        ops.add((EmpresaAtual.col('assistencias').doc(id), {'seguradora': novo}));
        nAss++;
      }
    }
    for (final (id, apolices) in _clientes) {
      final nova = trocarSeguradoraNasApolices(apolices, troca);
      if (nova != null) {
        ops.add((EmpresaAtual.col('clientes').doc(id), {'apolices': nova}));
        nCli++;
      }
    }
    setState(() {
      _fase = _Fase.aplicando;
      _feitos = 0;
      _totalOps = ops.length;
    });
    try {
      for (var i = 0; i < ops.length; i += 400) {
        final lote = FirebaseFirestore.instance.batch();
        for (final (ref, dados) in ops.skip(i).take(400)) {
          lote.update(ref, dados);
        }
        await lote.commit();
        setState(() => _feitos = (i + 400).clamp(0, ops.length));
      }
      setState(() {
        _fase = _Fase.pronto;
        _resultado = 'Corrigidos: $nSin sinistro(s), $nAss assistência(s) e as apólices de $nCli cliente(s).';
      });
    } catch (e) {
      setState(() {
        _fase = _Fase.erro;
        _mensagem = 'Parou depois de $_feitos de $_totalOps registros: $e\n\nRode "Verificar de novo": o que já foi corrigido não aparece mais.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeFechar = _fase != _Fase.aplicando;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('Corrigir nomes de seguradora'),
      content: SizedBox(width: 640, child: _conteudo()),
      actions: [
        if (_fase == _Fase.pronto || _fase == _Fase.erro)
          TextButton(onPressed: _carregar, child: const Text('Verificar de novo')),
        TextButton(onPressed: podeFechar ? () => Navigator.pop(context) : null, child: const Text('Fechar')),
        if (_fase == _Fase.revisao && _grafias.isNotEmpty)
          FilledButton.icon(
            onPressed: _troca.isEmpty ? null : _confirmarEAplicar,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: Text('Corrigir $_registrosATrocar registro(s)'),
          ),
      ],
    );
  }

  Widget _conteudo() {
    switch (_fase) {
      case _Fase.carregando:
        return _Centro(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(_mensagem),
        ]));
      case _Fase.aplicando:
        return _Centro(child: Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: _totalOps == 0 ? null : _feitos / _totalOps),
          const SizedBox(height: 12),
          Text('Corrigindo… $_feitos de $_totalOps'),
        ]));
      case _Fase.pronto:
        return _Centro(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 40),
          const SizedBox(height: 10),
          Text(_resultado, textAlign: TextAlign.center),
        ]));
      case _Fase.erro:
        return Text(_mensagem, style: const TextStyle(color: Color(0xFFC62828)));
      case _Fase.revisao:
        if (_cadastradas.isEmpty) {
          return const Text('Não há seguradoras ativas no cadastro. Cadastre primeiro e depois volte aqui.');
        }
        if (_grafias.isEmpty) {
          return _Centro(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified, color: Colors.green, size: 40),
            const SizedBox(height: 10),
            const Text('Tudo certo: todos os registros usam nomes do cadastro.'),
            if (_semSeguradora > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('$_semSeguradora sinistro(s)/assistência(s) estão sem seguradora.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ),
          ]));
        }
        return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Encontrei ${_grafias.length} nome(s) fora do cadastro. Confira a seguradora certa de cada um '
            '(a sugestão já vem marcada) ou deixe "Não mudar".',
            style: const TextStyle(fontSize: 13),
          ),
          if (_semSeguradora > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$_semSeguradora sinistro(s)/assistência(s) estão sem seguradora (não entram aqui).',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ),
          const SizedBox(height: 10),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _grafias.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _linha(_grafias[i]),
              ),
            ),
          ),
        ]);
    }
  }

  Widget _linha(GrafiaSeguradora g) {
    final partes = [
      if (g.sinistros > 0) '${g.sinistros} sinistro(s)',
      if (g.assistencias > 0) '${g.assistencias} assistência(s)',
      if (g.apolices > 0) '${g.apolices} apólice(s)',
    ];
    final escolhida = _escolha[g.nome];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(g.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(partes.join(' · '), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ]),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 18)),
        Expanded(
          flex: 5,
          child: DropdownButtonFormField<String?>(
            value: escolhida,
            isExpanded: true,
            isDense: true,
            dropdownColor: Colors.white,
            menuMaxHeight: 360,
            decoration: InputDecoration(
              isDense: true,
              helperText: escolhida != null && escolhida == g.sugestao ? 'sugestão' : null,
              helperStyle: const TextStyle(fontSize: 11),
            ),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Não mudar', style: TextStyle(color: Colors.grey))),
              for (final c in _cadastradas) DropdownMenuItem<String?>(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _escolha[g.nome] = v),
          ),
        ),
      ]),
    );
  }
}

class _Centro extends StatelessWidget {
  final Widget child;
  const _Centro({required this.child});
  @override
  Widget build(BuildContext context) => SizedBox(height: 160, child: Center(child: child));
}
