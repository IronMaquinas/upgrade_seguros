// lib/widgets/beta_chat.dart — Etapa 28: Beta, a assistente
//
//   • BotaoBeta   botão flutuante no canto INFERIOR ESQUERDO (o direito já tem
//                 o "Novo Registro"); só aparece com o módulo 'beta' no plano.
//   • painel      chat: pergunta → Function "beta" → cartões com os dados e
//                 botões (ligar, WhatsApp, e-mail, abrir o atendimento, escolher
//                 cliente). A conversa fica na memória enquanto o app está
//                 aberto; o servidor lembra o ASSUNTO (último sinistro/cliente),
//                 então "e do terceiro?" funciona sem repetir o número.
//
// A Beta só responde com dados do banco da corretora. O que não souber, ela diz
// e guarda a pergunta para a plataforma avaliar.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/assist_detail_screen.dart';
import '../screens/claim_detail_screen.dart';
import '../services/firestore_service.dart';
import '../services/funcoes_nuvem.dart';

const _kRoxo = Color(0xFF5E35B1);
const _kFundo = Color(0xFFF8F9FB);

class _Acao {
  final String tipo; // ligar · whatsapp · email · abrir · escolher
  final String valor;
  final String rotulo;
  final String tipoAtendimento;
  _Acao(Map m)
      : tipo = '${m['tipo'] ?? ''}',
        valor = '${m['valor'] ?? ''}',
        rotulo = '${m['rotulo'] ?? ''}',
        tipoAtendimento = '${m['tipoAtendimento'] ?? ''}';
}

class _Item {
  final String titulo;
  final List<String> linhas;
  final List<_Acao> acoes;
  _Item(Map m)
      : titulo = '${m['titulo'] ?? ''}',
        linhas = [for (final l in (m['linhas'] as List? ?? const [])) '$l'],
        acoes = [for (final a in (m['acoes'] as List? ?? const [])) _Acao(a as Map)];
}

class _Mensagem {
  final bool minha;
  final String texto;
  final List<_Item> itens;
  final List<_Acao> acoes;
  final bool fora;
  _Mensagem.minha(this.texto)
      : minha = true,
        itens = const [],
        acoes = const [],
        fora = false;
  _Mensagem.beta(this.texto, {this.itens = const [], this.acoes = const [], this.fora = false}) : minha = false;
}

/// Conversa da sessão (some ao recarregar o app ou em "Nova conversa").
final List<_Mensagem> _conversa = [];
bool _novaNaProxima = true;

class BotaoBeta extends StatelessWidget {
  final bool celular;
  const BotaoBeta({super.key, this.celular = false});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'beta',
      backgroundColor: _kRoxo,
      foregroundColor: Colors.white,
      onPressed: () => abrirBeta(context, celular: celular),
      icon: const Icon(Icons.auto_awesome),
      label: const Text('Beta', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

Future<void> abrirBeta(BuildContext context, {bool celular = false}) {
  if (celular) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * 0.88, child: const _PainelBeta()),
    );
  }
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black26,
    pageBuilder: (_, __, ___) => Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: const SizedBox(width: 420, height: 600, child: _PainelBeta()),
        ),
      ),
    ),
  );
}

class _PainelBeta extends StatefulWidget {
  const _PainelBeta();
  @override
  State<_PainelBeta> createState() => _PainelBetaState();
}

class _PainelBetaState extends State<_PainelBeta> {
  final _texto = TextEditingController();
  final _rolagem = ScrollController();
  bool _enviando = false;

  @override
  void dispose() {
    _texto.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  void _descer() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_rolagem.hasClients) _rolagem.animateTo(_rolagem.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });

  Future<void> _enviar({String? texto, String? escolherClienteId, String? rotuloEscolha}) async {
    final msg = (texto ?? _texto.text).trim();
    if (msg.isEmpty && escolherClienteId == null) return;
    setState(() {
      _conversa.add(_Mensagem.minha(escolherClienteId != null ? (rotuloEscolha ?? 'Esse') : msg));
      _enviando = true;
      _texto.clear();
    });
    _descer();
    try {
      final r = await FuncoesNuvem.post('beta', {
        'mensagem': msg,
        if (escolherClienteId != null) 'escolherClienteId': escolherClienteId,
        if (_novaNaProxima) 'novaConversa': true,
      });
      _novaNaProxima = false;
      if (r.statusCode != 200) {
        _conversa.add(_Mensagem.beta(FuncoesNuvem.erro(r), fora: true));
      } else {
        final j = jsonDecode(r.body) as Map;
        _conversa.add(_Mensagem.beta(
          '${j['texto'] ?? ''}',
          itens: [for (final i in (j['itens'] as List? ?? const [])) _Item(i as Map)],
          acoes: [for (final a in (j['acoes'] as List? ?? const [])) _Acao(a as Map)],
          fora: j['foraDoEscopo'] == true,
        ));
      }
    } catch (_) {
      _conversa.add(_Mensagem.beta('Não consegui falar com o servidor. Confira a internet e tente de novo.', fora: true));
    } finally {
      if (mounted) setState(() => _enviando = false);
      _descer();
    }
  }

  Future<void> _acao(_Acao a) async {
    switch (a.tipo) {
      case 'ligar':
        await launchUrl(Uri.parse('tel:${a.valor}'));
        break;
      case 'whatsapp':
        await launchUrl(Uri.parse('https://wa.me/${a.valor}'), mode: LaunchMode.externalApplication);
        break;
      case 'email':
        await launchUrl(Uri.parse('mailto:${a.valor}'));
        break;
      case 'escolher':
        await _enviar(escolherClienteId: a.valor, rotuloEscolha: a.rotulo);
        break;
      case 'abrir':
        final nav = Navigator.of(context);
        nav.pop(); // fecha a Beta (a conversa continua guardada)
        if (a.tipoAtendimento == 'assistencia') {
          nav.push(MaterialPageRoute(builder: (_) => AssistDetailScreen(assistId: a.valor)));
        } else {
          final claim = await FirestoreService().getClaimById(a.valor);
          if (claim != null) nav.push(MaterialPageRoute(builder: (_) => ClaimDetailScreen(claim: claim)));
        }
        break;
    }
  }

  Widget _botao(_Acao a) {
    final icone = switch (a.tipo) {
      'ligar' => Icons.call,
      'whatsapp' => Icons.chat,
      'email' => Icons.mail_outline,
      'abrir' => Icons.open_in_new,
      _ => Icons.person_outline,
    };
    final cor = a.tipo == 'whatsapp' ? const Color(0xFF2E7D32) : _kRoxo;
    return ActionChip(
      avatar: Icon(icone, size: 16, color: cor),
      label: Text(a.rotulo, style: TextStyle(fontSize: 12.5, color: cor)),
      backgroundColor: Colors.white,
      side: BorderSide(color: cor.withOpacity(0.4)),
      onPressed: () => _acao(a),
    );
  }

  Widget _bolha(_Mensagem m) {
    if (m.minha) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: _kRoxo, borderRadius: BorderRadius.circular(14)),
          child: Text(m.texto, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 24, bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: m.fora ? const Color(0xFFFFF8E1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m.texto.isNotEmpty) Text(m.texto, style: const TextStyle(fontWeight: FontWeight.w600)),
          for (final i in m.itens) ...[
            const SizedBox(height: 8),
            Text(i.titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kRoxo)),
            for (final l in i.linhas) SelectableText(l, style: const TextStyle(fontSize: 13.5)),
            if (i.acoes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final a in i.acoes) _botao(a)])),
          ],
          if (m.acoes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 4, children: [for (final a in m.acoes) _botao(a)])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kFundo,
      child: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
          child: Row(children: [
            const CircleAvatar(radius: 16, backgroundColor: _kRoxo, child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Beta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('Contatos, veículos e situação dos atendimentos', style: TextStyle(fontSize: 11.5, color: Colors.grey)),
              ]),
            ),
            IconButton(
              tooltip: 'Nova conversa',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {
                _conversa.clear();
                _novaNaProxima = true;
              }),
            ),
            IconButton(tooltip: 'Fechar', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
          ]),
        ),
        Expanded(
          child: _conversa.isEmpty
              ? ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Pergunte, por exemplo:', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  for (final ex in const [
                    'Telefone do segurado do sinistro SN…',
                    'E o contato do terceiro?',
                    'Qual o veículo segurado desse sinistro?',
                    'Tem ação pendente?',
                    'Quais os sinistros do cliente …?',
                    'De quem é a placa ABC1D23?',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        onTap: () => _texto.text = ex.replaceAll('…', ''),
                        child: Text('• $ex', style: const TextStyle(color: _kRoxo)),
                      ),
                    ),
                ])
              : ListView(controller: _rolagem, padding: const EdgeInsets.all(12), children: [for (final m in _conversa) _bolha(m)]),
        ),
        if (_enviando) const LinearProgressIndicator(minHeight: 2, color: _kRoxo),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _texto,
                  autofocus: true,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _enviando ? null : _enviar(),
                  decoration: InputDecoration(
                    hintText: 'Pergunte à Beta…',
                    isDense: true,
                    filled: true,
                    fillColor: _kFundo,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.send, color: _kRoxo), onPressed: _enviando ? null : () => _enviar()),
            ]),
          ),
        ),
      ]),
    );
  }
}
