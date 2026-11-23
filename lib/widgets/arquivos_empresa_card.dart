// lib/widgets/arquivos_empresa_card.dart
//
// Etapa 16c: cartão de Configurações (só administrador) para passar os
// ARQUIVOS antigos (fotos, laudos, documentos, vídeos) para a pasta da
// corretora no Storage e trocar os links públicos por links com chave.
// Chama a Function arquivosEmpresa (functions/arquivos.js):
//   • Diagnóstico → quantos arquivos ainda estão nas pastas antigas.
//   • Passar arquivos → copia em lotes e troca os links nos documentos
//     (repete sozinho até terminar; pode interromper e continuar depois).
//   • Apagar originais → depois de 7 dias da conversão, apaga das pastas
//     antigas o que já tem cópia. Os links públicos antigos param de abrir.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/funcoes_nuvem.dart';

class CartaoArquivosEmpresa extends StatefulWidget {
  const CartaoArquivosEmpresa({super.key});

  @override
  State<CartaoArquivosEmpresa> createState() => _CartaoArquivosEmpresaState();
}

class _CartaoArquivosEmpresaState extends State<CartaoArquivosEmpresa> {
  bool? _admin;
  bool _ocupado = false;
  bool _parar = false;
  String _progresso = '';

  static const _negrito = TextStyle(fontWeight: FontWeight.w600);

  @override
  void initState() {
    super.initState();
    AuthService().isAdmin().then((a) {
      if (mounted) setState(() => _admin = a);
    }).catchError((_) {
      if (mounted) setState(() => _admin = false);
    });
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> corpo) async {
    final r = await FuncoesNuvem.post('arquivosEmpresa', corpo);
    if (r.statusCode != 200) throw Exception(FuncoesNuvem.erro(r));
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }

  void _erro(Object e) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
  }

  Future<void> _mostrar(String titulo, List<Widget> linhas) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectionArea(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: linhas),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar'))],
      ),
    );
  }

  Future<void> _diagnostico() async {
    setState(() => _ocupado = true);
    Map<String, dynamic>? d;
    try {
      d = await _post({'acao': 'diagnostico'});
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    if (d == null || !mounted) return;
    final porColecao = Map<String, dynamic>.from(d['documentosPorColecao'] as Map);
    final porPasta = Map<String, dynamic>.from(d['arquivosPorPasta'] as Map);
    final faltam = d['arquivosParaPassar'] as num;
    await _mostrar('Diagnóstico dos arquivos', [
      Text('Arquivos ainda nas pastas antigas: $faltam', style: _negrito),
      for (final e in porPasta.entries) Text('  ${e.key}/: ${e.value}'),
      const SizedBox(height: 8),
      Text('Documentos com link antigo: ${d['documentosComLinkAntigo']}'),
      for (final e in porColecao.entries) Text('  ${e.key}: ${e.value}'),
      const SizedBox(height: 8),
      Text('Arquivos já na pasta da corretora: ${d['arquivosJaNaPasta']}'),
      if ((d['arquivosSemOriginal'] as num) > 0)
        Text('Links para arquivos que não existem mais (ficam como estão): ${d['arquivosSemOriginal']}'),
      if ((d['linksDeOutroBucket'] as num) > 0)
        Text('Links de outro bucket (não mexidos): ${d['linksDeOutroBucket']}'),
      const SizedBox(height: 12),
      Text(
        faltam > 0
            ? '⚠️ Use "Passar arquivos" (de preferência fora do expediente).'
            : d['podeApagarOriginais'] == true
                ? '✅ Tudo passado. Já é possível apagar os originais.'
                : '✅ Tudo passado. Os originais só podem ser apagados ${d['diasMinimos']} dias depois da conversão '
                    '(hoje: ${d['diasDesdeConversao'] ?? 0}).',
        style: _negrito,
      ),
    ]);
  }

  Future<bool> _confirmar(String titulo, String texto, String botao) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(botao)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _passar() async {
    final ok = await _confirmar(
      'Passar os arquivos para a pasta da corretora?',
      'Copia os arquivos antigos (em lotes de 100) para a pasta da corretora e troca os links gravados nos '
          'sinistros, assistências, clientes etc. Os originais NÃO são apagados. Pode levar alguns minutos; '
          'deixe esta tela aberta. Se interromper, é só rodar de novo: continua de onde parou.',
      'Passar',
    );
    if (!ok) return;
    setState(() {
      _ocupado = true;
      _parar = false;
      _progresso = 'Começando…';
    });
    var copiados = 0;
    var documentos = 0;
    final semOriginal = <String>[];
    Map<String, dynamic>? r;
    try {
      for (var volta = 0; volta < 500 && !_parar; volta++) {
        r = await _post({'acao': 'converter'});
        copiados += (r['copiados'] as num).toInt();
        documentos += (r['documentosAtualizados'] as num).toInt();
        semOriginal.addAll(List<String>.from(r['semOriginal'] as List));
        if (mounted) setState(() => _progresso = '$copiados arquivo(s) passados, faltam ${r!['restantes']}…');
        if (r['terminou'] == true) break;
      }
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _progresso = '';
        });
      }
    }
    if (!mounted) return;
    await _mostrar(r?['terminou'] == true ? 'Arquivos passados' : 'Passagem interrompida', [
      Text('Arquivos copiados para a pasta da corretora: $copiados', style: _negrito),
      Text('Documentos com links trocados: $documentos'),
      if (r != null && r['terminou'] != true) Text('Faltam ${r['restantes']}. Rode "Passar arquivos" de novo para continuar.'),
      if (semOriginal.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text('⚠️ ${semOriginal.length} link(s) apontam para arquivos que já não existiam (ficaram como estavam):', style: _negrito),
        for (final c in semOriginal.take(30)) Text('  $c', style: const TextStyle(fontSize: 12)),
      ],
      const SizedBox(height: 12),
      const Text('Recarregue o app (Cmd+Shift+R) para usar os links novos.'),
    ]);
  }

  Future<void> _apagarOriginais() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Apagar os arquivos originais?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apaga das pastas antigas (sinistros/, clientes/, videos/, veiculos/) só os arquivos que JÁ TÊM cópia '
                'na pasta da corretora. O app continua mostrando tudo (ele usa as cópias).\n\n'
                'Atenção: links antigos enviados por fora (WhatsApp, e-mail, PDFs gerados antes) param de abrir.\n'
                'Não dá para desfazer.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Digite APAGAR para confirmar'),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
              onPressed: ctrl.text.trim() == 'APAGAR' ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Apagar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() {
      _ocupado = true;
      _parar = false;
      _progresso = 'Apagando…';
    });
    var apagados = 0;
    var semCopia = 0;
    var bytesSemCopia = 0;
    final exemplos = <String>[];
    Object? cursor;
    var terminou = false;
    try {
      for (var volta = 0; volta < 1000 && !_parar; volta++) {
        final r = await _post({'acao': 'apagarOriginais', 'confirmacao': 'APAGAR', 'cursor': cursor});
        apagados += (r['apagados'] as num).toInt();
        semCopia += (r['semCopia'] as num).toInt();
        bytesSemCopia += (r['bytesSemCopia'] as num).toInt();
        for (final e in List<String>.from(r['exemplosSemCopia'] as List)) {
          if (exemplos.length < 20) exemplos.add(e);
        }
        cursor = r['cursor'];
        terminou = r['terminou'] == true;
        if (mounted) setState(() => _progresso = '$apagados apagado(s)…');
        if (terminou) break;
      }
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = false;
          _progresso = '';
        });
      }
    }
    if (!mounted) return;
    await _mostrar(terminou ? 'Originais apagados' : 'Limpeza interrompida', [
      Text('Originais apagados (tinham cópia): $apagados', style: _negrito),
      if (!terminou) const Text('Rode de novo para continuar.'),
      if (semCopia > 0) ...[
        const SizedBox(height: 8),
        Text('Arquivos antigos que nenhum documento usa (mantidos): $semCopia '
            '(${(bytesSemCopia / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB). Ex.:'),
        for (final e in exemplos) Text('  $e', style: const TextStyle(fontSize: 12)),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_admin != true) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📁 Arquivos da corretora (Etapa 16c)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Passa fotos, laudos, documentos e vídeos antigos para a pasta da sua corretora e troca os links '
            'públicos por links protegidos. Só administradores.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _diagnostico,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Diagnóstico'),
              ),
              ElevatedButton.icon(
                onPressed: _ocupado ? null : _passar,
                icon: _ocupado
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.drive_file_move_outline, size: 18),
                label: const Text('Passar arquivos'),
              ),
              TextButton.icon(
                onPressed: _ocupado ? null : _apagarOriginais,
                icon: Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red.shade400),
                label: Text('Apagar originais', style: TextStyle(color: Colors.red.shade400)),
              ),
              if (_ocupado && _progresso.isNotEmpty) ...[
                Text(_progresso, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                TextButton(onPressed: () => setState(() => _parar = true), child: const Text('Parar')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
