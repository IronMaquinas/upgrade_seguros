// lib/admin/portal_app.dart — Etapa 21: telas do portal da plataforma
//
//   PortaoPlataforma  login → confere no servidor se é admin → portal
//   _Portal           menu lateral: Visão geral · Corretoras · Auditoria
//
// Se a conta não for admin da plataforma (ou for usuário de uma corretora), o
// servidor recusa e o portal sai na hora.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'aba_seguradoras_portal.dart'; // Etapa 22
import 'plataforma_api.dart';

const _kEscuro = Color(0xFF263238);
const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);
const _kLaranja = Color(0xFFEF6C00);
const _kVermelho = Color(0xFFC62828);

Color corSituacao(String s) => switch (s) {
      'ativa' => _kVerde,
      'teste' => _kAzul,
      'teste_encerrado' || 'inadimplente' => _kLaranja,
      'suspensa' || 'cancelada' => _kVermelho,
      _ => Colors.grey.shade600,
    };

// ── Portão ─────────────────────────────────────────────────────────────────

class PortaoPlataforma extends StatefulWidget {
  const PortaoPlataforma({super.key});
  @override
  State<PortaoPlataforma> createState() => _PortaoPlataformaState();
}

class _PortaoPlataformaState extends State<PortaoPlataforma> {
  String? _email; // admin confirmado
  bool _conferindo = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    // Sessão já aberta (recarregou a página): confere de novo no servidor.
    if (FirebaseAuth.instance.currentUser != null) {
      _conferindo = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _conferir(entrada: false));
    }
  }

  Future<void> _conferir({required bool entrada}) async {
    setState(() {
      _conferindo = true;
      _aviso = null;
    });
    try {
      // token novo: a marca "plataforma" pode ter sido dada depois do último login
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      final email = await PlataformaApi.eu(entrada: entrada);
      if (mounted) setState(() => _email = email);
    } on AcessoNegado catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _aviso = e.mensagem);
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) setState(() => _aviso = 'Não foi possível conferir o acesso: $e');
    } finally {
      if (mounted) setState(() => _conferindo = false);
    }
  }

  Future<void> _sair() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() => _email = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_email != null) return _Portal(email: _email!, onSair: _sair);
    if (_conferindo) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return _Login(aviso: _aviso, onEntrou: () => _conferir(entrada: true));
  }
}

class _Login extends StatefulWidget {
  final String? aviso;
  final VoidCallback onEntrou;
  const _Login({this.aviso, required this.onEntrou});
  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _entrando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _entrando = true;
      _erro = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _senha.text);
      widget.onEntrou();
    } on FirebaseAuthException catch (e) {
      setState(() => _erro = switch (e.code) {
            'too-many-requests' => 'Muitas tentativas. Aguarde alguns minutos.',
            'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-email' => 'E-mail ou senha incorretos.',
            _ => 'Não foi possível entrar (${e.code}).',
          });
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aviso = _erro ?? widget.aviso;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: AutofillGroup(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 40, color: _kEscuro),
                  const SizedBox(height: 8),
                  const Text('Portal da plataforma', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Acesso restrito', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _email,
                    autofillHints: const [AutofillHints.email],
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _senha,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                    onSubmitted: (_) => _entrando ? null : _entrar(),
                  ),
                  if (aviso != null) ...[
                    const SizedBox(height: 12),
                    Text(aviso, style: const TextStyle(color: _kVermelho)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _entrando ? null : _entrar,
                    style: FilledButton.styleFrom(backgroundColor: _kEscuro, padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _entrando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Entrar'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Portal ─────────────────────────────────────────────────────────────────

class _Portal extends StatefulWidget {
  final String email;
  final VoidCallback onSair;
  const _Portal({required this.email, required this.onSair});
  @override
  State<_Portal> createState() => _PortalState();
}

class _PortalState extends State<_Portal> {
  int _aba = 0;
  List<CorretoraPlataforma>? _corretoras;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final l = await PlataformaApi.corretoras();
      if (mounted) setState(() => _corretoras = l);
    } on AcessoNegado {
      widget.onSair();
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final telas = [
      _VisaoGeral(corretoras: _corretoras, erro: _erro, onRecarregar: _carregar),
      _Corretoras(corretoras: _corretoras, erro: _erro, onRecarregar: _carregar),
      const AbaSeguradorasPortal(), // Etapa 22
      const _Auditoria(),
    ];
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kEscuro,
        foregroundColor: Colors.white,
        title: const Text('Portal da plataforma'),
        actions: [
          Center(child: Text(widget.email, style: const TextStyle(fontSize: 13))),
          IconButton(tooltip: 'Sair', icon: const Icon(Icons.logout), onPressed: widget.onSair),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: _aba,
          onDestinationSelected: (i) => setState(() => _aba = i),
          labelType: NavigationRailLabelType.all,
          backgroundColor: Colors.white,
          destinations: const [
            NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Visão geral')),
            NavigationRailDestination(icon: Icon(Icons.business_outlined), selectedIcon: Icon(Icons.business), label: Text('Corretoras')),
            NavigationRailDestination(icon: Icon(Icons.shield_outlined), selectedIcon: Icon(Icons.shield), label: Text('Seguradoras')),
            NavigationRailDestination(icon: Icon(Icons.history), label: Text('Auditoria')),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: telas[_aba]),
      ]),
    );
  }
}

Widget _carregandoOuErro(String? erro, VoidCallback onRecarregar) {
  if (erro == null) return const Center(child: CircularProgressIndicator());
  return Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(erro, style: const TextStyle(color: _kVermelho)),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: onRecarregar, child: const Text('Tentar de novo')),
    ]),
  );
}

class _Cartao extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icone;
  final Color cor;
  const _Cartao(this.titulo, this.valor, this.icone, this.cor);
  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(titulo, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ]),
          ),
        ]),
      );
}

class _VisaoGeral extends StatefulWidget {
  final List<CorretoraPlataforma>? corretoras;
  final String? erro;
  final Future<void> Function() onRecarregar;
  const _VisaoGeral({required this.corretoras, required this.erro, required this.onRecarregar});
  @override
  State<_VisaoGeral> createState() => _VisaoGeralState();
}

class _VisaoGeralState extends State<_VisaoGeral> {
  bool _criando = false;

  Future<void> _criarContas() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Criar contas que faltam'),
        content: const Text('As corretoras sem conta entram como "Ativa", plano "Tudo ligado", cortesia '
            '(corretoras anteriores aos planos). Fica registrado no histórico e na auditoria.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Criar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _criando = true);
    try {
      final criadas = await PlataformaApi.criarContasQueFaltam();
      await widget.onRecarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${criadas.length} conta(s) criada(s).')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.corretoras;
    if (l == null) return _carregandoOuErro(widget.erro, widget.onRecarregar);
    final r = ResumoPlataforma.de(l);
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Visão geral', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Cartao('Corretoras', '${r.corretoras}', Icons.business, _kEscuro),
        _Cartao('Usuários', '${r.usuarios}', Icons.people_outline, _kAzul),
        _Cartao('Atendimentos', '${r.atendimentos}', Icons.assignment_outlined, _kAzul),
        for (final e in r.porSituacao.entries) _Cartao(rotuloSituacao(e.key), '${e.value}', Icons.circle, corSituacao(e.key)),
      ]),
      if (r.semConta > 0) ...[
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFFCC80))),
          child: Row(children: [
            const Icon(Icons.warning_amber, color: _kLaranja),
            const SizedBox(width: 10),
            Expanded(child: Text('${r.semConta} corretora(s) sem conta na plataforma. Sem conta, ficam fora da receita e dos planos.')),
            FilledButton(
              onPressed: _criando ? null : _criarContas,
              style: FilledButton.styleFrom(backgroundColor: _kLaranja),
              child: Text(_criando ? 'Criando…' : 'Criar contas que faltam'),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 24),
      Text('Em breve: planos e módulos, cadastro de novas corretoras com teste grátis, receita.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
    ]);
  }
}

class _Corretoras extends StatelessWidget {
  final List<CorretoraPlataforma>? corretoras;
  final String? erro;
  final Future<void> Function() onRecarregar;
  const _Corretoras({required this.corretoras, required this.erro, required this.onRecarregar});

  @override
  Widget build(BuildContext context) {
    final l = corretoras;
    if (l == null) return _carregandoOuErro(erro, onRecarregar);
    String n(int? v) => v == null ? '–' : '$v';
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Text('Corretoras', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: onRecarregar),
      ]),
      const SizedBox(height: 12),
      for (final c in l)
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _detalhe(context, c),
            leading: CircleAvatar(backgroundColor: _kEscuro.withOpacity(0.08), child: const Icon(Icons.business, color: _kEscuro)),
            title: Text(c.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              if (c.cnpj.isNotEmpty) c.cnpj,
              '${n(c.usuarios)} usuário(s)',
              '${n(c.sinistros)} sinistro(s)',
              '${n(c.assistencias)} assistência(s)',
              '${n(c.clientes)} cliente(s)',
            ].join(' · ')),
            trailing: _ChipSituacao(c.conta),
          ),
        ),
    ]);
  }

  void _detalhe(BuildContext context, CorretoraPlataforma c) {
    final d = DateFormat('dd/MM/yyyy');
    Widget linha(String r, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(r, style: TextStyle(color: Colors.grey.shade600))),
            Expanded(child: SelectableText(v.isEmpty ? '–' : v)),
          ]),
        );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(c.nome),
        content: SizedBox(
          width: 460,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            linha('Razão social', c.razaoSocial),
            linha('CNPJ', c.cnpj),
            linha('E-mail', c.email),
            linha('Telefone', c.telefone),
            linha('Criada em', c.criadaEm == null ? '' : d.format(c.criadaEm!)),
            linha('Identificador', c.id),
            const Divider(height: 20),
            linha('Situação', rotuloSituacao(c.conta?.situacao ?? '')),
            linha('Plano', c.conta == null ? '' : '${c.conta!.planoNome}${c.conta!.cortesia ? ' (cortesia)' : ''}'),
            if (c.conta?.testeAte != null) linha('Teste até', d.format(c.conta!.testeAte!)),
            if ((c.conta?.observacao ?? '').isNotEmpty) linha('Observação', c.conta!.observacao),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }
}

class _ChipSituacao extends StatelessWidget {
  final ContaPlataforma? conta;
  const _ChipSituacao(this.conta);
  @override
  Widget build(BuildContext context) {
    final s = conta?.situacao ?? '';
    final cor = corSituacao(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(rotuloSituacao(s), style: TextStyle(color: cor, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class _Auditoria extends StatefulWidget {
  const _Auditoria();
  @override
  State<_Auditoria> createState() => _AuditoriaState();
}

class _AuditoriaState extends State<_Auditoria> {
  List<AcaoAuditoria>? _acoes;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final a = await PlataformaApi.auditoria();
      if (mounted) setState(() => _acoes = a);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _acoes;
    if (a == null) return _carregandoOuErro(_erro, _carregar);
    final f = DateFormat('dd/MM/yyyy HH:mm');
    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Text('Auditoria', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text('(últimas 100 ações)', style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _carregar),
      ]),
      const SizedBox(height: 12),
      if (a.isEmpty) Text('Nenhuma ação registrada.', style: TextStyle(color: Colors.grey.shade600)),
      for (final x in a)
        Card(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text(rotuloAcao(x.acao), style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text([
              x.email,
              if (x.alvoId.isNotEmpty) '${x.alvoTipo}: ${x.alvoId}',
              if (x.detalhes['ids'] is List) '${(x.detalhes['ids'] as List).length} item(ns)',
            ].join(' · ')),
            trailing: Text(x.em == null ? '' : f.format(x.em!), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ),
        ),
    ]);
  }
}
