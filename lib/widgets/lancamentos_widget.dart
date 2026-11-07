// lib/widgets/lancamentos_widget.dart
//
// Histórico de valores do sinistro (Etapa 02): totais (segurado, terceiros,
// total), lista de lançamentos com notas fiscais, botão de novo lançamento e
// cancelamento com motivo. Usado no detalhe do sinistro.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/claim_model.dart';
import '../models/lancamento_model.dart';
import '../services/lancamentos_service.dart';
import '../utils/formatters.dart';

final NumberFormat _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2);
final DateFormat _data = DateFormat('dd/MM/yyyy');
final DateFormat _dataHora = DateFormat('dd/MM/yyyy HH:mm');

String formatarMoedaLancamento(double v) => _moeda.format(v);

/// Lê "R$ 1.234,56" (com ou sem espaço especial) como 1234.56.
double lerMoedaDigitada(String texto) {
  final limpo = texto.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll(',', '.');
  return double.tryParse(limpo) ?? 0.0;
}

/// Abre o diálogo de novo lançamento. Devolve true se gravou.
Future<bool> mostrarDialogoNovoLancamento(
  BuildContext context, {
  required Claim claim,
  required String usuarioNome,
  required String usuarioEmail,
  LancamentosService? service,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _NovoLancamentoDialog(
      claim: claim,
      usuarioNome: usuarioNome,
      usuarioEmail: usuarioEmail,
      service: service ?? LancamentosService(),
    ),
  );
  return ok == true;
}

class LancamentosSinistroCard extends StatelessWidget {
  const LancamentosSinistroCard({
    super.key,
    required this.claim,
    required this.usuarioNome,
    required this.usuarioEmail,
    required this.onAbrirAnexo,
    this.service,
  });

  final Claim claim;
  final String usuarioNome;
  final String usuarioEmail;

  /// Abre a nota fiscal / evidência (o detalhe usa o url_launcher).
  final void Function(String url) onAbrirAnexo;
  final LancamentosService? service;

  static const _verde = Color(0xFF2E7D32);

  Future<void> _cancelar(BuildContext context, LancamentoSinistro l) async {
    final motivoCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar lançamento'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.tipo} — ${formatarMoedaLancamento(l.valor)} (${_data.format(l.data)})',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'O lançamento continua no histórico, riscado, com o motivo, quem cancelou e quando. '
                'O valor deixa de somar no total.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: motivoCtrl,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Motivo do cancelamento *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o motivo' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Voltar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, motivoCtrl.text.trim());
            },
            child: const Text('Cancelar lançamento'),
          ),
        ],
      ),
    );
    motivoCtrl.dispose();
    if (motivo == null || !context.mounted) return;

    try {
      await (service ?? LancamentosService()).cancelar(
        claimId: claim.id,
        lancamentoId: l.id,
        motivo: motivo,
        usuarioNome: usuarioNome,
        usuarioEmail: usuarioEmail,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lançamento cancelado.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cancelar: $e')));
      }
    }
  }

  Widget _total(String rotulo, double valor, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: destaque ? _verde.withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: destaque ? _verde.withOpacity(0.3) : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rotulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(
            formatarMoedaLancamento(valor),
            style: TextStyle(
              fontSize: destaque ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: destaque ? _verde : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, LancamentoSinistro l) {
    final riscado = l.cancelado ? TextDecoration.lineThrough : null;
    final corTexto = l.cancelado ? Colors.grey : Colors.black87;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: l.cancelado ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_data.format(l.data)} · ${l.tipo}',
                      style: TextStyle(fontWeight: FontWeight.w600, decoration: riscado, color: corTexto),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.beneficiarioLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: l.isTerceiro ? const Color(0xFF6A1B9A) : const Color(0xFF1565C0),
                        decoration: riscado,
                      ),
                    ),
                    if (l.descricao.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(l.descricao, style: TextStyle(fontSize: 12, decoration: riscado, color: corTexto)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatarMoedaLancamento(l.valor),
                style: TextStyle(fontWeight: FontWeight.bold, decoration: riscado, color: corTexto),
              ),
              if (!l.cancelado)
                IconButton(
                  tooltip: 'Cancelar lançamento',
                  icon: Icon(Icons.block, size: 18, color: Colors.red.shade400),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _cancelar(context, l),
                ),
            ],
          ),
          if (l.anexos.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: l.anexos
                  .map((a) => ActionChip(
                        avatar: const Icon(Icons.receipt_long, size: 16),
                        label: Text(a.nome, overflow: TextOverflow.ellipsis),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onAbrirAnexo(a.url),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'Registrado por ${l.registradoPor.isEmpty ? '—' : l.registradoPor} em ${_dataHora.format(l.registradoEm)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          if (l.cancelado)
            Text(
              'Cancelado por ${l.canceladoPor ?? '—'}'
              '${l.canceladoEm != null ? ' em ${_dataHora.format(l.canceladoEm!)}' : ''}'
              ' — motivo: ${l.motivoCancelamento ?? '—'}',
              style: TextStyle(fontSize: 11, color: Colors.red.shade700),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumo = claim.resumoValores;
    final lista = LancamentoSinistro.ordenar(claim.lancamentos);
    final anterior = claim.valorAnteriorAoHistorico;

    // Subtotal por terceiro, na ordem do cadastro.
    final porTerceiro = <MapEntry<String, double>>[];
    for (final tp in claim.terceiros) {
      final v = resumo.porTerceiro[tp.id];
      if (tp.id.isNotEmpty && v != null && v > 0) {
        porTerceiro.add(MapEntry(tp.nome.isEmpty ? 'Terceiro' : tp.nome, v));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _total('Segurado', lista.isEmpty ? anterior : resumo.segurado),
            _total('Terceiros', resumo.terceiros),
            _total('Total do sinistro', claim.valorTotalCalculado, destaque: true),
          ],
        ),
        if (porTerceiro.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...porTerceiro.map((e) => Text(
                '• ${e.key}: ${formatarMoedaLancamento(e.value)}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              )),
        ],
        const SizedBox(height: 12),
        if (anterior > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Text(
              'Este sinistro tem ${formatarMoedaLancamento(anterior)} registrados antes do histórico de lançamentos. '
              'No primeiro lançamento novo, esse valor entra no histórico como '
              '"${TiposLancamento.anteriorAoHistorico}" (e pode ser cancelado com motivo, se for o caso).',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (lista.isEmpty && anterior <= 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Nenhum lançamento ainda. Registre cada custo (reparo, peças, indenização…) com a nota fiscal.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ),
        ...lista.map((l) => _item(context, l)),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Novo lançamento'),
            style: ElevatedButton.styleFrom(backgroundColor: _verde, foregroundColor: Colors.white),
            onPressed: () => mostrarDialogoNovoLancamento(
              context,
              claim: claim,
              usuarioNome: usuarioNome,
              usuarioEmail: usuarioEmail,
              service: service,
            ),
          ),
        ),
      ],
    );
  }
}

class _NovoLancamentoDialog extends StatefulWidget {
  const _NovoLancamentoDialog({
    required this.claim,
    required this.usuarioNome,
    required this.usuarioEmail,
    required this.service,
  });

  final Claim claim;
  final String usuarioNome;
  final String usuarioEmail;
  final LancamentosService service;

  @override
  State<_NovoLancamentoDialog> createState() => _NovoLancamentoDialogState();
}

class _NovoLancamentoDialogState extends State<_NovoLancamentoDialog> {
  final _valorCtrl = TextEditingController();
  final _descricaoCtrl = TextEditingController();
  DateTime _dataEvento = DateTime.now();
  String _tipo = TiposLancamento.reparo;

  /// -1 = segurado; >= 0 = índice do terceiro em claim.terceiros.
  int _beneficiario = -1;
  final List<PlatformFile> _arquivos = [];
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _valorCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  String _rotuloTerceiro(int i) {
    final tp = widget.claim.terceiros[i];
    final nome = tp.nome.isEmpty ? 'Terceiro ${i + 1}' : tp.nome;
    return tp.placa.isEmpty ? nome : '$nome (${tp.placa})';
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _dataEvento,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null) setState(() => _dataEvento = escolhida);
  }

  Future<void> _anexar() async {
    final r = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'xml', 'doc', 'docx'],
    );
    if (r != null && r.files.isNotEmpty) setState(() => _arquivos.addAll(r.files));
  }

  Future<void> _salvar() async {
    final valor = lerMoedaDigitada(_valorCtrl.text);
    final terceiro = _beneficiario >= 0 ? widget.claim.terceiros[_beneficiario] : null;
    final beneficiario = terceiro != null ? BeneficiarioLancamento.terceiro : BeneficiarioLancamento.segurado;

    // O id do terceiro pode estar vazio (cadastrado antes da Etapa 02): o
    // serviço cria. Para validar, basta ter escolhido um terceiro.
    final erro = LancamentoSinistro.validar(
      valor: valor,
      tipo: _tipo,
      beneficiario: beneficiario,
      terceiroId: terceiro == null ? null : (terceiro.id.isEmpty ? 'novo' : terceiro.id),
      data: _dataEvento,
    );
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final anexos = await widget.service.enviarAnexos(widget.claim.numeroSinistro, _arquivos);
      final lancamento = LancamentoSinistro(
        id: LancamentoSinistro.novoId(),
        data: _dataEvento,
        tipo: _tipo,
        descricao: _descricaoCtrl.text.trim(),
        valor: valor,
        beneficiario: beneficiario,
        terceiroId: terceiro == null ? null : (terceiro.id.isEmpty ? null : terceiro.id),
        terceiroNome: terceiro?.nome,
        anexos: anexos,
        registradoPor: widget.usuarioNome,
        registradoPorEmail: widget.usuarioEmail,
        registradoEm: DateTime.now(),
      );
      await widget.service.adicionar(
        claimId: widget.claim.id,
        lancamento: lancamento,
        terceiroIndex: terceiro == null ? null : _beneficiario,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = 'Não foi possível gravar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final terceiros = widget.claim.terceiros;
    return AlertDialog(
      title: const Text('Novo lançamento de valor'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<int>(
                value: _beneficiario,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'A quem se refere'),
                items: [
                  const DropdownMenuItem(value: -1, child: Text('Segurado')),
                  for (var i = 0; i < terceiros.length; i++)
                    DropdownMenuItem(value: i, child: Text('Terceiro — ${_rotuloTerceiro(i)}')),
                ],
                onChanged: _salvando ? null : (v) => setState(() => _beneficiario = v ?? -1),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _tipo,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: TiposLancamento.manuais
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: _salvando ? null : (v) => setState(() => _tipo = v ?? TiposLancamento.outro),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _salvando ? null : _escolherData,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Data do evento'),
                        child: Text(_data.format(_dataEvento)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _valorCtrl,
                      enabled: !_salvando,
                      keyboardType: TextInputType.number,
                      inputFormatters: [BRFormatters.moedaFormatter],
                      decoration: const InputDecoration(labelText: 'Valor', hintText: 'R\$ 0,00'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descricaoCtrl,
                enabled: !_salvando,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex.: troca do para-choque — NF 1234 — Oficina X',
                ),
              ),
              const SizedBox(height: 12),
              Text('Nota fiscal / evidências', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  ..._arquivos.map((f) => Chip(
                        label: Text(f.name, overflow: TextOverflow.ellipsis),
                        onDeleted: _salvando ? null : () => setState(() => _arquivos.remove(f)),
                      )),
                  ActionChip(
                    avatar: const Icon(Icons.attach_file, size: 16),
                    label: const Text('Anexar'),
                    onPressed: _salvando ? null : _anexar,
                  ),
                ],
              ),
              if (_erro != null) ...[
                const SizedBox(height: 12),
                Text(_erro!, style: TextStyle(color: Colors.red.shade700)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _salvando ? null : _salvar,
          icon: _salvando
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.check),
          label: Text(_salvando ? 'Gravando…' : 'Gravar lançamento'),
        ),
      ],
    );
  }
}
