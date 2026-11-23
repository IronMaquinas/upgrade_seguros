// lib/widgets/migracao_empresa_card.dart
//
// Etapa 16: cartão de Configurações (só administrador) para passar os dados
// das coleções da raiz para a pasta da corretora (corretoras/{empresaId}/…).
// Chama a Function migrarEmpresa (functions/empresa.js):
//   • Diagnóstico → mostra o que existe, sem mudar nada.
//   • Copiar → copia o que ainda não está na pasta (pode repetir).
//   • Apagar dados antigos (Etapa 16b) → apaga da raiz só o que já tem cópia
//     na pasta; o servidor só aceita 7 dias depois da migração.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/funcoes_nuvem.dart';

class CartaoMigracaoEmpresa extends StatefulWidget {
  const CartaoMigracaoEmpresa({super.key});

  @override
  State<CartaoMigracaoEmpresa> createState() => _CartaoMigracaoEmpresaState();
}

class _CartaoMigracaoEmpresaState extends State<CartaoMigracaoEmpresa> {
  bool? _admin;
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    AuthService().isAdmin().then((a) {
      if (mounted) setState(() => _admin = a);
    }).catchError((_) {
      if (mounted) setState(() => _admin = false);
    });
  }

  Future<Map<String, dynamic>?> _chamar(String acao) async {
    setState(() => _ocupado = true);
    try {
      final r = await FuncoesNuvem.post('migrarEmpresa', {'acao': acao});
      if (r.statusCode != 200) throw Exception(FuncoesNuvem.erro(r));
      return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
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

  static const _negrito = TextStyle(fontWeight: FontWeight.w600);

  Future<void> _diagnostico() async {
    final d = await _chamar('diagnostico');
    if (d == null || !mounted) return;
    final colecoes = Map<String, dynamic>.from(d['colecoes'] as Map);
    final usuarios = List<Map>.from(d['usuarios'] as List);
    final faltam = colecoes.entries.where((e) => (e.value['raiz'] as num) > (e.value['naCorretora'] as num)).length;
    await _mostrar('Diagnóstico', [
      Text('Sua corretora (empresaId): ${d['empresa']}', style: _negrito),
      const SizedBox(height: 8),
      Text('Corretoras cadastradas: ${(d['corretoras'] as List).join(', ')}'),
      if (d['diasDesdeMigracao'] != null)
        Text('Migrada há ${d['diasDesdeMigracao']} dia(s). '
            '${d['podeApagarRaiz'] == true ? 'Já é possível apagar os dados antigos (faça o backup antes).' : 'Os dados antigos só podem ser apagados depois de ${d['diasMinimos']} dias.'}'),
      const SizedBox(height: 12),
      const Text('Documentos por coleção (raiz → pasta da corretora):', style: _negrito),
      for (final e in colecoes.entries) Text('  ${e.key}: ${e.value['raiz']} → ${e.value['naCorretora']}'),
      const SizedBox(height: 12),
      const Text('Usuários e a corretora de cada um:', style: _negrito),
      for (final u in usuarios) Text('  ${u['email']}: ${(u['empresaId'] as String).isEmpty ? '(sem corretora)' : u['empresaId']}'),
      const SizedBox(height: 12),
      Text(
        faltam == 0
            ? '✅ Nada a copiar.'
            : '⚠️ $faltam coleção(ões) com documentos na raiz que ainda não estão na pasta da corretora. Use "Copiar".',
        style: _negrito,
      ),
    ]);
  }

  Future<void> _copiar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Copiar dados para a corretora?'),
        content: const Text(
          'Copia os documentos da raiz do banco para a pasta da sua corretora (só os que ainda não estão lá) '
          'e liga à sua corretora os usuários sem corretora. A raiz não é apagada. Pode repetir sem duplicar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Copiar')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await _chamar('copiar');
    if (r == null || !mounted) return;
    final colecoes = Map<String, dynamic>.from(r['colecoes'] as Map);
    final outros = List<Map>.from(r['usuariosDeOutraEmpresa'] as List);
    await _mostrar('Cópia concluída', [
      Text('Corretora: ${r['empresa']}', style: _negrito),
      const SizedBox(height: 8),
      for (final e in colecoes.entries)
        Text('  ${e.key}: ${e.value['copiados']} copiado(s), ${e.value['jaExistiam']} já estavam lá'),
      const SizedBox(height: 8),
      Text('Índice de pesquisas NPS: ${r['indiceNps']} criado(s)'),
      Text('Usuários ligados à corretora: ${(r['usuariosLigados'] as List).length}'),
      if (outros.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text('⚠️ Usuários de OUTRA corretora (não alterados):', style: _negrito),
        for (final u in outros) Text('  ${u['email']}: ${u['empresaId']}'),
      ],
      const SizedBox(height: 12),
      const Text('Recarregue o app (Cmd+Shift+R) para ver os dados.'),
    ]);
  }

  Future<void> _apagarRaiz() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Apagar os dados antigos da raiz?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apaga as coleções antigas da raiz do banco (sinistros/, clientes/ …), mas SÓ os documentos que já '
                'têm cópia na pasta da corretora. Os dados da corretora não são tocados.\n\n'
                'Não dá para desfazer. Faça o backup do LEIA-ME 16b antes.',
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
    setState(() => _ocupado = true);
    Map<String, dynamic>? r;
    try {
      final resp = await FuncoesNuvem.post('migrarEmpresa', {'acao': 'apagarRaiz', 'confirmacao': 'APAGAR'});
      if (resp.statusCode != 200) throw Exception(FuncoesNuvem.erro(resp));
      r = Map<String, dynamic>.from(jsonDecode(resp.body) as Map);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
    if (r == null || !mounted) return;
    final colecoes = Map<String, dynamic>.from(r['colecoes'] as Map);
    await _mostrar('Dados antigos apagados', [
      for (final e in colecoes.entries)
        Text('  ${e.key}: ${e.value['apagados']} apagado(s)'
            '${(e.value['semCopia'] as List).isEmpty ? '' : ' — ${(e.value['semCopia'] as List).length} SEM cópia (mantidos)'}'),
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
          const Text('🏢 Dados da corretora (Etapa 16)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Passa os dados antigos para a pasta da sua corretora. Use "Diagnóstico" para conferir e "Copiar" para '
            'passar o que faltar. Só administradores.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _ocupado ? null : _diagnostico,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Diagnóstico'),
              ),
              ElevatedButton.icon(
                onPressed: _ocupado ? null : _copiar,
                icon: _ocupado
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.drive_file_move_outline, size: 18),
                label: const Text('Copiar'),
              ),
              // Etapa 16b
              TextButton.icon(
                onPressed: _ocupado ? null : _apagarRaiz,
                icon: Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red.shade400),
                label: Text('Apagar dados antigos', style: TextStyle(color: Colors.red.shade400)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
