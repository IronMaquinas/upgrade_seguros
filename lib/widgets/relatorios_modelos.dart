// lib/widgets/relatorios_modelos.dart
//
// Etapa 19b: "Exportar relatório" das listas de Sinistros e Assistências.
//   1. abre a lista de MODELOS da corretora (todos veem e usam);
//      sem nenhum, leva para "Criar modelo";
//   2. o modelo é montado numa tela própria: campos por seção, em ordem,
//      com o medidor de largura do PDF (cabe / apertado / ficha);
//   3. ao exportar: período, cliente, status, seguradora e tipo → prévia
//      (quantidade e total) → PDF ou Excel.
// Regras em lib/utils/relatorio_modelo.dart; banco em
// lib/services/relatorio_atendimentos.dart; PDF em relatorio_atendimentos_pdf.dart.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/marca_pdf.dart';
import '../services/relatorio_atendimentos.dart';
import '../services/relatorio_atendimentos_pdf.dart';
import '../utils/perfil_corretora.dart';
import '../utils/relatorio_modelo.dart';

String _nomeTipo(String tipo, {bool plural = true}) =>
    tipo == 'assistencia' ? (plural ? 'assistências' : 'assistência') : (plural ? 'sinistros' : 'sinistro');

/// Ponto de entrada (botão "Exportar relatório" das listas).
Future<void> abrirRelatoriosComModelos(BuildContext context, {required String tipo}) {
  return showDialog<void>(context: context, builder: (_) => _ModelosDialog(tipo: tipo));
}

// ════════════════════════════════════════════════════════════════════════
// 1. Lista de modelos
// ════════════════════════════════════════════════════════════════════════
class _ModelosDialog extends StatefulWidget {
  final String tipo;
  const _ModelosDialog({required this.tipo});

  @override
  State<_ModelosDialog> createState() => _ModelosDialogState();
}

class _ModelosDialogState extends State<_ModelosDialog> {
  final _svc = RelatorioAtendimentosService();
  List<ModeloRelatorio>? _modelos;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final l = await _svc.listarModelos(widget.tipo);
      if (mounted) setState(() => _modelos = l);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    }
  }

  Future<void> _editar(ModeloRelatorio? m) async {
    final salvo = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EditorModeloRelatorioScreen(
        modelo: m ?? ModeloRelatorio(nome: '', tipo: widget.tipo, campos: CatalogoRelatorio.padrao(widget.tipo)),
      ),
    ));
    if (salvo == true) {
      setState(() => _modelos = null);
      await _carregar();
    }
  }

  Future<void> _excluir(ModeloRelatorio m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Excluir modelo?'),
        content: Text('"${m.nome}" deixa de aparecer para toda a equipe. Os relatórios já exportados não mudam.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _svc.excluirModelo(m.id);
      await _carregar();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
    }
  }

  Future<void> _exportar(ModeloRelatorio m) async {
    await showDialog<void>(context: context, builder: (_) => _ExportarDialog(modelo: m));
  }

  @override
  Widget build(BuildContext context) {
    final modelos = _modelos;
    return AlertDialog(
      title: Text('Relatório de ${_nomeTipo(widget.tipo)}'),
      content: SizedBox(
        width: 560,
        child: _erro != null
            ? Text('Não foi possível carregar os modelos: $_erro')
            : modelos == null
                ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
                : modelos.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.description_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 8),
                          const Text('Nenhum modelo de relatório ainda.', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            'Crie um modelo escolhendo os campos (ex.: nº da ocorrência, data, placa, tipo, valor). '
                            'Ele fica salvo para toda a equipe usar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _editar(null),
                            icon: const Icon(Icons.add),
                            label: const Text('Criar modelo'),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final m in modelos)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(m.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${m.camposValidos.length} campos · '
                                    '${_rotuloLayout(OcupacaoPdf.de(m.camposValidos).layout)}'
                                    '${m.atualizadoPor.isEmpty ? '' : ' · editado por ${m.atualizadoPor}'}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onTap: () => _exportar(m),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(tooltip: 'Editar', icon: const Icon(Icons.edit_outlined), onPressed: () => _editar(m)),
                                      IconButton(
                                        tooltip: 'Duplicar',
                                        icon: const Icon(Icons.copy_outlined),
                                        onPressed: () => _editar(m.copiar(id: '', nome: '${m.nome} (cópia)')),
                                      ),
                                      IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: () => _excluir(m)),
                                      const SizedBox(width: 4),
                                      ElevatedButton(onPressed: () => _exportar(m), child: const Text('Exportar')),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
      ),
      actions: [
        if (modelos != null && modelos.isNotEmpty)
          TextButton.icon(onPressed: () => _editar(null), icon: const Icon(Icons.add), label: const Text('Novo modelo')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
      ],
    );
  }
}

String _rotuloLayout(LayoutPdf l) {
  switch (l) {
    case LayoutPdf.tabela:
      return 'PDF em tabela';
    case LayoutPdf.tabelaCompacta:
      return 'PDF em tabela (letra menor)';
    case LayoutPdf.ficha:
      return 'PDF em ficha';
  }
}

// ════════════════════════════════════════════════════════════════════════
// 2. Editor do modelo
// ════════════════════════════════════════════════════════════════════════
class EditorModeloRelatorioScreen extends StatefulWidget {
  final ModeloRelatorio modelo;
  const EditorModeloRelatorioScreen({super.key, required this.modelo});

  @override
  State<EditorModeloRelatorioScreen> createState() => _EditorModeloRelatorioScreenState();
}

class _EditorModeloRelatorioScreenState extends State<EditorModeloRelatorioScreen> {
  late final TextEditingController _nome = TextEditingController(text: widget.modelo.nome);
  late final List<String> _campos = widget.modelo.camposValidos.map((c) => c.id).toList();
  bool _salvando = false;

  String get _tipo => widget.modelo.tipo;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final m = widget.modelo.copiar(nome: _nome.text, campos: List.of(_campos));
    final erro = m.validar();
    if (erro != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      return;
    }
    setState(() => _salvando = true);
    try {
      await RelatorioAtendimentosService().salvarModelo(m);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  Widget _medidor() {
    final oc = OcupacaoPdf.de([for (final id in _campos) CatalogoRelatorio.porId(id)!]);
    final cor = switch (oc.layout) {
      LayoutPdf.tabela => Colors.green,
      LayoutPdf.tabelaCompacta => Colors.orange,
      LayoutPdf.ficha => Colors.red,
    };
    final emoji = switch (oc.layout) {
      LayoutPdf.tabela => '🟢',
      LayoutPdf.tabelaCompacta => '🟡',
      LayoutPdf.ficha => '🔴',
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$emoji Largura no PDF: ${oc.percentual.toStringAsFixed(0)}% da folha deitada',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (oc.percentual / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(cor),
            ),
          ),
          const SizedBox(height: 6),
          Text(oc.descricao, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final porSecao = CatalogoRelatorio.porSecao(_tipo);
    final largo = MediaQuery.of(context).size.width >= 900;

    final escolha = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nome,
          decoration: InputDecoration(
            labelText: 'Nome do modelo',
            hintText: 'Ex.: Águia Branca — assistências do mês',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Campos (${_nomeTipo(_tipo)})', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Marque o que deve sair no relatório. A ordem você ajusta ao lado.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        for (final e in porSecao.entries) ...[
          const SizedBox(height: 12),
          Text(e.key, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blue.shade800)),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final c in e.value)
                FilterChip(
                  label: Text(c.rotulo, style: const TextStyle(fontSize: 12)),
                  selected: _campos.contains(c.id),
                  onSelected: (v) => setState(() => v ? _campos.add(c.id) : _campos.remove(c.id)),
                ),
            ],
          ),
        ],
      ],
    );

    final ordem = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: _medidor()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Ordem das colunas (${_campos.length}) — arraste para mudar',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: _campos.isEmpty
              ? Center(child: Text('Nenhum campo escolhido.', style: TextStyle(color: Colors.grey.shade600)))
              : ReorderableListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onReorder: (de, para) => setState(() {
                    if (para > de) para--;
                    _campos.insert(para, _campos.removeAt(de));
                  }),
                  children: [
                    for (var i = 0; i < _campos.length; i++)
                      ListTile(
                        key: ValueKey(_campos[i]),
                        dense: true,
                        leading: CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 11))),
                        title: Text(CatalogoRelatorio.porId(_campos[i])!.rotulo),
                        subtitle: Text(CatalogoRelatorio.porId(_campos[i])!.secao, style: const TextStyle(fontSize: 11)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            tooltip: 'Tirar',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _campos.removeAt(i)),
                          ),
                          const Icon(Icons.drag_handle),
                        ]),
                      ),
                  ],
                ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.modelo.id.isEmpty ? 'Novo modelo de relatório' : 'Editar modelo'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _salvar,
              icon: _salvando
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Salvar'),
            ),
          ),
        ],
      ),
      body: largo
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 3, child: escolha),
              const VerticalDivider(width: 1),
              Expanded(flex: 2, child: ordem),
            ])
          : Column(children: [Expanded(child: escolha), const Divider(height: 1), SizedBox(height: 360, child: ordem)]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 3. Exportar (filtros, prévia, PDF / Excel)
// ════════════════════════════════════════════════════════════════════════
class _ExportarDialog extends StatefulWidget {
  final ModeloRelatorio modelo;
  const _ExportarDialog({required this.modelo});

  @override
  State<_ExportarDialog> createState() => _ExportarDialogState();
}

enum _Periodo { mesAtual, mesAnterior, anoAtual, personalizado, tudo }

class _ExportarDialogState extends State<_ExportarDialog> {
  List<RegistroRelatorio>? _registros;
  String? _erro;
  bool _gerando = false;

  _Periodo _periodo = _Periodo.mesAtual;
  DateTimeRange? _intervalo;
  bool _pelaOcorrencia = false;
  String? _clienteId;
  final Set<String> _status = {};
  String? _seguradora;
  String? _tipoAtendimento;

  bool get _assist => widget.modelo.tipo == 'assistencia';

  @override
  void initState() {
    super.initState();
    RelatorioAtendimentosService().carregarRegistros(widget.modelo.tipo).then((r) {
      if (mounted) setState(() => _registros = r);
    }).catchError((e) {
      if (mounted) setState(() => _erro = '$e');
    });
  }

  (DateTime?, DateTime?) get _datas {
    final h = DateTime.now();
    switch (_periodo) {
      case _Periodo.mesAtual:
        return (DateTime(h.year, h.month, 1), DateTime(h.year, h.month + 1, 0));
      case _Periodo.mesAnterior:
        return (DateTime(h.year, h.month - 1, 1), DateTime(h.year, h.month, 0));
      case _Periodo.anoAtual:
        return (DateTime(h.year, 1, 1), DateTime(h.year, 12, 31));
      case _Periodo.personalizado:
        return (_intervalo?.start, _intervalo?.end);
      case _Periodo.tudo:
        return (null, null);
    }
  }

  FiltroRelatorio get _filtro {
    final (de, ate) = _datas;
    return FiltroRelatorio(
      de: de,
      ate: ate,
      pelaOcorrencia: _pelaOcorrencia,
      status: _status,
      clienteId: _clienteId,
      seguradora: _seguradora,
      tipoAtendimento: _tipoAtendimento,
    );
  }

  String _nomeCliente(String? id) {
    for (final r in _registros ?? const <RegistroRelatorio>[]) {
      if (r.clienteId == id) return r.clienteNome;
    }
    return id ?? '';
  }

  Future<void> _escolherIntervalo() async {
    final h = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(h.year + 1, 12, 31),
      initialDateRange: _intervalo ?? DateTimeRange(start: DateTime(h.year, h.month, 1), end: h),
    );
    if (r != null) {
      setState(() {
        _intervalo = r;
        _periodo = _Periodo.personalizado;
      });
    }
  }

  Future<void> _gerar(bool pdf) async {
    final regs = _registros;
    if (regs == null) return;
    setState(() => _gerando = true);
    try {
      final filtro = _filtro;
      final r = RelatorioMontado.montar(widget.modelo, regs, filtro);
      final descricao = filtro.descrever(nomeCliente: _nomeCliente(_clienteId));
      final marca = await MarcaPdf.carregar();
      final h = DateTime.now();
      final data = '${h.year}-${h.month.toString().padLeft(2, '0')}-${h.day.toString().padLeft(2, '0')}';
      if (pdf) {
        await Printing.sharePdf(
          bytes: await RelatorioAtendimentosPdf.gerar(r, marca: marca, filtro: descricao),
          filename: PerfilCorretora.nomeArquivo(marca.corretora, '${widget.modelo.nome} - $data', 'pdf'),
        );
      } else {
        // Mesmo caminho dos outros CSV do app: baixa no navegador.
        await Printing.sharePdf(
          bytes: utf8.encode(r.paraCsv()),
          filename: PerfilCorretora.nomeArquivo(marca.corretora, '${widget.modelo.nome} - $data', 'csv'),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao gerar: $e')));
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regs = _registros;
    Widget corpo;
    if (_erro != null) {
      corpo = Text('Não foi possível carregar os dados: $_erro');
    } else if (regs == null) {
      corpo = const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    } else {
      final clientes = <String, String>{
        for (final r in regs)
          if (r.clienteId.isNotEmpty) r.clienteId: r.clienteNome.isEmpty ? r.clienteId : r.clienteNome,
      };
      final nomesClientes = clientes.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
      final status = {for (final r in regs) if (r.status.isNotEmpty) r.status}.toList()..sort();
      final seguradoras = {for (final r in regs) if (r.seguradora.trim().isNotEmpty) r.seguradora}.toList()..sort();
      final tipos = {for (final r in regs) if (r.tipoAtendimento.isNotEmpty) r.tipoAtendimento}.toList()..sort();
      final previa = RelatorioMontado.montar(widget.modelo, regs, _filtro);
      final campoValor = CatalogoRelatorio.porId('valor_total')!;
      final totalValor = previa.registros.fold<double>(0, (s, r) => s + ((r.valores['valor_total'] as num?)?.toDouble() ?? 0));
      final (de, ate) = _datas;

      corpo = SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Período', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final p in _Periodo.values)
                ChoiceChip(
                  label: Text(switch (p) {
                    _Periodo.mesAtual => 'Mês atual',
                    _Periodo.mesAnterior => 'Mês anterior',
                    _Periodo.anoAtual => 'Este ano',
                    _Periodo.personalizado => _intervalo == null
                        ? 'Escolher datas…'
                        : '${RelatorioMontado.formatar(const CampoRelatorio('d', '', '', formato: FormatoCampo.data), _intervalo!.start)}'
                            ' a ${RelatorioMontado.formatar(const CampoRelatorio('d', '', '', formato: FormatoCampo.data), _intervalo!.end)}',
                    _Periodo.tudo => 'Tudo',
                  }),
                  selected: _periodo == p,
                  onSelected: (_) => p == _Periodo.personalizado ? _escolherIntervalo() : setState(() => _periodo = p),
                ),
            ]),
            if (!_assist)
              Row(children: [
                const Text('Data de referência:', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Abertura'), selected: !_pelaOcorrencia, onSelected: (_) => setState(() => _pelaOcorrencia = false)),
                const SizedBox(width: 6),
                ChoiceChip(label: const Text('Ocorrência'), selected: _pelaOcorrencia, onSelected: (_) => setState(() => _pelaOcorrencia = true)),
              ]),
            if (de != null || ate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'De ${de == null ? 'início' : RelatorioMontado.formatar(const CampoRelatorio('d', '', '', formato: FormatoCampo.data), de)}'
                  ' a ${ate == null ? 'hoje' : RelatorioMontado.formatar(const CampoRelatorio('d', '', '', formato: FormatoCampo.data), ate)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: _clienteId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Cliente', isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Todos os clientes')),
                for (final e in nomesClientes) DropdownMenuItem<String?>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _clienteId = v),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _seguradora,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Seguradora', isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                    for (final s in seguradoras) DropdownMenuItem<String?>(value: s, child: Text(s, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _seguradora = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _tipoAtendimento,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: _assist ? 'Tipo de assistência' : 'Tipo de ocorrência', isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                    for (final t in tipos) DropdownMenuItem<String?>(value: t, child: Text(t, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _tipoAtendimento = v),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const Text('Status (nenhum marcado = todos)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              for (final s in status)
                FilterChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  selected: _status.contains(s),
                  onSelected: (v) => setState(() => v ? _status.add(s) : _status.remove(s)),
                ),
            ]),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(
                '${previa.quantidade} ${_nomeTipo(widget.modelo.tipo, plural: previa.quantidade != 1)} · '
                'valor total ${RelatorioMontado.formatar(campoValor, totalValor)} · '
                '${_rotuloLayout(OcupacaoPdf.de(previa.colunas).layout)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      title: Text('Exportar: ${widget.modelo.nome}'),
      content: SizedBox(width: 560, child: corpo),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        OutlinedButton.icon(
          onPressed: regs == null || _gerando ? null : () => _gerar(false),
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('Excel (CSV)'),
        ),
        ElevatedButton.icon(
          onPressed: regs == null || _gerando ? null : () => _gerar(true),
          icon: _gerando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF'),
        ),
      ],
    );
  }
}
