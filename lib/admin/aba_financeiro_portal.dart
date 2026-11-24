// lib/admin/aba_financeiro_portal.dart — Etapa 26: portal → Financeiro
//
// Receita do mês estimada pelo plano de cada corretora (lib/admin/financeiro.dart).
// Etapa 27: GB de arquivos e vídeos medidos (todo dia 03:30 e pelo botão "Medir uso agora"):
// MRR, ticket médio, em atraso, cortesias, testes (potencial) e a tabela por
// corretora — com "Copiar tabela" para colar no Excel. Não há cobrança ainda
// (Etapa 28): os números são o que cada conta deveria pagar hoje.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'financeiro.dart';
import 'plataforma_api.dart';

const _kEscuro = Color(0xFF263238);
const _kAzul = Color(0xFF1565C0);
const _kVerde = Color(0xFF2E7D32);
const _kLaranja = Color(0xFFEF6C00);
const _kVermelho = Color(0xFFC62828);

class AbaFinanceiroPortal extends StatelessWidget {
  final List<CorretoraPlataforma>? corretoras;
  final String? erro;
  final Future<void> Function() onRecarregar;
  const AbaFinanceiroPortal({super.key, required this.corretoras, required this.erro, required this.onRecarregar});

  @override
  Widget build(BuildContext context) {
    final l = corretoras;
    if (l == null) {
      return Center(
        child: erro == null
            ? const CircularProgressIndicator()
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Text(erro!, style: const TextStyle(color: _kVermelho)),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: onRecarregar, child: const Text('Tentar de novo')),
              ]),
      );
    }
    final r = ResumoFinanceiro.de(l);
    final d = DateFormat('dd/MM/yyyy');
    final semConta = l.where((c) => c.conta == null).length;

    return ListView(padding: const EdgeInsets.all(24), children: [
      Row(children: [
        const Text('Financeiro', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const Spacer(),
        _BotaoMedir(onMedido: onRecarregar), // Etapa 27
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: r.tabela()));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tabela copiada — cole no Excel ou no Planilhas.')));
            }
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar tabela'),
        ),
        IconButton(tooltip: 'Atualizar', icon: const Icon(Icons.refresh), onPressed: onRecarregar),
      ]),
      const SizedBox(height: 4),
      Text('Estimativa pelo plano de cada corretora (preço + usuários e GB acima da franquia); a cobrança automática vem depois. '
          'Valores de ${d.format(r.agora)}. '
          '${r.algumaSemMedicao ? 'Uso de GB: há corretora sem medição — use "Medir uso agora".' : r.medicaoMaisAntiga == null ? '' : 'Uso de GB medido em ${DateFormat('dd/MM HH:mm').format(r.medicaoMaisAntiga!)} (mede sozinho todo dia às 03:30).'}',
          style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Numero('Receita do mês (MRR)', Planos.reais(r.mrrCentavos), '${r.pagantes.length} corretora(s) pagante(s)', Icons.trending_up, _kVerde),
        _Numero('Ticket médio', Planos.reais(r.ticketMedioCentavos), 'por corretora pagante', Icons.receipt_long_outlined, _kAzul),
        _Numero('Usuários extras', Planos.reais(r.extrasCentavos), 'parte do MRR acima da franquia', Icons.group_add_outlined, _kAzul),
        _Numero('GB extras', Planos.reais(r.gbCentavos), 'arquivos e vídeos acima da franquia', Icons.cloud_upload_outlined, _kAzul), // Etapa 27
        _Numero('Armazenamento', '${r.gbArquivosTotal.toStringAsFixed(1).replaceAll('.', ',')} GB', // Etapa 27
            '+ ${r.gbVideosTotal.toStringAsFixed(1).replaceAll('.', ',')} GB de vídeo (todas as corretoras)', Icons.cloud_outlined, Colors.grey.shade700),
        _Numero('Em atraso', Planos.reais(r.emAtrasoCentavos), '${r.inadimplentes.length} inadimplente(s)', Icons.warning_amber, r.emAtrasoCentavos > 0 ? _kLaranja : Colors.grey),
        _Numero('Cortesias', Planos.reais(r.cortesiasCentavos), '${r.cortesias.length} conta(s) sem cobrança', Icons.card_giftcard, Colors.grey.shade700),
        _Numero('Potencial dos testes', Planos.reais(r.potencialTestesCentavos), '${r.testes.length} em teste · ${r.testesTerminados.length} terminado(s)', Icons.hourglass_bottom, _kAzul),
      ]),
      if (semConta > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('⚠ $semConta corretora(s) sem conta ficam fora destas contas (Visão geral → Criar contas que faltam).',
              style: const TextStyle(color: _kLaranja, fontSize: 12.5)),
        ),

      // ── atenção ──
      if (r.testesAcabando.isNotEmpty || r.testesTerminados.isNotEmpty || r.cortesiasVencendo.isNotEmpty || r.inadimplentes.isNotEmpty) ...[
        const SizedBox(height: 22),
        const Text('Para acompanhar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        for (final x in r.testesAcabando)
          _Aviso(Icons.hourglass_bottom, _kLaranja, '${x.corretora}: teste termina em ${DateFormat('dd/MM HH:mm').format(x.testeAte!)} — '
              '${x.totalCentavos > 0 ? 'pagaria ${Planos.reais(x.totalCentavos)}/mês no plano atual' : 'sem plano com preço (Tudo ligado)'}'),
        for (final x in r.testesTerminados)
          _Aviso(Icons.lock_clock_outlined, _kVermelho, '${x.corretora}: teste terminou${x.testeAte == null ? '' : ' em ${d.format(x.testeAte!)}'} — está só leitura. Ofereça um plano.'),
        for (final x in r.cortesiasVencendo)
          _Aviso(Icons.card_giftcard, _kAzul, '${x.corretora}: cortesia até ${d.format(x.cortesiaAte!)} — depois passa a ${Planos.reais(x.totalCentavos)}/mês.'),
        for (final x in r.inadimplentes)
          _Aviso(Icons.warning_amber, _kLaranja, '${x.corretora}: inadimplente — ${Planos.reais(x.totalCentavos)}/mês.'),
      ],

      // ── tabela ──
      const SizedBox(height: 22),
      const Text('Por corretora', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: _kEscuro, fontSize: 12.5),
            dataTextStyle: const TextStyle(fontSize: 12.5, color: Colors.black87),
            columnSpacing: 22,
            columns: const [
              DataColumn(label: Text('Corretora')),
              DataColumn(label: Text('Situação')),
              DataColumn(label: Text('Plano')),
              DataColumn(label: Text('Preço'), numeric: true),
              DataColumn(label: Text('Usuários'), numeric: true),
              DataColumn(label: Text('Extras'), numeric: true),
              DataColumn(label: Text('Arquivos'), numeric: true), // Etapa 27
              DataColumn(label: Text('Vídeos'), numeric: true),
              DataColumn(label: Text('Total/mês'), numeric: true),
              DataColumn(label: Text('Cobrança')),
            ],
            rows: [
              for (final x in r.linhas)
                DataRow(cells: [
                  DataCell(Text(x.corretora)),
                  DataCell(Text(rotuloSituacao(x.situacao))),
                  DataCell(Text(x.plano)),
                  DataCell(Text(Planos.reais(x.baseCentavos))),
                  DataCell(Text(x.usuariosIncluidos == null ? '${x.usuarios}' : '${x.usuarios} / ${x.usuariosIncluidos}')),
                  DataCell(Text(x.extrasCentavos > 0 ? '${x.usuariosExtras} · ${Planos.reais(x.extrasCentavos)}' : '–')),
                  DataCell(Text(_gb(x.medidoEm, x.gbArquivos, x.gbArquivosAcima))),
                  DataCell(Text(_gb(x.medidoEm, x.gbVideos, x.gbVideosAcima))),
                  DataCell(Text(Planos.reais(x.totalCentavos), style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(Text(
                    x.cortesia
                        ? (x.cortesiaAte == null ? 'cortesia' : 'cortesia até ${d.format(x.cortesiaAte!)}')
                        : x.cobravel
                            ? (x.totalCentavos > 0 ? 'cobrar' : 'sem preço')
                            : x.emTeste
                                ? 'em teste${x.testeAte == null ? '' : ' até ${d.format(x.testeAte!)}'}'
                                : 'não cobra',
                    style: TextStyle(color: x.cobravel && x.totalCentavos > 0 ? _kVerde : Colors.grey.shade700),
                  )),
                ]),
            ],
          ),
        ),
      ),
    ]);
  }
}

/// "3,2 GB" / "10,4 GB (+1)" / "–" sem medição.
String _gb(DateTime? medidoEm, double gb, int acima) {
  if (medidoEm == null) return '–';
  final t = '${gb.toStringAsFixed(gb < 10 ? 2 : 1).replaceAll('.', ',')} GB';
  return acima > 0 ? '$t (+$acima)' : t;
}

class _BotaoMedir extends StatefulWidget {
  final Future<void> Function() onMedido;
  const _BotaoMedir({required this.onMedido});
  @override
  State<_BotaoMedir> createState() => _BotaoMedirState();
}

class _BotaoMedirState extends State<_BotaoMedir> {
  bool _medindo = false;

  Future<void> _medir() async {
    setState(() => _medindo = true);
    try {
      await PlataformaApi.medirUso();
      await widget.onMedido();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uso medido.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _medindo = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: _medindo ? null : _medir,
        icon: _medindo
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.speed, size: 18),
        label: Text(_medindo ? 'Medindo…' : 'Medir uso agora'),
      );
}

class _Numero extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalhe;
  final IconData icone;
  final Color cor;
  const _Numero(this.titulo, this.valor, this.detalhe, this.icone, this.cor);
  @override
  Widget build(BuildContext context) => Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valor, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text(titulo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              Text(detalhe, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            ]),
          ),
        ]),
      );
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;
  const _Aviso(this.icone, this.cor, this.texto);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ]),
      );
}
