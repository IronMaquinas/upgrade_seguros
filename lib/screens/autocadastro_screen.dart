// lib/screens/autocadastro_screen.dart — Etapa 25: "Teste 14 dias grátis"
//
// Aberta pela tela de entrada, sem login. A corretora informa o CNPJ (consulta
// na Receita feita no navegador, como em Dados da corretora), o nome, o
// responsável e o e-mail. Vira um PEDIDO (Function autocadastro); depois que a
// plataforma aprova, o responsável recebe o e-mail para criar a senha e entra
// como gestor, com 14 dias de teste.

import 'package:flutter/material.dart';
import 'package:upgrade_seguros/services/funcoes_nuvem.dart';
import 'package:upgrade_seguros/services/receita_cnpj.dart';
import 'package:upgrade_seguros/utils/perfil_corretora.dart';

const _kAzul = Color(0xFF1565C0);
const _kVermelho = Color(0xFFC62828);

class AutocadastroScreen extends StatefulWidget {
  const AutocadastroScreen({super.key});
  @override
  State<AutocadastroScreen> createState() => _AutocadastroScreenState();
}

class _AutocadastroScreenState extends State<AutocadastroScreen> {
  final _cnpj = TextEditingController();
  final _nome = TextEditingController();
  final _responsavel = TextEditingController();
  final _email = TextEditingController();
  final _telefone = TextEditingController();
  final _susep = TextEditingController();
  final _site = TextEditingController(); // isca para robôs (fica escondido)

  DadosReceita? _receita;
  bool _consultando = false;
  bool _enviando = false;
  bool _aceite = false;
  bool _enviado = false;
  String? _erro;

  @override
  void dispose() {
    for (final c in [_cnpj, _nome, _responsavel, _email, _telefone, _susep, _site]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _consultar() async {
    setState(() {
      _consultando = true;
      _erro = null;
      _receita = null;
    });
    try {
      final r = await consultarReceitaCnpj(_cnpj.text);
      if (!mounted) return;
      if (!r.ativa) {
        setState(() => _erro = 'Na Receita, este CNPJ está "${r.situacao}". Só CNPJ ativo pode se cadastrar.');
        return;
      }
      setState(() {
        _receita = r;
        _cnpj.text = PerfilCorretora.formatarCnpj(_cnpj.text);
        if (_nome.text.trim().isEmpty) _nome.text = r.nomeFantasia.isNotEmpty ? r.nomeFantasia : r.razaoSocial;
        if (_telefone.text.trim().isEmpty) _telefone.text = r.telefone;
      });
    } on ErroReceita catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _enviar() async {
    final r = _receita;
    if (r == null) return setState(() => _erro = 'Consulte o CNPJ primeiro.');
    if (_nome.text.trim().isEmpty || _responsavel.text.trim().isEmpty) return setState(() => _erro = 'Preencha o nome da corretora e o seu nome.');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) return setState(() => _erro = 'E-mail inválido.');
    if (!_aceite) return setState(() => _erro = 'Marque que está de acordo para continuar.');
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final resp = await FuncoesNuvem.post(
        'autocadastro',
        {
          'cnpj': _cnpj.text,
          'nomeCorretora': _nome.text.trim(),
          'responsavel': _responsavel.text.trim(),
          'email': _email.text.trim(),
          'telefone': _telefone.text.trim(),
          'susep': _susep.text.trim(),
          'receita': {'razaoSocial': r.razaoSocial, 'nomeFantasia': r.nomeFantasia, 'situacao': r.situacao},
          'aceite': true,
          'site': _site.text,
        },
        comLogin: false,
      );
      if (!mounted) return;
      if (resp.statusCode != 200) return setState(() => _erro = FuncoesNuvem.erro(resp));
      setState(() => _enviado = true);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível enviar agora. Confira a internet e tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Teste 14 dias grátis'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF1A1A2E),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
              child: _enviado ? _recebido() : _formulario(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _recebido() => Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.mark_email_read_outlined, size: 52, color: _kAzul),
        const SizedBox(height: 12),
        const Text('Pedido recebido!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Vamos conferir os dados da corretora. Quando o cadastro for aprovado, ${_email.text.trim()} recebe um e-mail para criar a senha. '
          'O teste grátis de 14 dias começa na aprovação.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Voltar para a entrada')),
      ]);

  Widget _formulario() {
    final r = _receita;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Cadastre sua corretora', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('14 dias grátis, sem cartão. Depois do teste, o app fica só para consulta até você escolher um plano.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: TextField(
            controller: _cnpj,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'CNPJ da corretora', hintText: '00.000.000/0000-00'),
            onChanged: (_) {
              if (_receita != null) setState(() => _receita = null);
            },
            onSubmitted: (_) => _consultar(),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(onPressed: _consultando ? null : _consultar, child: Text(_consultando ? 'Consultando…' : 'Consultar')),
        ),
      ]),
      if (r != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(10)),
          child: SelectableText(
            [r.razaoSocial, if (r.nomeFantasia.isNotEmpty) 'Nome fantasia: ${r.nomeFantasia}', if (r.situacao.isNotEmpty) 'Situação: ${r.situacao}'].join('\n'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      if (r != null) ...[
        const SizedBox(height: 14),
        TextField(controller: _nome, decoration: const InputDecoration(labelText: 'Nome da corretora (como aparece no app)')),
        TextField(controller: _susep, decoration: const InputDecoration(labelText: 'Registro SUSEP (opcional)')),
        const SizedBox(height: 14),
        const Text('Responsável (vai ser o gestor no app)', style: TextStyle(fontWeight: FontWeight.w700)),
        TextField(controller: _responsavel, decoration: const InputDecoration(labelText: 'Seu nome')),
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Seu e-mail (vai ser o login)')),
        TextField(controller: _telefone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone / WhatsApp')),
        // isca: pessoas não veem; robôs preenchem
        Offstage(child: TextField(controller: _site, decoration: const InputDecoration(labelText: 'Site'))),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: _aceite,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('Declaro que represento esta corretora e concordo em usar os dados acima para o cadastro.', style: TextStyle(fontSize: 13)),
          onChanged: (v) => setState(() => _aceite = v == true),
        ),
      ],
      if (_erro != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_erro!, style: const TextStyle(color: _kVermelho))),
      const SizedBox(height: 18),
      if (r != null)
        SizedBox(
          height: 48,
          child: FilledButton(onPressed: _enviando ? null : _enviar, child: Text(_enviando ? 'Enviando…' : 'Pedir cadastro')),
        ),
    ]);
  }
}
