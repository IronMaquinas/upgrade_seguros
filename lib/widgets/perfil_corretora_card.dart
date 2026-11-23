// lib/widgets/perfil_corretora_card.dart
//
// Etapa 17: "🏢 Dados da corretora" em Configurações. É daqui que saem o
// cabeçalho (logo, nome, razão social, CNPJ, SUSEP, endereço, contatos) dos
// PDFs e o nome da corretora na assinatura e nas mensagens.
// Grava no cadastro da corretora (corretoras/{id}); só o gestor altera —
// funcionário vê somente leitura (mesma regra do banco, Etapa 16b).
// A logo vai para a pasta da corretora no Storage (corretoras/{id}/perfil/).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/corretora_model.dart';
import '../services/auth_service.dart';
import '../services/empresa_atual.dart';
import '../services/firestore_service.dart';
import '../utils/arquivos.dart';
import '../utils/perfil_corretora.dart';

class CartaoPerfilCorretora extends StatefulWidget {
  /// Chamado depois de salvar (a tela de assinatura usa nome/telefone/e-mail).
  final ValueChanged<Corretora>? onSalvo;

  const CartaoPerfilCorretora({super.key, this.onSalvo});

  @override
  State<CartaoPerfilCorretora> createState() => _CartaoPerfilCorretoraState();
}

class _CartaoPerfilCorretoraState extends State<CartaoPerfilCorretora> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _razao = TextEditingController();
  final _cnpj = TextEditingController();
  final _susep = TextEditingController();
  final _endereco = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();
  final _site = TextEditingController();

  Corretora? _corretora;
  String? _logoUrl;
  String? _logoCaminho;
  bool _carregando = true;
  bool _salvando = false;
  bool _enviandoLogo = false;
  bool _gestor = false;
  bool _alterado = false;

  @override
  void initState() {
    super.initState();
    AuthService().isAdmin().then((a) {
      if (mounted) setState(() => _gestor = a);
    }).catchError((_) {});
    _carregar();
  }

  @override
  void dispose() {
    for (final c in [_nome, _razao, _cnpj, _susep, _endereco, _telefone, _email, _site]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      if (!EmpresaAtual.carregada) await EmpresaAtual.carregar();
      final s = await EmpresaAtual.doc.get();
      final c = Corretora.fromMap(s.data() ?? const {}, s.id);
      if (!mounted) return;
      setState(() {
        _corretora = c;
        _nome.text = c.nome;
        _razao.text = c.razaoSocial ?? '';
        _cnpj.text = c.cnpj ?? '';
        _susep.text = c.susep ?? '';
        _endereco.text = c.endereco ?? '';
        _telefone.text = c.telefone;
        _email.text = c.email;
        _site.text = c.site ?? '';
        _logoUrl = (c.logo ?? '').isEmpty ? null : c.logo;
        _logoCaminho = c.logoCaminho;
        _carregando = false;
        _alterado = false;
      });
    } catch (e) {
      if (mounted) setState(() => _carregando = false);
      _aviso('Não foi possível carregar os dados da corretora: $e', erro: true);
    }
  }

  void _aviso(String texto, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: erro ? Colors.red.shade600 : null),
    );
  }

  Future<void> _escolherLogo() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
      withData: true,
    );
    final f = r?.files.single;
    if (f == null) return;
    if (!PerfilCorretora.logoAceita(f.name, f.size)) {
      _aviso('A logo precisa ser PNG ou JPG, com até 2 MB.', erro: true);
      return;
    }
    setState(() => _enviandoLogo = true);
    try {
      final urls = await FirestoreService().uploadArquivosEmPasta('perfil', [f]);
      setState(() {
        _logoUrl = urls.first;
        _logoCaminho = Arquivos.caminhoDoArquivo(urls.first);
        _alterado = true;
      });
      _aviso('Logo enviada. Clique em "Salvar" para usar nos PDFs.');
    } catch (e) {
      _aviso('Erro ao enviar a logo: $e', erro: true);
    } finally {
      if (mounted) setState(() => _enviandoLogo = false);
    }
  }

  Future<void> _salvar() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final antes = _corretora;
    final novo = (antes ?? Corretora(nome: '')).copyWith(
      nome: _nome.text,
      razaoSocial: _razao.text,
      cnpj: _cnpj.text,
      susep: _susep.text,
      endereco: _endereco.text,
      telefone: _telefone.text,
      email: _email.text,
      site: _site.text,
    )
      ..logo = _logoUrl
      ..logoCaminho = _logoCaminho;
    setState(() => _salvando = true);
    try {
      await EmpresaAtual.doc.update({
        ...novo.dadosPerfil(),
        'perfilAtualizadoEm': DateTime.now(),
      });
      // Logo trocada: apaga a anterior (só se for da pasta da corretora).
      final logoAntiga = antes?.logo ?? '';
      if (logoAntiga.isNotEmpty && logoAntiga != _logoUrl && (Arquivos.caminhoDoArquivo(logoAntiga) ?? '').startsWith('corretoras/')) {
        FirestoreService().deleteFileByUrl(logoAntiga).catchError((_) {});
      }
      setState(() {
        _corretora = novo;
        _alterado = false;
      });
      widget.onSalvo?.call(novo);
      _aviso('✅ Dados da corretora salvos. Os próximos PDFs já saem com eles.');
    } catch (e) {
      _aviso('Erro ao salvar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Widget _campo(TextEditingController c, String rotulo, {String? dica, bool obrigatorio = false, int linhas = 1}) {
    return TextFormField(
      controller: c,
      readOnly: !_gestor,
      maxLines: linhas,
      onChanged: (_) {
        if (!_alterado) setState(() => _alterado = true);
      },
      validator: obrigatorio ? (v) => (v ?? '').trim().isEmpty ? 'Obrigatório' : null : null,
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: dica,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _linha(List<Widget> filhos) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 560) {
        return Column(children: [
          for (var i = 0; i < filhos.length; i++) ...[if (i > 0) const SizedBox(height: 12), filhos[i]],
        ]);
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < filhos.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: filhos[i])],
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: _carregando
          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          : Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🏢 Dados da corretora', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    _gestor
                        ? 'Cabeçalho de todos os PDFs (sinistro, relatórios, tarefas) e nome nas mensagens.'
                        : 'Cabeçalho dos PDFs. Somente leitura: só o gestor altera.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _enviandoLogo
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : _logoUrl == null
                                ? Text('Sem logo', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))
                                : Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Image.network(
                                      _logoUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          Text('Logo não abriu', style: TextStyle(fontSize: 11, color: Colors.red.shade400)),
                                    ),
                                  ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_gestor)
                              Wrap(spacing: 8, children: [
                                OutlinedButton.icon(
                                  onPressed: _enviandoLogo || _salvando ? null : _escolherLogo,
                                  icon: const Icon(Icons.upload, size: 18),
                                  label: Text(_logoUrl == null ? 'Enviar logo' : 'Trocar logo'),
                                ),
                                if (_logoUrl != null)
                                  TextButton(
                                    onPressed: _enviandoLogo || _salvando
                                        ? null
                                        : () => setState(() {
                                              _logoUrl = null;
                                              _logoCaminho = null;
                                              _alterado = true;
                                            }),
                                    child: const Text('Remover'),
                                  ),
                              ]),
                            const SizedBox(height: 4),
                            Text(
                              'PNG ou JPG, até 2 MB. De preferência horizontal e com fundo branco ou transparente.',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _linha([
                    _campo(_nome, 'Nome (fantasia)', dica: 'Ex.: Upgrade Seguros', obrigatorio: true),
                    _campo(_razao, 'Razão social', dica: 'Ex.: Upgrade Corretora de Seguros Ltda.'),
                  ]),
                  const SizedBox(height: 12),
                  _linha([
                    _campo(_cnpj, 'CNPJ', dica: '00.000.000/0000-00'),
                    _campo(_susep, 'Registro SUSEP'),
                  ]),
                  const SizedBox(height: 12),
                  _campo(_endereco, 'Endereço', dica: 'Rua, número, bairro, cidade/UF, CEP', linhas: 2),
                  const SizedBox(height: 12),
                  _linha([
                    _campo(_telefone, 'Telefone'),
                    _campo(_email, 'E-mail'),
                    _campo(_site, 'Site'),
                  ]),
                  if (_gestor) ...[
                    const SizedBox(height: 16),
                    Row(children: [
                      ElevatedButton.icon(
                        onPressed: _salvando || _enviandoLogo || !_alterado ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save, size: 18),
                        label: const Text('Salvar'),
                      ),
                      const SizedBox(width: 8),
                      if (_alterado)
                        TextButton(
                          onPressed: _salvando ? null : _carregar,
                          child: const Text('Descartar alterações'),
                        ),
                    ]),
                  ],
                ],
              ),
            ),
    );
  }
}
