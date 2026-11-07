// widgets/employees_performance_widgets.dart
// VERSÃO DEFINITIVA - EXIBE DISTRIBUIÇÃO DE TIPOS

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/claim_model.dart';

DateTime _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.parse(value);
  if (value is DateTime) return value;
  return DateTime.now();
}

class EmployeesPerformanceWidgets {
  static Widget buildFuncionariosSinistros(
    List<Claim> sinistros,
    Map<String, String> funcionarioNomes,
  ) {
    if (sinistros.isEmpty) {
      return _buildEmptyState('Nenhum sinistro no período selecionado.');
    }

    final sinistrosPorFunc = <String, List<Claim>>{};
    int semResponsavel = 0;
    for (final s in sinistros) {
      if (s.responsavelId != null && s.responsavelId!.isNotEmpty) {
        sinistrosPorFunc.putIfAbsent(s.responsavelId!, () => []).add(s);
      } else {
        semResponsavel++;
      }
    }

    final List<MapEntry<String, List<Claim>>> entries = [];
    if (semResponsavel > 0) {
      entries.add(MapEntry('__sem_responsavel__', 
          sinistros.where((s) => s.responsavelId == null || s.responsavelId!.isEmpty).toList()));
    }
    entries.addAll(sinistrosPorFunc.entries);
    entries.sort((a, b) => b.value.length.compareTo(a.value.length));

    return _buildRankingCard(
      icon: Icons.assignment_ind_rounded,
      color: const Color(0xFFC62828),
      title: '📋 Sinistros por Funcionário (período)',
      entries: entries,
      funcionarioNomes: funcionarioNomes,
      tipo: 'sinistro',
    );
  }

  static Widget buildFuncionariosAssistencias(
    List<Claim> assistencias,
    Map<String, String> funcionarioNomes,
  ) {
    if (assistencias.isEmpty) {
      return _buildEmptyState('Nenhuma assistência no período selecionado.');
    }

    final assistenciasPorFunc = <String, List<Claim>>{};
    int semResponsavel = 0;
    for (final a in assistencias) {
      if (a.responsavelId != null && a.responsavelId!.isNotEmpty) {
        assistenciasPorFunc.putIfAbsent(a.responsavelId!, () => []).add(a);
      } else {
        semResponsavel++;
      }
    }

    final List<MapEntry<String, List<Claim>>> entries = [];
    if (semResponsavel > 0) {
      entries.add(MapEntry('__sem_responsavel__', 
          assistencias.where((a) => a.responsavelId == null || a.responsavelId!.isEmpty).toList()));
    }
    entries.addAll(assistenciasPorFunc.entries);
    entries.sort((a, b) => b.value.length.compareTo(a.value.length));

    return _buildRankingCard(
      icon: Icons.support_agent_rounded,
      color: const Color(0xFF00695C),
      title: '🆘 Assistências por Funcionário (período)',
      entries: entries,
      funcionarioNomes: funcionarioNomes,
      tipo: 'assistencia',
    );
  }

  static Widget _buildRankingCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<MapEntry<String, List<Claim>>> entries,
    required Map<String, String> funcionarioNomes,
    required String tipo,
  }) {
    final totalItems = entries.fold<int>(0, (sum, e) => sum + e.value.length);

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
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalItems',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...entries.map((entry) {
              final key = entry.key;
              final lista = entry.value;
              final quantidade = lista.length;
              final isSemResponsavel = key == '__sem_responsavel__';
              final nome = isSemResponsavel
                  ? '⚠️ Sem responsável'
                  : (funcionarioNomes[key] ?? key);

              final tempoMedio = _calcularTempoMedio(lista);
              final distribuicaoTipos = _getDistribuicaoTipos(lista, tipo);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSemResponsavel ? Colors.orange.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSemResponsavel ? Colors.orange.shade300 : Colors.grey.shade200,
                      width: isSemResponsavel ? 1.5 : 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome + quantidade (já tem no badge, não repete)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nome,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSemResponsavel ? Colors.orange.shade800 : Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$quantidade',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tempo médio + Distribuição de tipos (lado a lado)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tempo médio
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tempo médio',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tempoMedio,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Distribuição de tipos (expande)
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tipo == 'sinistro' ? 'Ramos atendidos' : 'Tipos atendidos',
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                if (distribuicaoTipos.isEmpty)
                                  const Text(
                                    'N/A',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  )
                                else
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 2,
                                    children: distribuicaoTipos.entries.map((entry) {
                                      final tipo = entry.key;
                                      final count = entry.value;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$tipo: $count',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '💡 Compare tempo médio e distribuição de tipos para identificar padrões de atendimento.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green.shade700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  static String _calcularTempoMedio(List<Claim> claims) {
    if (claims.isEmpty) return 'N/A';

    double somaDias = 0;
    int count = 0;

    for (final claim in claims) {
      DateTime inicio = claim.dataAbertura;
      DateTime fim;

      if (claim.dataConclusao != null) {
        fim = claim.dataConclusao!.toDate();
      } else {
        fim = claim.dataUltimaAtualizacao;
      }

      if (fim.isAfter(inicio)) {
        final dias = fim.difference(inicio).inHours / 24.0;
        if (dias > 0) {
          somaDias += dias;
          count++;
        }
      }
    }

    if (count == 0) {
      for (final claim in claims) {
        if (claim.historicoStatus.length >= 2) {
          try {
            final abertura = _parseDate(claim.historicoStatus.first['data']);
            final ultima = _parseDate(claim.historicoStatus.last['data']);
            final dias = ultima.difference(abertura).inHours / 24.0;
            if (dias > 0) {
              somaDias += dias;
              count++;
            }
          } catch (e) {
            // ignora
          }
        }
      }
    }

    if (count == 0) return 'N/A';
    final media = somaDias / count;
    return '${media.toStringAsFixed(1)} dias';
  }

  // Retorna um Map<String, int> com a distribuição de tipos
  static Map<String, int> _getDistribuicaoTipos(List<Claim> claims, String tipo) {
    final map = <String, int>{};
    for (final c in claims) {
      String chave;
      if (tipo == 'sinistro') {
        // Para sinistros: usa o ramo
        chave = c.ramoSinistro.isNotEmpty ? c.ramoSinistro : 'Não informado';
      } else {
        // Para assistências: usa tipoAssistencia ou tipoOcorrencia
        String? raw = c.tipoAssistencia ?? c.tipoOcorrencia;
        if (raw == null || raw.isEmpty) continue;
        chave = raw.contains(':') ? raw.split(':').first : raw;
        chave = _getTipoLabel(chave);
      }
      map[chave] = (map[chave] ?? 0) + 1;
    }
    return map;
  }

  static String _getTipoLabel(String tipo) {
    switch (tipo) {
      case 'guincho': return 'Guincho';
      case 'vidro': return 'Vidro';
      case 'combustivel': return 'Combustível';
      case 'pane_eletrica': return 'Pane Elétrica';
      case 'carga_bateria': return 'Carga Bateria';
      case 'falta': return 'Falta Peça';
      case 'reboque': return 'Reboque';
      case 'outro': return 'Outro';
      case 'sinistro': return 'Sinistro';
      default: return tipo;
    }
  }
}