// lib/admin/aba_seguradoras_portal.dart — Etapa 22: catálogo de seguradoras no portal
//
//   • Importar das corretoras (monta o catálogo a partir dos cadastros existentes)
//   • Aguardando aprovação: Aprovar (com o nome que quiser) · Juntar com… · Recusar
//   • Lista única: editar nome / CNPJ / SUSEP / apelidos, desativar, juntar
// Renomear ou juntar troca o nome nos sinistros, assistências e apólices de TODAS
// as corretoras (o servidor faz isso e registra na auditoria).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/services/receita_cnpj.dart';
import 'package:upgrade_seguros/utils/perfil_corretora.dart';
import 'package:upgrade_seguros/utils/seguradoras.dart';

import 'plataforma_api.dart';

const _kAzul = Color(0xFF1565C0);
const _kLaranja = Color(0xFFEF6C00);
const _kVermelho = Color(0xFFC62828);
const _kVerde = Color(0xFF2E7D32);

class AbaSeguradorasPortal extends StatefulWidget {
  const AbaSeguradorasPortal({super.key});
  @override
  State<AbaSeguradorasPortal> createState() => _AbaSeguradorasPortalState();
}

class _AbaSeguradorasPortalState extends State<AbaSeguradorasPortal> {
  List<SeguradoraCatalogo>? _lista;
  String? _erro;
  String _busca = '';
  bool _ocupado = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final l = await PlataformaApi.catalogo();
      if (mounted) setState(() => _lista = l);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  void _avisar(String m, {bool erro = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: erro ? _kVermelho : null));
  }

  /// Roda uma ação do servidor com espera e recarrega a lista.
  Future<void> _executar(Future<void> Function() acao, String ok) async {
    setState(() => _ocupado = true);
    try {
      await acao();
      _avisar(ok);
      await _carregar();
    } catch (e) {
      _avisar('$e'.replaceFirst('Exception: ', ''), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<bool> _confirmar(String titulo, String texto, {String botao = 'Confirmar'}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(titulo),
        content: SizedBox(width: 440, child: Text(texto)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(botao)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _importar() async {
    if (!await _confirmar(
      'Importar das corretoras',
      'Monta a lista única com as seguradoras cadastradas em todas as corretoras. Nomes parecidos '
          '(CHUBB × Chubb, AXA × AXA Seguros) viram uma entrada só: a grafia mais usada vira o nome e as '
          'outras ficam como apelidos; os registros que usavam as outras grafias passam a usar o nome. '
          'Pode rodar de novo: só vincula o que faltar.',
      botao: 'Importar',
    )) {
      return;
    }
    setState(() => _ocupado = true);
    try {
      final r = await PlataformaApi.catalogoImportar();
      _avisar('${r['criadas']} criada(s) · ${r['vinculadas']} cadastro(s) vinculado(s) · ${r['renomeadas']} grafia(s) trocada(s).');
      await _carregar();
    } catch (e) {
      _avisar('$e'.replaceFirst('Exception: ', ''), erro: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<String> _textoUso(SeguradoraCatalogo s) async {
    try {
      final u = await PlataformaApi.catalogoUso(s.id);
      return 'Em uso: ${u['sinistros']} sinistro(s), ${u['assistencias']} assistência(s), ${u['apolices']} apólice(s).';
    } catch (_) {
      return '';
    }
  }

  static String _dig(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// 22.2: a entrada da lista que já corresponde a este CNPJ ou a este nome da
  /// Receita (SUHAI SEGURADORA S.A. × SUHAI). [exceto]: a que está sendo editada.
  SeguradoraCatalogo? _jaNaLista(String cnpj, DadosReceita r, {String exceto = ''}) {
    final vivas = (_lista ?? const <SeguradoraCatalogo>[]).where((x) => (x.viva || x.pendente) && x.id != exceto).toList();
    final c = _dig(cnpj);
    for (final x in vivas) {
      if (c.isNotEmpty && _dig(x.cnpj) == c) return x;
    }
    final nomes = [for (final x in vivas) x.nome];
    for (final n in [r.nomeFantasia, r.razaoSocial]) {
      if (n.isEmpty) continue;
      final achou = resolverSeguradora(n, nomes);
      if (achou != null) return vivas.firstWhere((x) => x.nome == achou);
    }
    return null;
  }

  /// 22.1: o admin cria direto, já aprovada. CNPJ consultado na Receita pelo
  /// navegador. 22.2: se já existir (pelo CNPJ ou nome parecido), avisa logo
  /// na consulta e oferece completar a existente com os dados da Receita.
  Future<void> _nova() async {
    final cnpj = TextEditingController();
    final nome = TextEditingController();
    final susep = TextEditingController();
    DadosReceita? receita;
    SeguradoraCatalogo? existente;
    String? aviso;
    var consultando = false;
    final acao = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) {
          Future<void> consultar() async {
            set(() {
              consultando = true;
              aviso = null;
              existente = null;
              receita = null;
            });
            try {
              final r = await consultarReceitaCnpj(cnpj.text);
              set(() {
                receita = r;
                cnpj.text = PerfilCorretora.formatarCnpj(_dig(cnpj.text));
                existente = _jaNaLista(cnpj.text, r);
                nome.text = r.nomeFantasia.isNotEmpty ? r.nomeFantasia : r.razaoSocial;
                if (!r.ativa) aviso = '⚠️ Situação na Receita: ${r.situacao}';
              });
            } catch (e) {
              set(() => aviso = '$e');
            } finally {
              set(() => consultando = false);
            }
          }

          final r = receita;
          final ja = existente;
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            title: const Text('Nova seguradora'),
            content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: cnpj,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder()),
                      onSubmitted: (_) => consultando ? null : consultar(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(onPressed: consultando ? null : consultar, child: const Text('Consultar na Receita')),
                ]),
                if (consultando) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
                if (aviso != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(aviso!, style: const TextStyle(color: _kVermelho))),
                if (r != null) _DadosReceitaBox(r),
                if (ja != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'Já está na lista como "${ja.nome}"${ja.cnpj.isEmpty ? ' (sem CNPJ)' : ' (${ja.cnpj})'}. '
                      'Use "Completar" para gravar estes dados nela.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (r != null && ja == null) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: nome,
                    decoration: const InputDecoration(labelText: 'Nome na lista', border: OutlineInputBorder()),
                    onChanged: (_) => set(() {}),
                  ),
                  if (r.nomeFantasia.isNotEmpty && r.razaoSocial.isNotEmpty)
                    Wrap(spacing: 4, children: [
                      for (final o in [r.nomeFantasia, r.razaoSocial])
                        if (nome.text != o) TextButton(onPressed: () => set(() => nome.text = o), child: Text('Usar "$o"')),
                    ]),
                  const SizedBox(height: 10),
                  TextField(controller: susep, decoration: const InputDecoration(labelText: 'Código SUSEP (opcional)', border: OutlineInputBorder())),
                ],
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
              if (ja != null)
                FilledButton(onPressed: () => Navigator.pop(d, 'completar'), child: Text('Completar "${ja.nome}"'))
              else
                FilledButton(
                  onPressed: r == null || nome.text.trim().isEmpty ? null : () => Navigator.pop(d, 'criar'),
                  child: const Text('Criar'),
                ),
            ],
          );
        },
      ),
    );
    if (acao == 'completar' && existente != null && receita != null) {
      return _editar(existente!, receita: receita, cnpjConsultado: cnpj.text);
    }
    if (acao != 'criar' || receita == null) return;
    await _executar(
      () => PlataformaApi.catalogoCriar(cnpj: cnpj.text, nome: nome.text.trim(), razaoSocial: receita!.razaoSocial, susep: susep.text),
      '"${nome.text.trim()}" criada.',
    );
  }

  Future<void> _aprovar(SeguradoraCatalogo s) async {
    final nome = TextEditingController(text: s.nome);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Aprovar seguradora'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Receita: ${s.razaoSocial} · ${s.cnpj}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome na lista', border: OutlineInputBorder())),
            const SizedBox(height: 6),
            Text('Se mudar o nome, os registros que já usam esta seguradora são atualizados.',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Aprovar')),
        ],
      ),
    );
    if (ok != true) return;
    final n = nome.text.trim();
    await _executar(() => PlataformaApi.catalogoAprovar(s.id, nome: n.isEmpty || n == s.nome ? null : n), '"${n.isEmpty ? s.nome : n}" aprovada.');
  }

  Future<void> _juntar(SeguradoraCatalogo s) async {
    final aprovadas = (_lista ?? const <SeguradoraCatalogo>[]).where((x) => x.situacao == 'aprovada' && x.id != s.id).toList();
    final uso = await _textoUso(s);
    if (!mounted) return;
    String? para;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text('Juntar "${s.nome}" com…'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (uso.isNotEmpty) Text(uso, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: para,
                isExpanded: true,
                dropdownColor: Colors.white,
                menuMaxHeight: 380,
                decoration: const InputDecoration(labelText: 'Seguradora certa', border: OutlineInputBorder()),
                items: [for (final a in aprovadas) DropdownMenuItem(value: a.id, child: Text(a.nome))],
                onChanged: (v) => set(() => para = v),
              ),
              const SizedBox(height: 8),
              Text('Os registros de todas as corretoras passam a usar o nome da seguradora certa, '
                  'e "${s.nome}" vira apelido dela.', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(onPressed: para == null ? null : () => Navigator.pop(d, true), child: const Text('Juntar')),
          ],
        ),
      ),
    );
    if (ok != true || para == null) return;
    await _executar(() => PlataformaApi.catalogoJuntar(s.id, para!), 'Juntada.');
  }

  Future<void> _recusar(SeguradoraCatalogo s) async {
    final uso = await _textoUso(s);
    if (!mounted) return;
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Recusar "${s.nome}"'),
        content: SizedBox(
          width: 440,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (uso.isNotEmpty) Text('$uso Se estiver em uso, use "Juntar".', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            TextField(controller: motivo, decoration: const InputDecoration(labelText: 'Motivo', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kVermelho),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _executar(() => PlataformaApi.catalogoRecusar(s.id, motivo.text), 'Recusada.');
  }

  /// 22.2: [receita] / [cnpjConsultado] vêm do "Completar" da Nova seguradora.
  Future<void> _editar(SeguradoraCatalogo s, {DadosReceita? receita, String? cnpjConsultado}) async {
    final nome = TextEditingController(text: s.nome);
    final cnpj = TextEditingController(text: s.cnpj);
    final susep = TextEditingController(text: s.susep);
    final apelidos = TextEditingController(text: s.apelidos.join(', '));
    var ativa = s.situacao != 'inativa';
    var razao = s.razaoSocial; // 22.1: conferida pelo "Consultar"
    String? avisoCnpj;
    DadosReceita? achado; // 22.2: o que a última consulta trouxe

    // 22.2: Buscar CNPJ → dados encontrados → Salvar. O nome já vem o da Receita
    // (fantasia, se houver; senão razão social); "Manter" volta ao atual.
    void aplicar(DadosReceita r, String cnpjTxt) {
      achado = r;
      razao = r.razaoSocial;
      cnpj.text = PerfilCorretora.formatarCnpj(_dig(cnpjTxt));
      final sugerido = r.nomeFantasia.isNotEmpty ? r.nomeFantasia : r.razaoSocial;
      if (sugerido.isNotEmpty) nome.text = sugerido;
      avisoCnpj = r.ativa ? null : '⚠️ Situação na Receita: ${r.situacao}';
    }

    if (receita != null) aplicar(receita, cnpjConsultado ?? '');
    final uso = await _textoUso(s);
    if (!mounted) return;
    final acao = await showDialog<String>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Text(s.nome),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (uso.isNotEmpty) Text(uso, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if (achado == null && razao.isNotEmpty) SelectableText('Receita: $razao', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                if (achado != null) _DadosReceitaBox(achado!),
                if (avisoCnpj != null) Text(avisoCnpj!, style: const TextStyle(fontSize: 12, color: _kVermelho)),
                const SizedBox(height: 12),
                TextField(
                  controller: nome,
                  decoration: InputDecoration(
                    labelText: 'Nome na lista',
                    border: const OutlineInputBorder(),
                    helperText: nome.text != s.nome ? 'Antes: "${s.nome}" (vira apelido e os registros são atualizados)' : null,
                  ),
                  onChanged: (_) => set(() {}),
                ),
                Wrap(spacing: 4, children: [
                  if (nome.text != s.nome) TextButton(onPressed: () => set(() => nome.text = s.nome), child: Text('Manter "${s.nome}"')),
                  if (achado != null)
                    for (final o in {achado!.nomeFantasia, achado!.razaoSocial})
                      if (o.isNotEmpty && nome.text != o) TextButton(onPressed: () => set(() => nome.text = o), child: Text('Usar "$o"')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: cnpj, decoration: const InputDecoration(labelText: 'CNPJ', border: OutlineInputBorder()))),
                  IconButton(
                    tooltip: 'Consultar na Receita',
                    icon: const Icon(Icons.travel_explore),
                    onPressed: () async {
                      try {
                        final r = await consultarReceitaCnpj(cnpj.text);
                        final outra = (_lista ?? const <SeguradoraCatalogo>[])
                            .where((x) => x.id != s.id && (x.viva || x.pendente) && _dig(x.cnpj) == _dig(cnpj.text) && _dig(cnpj.text).isNotEmpty)
                            .firstOrNull;
                        set(() {
                          if (outra != null) {
                            avisoCnpj = 'Esse CNPJ já é de "${outra.nome}". Para unir as duas, use "Juntar com…".';
                          } else {
                            aplicar(r, cnpj.text);
                          }
                        });
                      } catch (e) {
                        set(() => avisoCnpj = '$e');
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: TextField(controller: susep, decoration: const InputDecoration(labelText: 'Código SUSEP', border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: apelidos,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Apelidos (separados por vírgula)',
                    helperText: 'Outras formas de escrever que devem virar este nome (ex.: AXA SEGUROS)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: ativa,
                  title: const Text('Ativa na lista'),
                  subtitle: const Text('Inativa: some da lista das corretoras (os registros antigos continuam).', style: TextStyle(fontSize: 11.5)),
                  onChanged: (v) => set(() => ativa = v),
                ),
                Text('Mudar o nome atualiza os registros de todas as corretoras; o nome antigo vira apelido.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, 'juntar'), child: const Text('Juntar com…')),
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(d, 'salvar'), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (acao == 'juntar') return _juntar(s);
    if (acao != 'salvar') return;
    final n = nome.text.trim();
    await _executar(
      () => PlataformaApi.catalogoEditar(
        s.id,
        nome: n.isEmpty || n == s.nome ? null : n,
        cnpj: cnpj.text,
        susep: susep.text,
        apelidos: lerApelidos(apelidos.text),
        ativa: ativa,
        razaoSocial: razao != s.razaoSocial ? razao : null,
      ),
      'Salvo.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    if (l == null) {
      return Center(
        child: _erro == null
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_erro!, style: const TextStyle(color: _kVermelho)),
                OutlinedButton(onPressed: _carregar, child: const Text('Tentar de novo')),
              ]),
      );
    }
    final pendentes = l.where((x) => x.pendente).toList();
    final q = _busca.trim().toUpperCase();
    final vivas = l
        .where((x) => x.viva)
        .where((x) => q.isEmpty || x.nome.toUpperCase().contains(q) || x.cnpj.contains(q) || x.apelidos.any((a) => a.toUpperCase().contains(q)))
        .toList();
    final outras = l.where((x) => x.situacao == 'juntada' || x.situacao == 'recusada').length;
    final f = DateFormat('dd/MM/yyyy');

    return Stack(children: [
      ListView(padding: const EdgeInsets.all(24), children: [
        Row(children: [
          const Text('Seguradoras', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('lista única de todas as corretoras', style: TextStyle(color: Colors.grey.shade600)),
          const Spacer(),
          OutlinedButton.icon(onPressed: _ocupado ? null : _importar, icon: const Icon(Icons.download, size: 18), label: const Text('Importar das corretoras')),
          const SizedBox(width: 8),
          FilledButton.icon(onPressed: _ocupado ? null : _nova, icon: const Icon(Icons.add, size: 18), label: const Text('Nova seguradora')),
          IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: _ocupado ? null : _carregar),
        ]),
        if (l.where((x) => x.viva).isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('A lista ainda está vazia: clique em "Importar das corretoras" para começar. '
                'Enquanto isso, cada corretora continua usando o próprio cadastro.', style: TextStyle(color: Colors.grey.shade700)),
          ),
        if (pendentes.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Aguardando aprovação (${pendentes.length})', style: const TextStyle(fontWeight: FontWeight.w700, color: _kLaranja)),
          const SizedBox(height: 8),
          for (final s in pendentes)
            Card(
              color: const Color(0xFFFFF8E1),
              surfaceTintColor: Colors.transparent,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.nome, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        [
                          if (s.cnpj.isNotEmpty) s.cnpj,
                          if (s.razaoSocial.isNotEmpty && s.razaoSocial != s.nome) s.razaoSocial,
                          if (s.situacaoReceita.isNotEmpty && s.situacaoReceita.toUpperCase() != 'ATIVA') '⚠️ Receita: ${s.situacaoReceita}',
                          if (s.dadosReceita == 'navegador') 'dados da Receita consultados pelo app — confira o CNPJ',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                      Text(
                        'Sugerida por ${s.criadaPorCorretora}${s.criadaPorEmail.isEmpty ? '' : ' (${s.criadaPorEmail})'}'
                        '${s.criadaEm == null ? '' : ' em ${f.format(s.criadaEm!)}'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ]),
                  ),
                  TextButton(onPressed: _ocupado ? null : () => _recusar(s), child: const Text('Recusar', style: TextStyle(color: _kVermelho))),
                  TextButton(onPressed: _ocupado ? null : () => _juntar(s), child: const Text('Juntar com…')),
                  FilledButton(
                    onPressed: _ocupado ? null : () => _aprovar(s),
                    style: FilledButton.styleFrom(backgroundColor: _kVerde),
                    child: const Text('Aprovar'),
                  ),
                ]),
              ),
            ),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Text('Lista única (${l.where((x) => x.viva).length})', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (outras > 0) Text('   · $outras juntada(s)/recusada(s) fora da lista', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          const Spacer(),
          SizedBox(
            width: 260,
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Buscar nome, CNPJ ou apelido', isDense: true),
              onChanged: (v) => setState(() => _busca = v),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        for (final s in vivas)
          Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              onTap: _ocupado ? null : () => _editar(s),
              title: Text(s.nome, style: TextStyle(fontWeight: FontWeight.w600, color: s.situacao == 'inativa' ? Colors.grey : null)),
              subtitle: Text([
                s.cnpj.isEmpty ? 'sem CNPJ' : s.cnpj,
                if (s.susep.isNotEmpty) 'SUSEP ${s.susep}',
                if (s.apelidos.isNotEmpty) 'apelidos: ${s.apelidos.join(', ')}',
              ].join(' · ')),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: (s.situacao == 'aprovada' ? _kVerde : Colors.grey).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(rotuloSituacaoSeguradora(s.situacao),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: s.situacao == 'aprovada' ? _kVerde : Colors.grey.shade700)),
              ),
            ),
          ),
      ]),
      if (_ocupado)
        const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: _kAzul)),
    ]);
  }
}

/// 22.2: dados da Receita, selecionáveis (dá para copiar).
class _DadosReceitaBox extends StatelessWidget {
  final DadosReceita r;
  const _DadosReceitaBox(this.r);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Encontrado na Receita', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kVerde)),
          SelectableText('Razão social: ${r.razaoSocial}', style: const TextStyle(fontSize: 12.5)),
          SelectableText('Nome fantasia: ${r.nomeFantasia.isEmpty ? '(não tem)' : r.nomeFantasia}', style: const TextStyle(fontSize: 12.5)),
          if (r.situacao.isNotEmpty) Text('Situação: ${r.situacao}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
        ]),
      );
}
