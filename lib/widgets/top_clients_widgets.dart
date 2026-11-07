// widgets/top_clients_widgets.dart - VERSÃO 2.0
// ═══════════════════════════════════════════════════════════════════════════
// Widgets para exibir Top Clientes - com indicadores corretos
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';
import '../utils/gatilho.dart';

class TopClientsWidgets {
  static final _fmtCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /// Top 10 Clientes por Receita (Valor de Apólices)
  /// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  static Widget buildTopClientesPorReceita(List<Client> clientes) {
    if (clientes.isEmpty) return const SizedBox.shrink();

    // Ordena por valor total de receita
    final clientesOrdenados = List<Client>.from(clientes)
      ..sort((a, b) => b.totalReceita.compareTo(a.totalReceita));

    final top10 = clientesOrdenados.take(10).toList();

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
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, color: Color(0xFF1565C0), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  '💰 Top 10 Clientes por Receita',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Lista
            ...List.generate(
              top10.length,
              (index) {
                final cliente = top10[index];
                final valor = cliente.totalReceita;
                final totalClientes = clientesOrdenados.fold<double>(0, (sum, c) => sum + c.totalReceita);
                final percentual = (valor > 0 && totalClientes > 0) 
                  ? (valor / totalClientes * 100).clamp(0.0, 100.0) 
                  : 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + Posição + Valor
                      Row(
                        children: [
                          // Posição
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getTopRankColor(index),
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
                          // Nome
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cliente.nome,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                    '${cliente.apolices?.length ?? 0} apólice${(cliente.apolices?.length ?? 0) != 1 ? 's' : ''}',                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Valor
                          Text(
                            _fmtCurrency.format(valor),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Barra de progresso
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentual / 100,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getTopRankColor(index),
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Percentual
                      Text(
                        '${percentual.toStringAsFixed(1)}% da receita total',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
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

      // 1️⃣ Agrupar sinistros por idApolice
      final claimsPorApolice = <String, List<Claim>>{};
      for (final claim in claims) {
        final idApolice = claim.apoliceId;
        if (idApolice != null && idApolice.isNotEmpty) {
          claimsPorApolice.putIfAbsent(idApolice, () => []).add(claim);
        }
      }

      // 2️⃣ Calcular o percentual máximo de uso do gatilho para cada cliente
      final List<({
        Client cliente,
        double percentual,
        String apoliceId,
        double valorGatilho,
        double gasto,
        String ramo,
        String numeroApolice,
      })> riscos = [];

      for (final cliente in clientes) {
        double maxPercentual = 0.0;
        String? apoliceIdMax;
        double gatilhoMax = 0.0;
        double gastoMax = 0.0;
        String ramoMax = '';
        String numeroApoliceMax = '';

        for (final apolice in cliente.apolices) {
          final gatilho = apolice.gatilhoEfetivo(percentualGatilho);
          if (gatilho <= 0) continue; // sem gatilho e sem valor da apólice

          // Soma dos sinistros dessa apólice dentro da vigência (sem cancelados/negados)
          final claimsApolice = (claimsPorApolice[apolice.id] ?? []).where((c) => GatilhoApolice.sinistroConta(
                dataOcorrencia: c.dataOcorrencia,
                status: c.statusAtual,
                inicioVigencia: apolice.dataInicio,
                fimVigencia: apolice.dataFim,
              ));
          final gastoTotal = claimsApolice.fold<double>(
            0.0,
            (sum, claim) => sum + claim.valorTotalSinistro,
          );

          final percentual = GatilhoApolice.usoPercentual(gastoTotal, gatilho);
          if (percentual > maxPercentual) {
            maxPercentual = percentual;
            apoliceIdMax = apolice.id;
            gatilhoMax = gatilho;
            gastoMax = gastoTotal;
            ramoMax = apolice.ramo;
            numeroApoliceMax = apolice.numeroApolice;
          }
        }

        if (maxPercentual > 0 && apoliceIdMax != null) {
          riscos.add((
            cliente: cliente,
            percentual: maxPercentual,
            apoliceId: apoliceIdMax,
            valorGatilho: gatilhoMax,
            gasto: gastoMax,
            ramo: ramoMax,
            numeroApolice: numeroApoliceMax,
          ));
        }
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
      status = '🔴 CRÍTICO - Gatilho Estourou';
      color = const Color(0xFFC62828);
    } else if (percentual >= 80) {
      status = '⚠️ ALTO - Acima de 80% do gatilho';
      color = const Color(0xFFE65100);
    } else if (percentual >= 60) {
      status = '⚠️ MODERADO - Acima de 60% do gatilho';
      color = const Color(0xFFFFA500);
    } else {
      status = '✅ NORMAL - Abaixo de 60% do gatilho';
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