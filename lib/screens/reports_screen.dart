// screens/reports_screen.dart
// ignore_for_file: unused_import, deprecated_member_use

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:upgrade_seguros/services/pdf_report_service.dart';
import '../models/report_data.dart';
import 'package:upgrade_seguros/widgets/top_clients_widgets.dart';
import 'package:upgrade_seguros/widgets/employees_performance_widgets.dart';

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

// ─── Tela principal ───────────────────────────────────────────────────────────
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _firestoreService = FirestoreService();

  ReportData? _data;
  bool _isLoading = true;
  String _periodoSelecionado = 'Últimos 30 dias';
  DateTime? _dataInicio;
  DateTime? _dataFim;
  String _meselecionado = '${DateTime.now().month}'; // 1-12
  bool _isExporting = false;

  final _fmtCurrency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _fmtDate    = DateFormat('dd/MM/yyyy');
  List<Claim> _filteredAssistencias = [];

  List<Claim> _assistencias = [];
  List<double> _npsNotas = [];
  int _selectedAssistLevel = 0;
  late final pw.Font _emojiFont;
  final GlobalKey _pizzaChartKey = GlobalKey();
  final GlobalKey _sinistrosSectionKey = GlobalKey();
  Map<int, int> contratosAtivosPoMes = {};

  Map<String, String> _funcionarioNomes = {};
  Map<String, String> _funcionarioIdNomes = {};

  List<Claim> _sinistros = [];
  List<Client> _allClients = [];

  @override
  void initState() {
    super.initState();
    _setPeriodo('Mês Atual');
    
    if (_dataInicio == null || _dataFim == null) {
      final now = DateTime.now();
      _dataInicio = DateTime(now.year, now.month, 1);
      _dataFim = now;
    }
    
    _load().then((_) {

    });
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

  Future<void> _carregarNomesFuncionarios() async {
    try {
      final users = await _firestoreService.getFuncionarios();
      for (final doc in users) {
        final data = doc.data() as Map<String, dynamic>;
        final email = data['email'] as String?;
        final nome = data['nome'] as String?;
        final id = doc.id;
        if (email != null && email.isNotEmpty) {
          _funcionarioNomes[email] = nome ?? email;
        }
        if (id.isNotEmpty) {
          _funcionarioIdNomes[id] = nome ?? email ?? 'Sem nome';
        }
      }
    } catch (e) {
      print('Erro ao carregar nomes dos funcionários: $e');
    }
  }

  // --- CAPTURAR O WIDGET DE GRÁFICO COMO IMAGEM ---
Future<Uint8List> _capturarWidget(GlobalKey key, {double width = 700, double height = 400}) async {
    final RenderRepaintBoundary? boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw Exception('Widget não encontrado para captura');
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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
      final allClaims = await _firestoreService.getAllClaims();
      final allClients = await _firestoreService.getAllClients();
      final now = DateTime.now();

      // Carregar funcionários para mapear ID -> Nome
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      _funcionarioNomes = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        final nome = data['nome'] as String?;
        if (nome != null && nome.isNotEmpty) {
          _funcionarioNomes[id] = nome;
        }
      }

      // ── LISTA COMPLETA (sem filtro de período) ──
      final todosSinistros = allClaims.where((c) => c.tipo != 'assistencia').toList();

      // ── LISTA COMPLETA DE ASSISTÊNCIAS ──
      final assistenciasSnap = await FirebaseFirestore.instance
          .collection('assistencias')
          .get();
      final todasAssistencias = assistenciasSnap.docs
          .map((doc) => Claim.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      // ── LISTA FILTRADA PELO PERÍODO ──
      final claims = todosSinistros.where((c) {
        if (_dataInicio == null || _dataFim == null) return true;
        return c.dataAbertura.isAfter(_dataInicio!) &&
            c.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
      }).toList();

      final assistenciasFiltradas = todasAssistencias.where((a) {
        if (_dataInicio == null || _dataFim == null) return true;
        return a.dataAbertura.isAfter(_dataInicio!) &&
            a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
      }).toList();

      // ── ARMAZENA NAS VARIÁVEIS DE ESTADO ──
      _sinistros = todosSinistros;
      _assistencias = todasAssistencias;
      _allClients = allClients;

      // ── Sinistralidade por Seguradora ──
      final sinistralidadePorSeguradora = <String, double>{};
      for (var c in claims) {
        if (c.seguradora.isNotEmpty) {
          sinistralidadePorSeguradora[c.seguradora] = 
              (sinistralidadePorSeguradora[c.seguradora] ?? 0) + c.valorTotalSinistro;
        }
      }

      // ── Mix de Carteira ──
      final mixCarteira = <String, double>{};
      for (var client in allClients) {
        for (var apolice in client.apolices) {
          mixCarteira[apolice.ramo] = 
              (mixCarteira[apolice.ramo] ?? 0) + apolice.valorApolice;
        }
      }

      // ── Métricas básicas (usando claims filtrado) ──
      final totalValor = claims.fold(0.0, (s, c) => s + c.valorTotalSinistro);
      final totalApolices = allClients.fold(0.0, (s, c) => s + c.valorTotalApolicesAtivas);
      final sinistralidade = totalApolices > 0 ? (totalValor / totalApolices) * 100 : 0.0;

      // ── Tempo médio de resolução (usando claims filtrado) ──
      final resolvidos = claims.where((c) => c.statusAtual == 'Concluído');
      double somaResolucao = 0;
      int countResolucao = 0;
      for (final c in resolvidos) {
        if (c.historicoStatus.length >= 2) {
          final abertura = _parseDate(c.historicoStatus.first['data']);
          final conclusao = _parseDate(c.historicoStatus.last['data']);
          somaResolucao += conclusao.difference(abertura).inHours / 24.0;
          countResolucao++;
        }
      }
      final tempoMedioResolucao = countResolucao > 0 ? somaResolucao / countResolucao : 0.0;

      // ── NPS (usando filtro de período) ──
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

      // ── Tempo médio sinistros e assistências (filtrados por período) ──
      double tempoMedioSinistros = 0.0;
      double tempoMedioAssistencias = 0.0;

      final sinistrosResolvidos = claims.where((c) => c.statusAtual == 'Concluído').toList();
      if (sinistrosResolvidos.isNotEmpty) {
        double somaSinistros = 0;
        for (final c in sinistrosResolvidos) {
          somaSinistros += c.dataUltimaAtualizacao.difference(c.dataAbertura).inHours / 24.0;
        }
        tempoMedioSinistros = somaSinistros / sinistrosResolvidos.length;
      }

      final assistenciasResolvidas = assistenciasFiltradas.where((a) => a.statusAtual == 'Concluído').toList();
      if (assistenciasResolvidas.isNotEmpty) {
        double somaAssistencias = 0;
        for (final a in assistenciasResolvidas) {
          somaAssistencias += a.dataUltimaAtualizacao.difference(a.dataAbertura).inHours / 24.0;
        }
        tempoMedioAssistencias = somaAssistencias / assistenciasResolvidas.length;
      }

      // ── Assistências por horário ──
      final assistenciasPorHorario = <String, int>{
        'Madrugada (0-6h)': 0,
        'Manhã (6-12h)': 0,
        'Tarde (12-18h)': 0,
        'Noite (18-24h)': 0,
        'Não informado': 0,
      };

      for (final a in assistenciasFiltradas) {
        // Prioridade: data/hora do comunicado retroativo, se existir
        int hora;
        if (a.dataRecebimentoComunicado != null) {
          // Se tiver data específica de comunicado, usa a hora dela
          hora = a.dataRecebimentoComunicado!.hour;
        } else {
          // Fallback: usa a hora da abertura
          hora = a.dataAbertura.hour;
        }
        // (Se houver campo horaRecebimentoComunicado como String, use-o; aqui assumimos dataRecebimentoComunicado como DateTime)

        if (hora >= 0 && hora < 6) {
          assistenciasPorHorario['Madrugada (0-6h)'] = (assistenciasPorHorario['Madrugada (0-6h)'] ?? 0) + 1;
        } else if (hora >= 6 && hora < 12) {
          assistenciasPorHorario['Manhã (6-12h)'] = (assistenciasPorHorario['Manhã (6-12h)'] ?? 0) + 1;
        } else if (hora >= 12 && hora < 18) {
          assistenciasPorHorario['Tarde (12-18h)'] = (assistenciasPorHorario['Tarde (12-18h)'] ?? 0) + 1;
        } else if (hora >= 18 && hora < 24) {
          assistenciasPorHorario['Noite (18-24h)'] = (assistenciasPorHorario['Noite (18-24h)'] ?? 0) + 1;
        } else {
          assistenciasPorHorario['Não informado'] = (assistenciasPorHorario['Não informado'] ?? 0) + 1;
        }
      }

      // ── Assistências por dia da semana ──
      final assistenciasPorDia = <int, int>{
        1: 0, // Segunda
        2: 0, // Terça
        3: 0, // Quarta
        4: 0, // Quinta
        5: 0, // Sexta
        6: 0, // Sábado
        7: 0, // Domingo
      };

      for (final a in assistenciasFiltradas) {
        // Prioridade: data do comunicado retroativo, senão dataAbertura
        final data = a.dataRecebimentoComunicado ?? a.dataAbertura;
        final diaSemana = data.weekday;
        assistenciasPorDia[diaSemana] = (assistenciasPorDia[diaSemana] ?? 0) + 1;
      }

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
      final sinistrosPorHorario = <String, int>{
        'Madrugada (0-6h)': 0,
        'Manhã (6-12h)': 0,
        'Tarde (12-18h)': 0,
        'Noite (18-24h)': 0,
        'Não informado': 0,
      };

      for (final c in claims) {
        int hora;
        if (c.horaOcorrencia != null && c.horaOcorrencia!.isNotEmpty) {
          final parts = c.horaOcorrencia!.split(':');
          hora = int.tryParse(parts[0]) ?? 0;
        } else {
          // Fallback: usa a hora da data de abertura
          hora = c.dataAbertura.hour;
        }
        
        if (hora >= 0 && hora < 6) {
          sinistrosPorHorario['Madrugada (0-6h)'] = (sinistrosPorHorario['Madrugada (0-6h)'] ?? 0) + 1;
        } else if (hora >= 6 && hora < 12) {
          sinistrosPorHorario['Manhã (6-12h)'] = (sinistrosPorHorario['Manhã (6-12h)'] ?? 0) + 1;
        } else if (hora >= 12 && hora < 18) {
          sinistrosPorHorario['Tarde (12-18h)'] = (sinistrosPorHorario['Tarde (12-18h)'] ?? 0) + 1;
        } else if (hora >= 18 && hora < 24) {
          sinistrosPorHorario['Noite (18-24h)'] = (sinistrosPorHorario['Noite (18-24h)'] ?? 0) + 1;
        } else {
          sinistrosPorHorario['Não informado'] = (sinistrosPorHorario['Não informado'] ?? 0) + 1;
        }
      }

      // ── Sinistros por dia da semana ──
      final sinistrosPorDia = <int, int>{
        1: 0, // Segunda
        2: 0, // Terça
        3: 0, // Quarta
        4: 0, // Quinta
        5: 0, // Sexta
        6: 0, // Sábado
        7: 0, // Domingo
      };

      for (final c in claims) {
        final diaSemana = c.dataOcorrencia.weekday;
        sinistrosPorDia[diaSemana] = (sinistrosPorDia[diaSemana] ?? 0) + 1;
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
        final responsavelId = c.responsavelId ?? '';
        final nomeExibido = _funcionarioNomes[responsavelId] ?? 'Sem responsável';
        porFuncionario[nomeExibido] = (porFuncionario[nomeExibido] ?? 0) + 1;

        if (c.statusAtual == 'Concluído' && c.historicoStatus.length >= 2) {
          final abertura = _parseDate(c.historicoStatus.first['data']);
          final conclusao = _parseDate(c.historicoStatus.last['data']);
          final dias = conclusao.difference(abertura).inHours / 24.0;
          temposPorFuncionario.putIfAbsent(nomeExibido, () => []).add(dias);
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
      final aprovacoesParadas = <ClaimAtraso>[];
      for (final c in claims) {
        if (c.statusAtual != 'Aguardando Aprovação') continue;
        final ultima = c.historicoStatus.isNotEmpty
            ? _parseDate(c.historicoStatus.last['data'])
            : c.dataAbertura;
        final dias = now.difference(ultima).inDays;
        if (dias >= 3) aprovacoesParadas.add(ClaimAtraso(c, dias));
      }
      aprovacoesParadas.sort((a, b) =>
          b.diasSemMovimentacao.compareTo(a.diasSemMovimentacao));

      // ── Reparos prolongados (Reparo em Andamento > 7 dias) ───────────────
      final reparosProlongados = <ClaimAtraso>[];
      for (final c in claims) {
        if (c.statusAtual != 'Reparo em Andamento') continue;
        final ultima = c.historicoStatus.isNotEmpty
            ? _parseDate(c.historicoStatus.last['data'])
            : c.dataAbertura;
        final dias = now.difference(ultima).inDays;
        if (dias >= 7) reparosProlongados.add(ClaimAtraso(c, dias));
      }
      reparosProlongados.sort((a, b) =>
          b.diasSemMovimentacao.compareTo(a.diasSemMovimentacao));

      // ── Demais sinistros em atraso (outros status, ≥ 7 dias, excluindo
      final _idsJaListados = {
        ...aprovacoesParadas.map((a) => a.claim.id ?? ''),
        ...reparosProlongados.map((a) => a.claim.id ?? ''),
      };
      final emAtraso = <ClaimAtraso>[];
      for (final c in claims) {
        if (c.statusAtual == 'Concluído') continue;
        if (c.statusAtual == 'Aguardando Aprovação') continue;
        if (c.statusAtual == 'Reparo em Andamento') continue;
        if (_idsJaListados.contains(c.id ?? '')) continue;
        final ultima = c.historicoStatus.isNotEmpty
            ? _parseDate(c.historicoStatus.last['data'])
            : c.dataAbertura;
        final dias = now.difference(ultima).inDays;
        if (dias >= 7) emAtraso.add(ClaimAtraso(c, dias));
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
      final clientesAltoRisco = <ClienteRisco>[];
      for (final client in allClients) {
        final valorApoliceTotal = client.valorTotalApolicesAtivas;  // ← MUDA
        if (valorApoliceTotal <= 0) continue;
        
        final sinistrosCliente = claims.where((c) => c.idCliente == client.id);
        final totalSinistrosCliente = sinistrosCliente.fold(0.0, (s, c) => s + c.valorTotalSinistro);
        final perc = (totalSinistrosCliente / valorApoliceTotal) * 100;
        
        if (perc >= 60) {
          clientesAltoRisco.add(ClienteRisco(client, perc, totalSinistrosCliente));
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

      _filteredAssistencias = allAssistList.where((a) {
        if (_dataInicio == null || _dataFim == null) return true;
        return a.dataAbertura.isAfter(_dataInicio!) &&
            a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
      }).toList();

      final npsCategoria = <String, int>{};
      for (final d in npsAvalSnap.docs) {
        final categoria = d.data()['categoria'] as String? ?? 'desconhecido';
        npsCategoria[categoria] = (npsCategoria[categoria] ?? 0) + 1;
      }

      // ── Sinistros por ramo ─────────────────────────────────────────────────
      final sinistrosPorRamo = <String, int>{};
        for (final c in claims) {
          final ramo = c.ramoSinistro.trim().isNotEmpty ? c.ramoSinistro : 'Não informado';
          sinistrosPorRamo[ramo] = (sinistrosPorRamo[ramo] ?? 0) + 1;
        }

      // ── MÉTRICAS MENSAIS (Um único loop organizado) ─────────────────────────────
      final Map<int, double> npsPoMes = {};
      final Map<int, int> sinistrosPoMes = {};
      final Map<int, int> assistenciasPoMes = {};
      final Map<int, double> sinistralidadePoMes = {};
      final Map<int, Map<String, int>> contratosPoRamoMes = {};
      final Map<int, double> valorApolicesPoMes = {};
      final Map<int, double> slaComplianceSinistrosPoMes = {};
      final Map<int, double> slaComplianceAssistenciasPoMes = {};
      final Map<int, double> ticketMedioPoMes = {};
      final Map<int, double> taxaRetencaoPoMes = {};
      final Map<int, int> contratosAtivosPoMes = {};
      final ativasInicioMes = <int, int>{};

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
          return c.tipo != 'assistencia' && 
                c.dataAbertura.year == now.year && 
                c.dataAbertura.month == mes;
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

        // 5. CONTRATOS ATIVOS MENSAIS + 11. TAXA DE RETENÇÃO
        for (int mes = 1; mes <= 12; mes++) {
          final mesInicio = DateTime(now.year, mes, 1);
          final mesFim = mes == 12
              ? DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1))
              : DateTime(now.year, mes + 1, 1).subtract(const Duration(days: 1));

          if (mesInicio.isAfter(now)) break;

          // Define a data de referência para "ativas no mês"
          final dataReferencia = (mes == now.month && now.year == now.year)
              ? now
              : mesFim;

          // 🔹 Conta apólices ativas na data de referência (para o gráfico de contratos)
          int totalApolicesMes = 0;
          for (var c in allClients) {
            for (var a in c.apolices) {
              if (!a.dataFim.isBefore(dataReferencia) && !a.dataInicio.isAfter(dataReferencia)) {
                totalApolicesMes++;
              }
            }
          }
          contratosAtivosPoMes[mes] = totalApolicesMes;

          // 🔹 Conta apólices ativas no início do mês (para a retenção)
          int ativasInicio = 0;
          for (var c in allClients) {
            for (var a in c.apolices) {
              if (!a.dataFim.isBefore(mesInicio) && !a.dataInicio.isAfter(mesInicio)) {
                ativasInicio++;
              }
            }
          }
          ativasInicioMes[mes] = ativasInicio;

          // 🔹 Conta apólices ativas no final do mês (para a retenção)
          int ativasFim = 0;
          for (var c in allClients) {
            for (var a in c.apolices) {
              if (!a.dataFim.isBefore(mesFim) && !a.dataInicio.isAfter(mesFim)) {
                ativasFim++;
              }
            }
          }

          // 🔹 Taxa de retenção = (ativas fim / ativas início) * 100
          if (ativasInicio > 0) {
            taxaRetencaoPoMes[mes] = (ativasFim / ativasInicio) * 100;
          } else {
            taxaRetencaoPoMes[mes] = 0.0;
          }
        }

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

        // 7. VALOR APÓLICES MENSAIS (valor das apólices ativas na data de referência)
        for (int mes = 1; mes <= 12; mes++) {
          final mesInicio = DateTime(now.year, mes, 1);
          
          // Define a data de referência: hoje para o mês corrente, último dia do mês para os anteriores
          final dataReferencia = (mes == now.month && now.year == now.year)
              ? now
              : (mes == 12
                  ? DateTime(now.year + 1, 1, 1).subtract(const Duration(days: 1))
                  : DateTime(now.year, mes + 1, 1).subtract(const Duration(days: 1)));

          if (mesInicio.isAfter(now)) break;

          double valorApolicesMes = 0.0;
          for (var c in allClients) {
            for (var a in c.apolices) {
              // 🔥 Verifica se a apólice está ativa na data de referência
              if (!a.dataFim.isBefore(dataReferencia) && !a.dataInicio.isAfter(dataReferencia)) {
                valorApolicesMes += a.valorApolice;
              }
            }
          }
          valorApolicesPoMes[mes] = valorApolicesMes;
        }

        // 8. SLA COMPLIANCE SINISTROS (apenas concluídos)
        final sinistrosConcluidos = sinistrosMes.where((c) => c.statusAtual == 'Concluído').toList();
        if (sinistrosConcluidos.isNotEmpty) {
          final dentroPrazo = sinistrosConcluidos.where((c) {
            // Usa dataConclusao se disponível
            final dataConclusao = c.dataConclusao != null
                ? c.dataConclusao!.toDate()
                : null;
            if (dataConclusao == null) return false;
            final diasAberto = dataConclusao.difference(c.dataAbertura).inDays;
            return diasAberto <= config.slaSinistrosDias;
          }).length;
          slaComplianceSinistrosPoMes[mes] = (dentroPrazo / sinistrosConcluidos.length) * 100;
        } else {
          slaComplianceSinistrosPoMes[mes] = 0.0; // ou -1 para não exibir
        }

        // 9. SLA COMPLIANCE ASSISTÊNCIAS (conforme slaPrevisto/slaAtendimento)
        final assistenciasConcluidas = assistenciasMes.where((a) => a.statusAtual == 'Concluído').toList();
        if (assistenciasConcluidas.isNotEmpty) {
          final dentroPrazo = assistenciasConcluidas.where((a) {
            final dataConclusao = a.dataConclusao != null
                ? a.dataConclusao!.toDate()
                : null;
            if (dataConclusao == null) return false;
            final prazoLimite = a.slaAtendimento ?? a.slaPrevisto;
            if (prazoLimite == null) return false;
            return dataConclusao.isBefore(prazoLimite) || dataConclusao.isAtSameMomentAs(prazoLimite);
          }).length;
          slaComplianceAssistenciasPoMes[mes] = (dentroPrazo / assistenciasConcluidas.length) * 100;
        } else {
          slaComplianceAssistenciasPoMes[mes] = 0.0;
        }

        // 10. TICKET MÉDIO (valor médio por sinistro)
        final ticketMedio = sinistrosMes.isNotEmpty
          ? sinistrosMes.fold<double>(0.0, (sum, c) => sum + c.valorTotalSinistro) / sinistrosMes.length
          : 0.0;
        ticketMedioPoMes[mes] = ticketMedio;

      }

      if (mounted) {
        setState(() {
          _data = ReportData(
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
            assistenciasPorHorario: assistenciasPorHorario,
            assistenciasPorDia: assistenciasPorDia,
            sinistralidadePorSeguradora: sinistralidadePorSeguradora,
            mixCarteira: mixCarteira,
          );
          _assistencias = allAssistList;
          _assistencias.sort((a, b) => b.dataAbertura.compareTo(a.dataAbertura));
          _filteredAssistencias = assistenciasFiltradas;
          _npsNotas = npsNotas;
          _sinistros = todosSinistros;
          _assistencias = todasAssistencias;
          _allClients = allClients;
          _isLoading = false;
        });
      }

      await _carregarNomesFuncionarios();
      if (mounted) setState(() {});

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

  // --- GRÁFICO DE ASSISTÊNCIA POR HORÁRIO ---
  Widget _buildAssistenciasPorHorarioChart() {
    if (_data == null || _data!.assistenciasPorHorario.isEmpty) return const SizedBox();

    final horariosData = _data!.assistenciasPorHorario;
    final maxValue = horariosData.values.isNotEmpty
        ? horariosData.values.reduce((a, b) => a > b ? a : b).toDouble()
        : 10;

    final cores = {
      'Madrugada (0-6h)': const Color(0xFF1A237E),
      'Manhã (6-12h)': const Color(0xFFFFA500),
      'Tarde (12-18h)': const Color(0xFFFFD700),
      'Noite (18-24h)': const Color(0xFF37474F),
      'Não informado': Colors.grey,
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
            '🕐 Assistências por Horário do Dia',
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _buildAssistenciasPorDiaChart() {
    if (_data == null || _data!.assistenciasPorDia.isEmpty) return const SizedBox();

    final Map<int, String> dias = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };

    final data = _data!.assistenciasPorDia;
    final maxValue = data.values.isNotEmpty
        ? data.values.reduce((a, b) => a > b ? a : b).toDouble()
        : 10;

    final cores = {
      1: const Color(0xFF1565C0),
      2: const Color(0xFF1E88E5),
      3: const Color(0xFF42A5F5),
      4: const Color(0xFF64B5F6),
      5: const Color(0xFF90CAF9),
      6: const Color(0xFFE65100),
      7: const Color(0xFFC62828),
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
            '📅 Assistências por Dia da Semana',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...data.entries.map((e) {
            final diaNum = e.key;
            final valor = e.value;
            final percent = (valor / maxValue * 100);
            final cor = cores[diaNum] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          dias[diaNum]!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$valor',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 20,
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

    final Map<int, String> dias = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };

    final data = _data!.sinistrosPorDia;
    final maxValue = data.values.isNotEmpty
        ? data.values.reduce((a, b) => a > b ? a : b).toDouble()
        : 10;

    // Cores progressivas para os dias úteis e cores diferentes para fim de semana
    final cores = {
      1: const Color(0xFF1565C0),
      2: const Color(0xFF1E88E5),
      3: const Color(0xFF42A5F5),
      4: const Color(0xFF64B5F6),
      5: const Color(0xFF90CAF9),
      6: const Color(0xFFE65100),
      7: const Color(0xFFC62828),
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
          ...data.entries.map((e) {
            final diaNum = e.key;
            final valor = e.value;
            final percent = (valor / maxValue * 100);
            final cor = cores[diaNum] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          dias[diaNum]!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '$valor',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 20,
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
    final meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    // Prepara os dados para o BarChart
    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 12; i++) {
      final mes = i + 1;
      final valor = data[mes] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: valor.toDouble(),
              color: const Color(0xFFD32F2F),
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
          // Exibe o valor acima da barra
          showingTooltipIndicators: valor > 0 ? [0] : [],
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
            '📊 Sinistros Mensais - Ano ${DateTime.now().year} (quantidade)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final valor = rod.toY.toInt();
                      return BarTooltipItem(
                        '$valor',
                        const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < meses.length) {
                          return Text(meses[index], style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                barGroups: barGroups,
                gridData: FlGridData(show: true),
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
    final meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];

    final List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < 12; i++) {
      final mes = i + 1;
      final valor = data[mes] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: valor.toDouble(),
              color: const Color(0xFF1976D2),
              width: 16,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
          ],
          showingTooltipIndicators: valor > 0 ? [0] : [],
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
            '🚗 Assistências Mensais - Ano ${DateTime.now().year} (quantidade)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final valor = rod.toY.toInt();
                      return BarTooltipItem(
                        '$valor',
                        const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < meses.length) {
                          return Text(meses[index], style: const TextStyle(fontSize: 10));
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}', style: const TextStyle(fontSize: 10));
                      },
                      reservedSize: 40,
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true),
                barGroups: barGroups,
                gridData: FlGridData(show: true),
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
  if (_data != null) {
  }
  if (_data == null || _data!.contratosAtivosPoMes.isEmpty) {
    return const SizedBox();
  }

  // 🔹 CONSTRUIR OS SPOTS DO GRÁFICO
  final data = _data!.contratosAtivosPoMes;
  final spots = <FlSpot>[];
  for (int mes = 1; mes <= 12; mes++) {
    final valor = (data[mes] ?? 0).toDouble();
    spots.add(FlSpot(mes.toDouble(), valor));
  }

  // 🔹 FORÇAR ALTURA FIXA
  return SizedBox(
    height: 320,
    child: Container(
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
          Expanded(
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
                            color: Color(0xFF388E3C),
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
                        const meses = [
                          'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                          'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
                        ];
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
    ),
  );
}

  // ── VALOR APÓLICES MENSAL
  Widget _buildValorApolicesAnualChart() {
    if (_data == null || _data!.valorApolicesPoMes.isEmpty) return const SizedBox();

    final data = _data!.valorApolicesPoMes;
    final spots = <FlSpot>[];

    double maxValor = 0.0;
    for (int mes = 1; mes <= 12; mes++) {
      final valor = data[mes] ?? 0.0;
      spots.add(FlSpot(mes.toDouble(), valor));
      if (valor > maxValor) maxValor = valor;
    }

    // Se não houver dados, retorna vazio
    if (maxValor == 0) return const SizedBox();

    // Ajusta o máximo do eixo Y com 10% de margem
    final maxY = maxValor * 1.1;

    // 🔹 Função para formatar o valor do eixo com sufixo (k, M, B)
    String _formatAxisLabel(double value) {
      if (value >= 1e9) return 'R\$${(value / 1e9).toStringAsFixed(1)}B';
      if (value >= 1e6) return 'R\$${(value / 1e6).toStringAsFixed(1)}M';
      if (value >= 1e3) return 'R\$${(value / 1e3).toStringAsFixed(1)}k';
      return 'R\$${value.toStringAsFixed(0)}';
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
            '💰 Valor Apólices Mensais - Ano ${DateTime.now().year}',
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
                        // 🔹 Tooltip com valor exato em reais
                        final valor = spot.y;
                        final formatted = NumberFormat.currency(
                          locale: 'pt_BR',
                          symbol: 'R\$',
                        ).format(valor);
                        return LineTooltipItem(
                          formatted,
                          const TextStyle(
                            color: Color(0xFF7B1FA2),
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
                        const meses = [
                          'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
                          'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
                        ];
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
                        // 🔹 Eixo Y com formatação inteligente
                        return Text(
                          _formatAxisLabel(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                      reservedSize: 50,
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
                maxY: maxY,
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
    double maxValor = 100.0; // Padrão 100%

    for (int mes = 1; mes <= 12; mes++) {
      final valor = data[mes] ?? 0.0;
      // Limita a 100% para exibição, mas mantém o valor original para tooltip
      spots.add(FlSpot(mes.toDouble(), valor));
      if (valor > maxValor) maxValor = valor;
    }
    // Adiciona uma margem de 10% acima do máximo encontrado
    final maxY = (maxValor * 1.1).clamp(100.0, double.infinity);
    
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
                maxY: maxY,
                borderData: FlBorderData(show: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MÉTODOS PARA GERAR O GRÁFICO DE SLA ---

  Map<int, double> _calculateSlaByMesSinistros() {
    final result = <int, double>{};
    
    for (int mes = 1; mes <= 12; mes++) {
      final dataInicio = DateTime(DateTime.now().year, mes, 1);
      final dataFim = mes == 12 
          ? DateTime(DateTime.now().year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(DateTime.now().year, mes + 1, 1).subtract(const Duration(days: 1));

      final sinistrosMes = _sinistros.where((s) {
        return s.dataAbertura.isAfter(dataInicio) &&
            s.dataAbertura.isBefore(dataFim.add(const Duration(days: 1)));
      }).toList();

      final concluidos = sinistrosMes
          .where((c) => c.statusAtual == 'Concluído' && c.dataConclusao != null && c.slaPrevisto != null)
          .toList();

      if (concluidos.isEmpty) {
        result[mes] = 0;
        continue;
      }

      int slaCumprido = 0;
      for (var e in concluidos) {
        final dataConclusaoDateTime = (e.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
        if (dataConclusaoDateTime.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }

      result[mes] = (slaCumprido / concluidos.length * 100);
    }
    
    return result;
  }

  Map<int, double> _calculateSlaByMesAssistencias() {
    final result = <int, double>{};
    
    for (int mes = 1; mes <= 12; mes++) {
      final dataInicio = DateTime(DateTime.now().year, mes, 1);
      final dataFim = mes == 12 
          ? DateTime(DateTime.now().year + 1, 1, 1).subtract(const Duration(days: 1))
          : DateTime(DateTime.now().year, mes + 1, 1).subtract(const Duration(days: 1));

      final assistenciasMes = _assistencias.where((a) {
        return a.dataAbertura.isAfter(dataInicio) &&
            a.dataAbertura.isBefore(dataFim.add(const Duration(days: 1)));
      }).toList();

      final concluidas = assistenciasMes
          .where((c) => c.statusAtual == 'Concluído' && c.dataConclusao != null && c.slaPrevisto != null)
          .toList();

      if (concluidas.isEmpty) {
        result[mes] = 0;
        continue;
      }

      int slaCumprido = 0;
      for (var e in concluidas) {
        final dataConclusaoDateTime = (e.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
        if (dataConclusaoDateTime.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }

      result[mes] = (slaCumprido / concluidas.length * 100);
    }
    
    return result;
  }

  // ── SLA COMPLIANCE SINISTROS
  Widget _buildSlaComplianceSinistrosAnualChart() {
    final data = _calculateSlaByMesSinistros();
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
            '✅ SLA Compliance Sinistros - Ano ${DateTime.now().year} (%) — Eventos Concluídos',
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
                    color: _C.red,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _C.red.withOpacity(0.1),
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

  Widget _buildSlaComplianceAssistenciasAnualChart() {
    final data = _calculateSlaByMesAssistencias();
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
            '✅ SLA Compliance Assistências - Ano ${DateTime.now().year} (%) — Eventos Concluídos',
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
                    color: _C.teal,
                    barWidth: 3,
                    dotData: FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: _C.teal.withOpacity(0.1),
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

      final slaMap = _calculateSlaPercentageAll();
      final slaGeral = slaMap['geral'] ?? 0;
      final slaSinistros = slaMap['sinistros'] ?? 0;
      final slaAssistencias = slaMap['assistencias'] ?? 0;

      Uint8List? imagemPizza;
        try {
          imagemPizza = await _capturarWidget(_pizzaChartKey);
        } catch (e) {
          print('Erro ao capturar gráfico: $e');
          // continua sem a imagem
        }

      Uint8List? imagemSinistros;
        try {
          imagemSinistros = await _capturarWidget(_sinistrosSectionKey, height: 400); // altura maior
        } catch (e) { print('Erro sinistros: $e'); }

      final pdf = await PdfReportService().generateReport(
        data: _data!,
        dataInicio: _dataInicio,
        dataFim: _dataFim,
        periodoLabel: _periodoSelecionado,
        totalClientes: _allClients.where((c) =>
          c.apolices.any((a) => a.dataFim.isAfter(DateTime.now()))
        ).length,
        slaGeral: slaGeral,
        imagemPizza: imagemPizza,
        slaSinistros: slaSinistros,
        slaAssistencias: slaAssistencias,
      );
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'Upgrade_Relatorio_${_fmtDate.format(DateTime.now()).replaceAll('/', '-')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
    @override
    Widget build(BuildContext context) {
    
    final sinistrosFiltrados = _sinistros.where((s) {
      if (_dataInicio == null || _dataFim == null) return true;
      return s.dataAbertura.isAfter(_dataInicio!) &&
          s.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();
 
    final assistenciasFiltradas = _assistencias.where((a) {
      if (_dataInicio == null || _dataFim == null) return true;
      return a.dataAbertura.isAfter(_dataInicio!) &&
          a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();
    
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
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 1️⃣ CABEÇALHO: VISÃO GERAL DO NEGÓCIO (KPI EXECUTIVO)
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildHeader(),
                          const SizedBox(height: 12),
                          _buildExecutiveKpiHeader(),
                          const SizedBox(height: 16),
                          RepaintBoundary(
                            key: _pizzaChartKey,
                            child: _buildSinistroVsAssistenciaChart(),
                          ),
                          const SizedBox(height: 28),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 2️⃣ SEÇÃO: SINISTROS
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('📊 SINISTROS', _C.red),
                          const SizedBox(height: 12),
                          RepaintBoundary(
                            key: _sinistrosSectionKey,
                            child: _buildSinistrosSection(),
                          ),
                          const SizedBox(height: 16),
                          _buildSinistrosAnualChart(),
                          const SizedBox(height: 16),
                          _buildSinistralidadeAnualChart(),
                          const SizedBox(height: 16),
                          _buildSlaComplianceSinistrosAnualChart(),
                          const SizedBox(height: 16),
                          _buildSlaByRamoTable(),
                          const SizedBox(height: 28),
                          _buildSinistrosPorRamoChart(),
                          const SizedBox(height: 16),
                          _buildSinistrosPorDiaChart(),
                          const SizedBox(height: 16),                          
                          _buildSinistrosPorHorarioChart(),
                          const SizedBox(height: 16),                          
                          _buildDistribuicaoStatus(),
                          const SizedBox(height: 16),
                          _buildFunilEtapas(),
                          const SizedBox(height: 16),
                          _buildReparosProlongados(),
                          const SizedBox(height: 16),
                           _buildEnvolvimentoTerceirosCard(),
                          const SizedBox(height: 16),
                          _buildTicketMedioAnualChart(),
                          const SizedBox(height: 16),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 3️⃣ SEÇÃO: ASSISTÊNCIAS
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('🆘 ASSISTÊNCIAS', _C.teal),
                          const SizedBox(height: 12),
                          _buildAssistenciasSection(),
                          const SizedBox(height: 16),
                          _buildAssistenciasAnualChart(),
                          const SizedBox(height: 16),
                          _buildSlaComplianceAssistenciasAnualChart(),
                          const SizedBox(height: 16),
                          _buildAssistenciasPorRamoChart(),
                          const SizedBox(height: 16),
                          _buildSlaByTipoAssistenciaTable(),
                          const SizedBox(height: 28),
                          _buildAssistenciasPorDiaChart(),
                          const SizedBox(height: 16),
                          _buildAssistenciasPorHorarioChart(),
                          const SizedBox(height: 16),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 4️⃣ SEÇÃO: CLIENTES
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('👥 CLIENTES', _C.blue),
                          const SizedBox(height: 12),
                          TopClientsWidgets.buildTopClientesPorReceita(_allClients),
                          const SizedBox(height: 16),
                          TopClientsWidgets.buildTopClientesPorRisco(_allClients,_sinistros),
                          const SizedBox(height: 16),
                          _buildClientesRisco(),
                          const SizedBox(height: 16),
                          _buildContratosAnualChart(),
                          const SizedBox(height: 16),
                          _buildValorApolicesAnualChart(),
                          const SizedBox(height: 16),
                          _buildTaxaRetencaoAnualChart(),
                          const SizedBox(height: 28),
                          _buildContratosProximos(),
                          const SizedBox(height: 16),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 5️⃣ SEÇÃO: SEGURADORAS
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('🏢 SEGURADORAS', _C.amber),
                          const SizedBox(height: 12),
                          _buildMixCarteiraChart(_data!.mixCarteira),
                          const SizedBox(height: 16),
                          _buildTopSeguradorasChart(_data!.sinistralidadePorSeguradora),
                          const SizedBox(height: 16),
                          _buildTopSeguradorasAcionamentosChart(_sinistros),
                          const SizedBox(height: 28),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 6️⃣ SEÇÃO: FUNCIONÁRIOS
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('👔 FUNCIONÁRIOS', _C.purple),
                          const SizedBox(height: 12),
                          EmployeesPerformanceWidgets.buildFuncionariosSinistros(
                            sinistrosFiltrados,
                            _funcionarioIdNomes,
                          ),
                          const SizedBox(height: 16),
                          EmployeesPerformanceWidgets.buildFuncionariosAssistencias(
                            assistenciasFiltradas,
                            _funcionarioIdNomes,
                          ),
                          const SizedBox(height: 28),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 7️⃣ SEÇÃO: SATISFAÇÃO (NPS)
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('⭐ SATISFAÇÃO DOS CLIENTES', const Color(0xFF6A1B9A)),
                          const SizedBox(height: 12),
                          _buildNpsSection(),
                          const SizedBox(height: 16),
                          _buildNpsCard(),
                          const SizedBox(height: 16),
                          _buildTempoMedioCard(),
                          const SizedBox(height: 16),
                          _buildNpsAnualChart(),
                          const SizedBox(height: 28),
 
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 8️⃣ SEÇÃO: ANÁLISE ESTRATÉGICA (SWOT)
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('🎯 ANÁLISE ESTRATÉGICA (SWOT)', _C.green),
                          const SizedBox(height: 12),
                          _buildOperationalBlock(_sinistros, _assistencias),
                          const SizedBox(height: 16),
                          _buildTacticalBlock(_sinistros, _assistencias, _allClients),
                          const SizedBox(height: 16),
                          _buildStrategicBlock(_sinistros, _assistencias, _allClients),
                          const SizedBox(height: 32),

                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          // 9️⃣ SEÇÃO: PENDÊNCIAS & AÇÕES
                          // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                          _buildSectionDivider('⚠️ PENDÊNCIAS & AÇÕES', _C.red),
                          const SizedBox(height: 12),
                          _buildAprovacoesParadas(),
                          const SizedBox(height: 16),
                          _buildSinistrosEmAtraso(),
                          const SizedBox(height: 16),
                        ],
                      ),
              ),
            ),
    );
  }
 
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // NOVO: Cabeçalho Executivo com KPIs principais
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildExecutiveKpiHeader() {
    // Filtra os dados PELO PERÍODO SELECIONADO
    final sinistrosFiltrados = _sinistros.where((s) {
      if (_dataInicio == null || _dataFim == null) return true;
      return s.dataAbertura.isAfter(_dataInicio!) &&
          s.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();
 
    final assistenciasFiltradas = _assistencias.where((a) {
      if (_dataInicio == null || _dataFim == null) return true;
      return a.dataAbertura.isAfter(_dataInicio!) &&
          a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();
 
    final totalSinistros = sinistrosFiltrados.length;
    final totalAssistencias = assistenciasFiltradas.length;
    final totalClientes = _allClients.where((c) =>
      c.apolices.any((a) => a.dataFim.isAfter(DateTime.now()))
    ).length;
 
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho com título e período
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Visão Geral do Negócio',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 13, color: _C.blue),
                  const SizedBox(width: 6),
                  Text(
                    _periodoSelecionado,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _C.blue,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_dataInicio != null && _dataFim != null)
                    Text(
                      '${_fmtDate.format(_dataInicio!)} a ${_fmtDate.format(_dataFim!)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
 
        const SizedBox(height: 16),
 
        // 3 Cards em row - cada um responsivo ao período
        Row(
          children: [
 
            // Card 1: Clientes (sempre total)
            Expanded(
              child: _buildKpiCardV2(
                icon: Icons.people_alt_rounded,
                iconColor: _C.green,
                label: 'Clientes Ativos',
                value: totalClientes.toString(),
                subtext: totalClientes == 1 ? '1 cliente' : '$totalClientes clientes com apólice vigente',
                bgColor: _C.green.withOpacity(0.08),
                borderColor: _C.green.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
            
            // Card 2: Ticket Médio
            Expanded(
              child: _buildKpiCardV2(
                icon: Icons.receipt_long_rounded,
                iconColor: _C.amber,
                label: 'Ticket Médio',
                value: _calculateTicketMedio(),
                subtext: 'R\$ Por evento',
                bgColor: _C.amber.withOpacity(0.08),
                borderColor: _C.amber.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),

            //Card 3: VGV em Carteira
            Expanded(
              child: _buildKpiCardV2(
                icon: Icons.trending_up_rounded,
                iconColor: _C.blue,
                label: 'Valor Total das Apólices (VGV)',
                value: _fmtCurrency.format(_calculateVgvPeriodo()),
                subtext: 'Em carteira',
                bgColor: _C.blue.withOpacity(0.08),
                borderColor: _C.blue.withOpacity(0.2),
              ),
            ),

          ],
        ),
      const SizedBox(height: 16),

        // Segunda linha
        Row(
          children: [
            
            // Card 1: Sinistros
            Expanded(
              child: _buildKpiCardV2(
                icon: Icons.warning_amber_rounded,
                iconColor: _C.red,
                label: 'Sinistros',
                value: totalSinistros.toString(),
                subtext: totalSinistros == 1 ? '1 evento' : '$totalSinistros eventos',
                bgColor: _C.red.withOpacity(0.08),
                borderColor: _C.red.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),
 
            // Card 2: Assistências
            Expanded(
              child: _buildKpiCardV2(
                icon: Icons.support_agent_rounded,
                iconColor: _C.teal,
                label: 'Assistências',
                value: totalAssistencias.toString(),
                subtext: totalAssistencias == 1 ? '1 evento' : '$totalAssistencias eventos',
                bgColor: _C.teal.withOpacity(0.08),
                borderColor: _C.teal.withOpacity(0.2),
              ),
            ),
            const SizedBox(width: 12),

            // SLA Compliance (Geral)
            Expanded(
              child: Builder(
                builder: (context) {
                  final slaMap = _calculateSlaPercentageAll();
                  final slaGeral = slaMap['geral'] ?? 0;
                  return _buildKpiCardV2(
                    icon: Icons.check_circle_rounded,
                    iconColor: slaGeral >= 80 ? _C.green : (slaGeral >= 60 ? _C.amber : _C.red),
                    label: 'SLA Geral',
                    value: slaGeral.toStringAsFixed(0) + '%',
                    subtext: 'Eventos concluídos',
                    bgColor: (slaGeral >= 80 ? _C.green : (slaGeral >= 60 ? _C.amber : _C.red)).withOpacity(0.08),
                    borderColor: (slaGeral >= 80 ? _C.green : (slaGeral >= 60 ? _C.amber : _C.red)).withOpacity(0.2),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            
            // NPS Score
            Expanded(
              child: _buildKpiCardV2(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFF6A1B9A),
                label: 'NPS Score',
                value: _npsNotas.isEmpty ? '--' : (_npsNotas.reduce((a, b) => a + b) / _npsNotas.length).toStringAsFixed(1),
                subtext: _npsNotas.isEmpty ? 'Sem dados' : '${_npsNotas.length} votos',
                bgColor: const Color(0xFF6A1B9A).withOpacity(0.08),
                borderColor: const Color(0xFF6A1B9A).withOpacity(0.2),
              ),
            ),
          ],
        ),
      ]
    );
  }
 
  Widget _buildSlaByRamoTable() {
    final slaByRamo = _calculateSlaByRamo();
    
    if (slaByRamo.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text('Nenhum sinistro concluído neste período'),
      );
    }

    return _Section(
      title: 'SLA por Ramo de Sinistro',
      icon: Icons.analytics_outlined,
      color: _C.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...slaByRamo.entries.map((entry) {
            final ramo = entry.key;
            final slaPercent = entry.value;
            final color = slaPercent >= 80 ? _C.green : (slaPercent >= 60 ? _C.amber : _C.red);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ramo,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${slaPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: slaPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

  Widget _buildSlaByTipoAssistenciaTable() {
    final slaByTipo = _calculateSlaByTipoAssistencia();
    
    if (slaByTipo.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text('Nenhuma assistência concluída neste período'),
      );
    }

    return _Section(
      title: 'SLA por Tipo de Assistência',
      icon: Icons.analytics_outlined,
      color: _C.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...slaByTipo.entries.map((entry) {
            final tipo = entry.key;
            final slaPercent = entry.value;
            final color = slaPercent >= 80 ? _C.green : (slaPercent >= 60 ? _C.amber : _C.red);
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getTipoAssistenciaLabel(tipo),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${slaPercent.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: slaPercent / 100,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(color),
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

  Widget _buildKpiCardV2({
      required IconData icon,
      required Color iconColor,
      required String label,
      required String value,
      required String subtext,
      required Color bgColor,
      required Color borderColor,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícone
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
  
            const SizedBox(height: 12),
  
            // Label (pequeno, muted)
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.2,
              ),
            ),
  
            const SizedBox(height: 6),
  
            // Valor grande
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: iconColor,
                height: 1.0,
              ),
            ),
  
            const SizedBox(height: 4),
  
            // Subtext (contexto)
            Text(
              subtext,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
 
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // NOVO: Divisor de seção temática
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildSectionDivider(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.3), color.withOpacity(0)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TOP SEGURADORAS ---
  Widget _buildTopSeguradorasChart(Map<String, double> sinistralidadePorSeguradora) {
    if (sinistralidadePorSeguradora.isEmpty) return const SizedBox();

    // Ordena por valor decrescente e pega top 5
    final top5 = sinistralidadePorSeguradora.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5List = top5.take(5).toList();
    final maxValue = top5List.isNotEmpty ? top5List.first.value : 1;

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
            '🏢 Top 5 Seguradoras por Sinistralidade (12 meses)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...top5List.map((e) {
            final percent = maxValue > 0 ? (e.value / maxValue * 100) : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _fmtCurrency.format(e.value),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 16,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        e.value > 10000 ? _C.red : _C.amber,
                      ),
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

  Widget _buildTopSeguradorasAcionamentosChart(List<Claim> sinistros) {
    if (sinistros.isEmpty) return const SizedBox();

    // Conta acionamentos por seguradora
    final acionamentosPorSeguradora = <String, int>{};
    for (final s in sinistros) {
      acionamentosPorSeguradora[s.seguradora] = 
        (acionamentosPorSeguradora[s.seguradora] ?? 0) + 1;
    }

    if (acionamentosPorSeguradora.isEmpty) return const SizedBox();

    // Ordena por quantidade decrescente e pega top 5
    final top5 = acionamentosPorSeguradora.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5List = top5.take(5).toList();
    final maxValue = top5List.isNotEmpty ? top5List.first.value : 1;

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
            '📞 Top 5 Seguradoras por Acionamentos',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...top5List.map((e) {
            final percent = maxValue > 0 ? (e.value / maxValue * 100) : 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${e.value} acionamentos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _C.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 16,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(_C.blue),
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

  // --- MIX DE CARTEIRA DE SEGUROS ---
  Widget _buildMixCarteiraChart(Map<String, double> mixCarteira) {
    if (mixCarteira.isEmpty) return const SizedBox();

    final total = mixCarteira.values.fold(0.0, (a, b) => a + b);
    final entries = mixCarteira.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Cores para cada ramo (pode ajustar conforme preferir)
    final cores = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFFE65100),
      const Color(0xFFC62828),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFFF57F17),
      const Color(0xFF37474F),
      const Color(0xFF00838F),
      const Color(0xFF4E342E),
    ];

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
            '📊 Mix de Carteira (Prêmio por Ramo)',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ...entries.map((e) {
            final percent = total > 0 ? (e.value / total * 100) : 0;
            final color = cores[entries.indexOf(e) % cores.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  // Nome do ramo
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Barra de progresso
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100, // value deve ser entre 0 e 1
                        minHeight: 16,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Porcentagem
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${percent.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
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

  // --- CABEÇALHO DA SEÇÃO DE SINISTRO ---
  Widget _buildSinistrosSection() {
    final sinistros = _sinistros.where((s) {
      if (_dataInicio == null || _dataFim == null) return true;
      return s.dataAbertura.isAfter(_dataInicio!) &&
          s.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();

    if (sinistros.isEmpty) return const SizedBox.shrink();

    // Agrupa por ramo
    final ramoMap = <String, int>{};
    for (final s in sinistros) {
      ramoMap[s.ramoSinistro] = (ramoMap[s.ramoSinistro] ?? 0) + 1;
    }
    final ramosOrdenados = ramoMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // SLA stats - apenas eventos CONCLUÍDOS
    final concluidos = sinistros.where((s) => s.statusAtual == 'Concluído').toList();
    final comSlaCompleto = concluidos
        .where((s) => s.dataConclusao != null && s.slaPrevisto != null)
        .toList();
    
    int slaCumprido = 0;
    for (var s in comSlaCompleto) {
      final dataConc = (s.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
      if (dataConc.isBefore(s.slaPrevisto!)) {
        slaCumprido++;
      }
    }
    
    final taxaSla = comSlaCompleto.isEmpty ? 0 : ((slaCumprido / comSlaCompleto.length) * 100).round();
    final vencidos = comSlaCompleto.length - slaCumprido;

    // Distribuição por status
    final statusMap = <String, int>{};
    for (final s in sinistros) {
      statusMap[s.statusAtual] = (statusMap[s.statusAtual] ?? 0) + 1;
    }

    return _Section(
      title: 'Sinistros — Análise Completa',
      subtitle: '${sinistros.length} registros · Concluídos: ${concluidos.length}',
      icon: Icons.warning_amber_rounded,
      color: _C.red,
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
                _MetricCard(label: 'Total Sinistros', value: '${sinistros.length}',
                    icon: Icons.warning_amber_rounded, color: _C.red),
                _MetricCard(label: 'Concluídos', value: '${concluidos.length}',
                    icon: Icons.check_circle_outlined, color: _C.green),
                _MetricCard(label: 'Abertos', value: '${sinistros.length - concluidos.length}',
                    icon: Icons.open_in_new, color: _C.blue),
                _MetricCard(
                    label: 'SLA Cumprido',
                    value: '$taxaSla%',
                    icon: Icons.timer_outlined,
                    color: taxaSla >= 80 ? _C.green : taxaSla >= 60 ? _C.amber : _C.red,
                    subtitle: '$slaCumprido no prazo · $vencidos vencidos'),
              ][i],
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Assistências Section ──────────────────────────────────────────────────
  Widget _buildAssistenciasSection() {
    final assistencias = _filteredAssistencias;
    if (assistencias.isEmpty) return const SizedBox.shrink();

    final veiculares = assistencias
        .where((a) => a.tipoAssistencia != 'residencial')
        .toList();
    final residenciais = assistencias
        .where((a) => a.tipoAssistencia == 'residencial')
        .toList();

    // SLA stats - CORRIGIDO: apenas eventos CONCLUÍDOS
    final concluidas = assistencias.where((a) => a.statusAtual == 'Concluído').toList();
    final comSlaCompleto = concluidas
        .where((a) => a.dataConclusao != null && a.slaPrevisto != null)
        .toList();
    
    int slaCumprido = 0;
    for (var a in comSlaCompleto) {
      final dataConc = (a.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
      if (dataConc.isBefore(a.slaPrevisto!)) {
        slaCumprido++;
      }
    }
    
    final taxaSla = comSlaCompleto.isEmpty ? 0 : ((slaCumprido / comSlaCompleto.length) * 100).round();
    final vencidas = comSlaCompleto.length - slaCumprido;

    // Tipos mais frequentes
    final tiposMap = <String, int>{};
    for (final a in assistencias) {
      final label = _getTipoLabel(a.tipoAssistencia);
      tiposMap[label] = (tiposMap[label] ?? 0) + 1;
    }
    final tiposOrdenados = tiposMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTipo = tiposOrdenados.isNotEmpty ? tiposOrdenados.first.value : 1;

    return _Section(
      title: 'Assistências — Análise Completa',
      subtitle: '${assistencias.length} registros · Veiculares: ${veiculares.length} · Residenciais: ${residenciais.length}',
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
                _MetricCard(label: 'Total Assistências', value: '${assistencias.length}',
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
                    subtitle: '$slaCumprido concluídos no prazo · $vencidas vencidos'),
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
                          if (assistencias.isNotEmpty) ...[
                            Flexible(
                              flex: veiculares.length,
                              child: Container(color: _C.blue,
                                  child: Center(child: Text(
                                    '${((veiculares.length / assistencias.length) * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ))),
                            ),
                            if (residenciais.isNotEmpty)
                              Flexible(
                                flex: residenciais.isNotEmpty ? residenciais.length : 1,
                                child: Container(color: _C.teal,
                                    child: Center(child: Text(
                                      '${((residenciais.length / assistencias.length) * 100).toStringAsFixed(0)}%',
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

    // Calcula valor total em risco (vencendo nos próximos 30 dias)
    double valorEmRisco = 0;
    for (var c in d.contratosProximos) {
      if (c.apolices.isNotEmpty) {
        final apoliceProxVencer = c.apolices.reduce((a, b) => 
          a.dataFim.isBefore(b.dataFim) ? a : b
        );
        final dias = apoliceProxVencer.dataFim.difference(now).inDays;
        if (dias <= 30) { // Apenas as que vençam nos próximos 30 dias
          valorEmRisco += apoliceProxVencer.valorApolice;
        }
      }
    }

    return _Section(
      title: 'Contratos próximos do vencimento',
      subtitle: '${d.contratosProximos.length} contratos',
      icon: Icons.event_outlined,
      color: _C.teal,
      child: Column(
        children: [
          // ⚠️ DESTAQUE: Valor em risco
          // ⚠️ DESTAQUE: Valor em risco
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _C.red.withOpacity(0.08),
              border: Border.all(color: _C.red.withOpacity(0.3), width: 1.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: _C.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Risco de perda de receita',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Text(
                  _fmtCurrency.format(valorEmRisco),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _C.red),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...d.contratosProximos.map((c) {
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
        ]
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // ASSISTÊNCIAS: SWOT Analysis em 3 Níveis
  // ───────────────────────────────────────────────────────────────────────────

  /// Operacional: Tempo real
  Map<String, dynamic> _getOperationalMetrics(List<Claim> sinistros, List<Claim> assistencias) {
    final now = DateTime.now();
    final inicio = now.subtract(const Duration(days: 30));
    final todos = [...sinistros, ...assistencias];
    final eventosNoPeriodo = todos.where((e) => e.dataAbertura.isAfter(inicio)).toList();

    final abertos = eventosNoPeriodo.where((e) => e.statusAtual == 'Aberto' || e.statusAtual == 'Em Andamento').length;

    final concluidos = eventosNoPeriodo.where((e) => e.statusAtual == 'Concluído').toList();
    double tempoMedioDias = 0;
    if (concluidos.isNotEmpty) {
      double soma = 0;
      for (var e in concluidos) {
        soma += e.dataUltimaAtualizacao.difference(e.dataAbertura).inHours / 24;
      }
      tempoMedioDias = soma / concluidos.length;
    }

    // SLA
    int slaCumprido = 0;
    int slaTotal = 0;
    for (var e in concluidos) {
      if (e.slaPrevisto != null) {
        slaTotal++;
        if (e.dataUltimaAtualizacao.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }
    }
    final slaPercentual = slaTotal == 0 ? 0 : (slaCumprido / slaTotal * 100).round();

    final statusMap = <String, int>{};
    for (var e in eventosNoPeriodo) {
      statusMap[e.statusAtual] = (statusMap[e.statusAtual] ?? 0) + 1;
    }

    return {
      'abertos': abertos,
      'tempoMedioDias': tempoMedioDias,
      'slaPercentual': slaPercentual,
      'totalEventos': eventosNoPeriodo.length,
      'statusMap': statusMap,
    };
  }

  /// Tático: Tendências (últimos 90 dias)
  Map<String, dynamic> _getTacticalMetrics(List<Claim> sinistros, List<Claim> assistencias, List<Client> allClients) {
        
    final now = DateTime.now();
    final inicio = now.subtract(const Duration(days: 90));
    final todos = [...sinistros, ...assistencias];
    final eventosNoPeriodo = todos.where((e) => e.dataAbertura.isAfter(inicio)).toList();

    final volume = eventosNoPeriodo.length;

    final concluidos = eventosNoPeriodo.where((e) => e.statusAtual == 'Concluído').toList();
    int slaCumprido = 0;
    int slaTotal = 0;
    for (var e in concluidos) {
      if (e.slaPrevisto != null) {
        slaTotal++;
        if (e.dataUltimaAtualizacao.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }
    }
    final slaPercentual = slaTotal == 0 ? 0 : (slaCumprido / slaTotal * 100).round();

    // Cross-Selling
    final clientesComApolices = allClients.where((c) => c.apolices.isNotEmpty).toList();
    final totalApolices = clientesComApolices.fold(0, (sum, c) => sum + c.apolices.length);
    final crossSelling = clientesComApolices.isEmpty ? 0 : (totalApolices / clientesComApolices.length);

    return {
      'volume': volume,
      'slaPercentual': slaPercentual,
      'crossSelling': crossSelling,
      'periodo': '${DateFormat('dd/MM').format(inicio)} - ${DateFormat('dd/MM').format(now)}',
    };
  }

  /// Estratégico: SWOT Analysis (últimos 12 meses)
  Map<String, dynamic> _getStrategicMetrics(List<Claim> sinistros, List<Claim> assistencias, List<Client> allClients) {
    
    final now = DateTime.now();
    final inicio = now.subtract(const Duration(days: 365));
    final todos = [...sinistros, ...assistencias];
    final eventosNoPeriodo = todos.where((e) => e.dataAbertura.isAfter(inicio)).toList();

    final totalEventos = eventosNoPeriodo.length;

    final concluidos = eventosNoPeriodo.where((e) => e.statusAtual == 'Concluído').toList();
    int slaCumprido = 0;
    int slaTotal = 0;
    for (var e in concluidos) {
      if (e.slaPrevisto != null) {
        slaTotal++;
        if (e.dataUltimaAtualizacao.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }
    }
    final slaPercentual = slaTotal == 0 ? 0 : (slaCumprido / slaTotal * 100).round();

    // Reincidência
    final eventosPorCliente = <String, int>{};
    for (var e in eventosNoPeriodo) {
      eventosPorCliente[e.idCliente] = (eventosPorCliente[e.idCliente] ?? 0) + 1;
    }
    final clientesReincidentes = eventosPorCliente.values.where((v) => v > 1).length;
    final totalClientes = eventosPorCliente.length;
    final taxaReincidencia = totalClientes == 0 ? 0 : (clientesReincidentes / totalClientes * 100).round();

    // VGV
    final vgv = allClients.fold(0.0, (sum, c) => sum + c.valorTotalApolicesAtivas);

    // Cross-Selling
    final clientesComApolices = allClients.where((c) => c.apolices.isNotEmpty).toList();
    final totalApolices = clientesComApolices.fold(0, (sum, c) => sum + c.apolices.length);
    final crossSelling = clientesComApolices.isEmpty ? 0 : (totalApolices / clientesComApolices.length);

    return {
      'slaPercentual': slaPercentual,
      'taxaReincidencia': taxaReincidencia,
      'vgv': vgv,
      'totalEventos': totalEventos,
      'crossSelling': crossSelling,
      'periodo': '${DateFormat('dd/MM/yyyy').format(inicio)} - ${DateFormat('dd/MM/yyyy').format(now)}',
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

  Widget _buildOperationalBlock(List<Claim> sinistros, List<Claim> assistencias) {
    final metrics = _getOperationalMetrics(sinistros, assistencias);
    final abertos = metrics['abertos'] as int;
    final tempoMedioDias = metrics['tempoMedioDias'] as double;
    final slaPercentual = metrics['slaPercentual'] as int;
    final totalEventos = metrics['totalEventos'] as int;
    final statusMap = metrics['statusMap'] as Map<String, int>;

    Color slaColor;
    if (slaPercentual >= 80) slaColor = _C.green;
    else if (slaPercentual >= 60) slaColor = _C.amber;
    else slaColor = _C.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                    color: _C.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.timeline, color: _C.blue),
                ),
                const SizedBox(width: 12),
                const Text(
                  '📊 Nível Operacional (30 dias)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  'Últimos 30 dias',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard('Eventos Abertos', '$abertos', Icons.open_in_new, _C.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('Tempo Médio', '${tempoMedioDias.toStringAsFixed(1)}d', Icons.timer, _C.amber),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('SLA Cumprido', '${slaPercentual}%', Icons.check_circle, slaColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('Total Eventos', '$totalEventos', Icons.history, _C.purple),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (statusMap.isNotEmpty) ...[
              const Text('Distribuição por Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...statusMap.entries.map(
                (e) => _buildStatusBar(e.key, e.value, totalEventos),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalBlock(List<Claim> sinistros, List<Claim> assistencias, List<Client> allClients) {
    final metrics = _getTacticalMetrics(sinistros, assistencias, allClients);
    final volume = metrics['volume'] as int;
    final slaPercentual = metrics['slaPercentual'] as int;
    final crossSelling = metrics['crossSelling'] as double;
    final periodo = metrics['periodo'] as String;

    Color slaColor;
    if (slaPercentual >= 80) slaColor = _C.green;
    else if (slaPercentual >= 60) slaColor = _C.amber;
    else slaColor = _C.red;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                    color: _C.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.trending_up, color: _C.teal),
                ),
                const SizedBox(width: 12),
                const Text(
                  '📈 Nível Tático (3 meses)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  periodo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard('Volume', '$volume', Icons.trending_up, _C.teal),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('SLA Cumprido', '${slaPercentual}%', Icons.check_circle, slaColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('Cross-Selling', '${crossSelling.toStringAsFixed(1)} apól./cliente', Icons.link, Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategicBlock(List<Claim> sinistros, List<Claim> assistencias, List<Client> allClients) {
    final metrics = _getStrategicMetrics(sinistros, assistencias, allClients);
    final slaPercentual = metrics['slaPercentual'] as int;
    final taxaReincidencia = metrics['taxaReincidencia'] as int;
    final vgv = metrics['vgv'] as double;
    final totalEventos = metrics['totalEventos'] as int;
    final crossSelling = metrics['crossSelling'] as double;
    final periodo = metrics['periodo'] as String;

    Color slaColor;
    if (slaPercentual >= 80) slaColor = _C.green;
    else if (slaPercentual >= 60) slaColor = _C.amber;
    else slaColor = _C.red;

    // Gerar textos da SWOT com base nos números
    final forcas = slaPercentual >= 80 ? 'SLA alto (${slaPercentual}%) indica boa performance operacional.' : 'SLA em ${slaPercentual}% - há espaço para melhoria.';
    final fraquezas = taxaReincidencia > 30 ? 'Taxa de reincidência alta (${taxaReincidencia}%) - clientes recorrentes podem indicar insatisfação.' : 'Reincidência em ${taxaReincidencia}% - estável.';
    final oportunidades = 'Cross-Selling de ${crossSelling.toStringAsFixed(1)} apólices/cliente. Oportunidade de aumentar para 2.0.';
    final ameacas = 'VGV total de ${_fmtCurrency.format(vgv)}. Monitorar mix de carteira para evitar concentração.';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
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
                    color: Colors.purple.shade100.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                const Text(
                  '🎯 Nível Estratégico (12 meses)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  periodo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard('SLA Cumprido', '${slaPercentual}%', Icons.check_circle, slaColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('Reincidência', '${taxaReincidencia}%', Icons.person_add, Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('VGV (Prêmios)', _fmtCurrency.format(vgv), Icons.attach_money, _C.blue),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildKpiCard('Total Eventos', '$totalEventos', Icons.event, _C.purple),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpiCard('Cross-Selling', '${crossSelling.toStringAsFixed(1)} apól./cliente', Icons.link, Colors.purple),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Análise SWOT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildSwotBox('Forças', forcas, _C.green),
            _buildSwotBox('Fraquezas', fraquezas, _C.red),
            _buildSwotBox('Oportunidades', oportunidades, _C.amber),
            _buildSwotBox('Ameaças', ameacas, _C.purple),
            const SizedBox(height: 8),
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

  Widget _buildTopSeguradoraRow(String seguradora, double valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              seguradora,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: (valor / 10000).clamp(0, 1), // valor fictício para escala
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_C.teal),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtCurrency.format(valor),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMixRow(String ramo, double valor, double total) {
    final percent = total > 0 ? (valor / total * 100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              ramo,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(Colors.orange),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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

  // ─── SLA Calculations (Estratificado por tipo) ────────────────────────────
  Map<String, double> _calculateSlaPercentageAll() {
    final sinistrosFiltrados = _sinistros.where((s) {
      if (_dataInicio == null || _dataFim == null) return true;
      return s.dataAbertura.isAfter(_dataInicio!) &&
          s.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();

    final assistenciasFiltradas = _assistencias.where((a) {
      if (_dataInicio == null || _dataFim == null) return true;
      return a.dataAbertura.isAfter(_dataInicio!) &&
          a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();

    // SLA = eventos CONCLUÍDOS que foram fechados no prazo vs total concluídos
    final slaGeral = _calculateSlaForConcludedEvents([...sinistrosFiltrados, ...assistenciasFiltradas]);
    final slaSinistros = _calculateSlaForConcludedEvents(sinistrosFiltrados);
    final slaAssistencias = _calculateSlaForConcludedEvents(assistenciasFiltradas);

    return {
      'geral': slaGeral,
      'sinistros': slaSinistros,
      'assistencias': slaAssistencias,
    };
  }

  double _calculateSlaForConcludedEvents(List<Claim> eventos) {
    // Pega apenas CONCLUÍDOS com dataConclusao e slaPrevisto
    final concluidos = eventos
        .where((c) => c.statusAtual == 'Concluído' && c.dataConclusao != null && c.slaPrevisto != null)
        .toList();
    
    if (concluidos.isEmpty) return 0; // Sem eventos concluídos = sem SLA a medir
    
    int slaCumprido = 0;
    
    for (var e in concluidos) {
      final dataConclusaoDateTime = (e.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
      
      // SLA cumprido = conclusão foi ANTES do prazo
      if (dataConclusaoDateTime.isBefore(e.slaPrevisto!)) {
        slaCumprido++;
      }
    }
    
    return (slaCumprido / concluidos.length * 100);
  }

  Map<String, double> _calculateSlaByRamo() {
    final sinistrosFiltrados = _sinistros.where((s) {
      if (_dataInicio == null || _dataFim == null) return true;
      return s.dataAbertura.isAfter(_dataInicio!) &&
          s.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();

    final concluidos = sinistrosFiltrados
        .where((c) => c.statusAtual == 'Concluído' && c.dataConclusao != null && c.slaPrevisto != null)
        .toList();

    final ramosUnicos = concluidos.map((c) => c.ramoSinistro).toSet();
    final result = <String, double>{};

    for (var ramo in ramosUnicos) {
      final ramoEventos = concluidos.where((c) => c.ramoSinistro == ramo).toList();
      int slaCumprido = 0;

      for (var e in ramoEventos) {
        final dataConclusaoDateTime = (e.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
        
        if (dataConclusaoDateTime.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }

      result[ramo] = ramoEventos.isEmpty ? 0 : (slaCumprido / ramoEventos.length * 100);
    }

    return result;
  }

  Map<String, double> _calculateSlaByTipoAssistencia() {
    final assistenciasFiltradas = _assistencias.where((a) {
      if (_dataInicio == null || _dataFim == null) return true;
      return a.dataAbertura.isAfter(_dataInicio!) &&
          a.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();

    final concluidos = assistenciasFiltradas
        .where((c) => c.statusAtual == 'Concluído' && c.dataConclusao != null && c.slaPrevisto != null)
        .toList();

    final tiposUnicos = concluidos.map((c) => c.tipoAssistencia ?? 'outro').toSet();
    final result = <String, double>{};

    for (var tipo in tiposUnicos) {
      final tipoEventos = concluidos.where((c) => (c.tipoAssistencia ?? 'outro') == tipo).toList();
      int slaCumprido = 0;

      for (var e in tipoEventos) {
        final dataConclusaoDateTime = (e.dataConclusao as Timestamp?)?.toDate() ?? DateTime.now();
        
        if (dataConclusaoDateTime.isBefore(e.slaPrevisto!)) {
          slaCumprido++;
        }
      }

      result[tipo] = tipoEventos.isEmpty ? 0 : (slaCumprido / tipoEventos.length * 100);
    }

    return result;
  }

  String _calculateTicketMedio() {
    final sinistrosFiltrados = _sinistros.where((s) {
      if (_dataInicio == null || _dataFim == null) return true;
      return s.dataAbertura.isAfter(_dataInicio!) &&
          s.dataAbertura.isBefore(_dataFim!.add(const Duration(days: 1)));
    }).toList();

    if (sinistrosFiltrados.isEmpty) return '--';
    
    double totalValor = 0;
    for (var s in sinistrosFiltrados) {
      totalValor += s.valorTotalSinistro;
    }
    
    final media = totalValor / sinistrosFiltrados.length;
    return _fmtCurrency.format(media);
  }

  double _calculateVgvPeriodo() {
    return _allClients.fold(0.0, (sum, c) => sum + c.valorTotalApolicesAtivas);
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
}