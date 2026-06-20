// screens/reports_screen.dart
// ignore_for_file: unused_import, deprecated_member_use

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fl_chart/fl_chart.dart';
import 'package:upgrade_seguros/services/config_service.dart';
import 'package:upgrade_seguros/services/firestore_service.dart';
import 'package:upgrade_seguros/models/client_model.dart';
import 'package:upgrade_seguros/models/claim_model.dart';

// ─── Helper para converter datas (Timestamp ou String) ───────────────────────
DateTime _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.parse(value);
  if (value is DateTime) return value;
  return DateTime.now();
}

// ─── Paleta de identidade ─────────────────────────────────────────────────────
class _C {
  static const blue   = Color(0xFF1565C0);
  static const green  = Color(0xFF2E7D32);
  static const amber  = Color(0xFFE65100);
  static const red    = Color(0xFFC62828);
  static const purple = Color(0xFF6A1B9A);
  static const teal   = Color(0xFF00695C);
  static const gray   = Color(0xFF546E7A);
  static const bg     = Color(0xFFF4F6F9);
}

// ─── Modelo interno de métricas ───────────────────────────────────────────────
class _ReportData {
  final int totalSinistros;
  final double valorTotalSinistros;
  final double valorTotalApolices;
  final double sinistralidade; // %
  final double tempoMedioResolucao; // dias
  final Map<String, int> porStatus;
  final Map<String, int> porFuncionario;
  final Map<String, double> tempoMedioEtapa;
  final Map<String, double> tempoMedioFuncionario;
  final List<_ClaimAtraso> aprovacoesParadas;   // Aguardando Aprovação > 3 dias
  final List<_ClaimAtraso> reparosProlongados;  // Reparo em Andamento > 7 dias
  final List<_ClaimAtraso> emAtraso;            // demais sinistros parados ≥ 7 dias
  final List<Client> contratosProximos;
  final List<_ClienteRisco> clientesAltoRisco;
  final double npsMedia;                          // 1. NPS
  final Map<String, int> npsCategoria;            // promotor, neutro, detrator
  final int totalPesquisasEnviadas;               
  final int totalPesquisasRespondidas;
  final double tempoMedioSinistros;               // 2. Tempo médio
  final double tempoMedioAssistencias;
  final Map<String, int> assistenciasPorRamo;     // 3. Distribuição por ramo
  final Map<String, int> assistenciasPorTipo;     // 4. Por tipo
  final double percentualComTerceiros;             // 5. Envolvimento terceiros
  final Map<String, int> sinistrosPorHorario;     // 6. Período (manha, tarde, noite, madrugada)
  final Map<String, int> sinistrosPorDia;
  final Map<String, int> sinistrosPorRamo;
  final Map<int, double> npsPoMes;           // Mês (1-12) → NPS média
  final Map<int, int> sinistrosPoMes;        // Mês (1-12) → Quantidade sinistros
  final Map<int, int> assistenciasPoMes;     // Mês (1-12) → Quantidade assistências
  final Map<int, double> sinistralidadePoMes; // Mês (1-12) → Loss Ratio %
  final Map<int, int> contratosAtivosPoMes;        // Mês → Qtd contratos ativos
  final Map<int, Map<String, int>> contratosPoRamoMes; // Mês → Ramo → Qtd
  final Map<int, double> valorApolicesPoMes;       // Mês → Valor total apólices
  final Map<int, double> ticketMedioPoMes;         // Mês → Ticket médio R$
  final Map<int, double> taxaRetencaoPoMes;        // Mês → Taxa retenção %
  final Map<int, double> slaComplianceSinistrosPoMes;
  final Map<int, double> slaComplianceAssistenciasPoMes;

  const _ReportData({
    required this.totalSinistros,
    required this.valorTotalSinistros,
    required this.valorTotalApolices,
    required this.sinistralidade,
    required this.tempoMedioResolucao,
    required this.porStatus,
    required this.porFuncionario,
    required this.tempoMedioEtapa,
    required this.tempoMedioFuncionario,
    required this.aprovacoesParadas,
    required this.reparosProlongados,
    required this.emAtraso,
    required this.contratosProximos,
    required this.clientesAltoRisco,
    required this.npsMedia,
    required this.npsCategoria,
    required this.totalPesquisasEnviadas,
    required this.totalPesquisasRespondidas,
    required this.tempoMedioSinistros,
    required this.tempoMedioAssistencias,
    required this.assistenciasPorRamo,
    required this.assistenciasPorTipo,
    required this.percentualComTerceiros,
    required this.sinistrosPorHorario,
    required this.sinistrosPorDia,
    required this.sinistrosPorRamo,
    required this.npsPoMes,
    required this.sinistrosPoMes,
    required this.assistenciasPoMes,
    required this.sinistralidadePoMes,
    required this.contratosAtivosPoMes,
    required this.contratosPoRamoMes,
    required this.valorApolicesPoMes,
    required this.ticketMedioPoMes,
    required this.taxaRetencaoPoMes,
    required this.slaComplianceSinistrosPoMes,
    required this.slaComplianceAssistenciasPoMes,
  });
}

class _ClaimAtraso {
  final Claim claim;
  final int diasSemMovimentacao;
  const _ClaimAtraso(this.claim, this.diasSemMovimentacao);
}

class _ClienteRisco {
  final Client client;
  final double sinistralidade;
  final double totalSinistros;
  const _ClienteRisco(this.client, this.sinistralidade, this.totalSinistros);
}

// ─── Tela principal ───────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestoreService = FirestoreService();

  _ReportData? _data;
  bool _isLoading = true;
  String _periodoSelecionado = 'Últimos 30 dias';
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _meselecionado = '${DateTime.now().month}'; // 1-12
  bool _isExporting = false;

  final _fmtCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _fmtDate    = DateFormat('dd/MM/yyyy');

  List<Claim> _assistencias = [];
  List<double> _npsNotas = [];
  int _selectedAssistLevel = 0;

  @override
  void initState() {
    super.initState();
    _setPeriodo('Mês Atual');
    
    // Garante que as datas foram setadas
    if (_dataInicio == null || _dataFim == null) {
      final now = DateTime.now();
      _dataInicio = DateTime(now.year, now.month, 1);
      _dataFim = now;
    }
    
    _load();
  }

  void _setPeriodo(String periodo) {
    switch (periodo) {
      case 'Mês Atual':
        final now = DateTime.now();
        _dataInicio = DateTime(now.year, now.month, 1);
        // Último dia do mês
        _dataFim = now.month == 12 
          ? DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
        break;
      case 'Acumulado do Ano':
        final now = DateTime.now();
          _dataInicio = DateTime(now.year, 1, 1);
          _dataFim = now;
        break;
    }
    _periodoSelecionado = periodo;
  }

  void _setMes(int mes) {
    final now = DateTime.now();
    _dataInicio = DateTime(now.year, mes, 1);
    
    // Pega o último dia do mês
    _dataFim = mes == 12 
      ? DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1))
      : DateTime(now.year, mes + 1, 1).subtract(const Duration(days: 1));
    
    _meselecionado = '$mes';
    _periodoSelecionado = 'Por mês';
    
    setState(() {});
    _load();
  }

  Future<void> _pickPeriodoCustomizado() async {
    final inicio = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Selecione a DATA INICIAL',
    );
    if (inicio == null || !mounted) return;
    
    // 🆕 Mostrar que está selecionando o fim
    if (!mounted) return;
    final fim = await showDatePicker(
      context: context,
      initialDate: _dataFim ?? DateTime.now(),
      firstDate: inicio,
      lastDate: DateTime.now(),
      helpText: 'Selecione a DATA FINAL',
    );
    if (fim == null || !mounted) return;
    
    setState(() {
      _dataInicio = inicio;
      _dataFim = fim;
      _periodoSelecionado = 'Por período';
    });
    _load();
  }

  Widget _buildAbaButton(String label, VoidCallback onTap, bool isActive) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1565C0) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      );
    }

    void _showMesPicker() {
    final meses = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecione o Mês'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: meses.length,
            itemBuilder: (context, index) {
              final mesNum = index + 1;
              final isSelected = int.parse(_meselecionado) == mesNum;
              
              return GestureDetector(
                onTap: () {
                  _setMes(mesNum);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1565C0) : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      meses[index],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  // Descrição da placa/ramo para exibir no card de reparo prolongado
  String _ramoInfo(Claim claim) {
    switch (claim.ramoSinistro) {
      case 'Frota':
      case 'Veículo Individual':
        if (claim.veiculoSelecionado != null) {
          final v = claim.veiculoSelecionado!;
          return '${v.placa.isNotEmpty ? v.placa : "N/I"} · ${v.marca} ${v.modelo}';
        }
        return claim.ramoSinistro;
      case 'Transporte':
        final t = claim.transporte;
        return t != null
            ? 'Cavalo: ${t.placaCavalo} · Carreta: ${t.placaCarreta ?? "N/I"}'
            : 'Transporte';
      default:
        return claim.ramoSinistro;
    }
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final config = await ConfigService().getConfig();
      final allClaims  = await _firestoreService.getAllClaims();
      final allClients = await _firestoreService.getAllClients();
      final now = DateTime.now();

      // Filtra por período
      final claims = allClaims.where((c) {
        if (_dataInicio == null || _dataFim == null) return true;
        return c.dataAbertura.isAfter(_dataInicio!) &&
            c.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
      }).toList();

      // ── Métricas básicas ───────────────────────────────────────────────────
      final totalValor = claims.fold(0.0, (s, c) => s + c.valorTotalSinistro);
      final totalApolices = allClients.fold(0.0, (s, c) => s + c.valorTotalApolicesAtivas);
      final sinistralidade = totalApolices > 0 ? (totalValor / totalApolices) * 100 : 0.0;

      // ── Tempo médio de resolução (Aberto → Concluído) ──────────────────────
      final resolvidos = claims.where((c) => c.statusAtual == 'Concluído');
      double somaResolucao = 0;
      int countResolucao   = 0;
      for (final c in resolvidos) {
        if (c.historicoStatus.length >= 2) {
          final abertura  = _parseDate(c.historicoStatus.first['data']);
          final conclusao = _parseDate(c.historicoStatus.last['data']);
          somaResolucao += conclusao.difference(abertura).inHours / 24.0;
          countResolucao++;
        }
      }
      final tempoMedioResolucao =
          countResolucao > 0 ? somaResolucao / countResolucao : 0.0;

      // ── NPS ────────────────────────────────────────────────────────────────
      final npsAvalSnap = await FirebaseFirestore.instance
          .collection('avaliacoes')
          .get();

      final npsNotas = npsAvalSnap.docs
          .where((d) {
            if (_dataInicio == null || _dataFim == null) return true;
            final respondidoEm = d.data()['respondidoEm'] as Timestamp?;
            if (respondidoEm == null) return false;
            final data = respondidoEm.toDate();
            return data.isAfter(_dataInicio!) && data.isBefore(_dataFim!.add(const Duration(days: 1)));
          })
          .map((d) => (d.data()['nota'] as num?)?.toDouble() ?? 0.0)
          .where((n) => n > 0)
          .toList();

      final npsMedia = npsNotas.isNotEmpty 
          ? npsNotas.reduce((a, b) => a + b) / npsNotas.length 
          : 0.0;

      // Contadores de pesquisas NPS
      final pesquisasSnap = await FirebaseFirestore.instance
          .collection('nps_pesquisas')
          .get();
      final totalPesquisasEnviadas = pesquisasSnap.docs.length;
      final totalPesquisasRespondidas = pesquisasSnap.docs
          .where((d) => d.data()['status'] == 'respondida')
          .length;

      // ── Tempo médio sinistros e assistências ────────────────────────────────
      double tempoMedioSinistros = 0.0;
      double tempoMedioAssistencias = 0.0;

      // Sinistros
      final sinistrosResolvidos = claims.where((c) => c.statusAtual == 'Concluído').toList();
      if (sinistrosResolvidos.isNotEmpty) {
        double somaSinistros = 0;
        for (final c in sinistrosResolvidos) {
          somaSinistros += c.dataUltimaAtualizacao.difference(c.dataAbertura).inHours / 24.0;
        }
        tempoMedioSinistros = somaSinistros / sinistrosResolvidos.length;
      }

      // Assistências (filtradas por período)
      final assistenciasSnap = await FirebaseFirestore.instance
          .collection('assistencias')
          .get();
      final todasAssistencias = assistenciasSnap.docs
          .map((doc) => Claim.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      final assistenciasResolvidas = todasAssistencias.where((a) {
        if (_dataInicio == null || _dataFim == null) return a.statusAtual == 'Concluído';
        return a.statusAtual == 'Concluído' &&
            a.dataAbertura.isAfter(_dataInicio!) &&
            a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
      }).toList();

      if (assistenciasResolvidas.isNotEmpty) {
        double somaAssistencias = 0;
        for (final a in assistenciasResolvidas) {
          somaAssistencias += a.dataUltimaAtualizacao.difference(a.dataAbertura).inHours / 24.0;
        }
        tempoMedioAssistencias = somaAssistencias / assistenciasResolvidas.length;
      }

      // ── Assistências por ramo ──────────────────────────────────────────────
      final assistenciasPorRamo = <String, int>{};
      for (final a in todasAssistencias) {
        // Filtra por período
        if (_dataInicio != null && _dataFim != null) {
          if (!a.dataAbertura.isAfter(_dataInicio!) ||
              a.dataAbertura.isAfter(_dataFim!.add(const Duration(days: 1)))) {
            continue;
          }
        }
        
        final ramo = a.ramoSinistro;
        assistenciasPorRamo[ramo] = (assistenciasPorRamo[ramo] ?? 0) + 1;
      }

      // ── Assistências por tipo ──────────────────────────────────────────────
      // (guincho, vidro, residencial, eletricista, chaveiro, etc)
      final assistenciasPorTipo = <String, int>{};
      for (final a in todasAssistencias) {
        // Filtra por período
        if (_dataInicio != null && _dataFim != null) {
          if (!a.dataAbertura.isAfter(_dataInicio!) ||
              a.dataAbertura.isAfter(_dataFim!.add(const Duration(days: 1)))) {
            continue;
          }
        }
        
        final tipo = a.tipoAssistencia ?? 'desconhecido';
        assistenciasPorTipo[tipo] = (assistenciasPorTipo[tipo] ?? 0) + 1;
      }

      // ── Envolvimento de terceiros (%) ──────────────────────────────────────
      double percentualComTerceiros = 0.0;
      if (claims.isNotEmpty) {
        final comTerceiros = claims.where((c) => 
          c.terceiros.isNotEmpty
        ).length;
        
        percentualComTerceiros = (comTerceiros / claims.length) * 100;
      }

      // ── Sinistros por período do dia ───────────────────────────────────────
      // Manhã (6-12), Tarde (12-18), Noite (18-24), Madrugada (0-6)
      final sinistrosPorHorario = <String, int>{
        'Madrugada': 0,
        'Manhã': 0,
        'Tarde': 0,
        'Noite': 0,
      };

      for (final c in claims) {
        final hora = c.dataOcorrencia.hour;
        
        if (hora >= 0 && hora < 6) {
          sinistrosPorHorario['Madrugada'] = (sinistrosPorHorario['Madrugada'] ?? 0) + 1;
        } else if (hora >= 6 && hora < 12) {
          sinistrosPorHorario['Manhã'] = (sinistrosPorHorario['Manhã'] ?? 0) + 1;
        } else if (hora >= 12 && hora < 18) {
          sinistrosPorHorario['Tarde'] = (sinistrosPorHorario['Tarde'] ?? 0) + 1;
        } else {
          sinistrosPorHorario['Noite'] = (sinistrosPorHorario['Noite'] ?? 0) + 1;
        }
      }

      // ── Sinistros por dia da semana ────────────────────────────────────────
      // 1=seg, 2=ter, 3=qua, 4=qui, 5=sex, 6=sab, 7=dom
      final sinistrosPorDia = <String, int>{
        'Dias de Semana': 0,
        'Fim de Semana': 0,
      };

      for (final c in claims) {
        final diaSemana = c.dataOcorrencia.weekday; // 1-7 (seg-dom)
        
        if (diaSemana >= 1 && diaSemana <= 5) {
          sinistrosPorDia['Dias de Semana'] = (sinistrosPorDia['Dias de Semana'] ?? 0) + 1;
        } else {
          sinistrosPorDia['Fim de Semana'] = (sinistrosPorDia['Fim de Semana'] ?? 0) + 1;
        }
      }

      // ── Por status ────────────────────────────────────────────────────────
      final porStatus = <String, int>{};
      for (final c in claims) {
        porStatus[c.statusAtual] = (porStatus[c.statusAtual] ?? 0) + 1;
      }

      // ── Por funcionário ───────────────────────────────────────────────────
      final porFuncionario = <String, int>{};
      final temposPorFuncionario = <String, List<double>>{};
      for (final c in claims) {
        if (c.historicoStatus.isNotEmpty) {
          final email =
              c.historicoStatus.last['responsavelEmail'] as String? ?? 'N/A';
          porFuncionario[email] = (porFuncionario[email] ?? 0) + 1;

          if (c.statusAtual == 'Concluído' && c.historicoStatus.length >= 2) {
            final abertura = _parseDate(c.historicoStatus.first['data']);
            final conclusao = _parseDate(c.historicoStatus.last['data']);
            final dias = conclusao.difference(abertura).inHours / 24.0;
            temposPorFuncionario.putIfAbsent(email, () => []).add(dias);
          }
        }
      }
      final tempoMedioFuncionario = <String, double>{};
      temposPorFuncionario.forEach((k, v) {
        tempoMedioFuncionario[k] = v.reduce((a, b) => a + b) / v.length;
      });

      // ── Tempo médio por etapa ─────────────────────────────────────────────
      final transicoesTempos = <String, List<double>>{};
      for (final c in claims) {
        final hist = c.historicoStatus;
        for (var i = 1; i < hist.length; i++) {
          final d1 = _parseDate(hist[i-1]['data']);
          final d2 = _parseDate(hist[i]['data']);
          final dias = d2.difference(d1).inHours / 24.0;
          final chave = '${hist[i-1]['status']} → ${hist[i]['status']}';
          transicoesTempos.putIfAbsent(chave, () => []).add(dias);
        }
      }
      final tempoMedioEtapa = <String, double>{};
      transicoesTempos.forEach((k, v) {
        tempoMedioEtapa[k] = v.reduce((a, b) => a + b) / v.length;
      });

      // ── Aprovações paradas (Aguardando Aprovação > 3 dias) ──────────────────
      final aprovacoesParadas = <_ClaimAtraso>[];
      for (final c in claims) {
        if (c.statusAtual != 'Aguardando Aprovação') continue;
        final ultima = c.historicoStatus.isNotEmpty
            ? _parseDate(c.historicoStatus.last['data'])
            : c.dataAbertura;
        final dias = now.difference(ultima).inDays;
        if (dias >= 3) aprovacoesParadas.add(_ClaimAtraso(c, dias));
      }
      aprovacoesParadas.sort((a, b) =>
          b.diasSemMovimentacao.compareTo(a.diasSemMovimentacao));

      // ── Reparos prolongados (Reparo em Andamento > 7 dias) ───────────────
      final reparosProlongados = <_ClaimAtraso>[];
      for (final c in claims) {
        if (c.statusAtual != 'Reparo em Andamento') continue;
        final ultima = c.historicoStatus.isNotEmpty
            ? _parseDate(c.historicoStatus.last['data'])
            : c.dataAbertura;
        final dias = now.difference(ultima).inDays;
        if (dias >= 7) reparosProlongados.add(_ClaimAtraso(c, dias));
      }
      reparosProlongados.sort((a, b) =>
          b.diasSemMovimentacao.compareTo(a.diasSemMovimentacao));

      // ── Demais sinistros em atraso (outros status, ≥ 7 dias, excluindo
      //    os dois acima para não duplicar) ──────────────────────────────────
      final _idsJaListados = {
        ...aprovacoesParadas.map((a) => a.claim.id ?? ''),
        ...reparosProlongados.map((a) => a.claim.id ?? ''),
      };
      final emAtraso = <_ClaimAtraso>[];
      for (final c in claims) {
        if (c.statusAtual == 'Concluído') continue;
        if (c.statusAtual == 'Aguardando Aprovação') continue;
        if (c.statusAtual == 'Reparo em Andamento') continue;
        if (_idsJaListados.contains(c.id ?? '')) continue;
        final ultima = c.historicoStatus.isNotEmpty
            ? _parseDate(c.historicoStatus.last['data'])
            : c.dataAbertura;
        final dias = now.difference(ultima).inDays;
        if (dias >= 7) emAtraso.add(_ClaimAtraso(c, dias));
      }
      emAtraso.sort((a, b) =>
          b.diasSemMovimentacao.compareTo(a.diasSemMovimentacao));

      // ── Contratos próximos do vencimento ──────────────────────────────────
      final contratosProximos = <Client>[];
      final thirtyDays = now.add(const Duration(days: 30));

      for (final client in allClients) {
        final temApoliceVencendo = client.apolices.any((a) => 
          a.dataFim.isAfter(now) && a.dataFim.isBefore(thirtyDays)
        );
        if (temApoliceVencendo) {
          contratosProximos.add(client);
        }
      }
      contratosProximos.sort((a, b) {
        final dataA = a.apolices.reduce((x, y) => x.dataFim.isBefore(y.dataFim) ? x : y).dataFim;
        final dataB = b.apolices.reduce((x, y) => x.dataFim.isBefore(y.dataFim) ? x : y).dataFim;
        return dataA.compareTo(dataB);
      });

      // ── Clientes com alta sinistralidade ──────────────────────────────────
      final clientesAltoRisco = <_ClienteRisco>[];
      for (final client in allClients) {
        final valorApoliceTotal = client.valorTotalApolicesAtivas;  // ← MUDA
        if (valorApoliceTotal <= 0) continue;
        
        final sinistrosCliente = claims.where((c) => c.idCliente == client.id);
        final totalSinistrosCliente = sinistrosCliente.fold(0.0, (s, c) => s + c.valorTotalSinistro);
        final perc = (totalSinistrosCliente / valorApoliceTotal) * 100;
        
        if (perc >= 60) {
          clientesAltoRisco.add(_ClienteRisco(client, perc, totalSinistrosCliente));
        }
      }
      clientesAltoRisco.sort(
          (a, b) => b.sinistralidade.compareTo(a.sinistralidade));

      // ── Assistências ───────────────────────────────────────────────────
      final allAssistencias = await FirebaseFirestore.instance
          .collection('assistencias')
          .get();
      final allAssistList = allAssistencias.docs
          .map((doc) => Claim.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      final npsCategoria = <String, int>{};
      for (final d in npsAvalSnap.docs) {
        final categoria = d.data()['categoria'] as String? ?? 'desconhecido';
        npsCategoria[categoria] = (npsCategoria[categoria] ?? 0) + 1;
      }

      // ── Sinistros por ramo ─────────────────────────────────────────────────
      final sinistrosPorRamo = <String, int>{};
      for (final c in claims) {
        if (c.tipo != 'sinistro') continue; // ← FILTRO
        
        final ramo = c.ramoSinistro;
        sinistrosPorRamo[ramo] = (sinistrosPorRamo[ramo] ?? 0) + 1;
      }

      // ── MÉTRICAS MENSAIS (Um único loop organizado) ─────────────────────────────
      final Map<int, double> npsPoMes = {};
      final Map<int, int> sinistrosPoMes = {};
      final Map<int, int> assistenciasPoMes = {};
      final Map<int, double> sinistralidadePoMes = {};
      final Map<int, int> contratosAtivosPoMes = {};
      final Map<int, Map<String, int>> contratosPoRamoMes = {};
      final Map<int, double> valorApolicesPoMes = {};
      final Map<int, double> slaComplianceSinistrosPoMes = {};
      final Map<int, double> slaComplianceAssistenciasPoMes = {};
      final Map<int, double> ticketMedioPoMes = {};
      final Map<int, double> taxaRetencaoPoMes = {};

      for (int mes = 1; mes <= 12; mes++) {
        final mesInicio = DateTime(now.year, mes, 1);
        final mesFim = mes == 12
          ? DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(now.year, mes + 1, 1).subtract(const Duration(days: 1));

        if (mesInicio.isAfter(now)) break;

        // 1. NPS MENSAL
        final npsAvalMes = npsAvalSnap.docs
          .where((d) {
            final respondidoEm = d.data()['respondidoEm'] as Timestamp?;
            if (respondidoEm == null) return false;
            final data = respondidoEm.toDate();
            return data.year == now.year && data.month == mes;
          })
          .map((d) => (d.data()['nota'] as num?)?.toDouble() ?? 0.0)
          .where((n) => n > 0)
          .toList();

        npsPoMes[mes] = npsAvalMes.isNotEmpty
          ? npsAvalMes.reduce((a, b) => a + b) / npsAvalMes.length
          : 0.0;

        // 2. SINISTROS MENSAIS
        final sinistrosMes = allClaims.where((c) {
          return c.dataAbertura.year == now.year && c.dataAbertura.month == mes;
        }).toList();
        sinistrosPoMes[mes] = sinistrosMes.length;

        // 3. ASSISTÊNCIAS MENSAIS
        final assistenciasMes = todasAssistencias.where((a) {
          return a.dataAbertura.year == now.year && a.dataAbertura.month == mes;
        }).toList();
        assistenciasPoMes[mes] = assistenciasMes.length;

        // 4. SINISTRALIDADE MENSAL
        if (sinistrosMes.isNotEmpty) {
          final totalValorMes = sinistrosMes.fold<double>(0, (s, c) => s + c.valorTotalSinistro);
          sinistralidadePoMes[mes] = (totalValorMes / totalApolices) * 100;
        } else {
          sinistralidadePoMes[mes] = 0.0;
        }

        // 5. CONTRATOS ATIVOS MENSAIS
        final contratosAtivosMes = allClients.where((c) {
          return c.apolices.any((a) {
            // Apólice está ativa em algum ponto do mês
            return !a.dataFim.isBefore(mesInicio) && !a.dataInicio.isAfter(mesFim);
          });
        }).length;
        contratosAtivosPoMes[mes] = contratosAtivosMes;

        // 6. CONTRATOS POR RAMO MENSAIS
        final contratosPorRamo = <String, int>{};
        for (final c in allClients) {
          for (final apolice in c.apolices.where((a) {
            return !a.dataFim.isBefore(mesInicio) && !a.dataInicio.isAfter(mesFim);
          })) {
            contratosPorRamo[apolice.ramo] = (contratosPorRamo[apolice.ramo] ?? 0) + 1;
          }
        }
        contratosPoRamoMes[mes] = contratosPorRamo;

        // 7. VALOR APÓLICES MENSAIS
        final valorApolicesMes = allClients.fold<double>(0, (sum, c) {
          final valor = c.apolices
            .where((a) {
              return !a.dataFim.isBefore(mesInicio) && !a.dataInicio.isAfter(mesFim);
            })
            .fold<double>(0, (s, a) => s + a.valorApolice);
          return sum + valor;
        });
        valorApolicesPoMes[mes] = valorApolicesMes;

        // 8. SLA COMPLIANCE SINISTROS (10 dias fixo)
              if (sinistrosMes.isNotEmpty) {
                final dentroPrazo = sinistrosMes.where((c) {
                  if (c.dataConclusao == null) {
                    if (c.statusAtual == 'Concluído' && c.historicoStatus.isNotEmpty) {
                      final statusConcluido = c.historicoStatus.lastWhere(
                        (h) => h['novoStatus'] == 'Concluído',
                        orElse: () => c.historicoStatus.last,
                      );
                      final dataMudanca = statusConcluido['dataMudanca'];
                      if (dataMudanca is Timestamp) {
                        final diasAberto = dataMudanca.toDate().difference(c.dataAbertura).inDays;
                        return diasAberto <= config.slaSinistrosDias;  // ✅ SEM await, usa config
                      }
                    }
                    return false;
                  }
                  final diasAberto = c.dataConclusao!.toDate().difference(c.dataAbertura).inDays;
                  return diasAberto <= config.slaSinistrosDias;  // ✅ SEM await, usa config
                }).length;
                slaComplianceSinistrosPoMes[mes] = (dentroPrazo / sinistrosMes.length) * 100;
              } else {
                slaComplianceSinistrosPoMes[mes] = 100.0;
              }

        // 9. SLA COMPLIANCE ASSISTÊNCIAS (conforme slaPrevisto/slaAtendimento)
        if (assistenciasMes.isNotEmpty) {
          final dentroPrazo = assistenciasMes.where((a) {
            if (a.dataConclusao == null) {
              if (a.statusAtual == 'Concluído' && a.historicoStatus.isNotEmpty) {
                final statusConcluido = a.historicoStatus.lastWhere(
                  (h) => h['novoStatus'] == 'Concluído',
                  orElse: () => a.historicoStatus.last,
                );
                final dataMudanca = statusConcluido['dataMudanca'];
                final prazolimite = a.slaAtendimento ?? a.slaPrevisto;
                if (dataMudanca is Timestamp && prazolimite != null) {
                  return (dataMudanca as Timestamp).toDate().isBefore(prazolimite);
                }
              }
              return false;
            }
            final prazolimite = a.slaAtendimento ?? a.slaPrevisto;
            if (prazolimite == null) return false;
            return a.dataConclusao!.toDate().isBefore(prazolimite);
          }).length;
          slaComplianceAssistenciasPoMes[mes] = (dentroPrazo / assistenciasMes.length) * 100;
        } else {
          slaComplianceAssistenciasPoMes[mes] = -1.0;
        }

        // 10. TICKET MÉDIO (valor médio por sinistro)
        final ticketMedio = sinistrosMes.isNotEmpty
          ? sinistrosMes.fold<double>(0.0, (sum, c) => sum + c.valorTotalSinistro) / sinistrosMes.length
          : 0.0;
        ticketMedioPoMes[mes] = ticketMedio;

        // 11. TAXA DE RETENÇÃO (% de contratos que não venceram no mês)
       if (contratosAtivosMes > 0) {
          final naoVencemNoMes = allClients.where((c) {
            return c.apolices.any((a) {
              return a.dataFim.isAfter(mesFim);
            });
          }).length;
          taxaRetencaoPoMes[mes] = (naoVencemNoMes / contratosAtivosMes) * 100;
        } else {
          taxaRetencaoPoMes[mes] = 0.0;
        }
      }

      if (mounted) {
        setState(() {
          _data = _ReportData(
            totalSinistros:         claims.length,
            valorTotalSinistros:    totalValor,
            valorTotalApolices:     totalApolices,
            sinistralidade:         sinistralidade,
            tempoMedioResolucao:    tempoMedioResolucao,
            porStatus:              porStatus,
            porFuncionario:         porFuncionario,
            tempoMedioEtapa:        tempoMedioEtapa,
            tempoMedioFuncionario:  tempoMedioFuncionario,
            aprovacoesParadas:      aprovacoesParadas,
            reparosProlongados:     reparosProlongados,
            emAtraso:               emAtraso,
            contratosProximos:      contratosProximos,
            clientesAltoRisco:      clientesAltoRisco,
            npsMedia: npsMedia,
            npsCategoria: npsCategoria,
            totalPesquisasEnviadas: totalPesquisasEnviadas,
            totalPesquisasRespondidas: totalPesquisasRespondidas,
            tempoMedioSinistros: tempoMedioSinistros,
            tempoMedioAssistencias: tempoMedioAssistencias,
            assistenciasPorRamo: assistenciasPorRamo,
            assistenciasPorTipo: assistenciasPorTipo,
            percentualComTerceiros: percentualComTerceiros,
            sinistrosPorHorario: sinistrosPorHorario,
            sinistrosPorDia: sinistrosPorDia,
            sinistrosPorRamo: sinistrosPorRamo,
            npsPoMes: npsPoMes,
            sinistrosPoMes: sinistrosPoMes,
            assistenciasPoMes: assistenciasPoMes,
            sinistralidadePoMes: sinistralidadePoMes,
            contratosAtivosPoMes: contratosAtivosPoMes,
            contratosPoRamoMes: contratosPoRamoMes,
            valorApolicesPoMes: valorApolicesPoMes,
            ticketMedioPoMes: ticketMedioPoMes,
            taxaRetencaoPoMes: taxaRetencaoPoMes,
            slaComplianceSinistrosPoMes: slaComplianceSinistrosPoMes,
            slaComplianceAssistenciasPoMes: slaComplianceAssistenciasPoMes,
          );
          _assistencias = allAssistList;
          _assistencias.sort((a, b) => b.dataAbertura.compareTo(a.dataAbertura));
          _npsNotas = npsNotas;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar relatório: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNpsCard() {
    if (_data == null) return const SizedBox();
    
    final totalRespostas = _data!.totalPesquisasRespondidas;
    final promotores = _data!.npsCategoria['promotor'] ?? 0;
    final neutros = _data!.npsCategoria['neutro'] ?? 0;
    final detratores = _data!.npsCategoria['detrator'] ?? 0;
    
    final percPromotor = totalRespostas > 0 ? (promotores / totalRespostas * 100) : 0.0;
    final percNeutro = totalRespostas > 0 ? (neutros / totalRespostas * 100) : 0.0;
    final percDetrator = totalRespostas > 0 ? (detratores / totalRespostas * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⭐ NPS (Net Promoter Score)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          
          // Nota média em destaque
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _data!.npsMedia.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nota Média',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    Text(
                      'de 0 a 10',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_data!.totalPesquisasRespondidas} respostas de ${_data!.totalPesquisasEnviadas} pesquisas',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          
          // Distribuição
          Text(
            'Distribuição de Respostas',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          _buildNpsBar('Promotor (≥9)', promotores, totalRespostas, Colors.green),
          _buildNpsBar('Neutro (7-8)', neutros, totalRespostas, Colors.orange),
          _buildNpsBar('Detrator (≤6)', detratores, totalRespostas, Colors.red),
        ],
      ),
    );
  }

  // ── Tempo médio card ──────────────────────────────────────────────
  Widget _buildTempoMedioCard() {
    if (_data == null) return const SizedBox();
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⏱️ Tempo Médio de Resolução',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Sinistros
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sinistros',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_data!.tempoMedioSinistros.toStringAsFixed(1)} dias',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'da abertura à conclusão',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Assistências
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assistências',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_data!.tempoMedioAssistencias.toStringAsFixed(1)} dias',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'da abertura à conclusão',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gráfico Pizza - Assisência por Ramo ───────────────────────────────────
  Widget _buildAssistenciasPorRamoChart() {
    if (_data == null || _data!.assistenciasPorRamo.isEmpty) {
      return const SizedBox();
    }

    final data = _data!.assistenciasPorTipo;
    final total = data.values.fold<int>(0, (sum, val) => sum + val);
    
    // Cores alternadas
    final cores = [Colors.blue, Colors.orange, Colors.green, Colors.red, Colors.purple];
    final entries = data.entries.toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🚗 Assistências por Ramo',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final ramo = e.value.key;
                  final count = e.value.value;
                  final percent = (count / total * 100);
                  
                  return PieChartSectionData(
                    value: count.toDouble(),
                    title: '${percent.toStringAsFixed(0)}%',
                    color: cores[idx % cores.length],
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList(),
                centerSpaceRadius: 50,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Legenda
          ...entries.asMap().entries.map((e) {
            final idx = e.key;
            final ramo = _getTipoAssistenciaLabel(e.value.key);
            final count = e.value.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: cores[idx % cores.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ramo,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Gráfico Pizza - Sinistros vs Assistências ──────────────────────────────────────────────
  Widget _buildSinistroVsAssistenciaChart() {
    if (_data == null) return const SizedBox();
    
    // Total de sinistros e assistências no período
    int totalSinistros = _data!.totalSinistros;
    int totalAssistencias = _data!.assistenciasPorRamo.values.fold<int>(0, (sum, val) => sum + val);
    int total = totalSinistros + totalAssistencias;
    
    if (total == 0) return const SizedBox();
    
    final percSinistros = (totalSinistros / total * 100);
    final percAssistencias = (totalAssistencias / total * 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Sinistros vs Assistências',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: totalSinistros.toDouble(),
                    title: '${percSinistros.toStringAsFixed(0)}%',
                    color: const Color(0xFF1565C0),
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  PieChartSectionData(
                    value: totalAssistencias.toDouble(),
                    title: '${percAssistencias.toStringAsFixed(0)}%',
                    color: const Color(0xFF2E7D32),
                    radius: 80,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
                centerSpaceRadius: 50,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Legenda
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Sinistros',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '$totalSinistros',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: const Text(
                  'Assistências',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '$totalAssistencias',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Gráfico de Sinitro por Ramo ────────────────────────────────────────────
  Widget _buildSinistrosPorRamoChart() {
    if (_data == null || _data!.sinistrosPorRamo.isEmpty) return const SizedBox();
    
    final ramoData = _data!.sinistrosPorRamo;
    final maxValue = ramoData.values.isNotEmpty 
      ? ramoData.values.reduce((a, b) => a > b ? a : b).toDouble() 
      : 10;
    
    // 🎨 Cores distintas para cada ramo
    final cores = {
      'Frota': const Color(0xFF1565C0),           // Azul
      'Veículo Individual': const Color(0xFF2E7D32), // Verde
      'Transporte': const Color(0xFFE65100),      // Laranja
      'Máquinas e Equipamentos': const Color(0xFFC62828), // Vermelho
      'Residencial': const Color(0xFF6A1B9A),    // Roxo
      'Vida': const Color(0xFF00695C),           // Teal
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 Sinistros por Ramo',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          ...ramoData.entries.map((e) {
            final ramo = e.key;
            final valor = e.value;
            final percent = (valor / maxValue * 100);
            final cor = cores[ramo] ?? const Color(0xFF9E9E9E);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ramo,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$valor',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 24,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(cor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Gráfico de Sinitro por Dia da Semana ─────────────────────────────────────────
  Widget _buildSinistrosPorDiaChart() {
    if (_data == null || _data!.sinistrosPorDia.isEmpty) return const SizedBox();
    
    final diaData = _data!.sinistrosPorDia;
    final maxValue = diaData.values.isNotEmpty 
      ? diaData.values.reduce((a, b) => a > b ? a : b).toDouble() 
      : 10;

    final cores = {
      'Dias de Semana': const Color(0xFF1565C0),  // Azul
      'Fim de Semana': const Color(0xFFC62828),   // Vermelho
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📅 Sinistros por Dia da Semana',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          ...diaData.entries.map((e) {
            final dia = e.key;
            final valor = e.value;
            final percent = (valor / maxValue * 100);
            final cor = cores[dia] ?? Colors.grey;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          dia,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$valor',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 24,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(cor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Gráfico de Sinitro com Envolvimento de Terceiros ──────────────────────────
  Widget _buildEnvolvimentoTerceirosCard() {
    if (_data == null) return const SizedBox();
    
    final percent = _data!.percentualComTerceiros;
    final status = percent < 20 
      ? 'Baixo'
      : percent < 50 
        ? 'Moderado'
        : 'Elevado';
    final cor = percent < 20 
      ? Colors.green 
      : percent < 50 
        ? Colors.orange 
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👥 Envolvimento de Terceiros',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sinistros com Terceiros',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Gráfico Sinistro por Horário ──────────────────────────────────────────────
  Widget _buildSinistrosPorHorarioChart() {
    if (_data == null || _data!.sinistrosPorHorario.isEmpty) return const SizedBox();
    
    final horariosData = _data!.sinistrosPorHorario;
    final maxValue = horariosData.values.isNotEmpty 
      ? horariosData.values.reduce((a, b) => a > b ? a : b).toDouble() 
      : 10;

    final cores = {
      'Madrugada': const Color(0xFF1A237E),    // Azul escuro
      'Manhã': const Color(0xFFFFA500),        // Laranja
      'Tarde': const Color(0xFFFFD700),        // Amarelo
      'Noite': const Color(0xFF37474F),        // Cinza escuro
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🕐 Sinistros por Horário do Dia',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          ...horariosData.entries.map((e) {
            final horario = e.key;
            final valor = e.value;
            final percent = (valor / maxValue * 100);
            final cor = cores[horario] ?? Colors.grey;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          horario,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$valor',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 24,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(cor),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // ── Gráfico de evolução de NPS ──────────────────────────────────────────────
  // ── Gráfico de evolução de NPS ──────────────────────────────────────────────
  Widget _buildNpsAnualChart() {
    if (_data == null || _data!.npsPoMes.isEmpty) return const SizedBox();
    
    final npsData = _data!.npsPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final nps = npsData[mes] ?? 0.0;
      spots.add(FlSpot(mes.toDouble(), nps));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📈 NPS Mensal - Ano ${DateTime.now().year} (0-10)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final valor = _formatarValorTooltip(spot.y, 'nps');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF2E7D32),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF2E7D32),
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 10,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gráfico Sinistros por mês ──────────────────────────────────────────────
  Widget _buildSinistrosAnualChart() {
    if (_data == null || _data!.sinistrosPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.sinistrosPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = (data[mes] ?? 0).toDouble();
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Sinistros Mensais - Ano ${DateTime.now().year} (quantidade)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                      final valor = _formatarValorTooltip(spot.y, 'contador');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: Color(0xFFD32F2F),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFFD32F2F),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFD32F2F).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── ASSISTÊNCIAS MENSAIS
  Widget _buildAssistenciasAnualChart() {
    if (_data == null || _data!.assistenciasPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.assistenciasPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = (data[mes] ?? 0).toDouble();
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🚗 Assistências Mensais - Ano ${DateTime.now().year} (quantidade)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                      final valor = _formatarValorTooltip(spot.y, 'contador');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: const Color(0xFF1976D2),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF1976D2),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SINISTRALIDADE MENSAL PARA GRÁFICO ANUAL
  Widget _buildSinistralidadeAnualChart() {
    if (_data == null || _data!.sinistralidadePoMes.isEmpty) {
      return const SizedBox();
    }
    
    final data = _data!.sinistralidadePoMes;
    final spots = <FlSpot>[];
    double maxValor = 100.0;  // Valor padrão
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = data[mes] ?? 0.0;
      
      // 🔥 Garante que o valor é válido
      if (valor.isFinite && valor >= 0) {
        spots.add(FlSpot(mes.toDouble(), valor));
        if (valor > maxValor) maxValor = valor;
      } else {
        spots.add(FlSpot(mes.toDouble(), 0.0));
      }
    }
    
    // Se todos os valores são 0, mostra mensagem
    if (spots.every((s) => s.y == 0)) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text('Sem dados de sinistralidade para este período'),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📉 Sinistralidade Mensal - Ano ${DateTime.now().year} (%)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final valor = _formatarValorTooltip(spot.y, 'percentual');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: Color(0xFFF57C00),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFFF57C00),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFF57C00).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: (maxValor * 1.2).clamp(0, double.infinity),  // 20% acima do máximo
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── CONTRATOS ATIVOS MENSAIS
  Widget _buildContratosAnualChart() {
    if (_data == null || _data!.contratosAtivosPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.contratosAtivosPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = (data[mes] ?? 0).toDouble();
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 Contratos Ativos Mensais - Ano ${DateTime.now().year} (quantidade)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                      final valor = _formatarValorTooltip(spot.y, 'contador');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: const Color(0xFF388E3C),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF388E3C),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF388E3C).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── VALOR APÓLICES MENSAL
  Widget _buildValorApolicesAnualChart() {
    if (_data == null || _data!.valorApolicesPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.valorApolicesPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = (data[mes] ?? 0.0) / 1000; // Converter para milhares
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💰 Valor Apólices Mensais - Ano ${DateTime.now().year} (R\$)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                      final valor = _formatarValorTooltip(spot.y, 'moeda');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: const Color(0xFF7B1FA2),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('R\$${value.toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF7B1FA2),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF7B1FA2).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SLA COMPLIANCE MENSAL


  // ── TICKET MÉDIO MENSAL
  Widget _buildTicketMedioAnualChart() {
    if (_data == null || _data!.ticketMedioPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.ticketMedioPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = (data[mes] ?? 0.0) / 1000; // Converter para milhares
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🎫 Ticket Médio Mensal - Ano ${DateTime.now().year} (R\$)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                      final valor = _formatarValorTooltip(spot.y, 'moeda');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: const Color(0xFFE64A19),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('R\$${value.toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFFE64A19),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFFE64A19).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── TAXA DE RETENÇÃO MENSAL
  Widget _buildTaxaRetencaoAnualChart() {
    if (_data == null || _data!.taxaRetencaoPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.taxaRetencaoPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = data[mes] ?? 0.0;
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Taxa de Retenção Mensal - Ano ${DateTime.now().year} (%)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                      final valor = _formatarValorTooltip(spot.y, 'percentual');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(
                            color: const Color(0xFF6A1B9A),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF6A1B9A),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF6A1B9A).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SLA COMPLIANCE SINISTROS
  Widget _buildSlaComplianceSinistrosAnualChart() {
    if (_data == null || _data!.slaComplianceSinistrosPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.slaComplianceSinistrosPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = data[mes] ?? 0.0;
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✅ SLA Compliance Sinistros - Ano ${DateTime.now().year} (%)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final valor = _formatarValorTooltip(spot.y, 'percentual');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF00796B),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF00796B).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SLA COMPLIANCE ASSISTÊNCIAS
  Widget _buildSlaComplianceAssistenciasAnualChart() {
    if (_data == null || _data!.slaComplianceAssistenciasPoMes.isEmpty) return const SizedBox();
    
    final data = _data!.slaComplianceAssistenciasPoMes;
    final spots = <FlSpot>[];
    
    for (int mes = 1; mes <= 12; mes++) {
      final valor = data[mes] ?? 0.0;
      spots.add(FlSpot(mes.toDouble(), valor));
    }
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✅ SLA Compliance Assistências - Ano ${DateTime.now().year} (%)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.white,
                    tooltipPadding: const EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final valor = _formatarValorTooltip(spot.y, 'percentual');
                        return LineTooltipItem(
                          valor,
                          const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                                      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
                        final mes = value.toInt();
                        return mes >= 1 && mes <= 12 
                          ? Text(meses[mes - 1], style: const TextStyle(fontSize: 10))
                          : const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: const Color(0xFF0288D1),
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF0288D1).withOpacity(0.1),
                    ),
                  ),
                ],
                minY: 0,
                maxY: 100,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Geração do PDF executivo ──────────────────────────────────────────────
  Future<void> _exportarPdf() async {
    if (_data == null) return;
    setState(() => _isExporting = true);
    try {
      final pdf = pw.Document();
      final d = _data!;
      final periodo = _dataInicio != null && _dataFim != null
          ? '${_fmtDate.format(_dataInicio!)} a ${_fmtDate.format(_dataFim!)}'
          : _periodoSelecionado;

      // Cores PDF
      const corBlue   = PdfColor.fromInt(0xFF1565C0);
      const corGreen  = PdfColor.fromInt(0xFF2E7D32);
      const corRed    = PdfColor.fromInt(0xFFC62828);
      const corAmber  = PdfColor.fromInt(0xFFE65100);
      const corGray   = PdfColor.fromInt(0xFF546E7A);
      const corBg     = PdfColor.fromInt(0xFFF4F6F9);

      pw.Widget metricBox(String label, String value, {PdfColor color = corBlue}) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: corBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(fontSize: 8, color: corGray)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: color)),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => [

            // Cabeçalho
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Upgrade Corretora de Seguros',
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: corBlue)),
                    pw.Text('Sumário Executivo · $periodo',
                        style: pw.TextStyle(
                            fontSize: 10, color: corGray)),
                  ],
                ),
                pw.Text(
                  'Gerado em ${_fmtDate.format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 8, color: corGray),
                ),
              ],
            ),
            pw.Divider(color: corBlue, height: 20),

            // Métricas principais
            pw.Text('Visão geral do período',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Row(
              children: [
                pw.Expanded(child: metricBox('Total de sinistros', d.totalSinistros.toString())),
                pw.SizedBox(width: 8),
                pw.Expanded(child: metricBox('Valor total', _fmtCurrency.format(d.valorTotalSinistros))),
                pw.SizedBox(width: 8),
                pw.Expanded(child: metricBox(
                    'Sinistralidade',
                    '${d.sinistralidade.toStringAsFixed(1)}%',
                    color: d.sinistralidade > 75
                        ? corRed
                        : d.sinistralidade > 50
                            ? corAmber
                            : corGreen)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: metricBox(
                    'Tempo médio resolução',
                    '${d.tempoMedioResolucao.toStringAsFixed(1)} dias')),
              ],
            ),
            pw.SizedBox(height: 16),

            // Distribuição por status
            pw.Text('Distribuição por status',
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: corBg),
                  children: ['Status', 'Quantidade', '% do total']
                      .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold)),
                          ))
                      .toList(),
                ),
                ...d.porStatus.entries.map((e) {
                  final pct = d.totalSinistros > 0
                      ? (e.value / d.totalSinistros * 100)
                          .toStringAsFixed(1)
                      : '0';
                  return pw.TableRow(
                    children: [e.key, '${e.value}', '$pct%']
                        .map((cell) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(cell,
                                  style:
                                      const pw.TextStyle(fontSize: 9)),
                            ))
                        .toList(),
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),

            // Sinistros em atraso
            if (d.emAtraso.isNotEmpty) ...[
              pw.Text(
                  'Sinistros em atraso (sem movimentação ≥ 7 dias)',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: corRed)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: corBg),
                    children:
                        ['Nº Sinistro', 'Cliente', 'Status', 'Dias parado']
                            .map((h) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(h,
                                      style: pw.TextStyle(
                                          fontSize: 9,
                                          fontWeight:
                                              pw.FontWeight.bold)),
                                ))
                            .toList(),
                  ),
                  ...d.emAtraso.take(15).map((a) => pw.TableRow(
                        children: [
                          a.claim.numeroSinistro,
                          a.claim.clientNome,
                          a.claim.statusAtual,
                          '${a.diasSemMovimentacao} dias',
                        ]
                            .map((cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(cell,
                                      style: const pw.TextStyle(
                                          fontSize: 9)),
                                ))
                            .toList(),
                      )),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Tempo médio por etapa
            if (d.tempoMedioEtapa.isNotEmpty) ...[
              pw.Text('Tempo médio por etapa do processo',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: corBg),
                    children: ['Transição', 'Média (dias)']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight:
                                          pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...d.tempoMedioEtapa.entries.map((e) =>
                      pw.TableRow(
                        children: [e.key, e.value.toStringAsFixed(1)]
                            .map((cell) => pw.Padding(
                                  padding:
                                      const pw.EdgeInsets.all(6),
                                  child: pw.Text(cell,
                                      style: const pw.TextStyle(
                                          fontSize: 9)),
                                ))
                            .toList(),
                      )),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Clientes em risco
            if (d.clientesAltoRisco.isNotEmpty) ...[
              pw.Text('Clientes com sinistralidade elevada (≥ 60%)',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: corAmber)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: corBg),
                    children: [
                      'Cliente',
                      'Sinistralidade',
                      'Total sinistros',
                      'Vencimento apólice'
                    ]
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight:
                                          pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...d.clientesAltoRisco.map((r) => pw.TableRow(
                        children: [
                          r.client.nome,
                          '${r.sinistralidade.toStringAsFixed(1)}%',
                          _fmtCurrency.format(r.totalSinistros),
                          _fmtDate.format(
                            r.client.apolices.reduce((a, b) => a.dataFim.isBefore(b.dataFim) ? a : b).dataFim
                          ),
                        ]
                            .map((cell) => pw.Padding(
                                  padding:
                                      const pw.EdgeInsets.all(6),
                                  child: pw.Text(cell,
                                      style: const pw.TextStyle(
                                          fontSize: 9)),
                                ))
                            .toList(),
                      )),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Aprovações travadas
            if (d.aprovacoesParadas.isNotEmpty) ...[
              pw.Text('Aprovações travadas (> 3 dias)',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: corAmber)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: corBg),
                    children: ['Nº Sinistro', 'Cliente', 'Seguradora', 'Dias parado']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...d.aprovacoesParadas.map((a) => pw.TableRow(
                        children: [
                          a.claim.numeroSinistro,
                          a.claim.clientNome,
                          a.claim.seguradora.isNotEmpty ? a.claim.seguradora : '—',
                          '${a.diasSemMovimentacao} dias',
                        ]
                            .map((cell) => pw.Padding(
                                  padding: const pw.EdgeInsets.all(6),
                                  child: pw.Text(cell,
                                      style: const pw.TextStyle(fontSize: 9)),
                                ))
                            .toList(),
                      )),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Reparos prolongados
            if (d.reparosProlongados.isNotEmpty) ...[
              pw.Text('Veículos em manutenção prolongada (> 7 dias)',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: corBlue)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: corBg),
                    children: ['Nº Sinistro', 'Cliente', 'Veículo / Placa', 'Dias em reparo']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...d.reparosProlongados.map((a) {
                    String veiculo = '—';
                    if (a.claim.veiculoSelecionado != null) {
                      final v = a.claim.veiculoSelecionado!;
                      veiculo = '${v.placa.isNotEmpty ? v.placa : "N/I"} · ${v.marca}';
                    } else if (a.claim.transporte != null) {
                      veiculo = 'Cavalo: ${a.claim.transporte!.placaCavalo}';
                    }
                    return pw.TableRow(
                      children: [
                        a.claim.numeroSinistro,
                        a.claim.clientNome,
                        veiculo,
                        '${a.diasSemMovimentacao} dias${a.diasSemMovimentacao > 14 ? " ⚠" : ""}',
                      ]
                          .map((cell) => pw.Padding(
                                padding: const pw.EdgeInsets.all(6),
                                child: pw.Text(cell,
                                    style: const pw.TextStyle(fontSize: 9)),
                              ))
                          .toList(),
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Contratos próximos
            if (d.contratosProximos.isNotEmpty) ...[
              pw.Text('Contratos próximos do vencimento (30 dias)',
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                    color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration:
                        const pw.BoxDecoration(color: corBg),
                    children: ['Cliente', 'Vencimento', 'Valor apólice']
                        .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight:
                                          pw.FontWeight.bold)),
                            ))
                        .toList(),
                  ),
                  ...d.contratosProximos.map((c) => pw.TableRow(
                        children: [
                        c.nome,
                        _fmtDate.format(
                          c.apolices.isNotEmpty 
                              ? c.apolices.reduce((a, b) => a.dataFim.isBefore(b.dataFim) ? a : b).dataFim
                              : DateTime.now()
                        ),
                        // MUDA PARA: valor total
                        _fmtCurrency.format(c.valorTotalApolicesAtivas),
                      ]
                            .map((cell) => pw.Padding(
                                  padding:
                                      const pw.EdgeInsets.all(6),
                                  child: pw.Text(cell,
                                      style: const pw.TextStyle(
                                          fontSize: 9)),
                                ))
                            .toList(),
                      )),
                ],
              ),
            ],

            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'Upgrade Corretora de Seguros · Relatório gerado automaticamente pelo sistema de gestão',
              style: pw.TextStyle(fontSize: 7, color: corGray),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Upgrade_Relatorio_${_fmtDate.format(DateTime.now()).replaceAll('/', '-')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: _data == null
                    ? const Center(child: Text('Erro ao carregar dados.'))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildMetricasGerais(),
                          const SizedBox(height: 16),
                          _buildDistribuicaoStatus(),
                          const SizedBox(height: 16),
                          _buildFunilEtapas(),
                          const SizedBox(height: 16),
                          _buildAprovacoesParadas(),
                          const SizedBox(height: 16),
                          _buildReparosProlongados(),
                          const SizedBox(height: 16),
                          _buildFuncionarios(),
                          const SizedBox(height: 16),
                          _buildClientesRisco(),
                          const SizedBox(height: 16),
                          _buildContratosProximos(),
                          const SizedBox(height: 16),
                          _buildSinistrosEmAtraso(),
                          const SizedBox(height: 16),
                          _buildNpsSection(),
                          const SizedBox(height: 16),
                          _buildNpsCard(),
                          const SizedBox(height: 16),
                          _buildTempoMedioCard(),
                          const SizedBox(height: 16),
                          _buildAssistenciasPorRamoChart(),
                          const SizedBox(height: 16),
                          _buildSinistroVsAssistenciaChart(),
                          const SizedBox(height: 16),
                          _buildSinistrosPorRamoChart(),
                          const SizedBox(height: 16),
                          _buildSinistrosPorHorarioChart(),
                          const SizedBox(height: 16),
                          _buildSinistrosPorDiaChart(),
                          const SizedBox(height: 16),
                          _buildEnvolvimentoTerceirosCard(),
                          const SizedBox(height: 16),
                          _buildNpsAnualChart(),
                          const SizedBox(height: 16),
                          _buildSinistrosAnualChart(),
                          const SizedBox(height: 16),
                          _buildAssistenciasAnualChart(),
                          const SizedBox(height: 16),
                          _buildSinistralidadeAnualChart(),
                          const SizedBox(height: 16),
                          _buildContratosAnualChart(),
                          const SizedBox(height: 16),
                          _buildValorApolicesAnualChart(),
                          const SizedBox(height: 16),
                          const SizedBox(height: 16),
                          _buildSlaComplianceSinistrosAnualChart(),
                          const SizedBox(height: 16),
                          _buildSlaComplianceAssistenciasAnualChart(),
                          const SizedBox(height: 16),
                          _buildTicketMedioAnualChart(),
                          const SizedBox(height: 16),
                          _buildTaxaRetencaoAnualChart(),
                          const SizedBox(height: 16),
                          _buildAssistenciasSection(),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
            ),
    );
  }

  // ── NPS Section ────────────────────────────────────────────────────────────
  Widget _buildNpsSection() {
    if (_npsNotas.isEmpty) return const SizedBox.shrink();

    final total = _npsNotas.length;
    final promotores = _npsNotas.where((n) => n >= 9).length;
    final neutros = _npsNotas.where((n) => n >= 7 && n <= 8).length;
    final detratores = _npsNotas.where((n) => n <= 6).length;
    final score = total > 0
        ? ((promotores - detratores) / total * 100).round()
        : 0;
    final media = total > 0
        ? _npsNotas.reduce((a, b) => a + b) / total
        : 0.0;

    final scoreColor = score >= 50
        ? _C.green
        : score >= 0
            ? _C.amber
            : _C.red;

    return _Section(
      title: 'NPS — Satisfação dos Clientes',
      subtitle: '$total avaliações coletadas',
      icon: Icons.star_half_outlined,
      color: const Color(0xFF6A1B9A),
      child: Column(
        children: [
          // Score principal
          Row(
            children: [
              // Score NPS
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scoreColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Text('Score NPS',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        score >= 0 ? '+$score' : '$score',
                        style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: scoreColor),
                      ),
                      Text(
                        score >= 70
                            ? 'Excelente'
                            : score >= 50
                                ? 'Muito Bom'
                                : score >= 0
                                    ? 'Bom'
                                    : 'Precisa melhorar',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: scoreColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Média + breakdown
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Média das notas', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text(media.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildNpsBar('Promotores (9–10)', promotores, total, _C.green),
                    _buildNpsBar('Neutros (7–8)', neutros, total, _C.amber),
                    _buildNpsBar('Detratores (0–6)', detratores, total, _C.red),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNpsBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Stack(children: [
              Container(height: 6,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(3))),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(height: 6,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(3))),
              ),
            ]),
          ),
          const SizedBox(width: 6),
          Text('$count (${(pct * 100).toStringAsFixed(0)}%)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  // ── Assistências Section ──────────────────────────────────────────────────
  Widget _buildAssistenciasSection() {
    if (_assistencias.isEmpty) return const SizedBox.shrink();

    final veiculares = _assistencias
        .where((a) => a.tipoAssistencia != 'residencial')
        .toList();
    final residenciais = _assistencias
        .where((a) => a.tipoAssistencia == 'residencial')
        .toList();

    // SLA stats
    final agora = DateTime.now();
    final comSla = _assistencias.where((a) => a.slaPrevisto != null || a.slaAtendimento != null).toList();
    final noPrazo = comSla.where((a) {
      final sla = a.slaAtendimento ?? a.slaPrevisto;
      return sla != null && sla.isAfter(agora);
    }).length;
    final vencidas = comSla.length - noPrazo;
    final taxaSla = comSla.isEmpty ? 0 : ((noPrazo / comSla.length) * 100).round();

    // Tipos mais frequentes
    final tiposMap = <String, int>{};
    for (final a in _assistencias) {
      final label = _getTipoLabel(a.tipoAssistencia);
      tiposMap[label] = (tiposMap[label] ?? 0) + 1;
    }
    final tiposOrdenados = tiposMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTipo = tiposOrdenados.isNotEmpty ? tiposOrdenados.first.value : 1;

    return _Section(
      title: 'Assistências — Análise Completa',
      subtitle: '${_assistencias.length} registros · Veiculares: ${veiculares.length} · Residenciais: ${residenciais.length}',
      icon: Icons.car_repair,
      color: Colors.orange,
      child: Column(
        children: [
          // KPI grid
          LayoutBuilder(builder: (ctx, c) {
            final cols = c.maxWidth > 600 ? 4 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 80,
              ),
              itemCount: 4,
              itemBuilder: (_, i) => [
                _MetricCard(label: 'Total Assistências', value: '${_assistencias.length}',
                    icon: Icons.handshake_outlined, color: Colors.orange),
                _MetricCard(label: 'Veiculares', value: '${veiculares.length}',
                    icon: Icons.directions_car_outlined, color: _C.blue),
                _MetricCard(label: 'Residenciais', value: '${residenciais.length}',
                    icon: Icons.home_outlined, color: _C.teal),
                _MetricCard(
                    label: 'SLA Cumprido',
                    value: '$taxaSla%',
                    icon: Icons.timer_outlined,
                    color: taxaSla >= 80 ? _C.green : taxaSla >= 60 ? _C.amber : _C.red,
                    subtitle: '$noPrazo no prazo · $vencidas vencidas'),
              ][i],
            );
          }),

          const SizedBox(height: 16),

          // Breakdown veicular/residencial
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra proporcional
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Distribuição por modalidade',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 20,
                        child: Row(children: [
                          if (_assistencias.isNotEmpty) ...[
                            Flexible(
                              flex: veiculares.length,
                              child: Container(color: _C.blue,
                                  child: Center(child: Text(
                                    '${((veiculares.length / _assistencias.length) * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ))),
                            ),
                            if (residenciais.isNotEmpty)
                              Flexible(
                                flex: residenciais.isNotEmpty ? residenciais.length : 1,
                                child: Container(color: _C.teal,
                                    child: Center(child: Text(
                                      '${((residenciais.length / _assistencias.length) * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ))),
                              ),
                          ],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      Container(width: 10, height: 10, color: _C.blue),
                      const SizedBox(width: 4),
                      Text('Veicular', style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 12),
                      Container(width: 10, height: 10, color: _C.teal),
                      const SizedBox(width: 4),
                      Text('Residencial', style: const TextStyle(fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tipos mais frequentes
          Text('Tipos mais solicitados',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          ...tiposOrdenados.take(6).map((e) {
            final pct = e.value / maxTipo;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                SizedBox(width: 130,
                    child: Text(e.key, style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                Expanded(child: Stack(children: [
                  Container(height: 8, decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4))),
                  FractionallySizedBox(
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: Container(height: 8, decoration: BoxDecoration(
                        color: Colors.orange.shade400,
                        borderRadius: BorderRadius.circular(4))),
                  ),
                ])),
                const SizedBox(width: 8),
                Text('${e.value}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600)),
              ]),
            );
          }),

          const SizedBox(height: 16),

          // Sub-tabs nível operacional/tático/estratégico (existente)
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(children: [
                  _buildSubTab('Operacional', 0),
                  _buildSubTab('Tático', 1),
                  _buildSubTab('Estratégico', 2),
                ]),
                Divider(height: 1, color: Colors.grey.shade200),
                if (_selectedAssistLevel == 0)
                  _buildOperationalLevel()
                else if (_selectedAssistLevel == 1)
                  _buildTacticalLevel()
                else
                  _buildStrategicLevel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header com filtro de período e botão PDF ───────────────────────────────
  Widget _buildHeader() {
    final periodos = [
      'Últimos 7 dias',
      'Últimos 30 dias',
      'Mês corrente',
      'Este ano',
      'Por período',
    ];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Relatórios',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E))),
              if (_dataInicio != null && _dataFim != null)
                Text(
                  '${_fmtDate.format(_dataInicio!)} → ${_fmtDate.format(_dataFim!)}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        // Seletor de período
        // Seletor de período com 3 abas
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200, width: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Abas
              Row(
                children: [
                  _buildAbaButton('Mês Atual', () {
                    setState(() => _setPeriodo('Mês Atual'));
                    _load();
                  }, _periodoSelecionado == 'Mês Atual'),
                  const SizedBox(width: 8),
                  _buildAbaButton('Por Mês', () {
                    // Vai abrir seletor de mês
                    _showMesPicker();
                  }, _periodoSelecionado == 'Por mês'),
                  const SizedBox(width: 8),
                  _buildAbaButton('Acumulado do Ano', () {
                    setState(() => _setPeriodo('Acumulado do Ano'));
                    _load();
                  }, _periodoSelecionado == 'Acumulado do Ano'),
                  const SizedBox(width: 8),
                  _buildAbaButton('Por Período', () {
                    _pickPeriodoCustomizado();
                  }, _periodoSelecionado == 'Por período'),
                ],
              ),
              const SizedBox(height: 12),
              // Exibe a seleção atual
              Text(
                'Período: ${_fmtDate.format(_dataInicio!)} a ${_fmtDate.format(_dataFim!)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Botão PDF
        FilledButton.icon(
          onPressed: _isExporting ? null : _exportarPdf,
          icon: _isExporting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: Text(_isExporting ? 'Gerando...' : 'Exportar PDF'),
          style: FilledButton.styleFrom(
            backgroundColor: _C.red,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ── Métricas gerais ────────────────────────────────────────────────────────
    Widget _buildMetricasGerais() {
    final d = _data!;
    final sinColor = d.sinistralidade > 75
        ? _C.red
        : d.sinistralidade > 50
            ? _C.amber
            : _C.green;
 
    final cards = [
      _MetricCard(
        label: 'Total de sinistros',
        value: d.totalSinistros.toString(),
        icon: Icons.assignment_outlined,
        color: _C.blue,
      ),
      _MetricCard(
        label: 'Valor total sinistros',
        value: _fmtCurrency.format(d.valorTotalSinistros),
        icon: Icons.monetization_on_outlined,
        color: _C.purple,
        valueSmall: true,
      ),
      _MetricCard(
        label: 'Sinistralidade',
        value: '${d.sinistralidade.toStringAsFixed(1)}%',
        icon: Icons.percent_outlined,
        color: sinColor,
        subtitle: d.sinistralidade > 75
            ? 'Acima do limite'
            : d.sinistralidade > 50
                ? 'Atenção'
                : 'Saudável',
      ),
      _MetricCard(
        label: 'Tempo médio resolução',
        value: '${d.tempoMedioResolucao.toStringAsFixed(1)} dias',
        icon: Icons.timer_outlined,
        color: _C.teal,
      ),
    ];
 
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 700 ? 4 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 90,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) => cards[i],
      );
    });
  }

  // ── Sinistros em atraso ────────────────────────────────────────────────────

  // ── Aprovações travadas (> 3 dias) ────────────────────────────────────────
  Widget _buildAprovacoesParadas() {
    final d = _data!;
    if (d.aprovacoesParadas.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Aprovações travadas',
      subtitle: 'Aguardando aprovação há mais de 3 dias — inércia interna',
      color: _C.amber,
      icon: Icons.pending_actions_outlined,
      child: Column(
        children: d.aprovacoesParadas.map((a) {
          final urgencia = a.diasSemMovimentacao > 10
              ? _C.red
              : a.diasSemMovimentacao > 5
                  ? _C.amber
                  : Colors.orange.shade400;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: urgencia.withOpacity(0.05),
              border: Border.all(color: urgencia.withOpacity(0.2), width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: urgencia.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${a.diasSemMovimentacao}d',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: urgencia),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.claim.clientNome,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${a.claim.numeroSinistro} · ${a.claim.seguradora.isNotEmpty ? a.claim.seguradora : "—"}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtDate.format(a.claim.dataOcorrencia),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Reparos prolongados (> 7 dias) ────────────────────────────────────────
  Widget _buildReparosProlongados() {
    final d = _data!;
    if (d.reparosProlongados.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Veículos em manutenção prolongada',
      subtitle: 'Reparo em andamento há mais de 7 dias — risco de pressão por carro reserva',
      color: _C.blue,
      icon: Icons.build_circle_outlined,
      child: Column(
        children: d.reparosProlongados.map((a) {
          // Cor sobe com o tempo: 7-14d = azul, 14-21d = laranja, >21d = vermelho
          final urgencia = a.diasSemMovimentacao > 21
              ? _C.red
              : a.diasSemMovimentacao > 14
                  ? _C.amber
                  : _C.blue;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: urgencia.withOpacity(0.05),
              border: Border.all(color: urgencia.withOpacity(0.2), width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: urgencia.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${a.diasSemMovimentacao}d',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: urgencia),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.claim.clientNome,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${a.claim.numeroSinistro} · ${_ramoInfo(a.claim)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                // Alerta visual se > 14 dias (carro reserva provavelmente vencido)
                if (a.diasSemMovimentacao > 14)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: urgencia.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Reserva em risco',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: urgencia),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  _fmtDate.format(a.claim.dataOcorrencia),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSinistrosEmAtraso() {
    final d = _data!;
    if (d.emAtraso.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Demais sinistros parados',
      subtitle: 'Outros status sem movimentação há 7 dias ou mais (Aprovações e Reparos listados acima)',
      color: _C.gray,
      icon: Icons.hourglass_empty_outlined,
      child: Column(
        children: d.emAtraso.take(20).map((a) {
          final urgencia = a.diasSemMovimentacao > 30
              ? _C.red
              : a.diasSemMovimentacao > 14
                  ? _C.amber
                  : Colors.orange.shade400;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: urgencia.withOpacity(0.05),
              border: Border.all(
                  color: urgencia.withOpacity(0.2), width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: urgencia.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${a.diasSemMovimentacao}d',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: urgencia),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.claim.clientNome,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${a.claim.numeroSinistro} · ${a.claim.statusAtual}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtDate.format(a.claim.dataOcorrencia),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Distribuição por status ────────────────────────────────────────────────
  Widget _buildDistribuicaoStatus() {
    final d = _data!;
    if (d.porStatus.isEmpty) return const SizedBox.shrink();

    final statusColors = {
      'Rascunho':               Colors.grey.shade400,
      'Aberto':                 _C.red,
      'Vistoria em Andamento':  Colors.orange.shade400,
      'Aguardando Aprovação':   Colors.yellow.shade700,
      'Aguardando Peças':       Colors.blueGrey.shade400,
      'Reparo em Andamento':    _C.blue,
      'Concluído':              _C.green,
    };

    return _Section(
      title: 'Distribuição por status',
      icon: Icons.donut_large_outlined,
      color: _C.blue,
      child: Column(
        children: d.porStatus.entries
            .sorted((a, b) => b.value.compareTo(a.value))
            .map((e) {
          final pct = d.totalSinistros > 0
              ? e.value / d.totalSinistros
              : 0.0;
          final color = statusColors[e.key] ?? Colors.grey;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(e.key,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: pct.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${e.value} (${(pct * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Funil de etapas ────────────────────────────────────────────────────────
  Widget _buildFunilEtapas() {
    final d = _data!;
    if (d.tempoMedioEtapa.isEmpty) return const SizedBox.shrink();

    final sorted = d.tempoMedioEtapa.entries
        .sorted((a, b) => b.value.compareTo(a.value));
    final maxDias = sorted.first.value;

    return _Section(
      title: 'Gargalos do processo',
      subtitle: 'Tempo médio em cada transição de status (dias)',
      icon: Icons.hourglass_bottom_outlined,
      color: _C.amber,
      child: Column(
        children: sorted.map((e) {
          final frac = maxDias > 0 ? e.value / maxDias : 0.0;
          final color = e.value > 7
              ? _C.red
              : e.value > 3
                  ? _C.amber
                  : _C.green;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${e.value.toStringAsFixed(1)} dias',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Stack(children: [
                  Container(
                      height: 6,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(3))),
                  FractionallySizedBox(
                    widthFactor: frac.clamp(0.0, 1.0),
                    child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3))),
                  ),
                ]),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Funcionários ────────────────────────────────────────────────────────────
  Widget _buildFuncionarios() {
    final d = _data!;
    if (d.porFuncionario.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Desempenho por funcionário',
      icon: Icons.people_outline,
      color: _C.purple,
      child: Column(
        children: d.porFuncionario.entries
            .sorted((a, b) => b.value.compareTo(a.value))
            .map((e) {
          final nome = e.key.split('@').first;
          final tempoMedio = d.tempoMedioFuncionario[e.key];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                  color: Colors.grey.shade200, width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _C.purple.withOpacity(0.1),
                  child: Text(
                    nome[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _C.purple),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      if (tempoMedio != null)
                        Text(
                          'Tempo médio: ${tempoMedio.toStringAsFixed(1)} dias',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${e.value} sinistros',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.purple),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Clientes em risco ──────────────────────────────────────────────────────
  Widget _buildClientesRisco() {
    final d = _data!;
    if (d.clientesAltoRisco.isEmpty) return const SizedBox.shrink();

    return _Section(
      title: 'Clientes com sinistralidade elevada',
      subtitle: 'Sinistros acumulados acima de 60% do prêmio — atenção na renovação',
      icon: Icons.flag_outlined,
      color: _C.amber,
      child: Column(
        children: d.clientesAltoRisco.map((r) {
          final color = r.sinistralidade > 90
              ? _C.red
              : r.sinistralidade > 75
                  ? _C.amber
                  : Colors.orange.shade400;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.04),
              border: Border.all(
                  color: color.withOpacity(0.2), width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.client.nome,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        'Total sinistros: ${_fmtCurrency.format(r.totalSinistros)} · Apólices: ${_fmtCurrency.format(r.client.valorTotalApolicesAtivas)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${r.sinistralidade.toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Contratos próximos ─────────────────────────────────────────────────────
  Widget _buildContratosProximos() {
    final d = _data!;
    if (d.contratosProximos.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();

    return _Section(
      title: 'Contratos próximos do vencimento',
      subtitle: 'Vencendo nos próximos 30 dias',
      icon: Icons.event_outlined,
      color: _C.teal,
      child: Column(
        children: d.contratosProximos.map((c) {
            final apoliceProxVencer = c.apolices.reduce((a, b) => 
              a.dataFim.isBefore(b.dataFim) ? a : b
            );
            final dias = apoliceProxVencer.dataFim.difference(now).inDays;
          final vencido = dias < 0;
          final color = vencido
              ? _C.red
              : dias <= 7
                  ? _C.amber
                  : _C.teal;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                  color: Colors.grey.shade200, width: 0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nome,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        'Vencimento: ${_fmtDate.format(apoliceProxVencer.dataFim)} · ${_fmtCurrency.format(apoliceProxVencer.valorApolice)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    vencido
                        ? 'Vencido há ${(-dias)} dias'
                        : '$dias dias',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ASSISTÊNCIAS: SWOT Analysis em 3 Níveis
  // ───────────────────────────────────────────────────────────────────────────

  /// Operacional: Tempo real
  Map<String, dynamic> _getOperationalMetrics() {
    final now = DateTime.now();
    final assistenciasAbertas = _assistencias
        .where((a) => a.statusAtual == 'Aberto' || a.statusAtual == 'Em Andamento')
        .toList();

    // Tempo médio de resposta
    double tempoMedioMinutos = 0;
    if (assistenciasAbertas.isNotEmpty) {
      final totalMinutos = assistenciasAbertas.fold<double>(0, (sum, a) {
        if (a.slaPrevisto != null) {
          final minutos = a.slaPrevisto!.difference(a.dataAbertura).inMinutes;
          return sum + minutos;
        }
        return sum;
      });
      tempoMedioMinutos = totalMinutos / assistenciasAbertas.length;
    }

    // SLA cumprido vs excedido (últimas 24h)
    final assistenciasUltimas24h = _assistencias
        .where((a) => now.difference(a.dataAbertura).inHours <= 24)
        .toList();
    
    int slaCumprido = 0;
    int slaExcedido = 0;
    for (var a in assistenciasUltimas24h) {
      if (a.slaPrevisto != null) {
        if (a.slaPrevisto!.isAfter(now)) {
          slaCumprido++;
        } else {
          slaExcedido++;
        }
      }
    }
    
    double slaCumpridoPercent = assistenciasUltimas24h.isEmpty
        ? 0
        : (slaCumprido / assistenciasUltimas24h.length) * 100;

    // Distribuição por status
    final statusMap = <String, int>{};
    for (var a in _assistencias) {
      statusMap[a.statusAtual] = (statusMap[a.statusAtual] ?? 0) + 1;
    }

    // Top 5 tipos mais frequentes (hoje)
    final assistenciasHoje = _assistencias
        .where((a) => now.difference(a.dataAbertura).inDays == 0)
        .toList();
    
    final tiposMap = <String, int>{};
    for (var a in assistenciasHoje) {
      final tipo = _getTipoLabel(a.tipoAssistencia);
      tiposMap[tipo] = (tiposMap[tipo] ?? 0) + 1;
    }
    final top5Tipos = tiposMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    // Alertas SLA (as que excederam nas últimas 24h)
    final alertasSLA = assistenciasUltimas24h
        .where((a) => a.slaPrevisto != null && a.slaPrevisto!.isBefore(now))
        .toList();

    return {
      'abertas': assistenciasAbertas.length,
      'tempoMedio': tempoMedioMinutos.round(),
      'slaCompliance': slaCumpridoPercent.round(),
      'distribuicaoStatus': statusMap,
      'top5Tipos': top5Tipos.take(5).toList(),
      'alertasSLA': alertasSLA,
      'totalUltimas24h': assistenciasUltimas24h.length,
    };
  }

  /// Tático: Tendências (últimos 30 dias)
  Map<String, dynamic> _getTacticalMetrics() {
    final now = DateTime.now();
    final inicio30dias = now.subtract(const Duration(days: 30));

    final assistencias30dias = _assistencias
        .where((a) => a.dataAbertura.isAfter(inicio30dias))
        .toList();

    // Tempo médio por tipo
    final temposPorTipo = <String, List<int>>{};
    for (var a in assistencias30dias) {
      final tipo = _getTipoLabel(a.tipoAssistencia);
      final minutos = a.slaPrevisto != null
          ? a.slaPrevisto!.difference(a.dataAbertura).inMinutes
          : 0;
      if (!temposPorTipo.containsKey(tipo)) {
        temposPorTipo[tipo] = [];
      }
      temposPorTipo[tipo]!.add(minutos);
    }

    final mediasPorTipo = temposPorTipo.map((tipo, valores) {
      final media = valores.isEmpty
          ? 0
          : (valores.reduce((a, b) => a + b) / valores.length).round();
      return MapEntry(tipo, media);
    });

    // Taxa de resolução
    final concluidas = assistencias30dias
        .where((a) => a.statusAtual == 'Concluído')
        .length;
    final taxaResolucao = assistencias30dias.isEmpty
        ? 0
        : ((concluidas / assistencias30dias.length) * 100).round();

    // Ranking de clientes
    final clientesMap = <String, int>{};
    for (var a in assistencias30dias) {
      clientesMap[a.clientNome] = (clientesMap[a.clientNome] ?? 0) + 1;
    }
    final rankingClientes = clientesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'mediaTemposPorTipo': mediasPorTipo,
      'taxaResolucao': taxaResolucao,
      'rankingClientes': rankingClientes.take(10).toList(),
      'assistenciasVolume': assistencias30dias.length,
      'periodo': '${DateFormat('dd/MM').format(inicio30dias)} - ${DateFormat('dd/MM').format(now)}',
    };
  }

  /// Estratégico: SWOT Analysis (últimos 12 meses)
  Map<String, dynamic> _getStrategicMetrics() {
    final now = DateTime.now();
    final inicio12meses = now.subtract(const Duration(days: 365));

    final assistencias12m = _assistencias
        .where((a) => a.dataAbertura.isAfter(inicio12meses))
        .toList();

    // Strengths: SLA cumprido %
    int slaCumprido = 0;
    for (var a in assistencias12m) {
      if (a.slaPrevisto != null && a.slaPrevisto!.isAfter(now)) {
        slaCumprido++;
      }
    }
    final slaCumpridoPercent = assistencias12m.isEmpty
        ? 0
        : ((slaCumprido / assistencias12m.length) * 100).round();

    // Weaknesses: SLA excedido %
    final slaExcedidoPercent = 100 - slaCumpridoPercent;

    // Taxa de reincidência
    final clientesComMult = <String, int>{};
    for (var a in assistencias12m) {
      clientesComMult[a.clientNome] = (clientesComMult[a.clientNome] ?? 0) + 1;
    }
    final reincidentes = clientesComMult.values
        .where((count) => count > 1)
        .length;
    final taxaReincidencia = assistencias12m.isEmpty
        ? 0
        : ((reincidentes / clientesComMult.length) * 100).round();

    // Distribuição por tipo
    final tipos12m = <String, int>{};
    for (var a in assistencias12m) {
      final tipo = _getTipoLabel(a.tipoAssistencia);
      tipos12m[tipo] = (tipos12m[tipo] ?? 0) + 1;
    }

    return {
      'slaCumpridoPercent': slaCumpridoPercent,
      'slaExcedidoPercent': slaExcedidoPercent,
      'taxaReincidencia': taxaReincidencia,
      'tiposDistribuicao': tipos12m,
      'totalAssistencias12m': assistencias12m.length,
      'clientesUnicos': clientesComMult.length,
      'periodo': '${DateFormat('dd/MM/yyyy').format(inicio12meses)} - ${DateFormat('dd/MM/yyyy').format(now)}',
    };
  }

  /// Helper: Converter tipo para label legível
  String _getTipoLabel(String? tipo) {
    const map = {
      'guincho': 'Guincho',
      'vidro': 'Vidro Quebrado',
      'vidro_quebrado': 'Vidro Quebrado',
      'combustivel': 'Combustível',
      'combustível': 'Combustível',
      'pane_eletrica': 'Pane Elétrica',
      'pane_elétrica': 'Pane Elétrica',
      'carga_bateria': 'Carga de Bateria',
      'falta': 'Falta de Peça',
      'falta_de_peça': 'Falta de Peça',
      'reboque': 'Reboque',
      'outro': 'Outro',
    };
    return map[tipo] ?? 'Outro';
  }

Widget _buildSubTab(String label, int index) {
  final isActive = _selectedAssistLevel == index;
  return Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _selectedAssistLevel = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _C.teal : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? _C.teal : Colors.grey,
          ),
        ),
      ),
    ),
  );
}

Widget _buildOperationalLevel() {
  final metrics = _getOperationalMetrics();

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPIs
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKpiCard(
                'Assistências Abertas',
                '${metrics['abertas']}',
                Icons.open_in_new,
                _C.blue,
              ),
              _buildKpiCard(
                'Tempo Médio',
                '${metrics['tempoMedio']}min',
                Icons.timer,
                _C.amber,
              ),
              _buildKpiCard(
                'SLA Cumprido',
                '${metrics['slaCompliance']}%',
                Icons.check_circle,
                _C.green,
              ),
              _buildKpiCard(
                'Total 24h',
                '${metrics['totalUltimas24h']}',
                Icons.history,
                _C.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Distribuição por status
          Text(
            'Distribuição por Status',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...(metrics['distribuicaoStatus'] as Map<String, int>).entries.map(
            (e) => _buildStatusBar(e.key, e.value, metrics['totalUltimas24h']),
          ),
          const SizedBox(height: 24),

          // Top 5 tipos
          if ((metrics['top5Tipos'] as List).isNotEmpty) ...[
            Text(
              'Top 5 Tipos (Hoje)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...(metrics['top5Tipos'] as List).map(
              (e) => _buildTopTypeRow(e.key, e.value),
            ),
            const SizedBox(height: 24),
          ],

          // Alertas SLA
          if ((metrics['alertasSLA'] as List).isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.red),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: _C.red, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Alertas SLA (${(metrics['alertasSLA'] as List).length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _C.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(metrics['alertasSLA'] as List<Claim>).take(5).map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${a.numeroSinistro} - ${a.clientNome}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildTacticalLevel() {
  final metrics = _getTacticalMetrics();

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Período: ${metrics['periodo']}', 
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // KPIs tático
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKpiCard(
                'Assistências 30d',
                '${metrics['assistenciasVolume']}',
                Icons.trending_up,
                _C.teal,
              ),
              _buildKpiCard(
                'Taxa Resolução',
                '${metrics['taxaResolucao']}%',
                Icons.done_all,
                _C.green,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tempo médio por tipo
          Text(
            'Tempo Médio por Tipo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...(metrics['mediaTemposPorTipo'] as Map<String, int>).entries.map(
            (e) => _buildTypePerformanceBar(e.key, e.value),
          ),
          const SizedBox(height: 24),

          // Ranking de clientes
          Text(
            'Top 10 Clientes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...(metrics['rankingClientes'] as List).map(
            (e) => _buildRankingRow(e.key, e.value),
          ),
        ],
      ),
    ),
  );
}

Widget _buildStrategicLevel() {
  final metrics = _getStrategicMetrics();

  return SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Período: ${metrics['periodo']}', 
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),

          // KPIs estratégico
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKpiCard(
                'SLA Cumprido',
                '${metrics['slaCumpridoPercent']}%',
                Icons.check_circle,
                _C.green,
              ),
              _buildKpiCard(
                'SLA Excedido',
                '${metrics['slaExcedidoPercent']}%',
                Icons.cancel,
                _C.red,
              ),
              _buildKpiCard(
                'Taxa Reincidência',
                '${metrics['taxaReincidencia']}%',
                Icons.person_add,
                Colors.orange,
              ),
              _buildKpiCard(
                'Total 12m',
                '${metrics['totalAssistencias12m']}',
                Icons.calendar_month,
                _C.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SWOT Text
          Text(
            'Análise SWOT',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _buildSwotBox(
            'Forças (Strengths)',
            'SLA cumprido em ${metrics['slaCumpridoPercent']}% dos casos.',
            _C.green,
          ),
          _buildSwotBox(
            'Fraquezas (Weaknesses)',
            'SLA excedido em ${metrics['slaExcedidoPercent']}% dos casos. Taxa de reincidência: ${metrics['taxaReincidencia']}%',
            _C.red,
          ),
          _buildSwotBox(
            'Oportunidades (Opportunities)',
            'Crescimento em tipos com melhor performance. ${metrics['clientesUnicos']} clientes únicos para expansão.',
            _C.amber,
          ),
          _buildSwotBox(
            'Ameaças (Threats)',
            'Tipos com SLA fraco podem levar à perda de clientes. Monitorar sazonalidade.',
            _C.purple,
          ),
          const SizedBox(height: 24),

          // Distribuição de tipos
          Text(
            'Distribuição por Tipo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          ...(metrics['tiposDistribuicao'] as Map<String, int>).entries.map(
            (e) => _buildTypeDistributionBar(e.key, e.value, metrics['totalAssistencias12m']),
          ),
        ],
      ),
    ),
  );
}

  // ─── Componentes reutilizáveis ───
  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String status, int count, int total) {
    final percentage = total == 0 ? 0 : (count / total * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(status, style: const TextStyle(fontSize: 13)),
              Text('$count ($percentage%)', 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                status == 'Concluído' ? _C.green : _C.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTypeRow(String tipo, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(tipo, style: const TextStyle(fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _C.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePerformanceBar(String tipo, int minutos) {
    final color = minutos <= 30 ? _C.green : minutos <= 60 ? _C.amber : _C.red;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(tipo, style: const TextStyle(fontSize: 13)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${minutos}min',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingRow(String cliente, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              cliente,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _C.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _C.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwotBox(String titulo, String conteudo, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              conteudo,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDistributionBar(String tipo, int count, int total) {
    final percentage = total == 0 ? 0 : (count / total * 100);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tipo, style: const TextStyle(fontSize: 13)),
              Text('$count (${percentage.toStringAsFixed(1)}%)', 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(_C.teal),
            ),
          ),
        ],
      ),
    );
  }

  // Helper para label dos Tipos
  String _getTipoAssistenciaLabel(String tipo) {
    return TipoAssistencia.fromString(tipo).label;
  }

  // Helper para formatação dos gráficos
  String _formatarValorTooltip(double valor, String tipo) {
    switch(tipo) {
      case 'nps':
        return valor.toStringAsFixed(1);
      case 'contador':
        return valor.toInt().toString();
      case 'percentual':
        return valor.toStringAsFixed(1);
      case 'moeda':
        return 'R\$ ${(valor / 1000).toStringAsFixed(1)}k';
      default:
        return valor.toString();
    }
  }

}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.valueSmall = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final bool valueSmall;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSmall ? 14 : 18,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 0.8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border:
                  Border(left: BorderSide(color: color, width: 4)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ]),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
              padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }

  // ─── Widgets de UI para Assistências ───────────────────────────────────────
  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(String status, int count, int total) {
    final percentage = total == 0 ? 0 : (count / total * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(status, style: const TextStyle(fontSize: 13)),
              Text('$count ($percentage%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                status == 'Concluído' ? _C.green : _C.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwotBox(String titulo, String conteudo, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              conteudo,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}