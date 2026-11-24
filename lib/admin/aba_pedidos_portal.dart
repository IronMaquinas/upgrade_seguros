// lib/admin/aba_pedidos_portal.dart — Etapa 25: portal → Pedidos
//
//   • Cadastro     corretora que se cadastrou pela tela de entrada ("Teste 14 dias
//                  grátis"). Aprovar cria a corretora, o gestor e a conta em teste
//                  e manda o e-mail para ele criar a senha. Recusar, com motivo.
//   • Contratação  "Quero este plano" / "Falar sobre o meu plano" (Meu plano no
//                  app). O admin combina com a corretora, ajusta Plano e Situação
//                  dela em Corretoras e marca como atendido.
//
// Também: abrirSituacaoDaConta — mudar a situação (teste, ativa, suspensa…).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'plataforma_api.dart';

const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);
const _kLaranja = Color(0xFFEF6C00);
const _kVermelho = Color(0xFFC62828);

class AbaPedidosPortal extends StatefulWidget {
  /// Avisa o portal (contador no menu, lista de corretoras) depois de uma ação.
  final Future<void> Function() onMudou;
  const AbaPedidosPortal({super.key, required this.onMudou});
  @override
  State<AbaPedidosPortal> createState() => _AbaPedidosPortalState();
}

class _AbaPedidosPortalState extends State<AbaPedidosPortal> {
  List<PedidoPlataforma>? _pedidos;
  String? _erro;
  bool _verResolvidos = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final p = await PlataformaApi.pedidos();
      if (mounted) setState(() => _pedidos = p);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _depois() async {
    await _carregar();
    await widget.onMudou();
  }

  void _msg(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _aprovar(PedidoPlataforma p) async {
    final r = await showDialog<({String? planoId, int dias})>(context: context, builder: (_) => _AprovarDialog(p));
    if (r == null) return;
    try {
      final email = await PlataformaApi.pedidoAprovar(p.id, planoId: r.planoId, diasTeste: r.dias);
      // E-mail padrão do Firebase para o gestor criar a senha (como em "criar usuário").
      var enviado = true;
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      } catch (_) {
        enviado = false;
      }
      if (mounted) {
        _msg(enviado
            ? 'Aprovado. $email recebeu o e-mail para criar a senha.'
            : 'Aprovado, mas o e-mail não foi enviado. Peça para $email usar "Esqueci minha senha" na entrada do app.');
      }
      await _depois();
    } catch (e) {
      if (mounted) _msg('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<String?> _pedirTexto(String titulo, String rotulo, String botao) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(titulo),
        content: SizedBox(width: 420, child: TextField(controller: c, maxLines: 3, decoration: InputDecoration(labelText: rotulo))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(botao)),
        ],
      ),
    );
    final t = c.text.trim();
    c.dispose();
    return ok == true ? t : null;
  }

  Future<void> _recusar(PedidoPlataforma p) async {
    final motivo = await _pedirTexto('Recusar pedido de ${p.nomeCorretora}', 'Motivo (fica registrado)', 'Recusar');
    if (motivo == null) return;
    try {
      await PlataformaApi.pedidoRecusar(p.id, motivo);
      await _depois();
    } catch (e) {
      if (mounted) _msg('$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _atendido(PedidoPlataforma p) async {
    final nota = await _pedirTexto('Pedido de ${p.nomeCorretora} atendido', 'Anotação (ex.: combinado o plano Essencial a partir de 01/12)', 'Marcar como atendido');
    if (nota == null) return;
    try {
      await PlataformaApi.pedidoAtendido(p.id, nota);
      await _depois();
    } catch (e) {
      if (mounted) _msg('$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos = _pedidos;
    final lista = todos?.where((p) => _verResolvidos || p.pendente).toList();
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Text('Pedidos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        FilterChip(label: const Text('Mostrar resolvidos'), selected: _verResolvidos, onSelected: (v) => setState(() => _verResolvidos = v)),
        IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _carregar),
      ]),
      const SizedBox(height: 6),
      Text('Cadastros pela tela de entrada do app ("Teste 14 dias grátis") e pedidos de plano feitos em Meu plano.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
      const SizedBox(height: 14),
      if (todos == null && _erro == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
      if (_erro != null) Text(_erro!, style: const TextStyle(color: _kVermelho)),
      if (lista != null && lista.isEmpty) Text('Nenhum pedido ${_verResolvidos ? '' : 'pendente'}.', style: TextStyle(color: Colors.grey.shade600)),
      if (lista != null)
        for (final p in lista)
          _CartaoPedido(p, onAprovar: () => _aprovar(p), onRecusar: () => _recusar(p), onAtendido: () => _atendido(p)),
    ]);
  }
}

class _CartaoPedido extends StatelessWidget {
  final PedidoPlataforma p;
  final VoidCallback onAprovar;
  final VoidCallback onRecusar;
  final VoidCallback onAtendido;
  const _CartaoPedido(this.p, {required this.onAprovar, required this.onRecusar, required this.onAtendido});

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    final (rotulo, cor) = switch (p.situacao) {
      'pendente' => ('Pendente', _kLaranja),
      'aprovado' => ('Aprovado', _kVerde),
      'atendido' => ('Atendido', _kVerde),
      'recusado' => ('Recusado', _kVermelho),
      _ => (p.situacao, Colors.grey),
    };
    Widget linha(String r, String v) => v.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(r, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600))),
              Expanded(child: SelectableText(v, style: const TextStyle(fontSize: 12.5))),
            ]),
          );
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(p.cadastro ? Icons.person_add_alt_1_outlined : Icons.workspace_premium_outlined, color: _kAzul),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${p.cadastro ? 'Cadastro' : 'Plano'} — ${p.nomeCorretora}',
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text(rotulo, style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 6),
          if (p.cadastro) ...[
            linha('CNPJ', p.cnpj),
            linha('Receita', [p.razaoSocial, if (p.nomeFantasia.isNotEmpty) p.nomeFantasia, if (p.situacaoReceita.isNotEmpty) p.situacaoReceita].join(' · ')),
            linha('SUSEP', p.susep),
          ],
          linha('Responsável', p.responsavel),
          linha('E-mail', p.email),
          linha('Telefone', p.telefone),
          if (!p.cadastro) linha('Plano pedido', p.planoNome.isEmpty ? '(quer conversar)' : p.planoNome),
          linha('Mensagem', p.mensagem),
          linha('Recebido em', p.criadoEm == null ? '' : f.format(p.criadoEm!)),
          if (!p.pendente) linha('Resolvido', [if (p.resolvidoEm != null) f.format(p.resolvidoEm!), p.resolvidoPor, p.motivo].where((x) => x.isNotEmpty).join(' · ')),
          if (p.cadastro && p.pendente)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Os dados da Receita foram consultados no navegador de quem pediu — confira o CNPJ antes de aprovar.',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ),
          if (p.pendente)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: onRecusar, style: TextButton.styleFrom(foregroundColor: _kVermelho), child: const Text('Recusar')),
              const SizedBox(width: 8),
              if (p.cadastro)
                FilledButton.icon(onPressed: onAprovar, icon: const Icon(Icons.check, size: 18), label: const Text('Aprovar'))
              else
                FilledButton.icon(onPressed: onAtendido, icon: const Icon(Icons.check, size: 18), label: const Text('Marcar como atendido')),
            ]),
        ]),
      ),
    );
  }
}

class _AprovarDialog extends StatefulWidget {
  final PedidoPlataforma p;
  const _AprovarDialog(this.p);
  @override
  State<_AprovarDialog> createState() => _AprovarDialogState();
}

class _AprovarDialogState extends State<_AprovarDialog> {
  List<PlanoModelo>? _planos;
  String _planoId = ''; // '' = Tudo ligado
  final _dias = TextEditingController(text: '14');
  String? _erro;

  @override
  void initState() {
    super.initState();
    PlataformaApi.planos().then((p) {
      if (mounted) setState(() => _planos = p.where((x) => x.ativo).toList());
    }).catchError((Object e) {
      if (mounted) setState(() => _planos = const []);
    });
  }

  @override
  void dispose() {
    _dias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planos = _planos;
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Aprovar ${widget.p.nomeCorretora}'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cria a corretora, o gestor (${widget.p.email}) e a conta em teste. Ele recebe o e-mail para criar a senha.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          const Text('Plano durante o teste', style: TextStyle(fontWeight: FontWeight.w700)),
          if (planos == null)
            const LinearProgressIndicator()
          else
            DropdownButton<String>(
              value: _planoId,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('Tudo ligado (mostra tudo o que o app faz)')),
                for (final p in planos) DropdownMenuItem(value: p.id, child: Text('${p.nome} — ${Planos.resumo(p.precoCentavos, p.franquias)}')),
              ],
              onChanged: (v) => setState(() => _planoId = v ?? ''),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: 160,
            child: TextField(controller: _dias, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Dias de teste', isDense: true)),
          ),
          if (_erro != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erro!, style: const TextStyle(color: _kVermelho))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final d = int.tryParse(_dias.text.trim());
            if (d == null || d < 1 || d > 90) return setState(() => _erro = 'Dias de teste: de 1 a 90.');
            Navigator.pop(context, (planoId: _planoId.isEmpty ? null : _planoId, dias: d));
          },
          child: const Text('Aprovar'),
        ),
      ],
    );
  }
}

// ── situação da conta (Corretoras → corretora → Situação) ────────────────────

/// true = salvou.
Future<bool> abrirSituacaoDaConta(BuildContext context, CorretoraPlataforma c) async {
  final r = await showDialog<bool>(context: context, builder: (_) => _SituacaoDialog(c));
  return r == true;
}

class _SituacaoDialog extends StatefulWidget {
  final CorretoraPlataforma c;
  const _SituacaoDialog(this.c);
  @override
  State<_SituacaoDialog> createState() => _SituacaoDialogState();
}

class _SituacaoDialogState extends State<_SituacaoDialog> {
  static const _opcoes = ['teste', 'ativa', 'inadimplente', 'suspensa', 'cancelada', 'teste_encerrado'];
  late String _situacao = _opcoes.contains(widget.c.conta!.situacao) ? widget.c.conta!.situacao : 'ativa';
  late DateTime _testeAte = (widget.c.conta!.testeAte != null && widget.c.conta!.testeAte!.isAfter(DateTime.now()))
      ? widget.c.conta!.testeAte!
      : DateTime.now().add(const Duration(days: 14));
  final _motivo = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  String _explica(String s) => switch (s) {
        'teste' => 'Teste grátis até a data escolhida; depois, só leitura.',
        'ativa' => 'Uso normal.',
        'inadimplente' => 'Uso normal, com aviso de pagamento pendente no app.',
        'suspensa' => 'Só leitura (aviso no app).',
        'cancelada' => 'Só leitura (aviso no app).',
        'teste_encerrado' => 'Só leitura: o teste terminou.',
        _ => '',
      };

  Future<void> _salvar() async {
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await PlataformaApi.contaDefinirSituacao(
        widget.c.id,
        _situacao,
        testeAte: _situacao == 'teste' ? DateFormat('yyyy-MM-dd').format(_testeAte) : null,
        motivo: _motivo.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy');
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Text('Situação — ${widget.c.nome}'),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final s in _opcoes)
            RadioListTile<String>(
              value: s,
              groupValue: _situacao,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(rotuloSituacao(s), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(_explica(s), style: const TextStyle(fontSize: 12)),
              onChanged: (v) => setState(() => _situacao = v!),
            ),
          if (_situacao == 'teste')
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: TextButton.icon(
                icon: const Icon(Icons.event, size: 18),
                label: Text('Teste até ${f.format(_testeAte)}'),
                onPressed: () async {
                  final hoje = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _testeAte,
                    firstDate: DateTime(hoje.year, hoje.month, hoje.day),
                    lastDate: DateTime(hoje.year + 1, hoje.month, hoje.day),
                  );
                  if (d != null) setState(() => _testeAte = d);
                },
              ),
            ),
          if (widget.c.conta!.cortesia)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('⚠ Corretora com cortesia: só leitura trava a equipe dela também.', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
            ),
          TextField(controller: _motivo, decoration: const InputDecoration(labelText: 'Motivo (vai para o histórico, opcional)', isDense: true)),
          if (_erro != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_erro!, style: const TextStyle(color: _kVermelho))),
        ]),
      ),
      actions: [
        TextButton(onPressed: _salvando ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvando ? null : _salvar, child: Text(_salvando ? 'Salvando…' : 'Salvar')),
      ],
    );
  }
}
