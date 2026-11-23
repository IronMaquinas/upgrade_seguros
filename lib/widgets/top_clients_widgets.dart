// widgets/top_clients_widgets.dart - VERSÃO 2.0
// ═══════════════════════════════════════════════════════════════════════════
// Widgets para exibir Top Clientes - com indicadores corretos
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';
import '../utils/gatilho.dart';
import '../services/recomendacao_service.dart';
import '../utils/rankings_clientes.dart'; // Etapa 18

class TopClientsWidgets {
  static final _fmtCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// Top 10 Clientes por VALOR DE SINISTROS (Etapa 18)
  /// Antes: "Top 10 Clientes por Receita", lido do campo total_receita do
  /// cliente (soma de sinistros, desatualizada e com Cancelado/Negado).
  /// Regra em lib/utils/rankings_clientes.dart.
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Widget buildTopClientesPorValorSinistros(List<Client> clientes, List<Claim> sinistros) {
    final top10 = RankingsClientes.porValorSinistros(
      [for (final c in clientes) ClienteRanking(id: c.id, nome: c.nome, qtdApolices: c.apolices.length)],
      [
        for (final s in sinistros)
          SinistroRanking(idCliente: s.idCliente, tipo: s.tipo, status: s.statusAtual, valor: s.valorTotalSinistro),
      ],
    );
    if (top10.isEmpty) return const SizedBox.shrink();

    return _cartao(
      icone: Icons.trending_up,
      cor: const Color(0xFF1565C0),
      titulo: '💰 Top 10 Clientes por Valor de Sinistros',
      subtitulo: 'Soma do valor dos sinistros de cada cliente (todos os períodos), sem Cancelado/Negado. '
          'Não é receita da corretora.',
      filhos: [
        for (var index = 0; index < top10.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _posicao(index),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(top10[index].cliente.nome,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(
                            '${top10[index].qtdSinistros} sinistro${top10[index].qtdSinistros != 1 ? 's' : ''} · '
                            '${top10[index].cliente.qtdApolices} apólice${top10[index].cliente.qtdApolices != 1 ? 's' : ''}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Text(_fmtCurrency.format(top10[index].valor),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (top10[index].percentual / 100).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(_getTopRankColor(index)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${top10[index].percentual.toStringAsFixed(1)}% do valor de todos os sinistros',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
          ),
      ],
    );
  }

  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// Maiores apólices vigentes (Etapa 18) — para conferir o gráfico
  /// "Valor Apólices Mensais" e achar valor digitado errado.
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Widget buildMaioresApolices(List<Client> clientes, {DateTime? hoje}) {
    final itens = RankingsClientes.maioresApolicesVigentes(
      [
        for (final c in clientes)
          for (final a in c.apolices)
            ApoliceRanking(
              clienteNome: c.nome,
              numero: a.numeroApolice,
              ramo: a.ramo,
              inicio: a.dataInicio,
              fim: a.dataFim,
              valor: a.valorApolice,
            ),
      ],
      hoje ?? DateTime.now(),
    );
    if (itens.isEmpty) return const SizedBox.shrink();
    final data = DateFormat('dd/MM/yyyy');
    final suspeitas = itens.where((i) => i.suspeita).length;

    return _cartao(
      icone: Icons.policy_outlined,
      cor: const Color(0xFF7B1FA2),
      titulo: '📄 Maiores Apólices Vigentes',
      subtitulo: suspeitas == 0
          ? 'As 10 apólices vigentes de maior valor (as que mais pesam no gráfico acima).'
          : '⚠️ $suspeitas apólice${suspeitas != 1 ? 's' : ''} com valor muito acima das demais — '
              'confira se foi digitado certo (Clientes → cliente → apólice → Editar).',
      filhos: [
        for (var i = 0; i < itens.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: itens[i].suspeita ? Colors.red.shade50 : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: itens[i].suspeita ? Colors.red.shade200 : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                _posicao(i),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(itens[i].apolice.clienteNome,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        'Apólice ${itens[i].apolice.numero.isEmpty ? '(sem número)' : itens[i].apolice.numero}'
                        '${itens[i].apolice.ramo.isEmpty ? '' : ' · ${itens[i].apolice.ramo}'}'
                        ' · ${data.format(itens[i].apolice.inicio)} a ${data.format(itens[i].apolice.fim)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_fmtCurrency.format(itens[i].apolice.valor),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: itens[i].suspeita ? Colors.red.shade700 : const Color(0xFF7B1FA2),
                        )),
                    if (itens[i].suspeita)
                      Text('⚠️ confira o valor', style: TextStyle(fontSize: 10, color: Colors.red.shade700)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  static Widget _posicao(int index) => Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(color: _getTopRankColor(index), borderRadius: BorderRadius.circular(6)),
        alignment: Alignment.center,
        child: Text('${index + 1}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      );

  static Widget _cartao({
    required IconData icone,
    required Color cor,
    required String titulo,
    required String subtitulo,
    required List<Widget> filhos,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icone, color: cor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            ...filhos,
          ],
        ),
      ),
    );
  }

  /// Top 10 Apólices com Maior Risco de Estourar Gatilho
  static Widget buildTopApolicesRisco(List<Client> clientes) {
    if (clientes.isEmpty) return const SizedBox.shrink();

    // 1. Extrair TODAS as apólices de TODOS os clientes com risco
    final apolicesRisco = <({
      String clienteNome,
      String ramo,
      String numeroApolice,
      double valorGatilho,
      double valorApolice,
      double percentualGatilho,
    })>[];

    for (final cliente in clientes) {
      if (cliente.apolices == null || cliente.apolices!.isEmpty) continue;

      for (final apolice in cliente.apolices!) {
        if (apolice.valorGatilho <= 0) continue; // Skip sem gatilho

        // Calcular % do gatilho (comparar com campo que existe no modelo)
        final percentualGatilho = (apolice.valorApolice / apolice.valorGatilho) * 100;

        if (percentualGatilho >= 60) { // Só inclui se >= 60% de risco
          apolicesRisco.add((
            clienteNome: cliente.nome,
            ramo: apolice.ramo,
            numeroApolice: apolice.numeroApolice,
            valorGatilho: apolice.valorGatilho,
            valorApolice: apolice.valorApolice,
            percentualGatilho: percentualGatilho,
          ));
        }
      }
    }

    if (apolicesRisco.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Text(
          '✅ Nenhuma apólice em risco de estourar gatilho',
          style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
        ),
      );
    }

    // 2. Ordenar por maior risco
    apolicesRisco.sort((a, b) => b.percentualGatilho.compareTo(a.percentualGatilho));
    final top10 = apolicesRisco.take(10).toList();

    // 3. Montar UI
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_rounded, color: Color(0xFFD32F2F), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '⚠️ Top 10 Apólices em Risco',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(top10.length, (index) {
              final item = top10[index];
              final percentual = item.percentualGatilho;
              final cor = percentual > 100
                  ? const Color(0xFFC62828)
                  : percentual >= 80
                      ? const Color(0xFFE65100)
                      : const Color(0xFFFFA500);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cor.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(6)),
                            alignment: Alignment.center,
                            child: Text('${index + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.ramo} - ${item.clienteNome}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(item.numeroApolice, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: cor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                            child: Text('${percentual.toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text('Gatilho: ${_fmtCurrency.format(item.valorGatilho)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600))),
                          Text('Prêmio: ${_fmtCurrency.format(item.valorApolice)}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: cor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          percentual > 100 ? '🔴 CRÍTICO - Estourou' : percentual >= 80 ? '⚠️ ALTO - >80%' : '⚠️ MODERADO - >60%',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cor),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// Top 10 Clientes com Maior Risco Financeiro (% de Uso do Gatilho)
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Etapa 07 — cálculo revisado:
  //  • gatilho EFETIVO: o do contrato ou, se não houver (0 / 0,01), o % padrão
  //    das Configurações × valor da apólice (antes, R$ 0,01 dava 2.375.000.000%);
  //  • gasto = sinistros ligados à apólice, ocorridos DENTRO da vigência e não
  //    cancelados/negados (antes somava qualquer sinistro da apólice, de qualquer época);
  //  • % mostrado sem casas decimais.
  static Widget buildTopClientesPorRisco(
      List<Client> clientes,
      List<Claim> claims, {
      double percentualGatilho = GatilhoApolice.percentualPadraoInicial,
    }) {
      if (clientes.isEmpty) return const SizedBox.shrink();

      // Etapa 10: mesma regra da recomendação do cliente
      // (lib/utils/recomendacao_cliente.dart): só apólices vigentes, sinistros da
      // vigência sem Cancelado/Negado, sinistro sem vínculo ligado pela apólice do
      // mesmo ramo cuja vigência cobre a data, e vale a pior apólice do cliente.
      final claimsPorCliente = <String, List<Claim>>{};
      for (final claim in claims) {
        claimsPorCliente.putIfAbsent(claim.idCliente, () => []).add(claim);
      }

      final List<({
        Client cliente,
        double percentual,
        double valorGatilho,
        double gasto,
        String ramo,
        String numeroApolice,
      })> riscos = [];

      for (final cliente in clientes) {
        final r = recomendarCliente(cliente, claimsPorCliente[cliente.id] ?? const [], percentualGatilho);
        if (r.gatilho <= 0 || r.usoGatilho <= 0) continue;
        riscos.add((
          cliente: cliente,
          percentual: r.usoGatilho,
          valorGatilho: r.gatilho,
          gasto: r.gasto,
          ramo: r.apoliceRamo ?? '',
          numeroApolice: r.apoliceNumero ?? '',
        ));
      }

      // 3️⃣ Ordenar por maior percentual e pegar os 10 primeiros
      riscos.sort((a, b) => b.percentual.compareTo(a.percentual));
      final top10 = riscos.take(10).toList();

      if (top10.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Text(
            '✅ Nenhum cliente com risco de gatilho identificado.',
            style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
          ),
        );
      }

      // 4️⃣ Montar UI
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_rounded,
                      color: Color(0xFFD32F2F),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '⚠️ Top 10 Clientes com Maior Risco de Gatilho',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista
              ...List.generate(
                top10.length,
                (index) {
                  final item = top10[index];
                  final percentual = item.percentual;
                  final cor = _getRiscoColor(percentual);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Posição + Nome + Percentual
                          Row(
                            children: [
                              // Posição
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: cor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Nome e detalhes da apólice
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.cliente.nome,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${item.ramo} - ${item.numeroApolice}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Percentual
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: cor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${percentual.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: cor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Financeiro
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Gatilho: ${_fmtCurrency.format(item.valorGatilho)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                              Text(
                                'Gasto: ${_fmtCurrency.format(item.gasto)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Barra de progresso
                          _buildRiscoProgressBar(percentual),
                          const SizedBox(height: 6),

                          // Status
                          _buildRiscoStatus(percentual),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

  // ─── Helpers ───

  static Color _getTopRankColor(int index) {
    if (index == 0) return const Color(0xFFFFB300); // Ouro
    if (index == 1) return const Color(0xFFC0C0C0); // Prata
    if (index == 2) return const Color(0xFFCD7F32); // Bronze
    return const Color(0xFF1565C0);
  }

  static Color _getRiscoColor(double percentual) {
    if (percentual > 100) return const Color(0xFFC62828); // Vermelho crítico
    if (percentual >= 80) return const Color(0xFFE65100); // Laranja escuro
    if (percentual >= 60) return const Color(0xFFFFA500); // Laranja
    return const Color(0xFF2E7D32); // Verde
  }

  static Widget _buildRiscoProgressBar(double percentual) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (percentual / 120).clamp(0.0, 1.0), // Normaliza até 120%
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(_getRiscoColor(percentual)),
          ),
        ],
      ),
    );
  }

  static Widget _buildRiscoStatus(double percentual) {
    late String status;
    late Color color;

    if (percentual > 100) {
      status = '🔴 Não recomendado — gatilho estourou';
      color = const Color(0xFFC62828);
    } else if (percentual >= 80) {
      status = '🟠 Atenção — acima de 80% do gatilho';
      color = const Color(0xFFE65100);
    } else if (percentual >= 60) {
      status = '🟡 Regular — acima de 60% do gatilho';
      color = const Color(0xFFFFA500);
    } else {
      status = '🟢 Ótimo — abaixo de 60% do gatilho';
      color = const Color(0xFF2E7D32);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}