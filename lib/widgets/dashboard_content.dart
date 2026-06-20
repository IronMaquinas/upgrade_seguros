// 🎯 Novo Dashboard - Código Implementável
// Coloque em: lib/widgets/dashboard_content_v2.dart

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upgrade_seguros/screens/assist_detail_screen.dart';
import 'package:upgrade_seguros/screens/assist_list_screen.dart';
import 'package:upgrade_seguros/screens/claim_detail_screen.dart';
import 'package:upgrade_seguros/screens/claim_list_screen.dart';
import 'package:upgrade_seguros/services/notification_service.dart';
import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

class DashboardContent extends StatefulWidget {
  final Function(Widget)? onNavigate;

  const DashboardContent({super.key, this.onNavigate});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  List<Map<String, dynamic>> _tasks = [];

  List<Claim> _recentClaims = [];
  List<Client> _clients = [];
  bool _isLoading = true;
  List<Claim> _assistencias = [];
  double _npsMedia = 0.0;

  // Controle de notificações
  Timer? _notifTimer;
  final Set<String> _alertadosRecentemente = {}; // evita repetir o mesmo alerta

  @override
  void initState() {
    super.initState();
    _fetchRecentClaims();
    _fetchAssistencias();
    _fetchTasks();
    _fetchNPS();
    _fetchNpsMedia();
    // _iniciarMonitoramentoAlertas();
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    super.dispose();
  }

  // IMPLEMENTAÇÃO FUTURA DO NPS
  Future<void> _fetchNPS() async {
    // Busca últimas 100 respostas NPS
    // Calcula média e atualiza _npsScore
  }

  // ── Monitoramento de alertas ──────────────────────────────────────────────
  void _solicitarPermissaoNotificacao() {
    try {
      js.context.callMethod('eval', [
        'if (typeof Notification !== "undefined" && Notification.permission === "default") {'
        '  Notification.requestPermission(); '
        '}'
      ]);
    } catch (_) {}
  }

  // FUNÇÃO PARA BUSCAR ASSISTÊNCIAS EM ANDAMENTO
  Future<void> _fetchAssistencias() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('assistencias')
          .where('status_atual', whereNotIn: ['Concluído', 'Cancelado'])
          .get();
      if (mounted) {
        setState(() {
          _assistencias = snapshot.docs
              .map((doc) => Claim.fromMap({...doc.data(), 'id': doc.id}))
              .toList();
        });
        //_verificarAlertas();
      }
    } catch (e) {
      print('Erro ao buscar assistências: $e');
    }
  }

  // FUNÇÃO PARA BUSCAR SINISTROS RECENTES
  Future<void> _fetchRecentClaims() async {
    setState(() => _isLoading = true);

    try {
      final userId = _authService.getUserId();
      final role = await _authService.getUserRole();

      final results = await Future.wait([
        _firestoreService.getClaims(),
        _firestoreService.getAllClients(),
      ]);
      final allClaims = results[0] as List<Claim>;
      final allClients = results[1] as List<Client>;

      List<Claim> baseClaims;

      if (role == 'admin') {
        baseClaims = allClaims;
      } else {
        baseClaims = allClaims
            .where((c) =>
                c.responsavelId == userId || c.responsavelId == null)
            .toList();
      }

      final filtered = baseClaims;

      if (mounted) {
        setState(() {
          _recentClaims = filtered;
          _clients = allClients;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // FUNÇÃO PARA BUSCAR TAREFAS
  Future<void> _fetchTasks() async {
    try {
      final userId = _authService.getUserId();
      final role = await _authService.getUserRole();

      final snapshot = await _firestoreService.getTasksCollection().get();
      final allTasks = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        // ✅ Converter prazo de Timestamp para DateTime
        if (data['prazo'] is Timestamp) {
          data['prazo'] = (data['prazo'] as Timestamp).toDate();
        }
        return data;
      }).toList();

      if (role == 'admin') {
        _tasks = allTasks;
      } else {
        _tasks = allTasks
            .where((t) => t['responsavelId'] == userId)
            .toList();
      }
      if (mounted) setState(() {});
      //_verificarAlertas();
    } catch (e) {
      debugPrint('Erro ao buscar tasks: $e');
    }
  }

  // BUSCAR NPS MÉDIO DE TODOS OS CLIENTES
  Future<void> _fetchNpsMedia() async {
    try {
      final snapshot = await FirebaseFirestore.instance
        .collection('nps_pesquisas')
        .where('status', isEqualTo: 'respondida')
        .get();
      
      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() => _npsMedia = 0.0);
        return;
      }

      final dataLimite = DateTime.now().subtract(Duration(days: _periodoDias));
      final notas = snapshot.docs
          .where((doc) {
            final respondidoEm = doc.data()['respondidoEm'];
            if (respondidoEm == null) return false;
            final data = (respondidoEm as Timestamp).toDate();
            return data.isAfter(dataLimite);
          })
          .map((doc) => (doc.data()['nota'] as num?)?.toDouble() ?? 0.0)
          .where((nota) => nota > 0)
          .toList();

      if (snapshot.docs.isEmpty) {
        if (mounted) setState(() => _npsMedia = 0.0);
        return;
      }

      if (notas.isEmpty) {
        if (mounted) setState(() => _npsMedia = 0.0);
        return;
      }

      final media = notas.reduce((a, b) => a + b) / notas.length;
      if (mounted) setState(() => _npsMedia = media);
    } catch (e) {
      debugPrint('Erro ao buscar NPS: $e');
    }
  }

  // CALCULO DE PRIORIDADE DE TAREFA
  double calculateTaskPriority(Map<String, dynamic> t) {
    final prazo = t['prazo'] as DateTime; 
    final status = t['status'] ?? '';

    double score = 0;

    final diasRestantes = prazo.difference(DateTime.now()).inDays;

    // 🔴 atraso
    if (status != 'Concluída' && diasRestantes < 0) {
      score += 100;
    }

    // ⏱ proximidade
    score += (30 - diasRestantes.clamp(0, 30));

    // 🔥 bônus se for comunicação
    if ((t['descricao'] ?? '').contains('Atualizar cliente')) {
      score += 20;
    }

    return score;
  }

  // PRIORIDADE DE TASK
  double _taskScore(Map<String, dynamic> t) {
    final prazo = t['prazo'] as DateTime;
    final status = t['status'] ?? '';

    double score = 0;

    final dias = prazo.difference(DateTime.now()).inDays;

    if (status != 'Concluída' && dias < 0) score += 100;
    score += (30 - dias.clamp(0, 30));

    if ((t['descricao'] ?? '').contains('cliente')) score += 20;

    return score;
  }

  // TOP TASKS
  List<Map<String, dynamic>> _topTasks() {
    final abertas =
        _tasks.where((t) => t['status'] != 'Concluída').toList();

    abertas.sort((a, b) =>
        _taskScore(b).compareTo(_taskScore(a)));

    return abertas.take(5).toList();
  }

  // NOVO CARD DE TAREFAS
  Widget _buildTopTasks() {
    final tasks = _topTasks();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔥 O QUE VOCÊ PRECISA FAZER HOJE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          if (tasks.isEmpty)
            Text(
              'Nenhuma tarefa pendente 🎉',
              style: TextStyle(color: Colors.grey.shade500),
            ),

          ...tasks.map((t) {
            final prazo = t['prazo'] as DateTime;
            final dias = prazo.difference(DateTime.now()).inDays;

            final isLate = dias < 0;

            return ListTile(
              contentPadding: EdgeInsets.zero,

              onTap: () async {
                final claimId = t['claimId'];

                if (claimId == null || claimId.toString().isEmpty) {
                  debugPrint('Task sem claimId: ${t['descricao']}');
                  return;
                }

                try {
                  final claim = await _firestoreService.getClaimById(claimId);

                  if (claim != null) {
                    widget.onNavigate?.call(
                      ClaimDetailScreen(claim: claim),
                    );
                  }
                } catch (e) {
                  debugPrint('Erro ao abrir claim: $e');
                }
              },

              title: Text(t['descricao'] ?? ''),
              subtitle: Text(
                isLate
                    ? 'Atrasada há ${dias.abs()} dias'
                    : 'Prazo em $dias dias',
                style: TextStyle(
                  color: isLate ? Colors.red : Colors.orange,
                ),
              ),
              leading: Icon(
                isLate ? Icons.warning : Icons.schedule,
                color: isLate ? Colors.red : Colors.orange,
              ),

              // 🔥 opcional (recomendo MUITO)
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            );
          }),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // CÁLCULOS DE MÉTRICAS
  // ═════════════════════════════════════════════════════════════════════

  // ── Sinistros ativos (qualquer status exceto Concluído) ───────────────
  int get _totalAbertos {
    final dataLimite = DateTime.now().subtract(Duration(days: _periodoDias));
    return _recentClaims.where((c) => 
      c.statusAtual != 'Concluído' &&
      c.dataAbertura.isAfter(dataLimite)
    ).length;
  }

  // ── Prazo médio real: dataAbertura → dataUltimaAtualizacao dos concluídos
  double get _prazoMedio {
    final dataLimite = DateTime.now().subtract(Duration(days: _periodoDias));
    final concluidos = _recentClaims
        .where((c) => 
          c.statusAtual == 'Concluído' &&
          c.dataUltimaAtualizacao.isAfter(dataLimite)
        );
    if (concluidos.isEmpty) return 0;
    final dias = concluidos
        .map((c) => c.dataUltimaAtualizacao
            .difference(c.dataAbertura)
            .inDays
            .abs())
        .toList();
    return dias.reduce((a, b) => a + b) / dias.length;
  }

  // ── Custo médio: média de valorTotalSinistro de todos os sinistros ────
  double get _custoMedio {
    final dataLimite = DateTime.now().subtract(Duration(days: _periodoDias));
    final filtered = _recentClaims
        .where((c) => c.dataAbertura.isAfter(dataLimite))
        .toList();
    if (filtered.isEmpty) return 0;
    final valores = filtered
        .map((c) => c.valorTotalSinistro)
        .toList();
    return valores.reduce((a, b) => a + b) / valores.length;
  }

  // ── SLA: % de sinistros ativos dentro de 10 dias desde abertura ───────
  static const int _slaDias = 10;
  static const int _periodoDias = 30;
  double get _slaPercentage {
    final dataLimite = DateTime.now().subtract(Duration(days: _periodoDias));
    final ativos = _recentClaims
        .where((c) => 
          c.statusAtual != 'Concluído' &&
          c.dataAbertura.isAfter(dataLimite)
        )
        .toList();
    if (ativos.isEmpty) return 100;
    final dentroPrazo = ativos
        .where((c) =>
            DateTime.now().difference(c.dataAbertura).inDays <= _slaDias)
        .length;
    return (dentroPrazo / ativos.length) * 100;
  }

  // ── Taxa de Sinistralidade (Loss Ratio) ─────────────────────────────
  // sinistros pagos (concluídos) ÷ prêmios totais da carteira × 100
  double get _lossRatio {
    final dataLimite = DateTime.now().subtract(Duration(days: _periodoDias));
    final totalPago = _recentClaims
        .where((c) => 
          c.statusAtual == 'Concluído' &&
          c.valorTotalSinistro > 0 &&
          c.dataUltimaAtualizacao.isAfter(dataLimite)
        )
        .fold(0.0, (s, c) => s + c.valorTotalSinistro);
    final totalPremios = _clients
        .fold(0.0, (s, c) => s + c.valorTotalApolicesAtivas);  // ← MUDA
    if (totalPremios == 0) return 0;
    return (totalPago / totalPremios) * 100;
  }

  // ── Receita total da carteira (soma de totalReceita dos clientes) ─────
  double get _receitaCarteira =>
      _clients.fold(0.0, (s, c) => s + c.totalReceita);

  // ── Variação de novos sinistros: esta semana vs semana passada ────────
  int get _variacaoAbertos {
    final agora = DateTime.now();
    final ultimos30 = agora.subtract(Duration(days: _periodoDias));
    final dias30Anteriores = agora.subtract(Duration(days: _periodoDias * 2));

    final estasPeriodo = _recentClaims
        .where((c) => c.dataAbertura.isAfter(ultimos30))
        .length;
    final passadaPeriodo = _recentClaims
        .where((c) =>
            c.dataAbertura.isAfter(dias30Anteriores) &&
            c.dataAbertura.isBefore(ultimos30))
        .length;
    return estasPeriodo - passadaPeriodo;
  }

  // Agrupar por ramo
  Map<String, List<Claim>> get _claimsByRamo {
    final Map<String, List<Claim>> grouped = {};
    for (final claim in _recentClaims) {
      grouped.putIfAbsent(claim.ramoSinistro, () => []).add(claim);
    }
    return grouped;
  }

  // Variação de sinistros por ramo (últimos 30 dias vs 30 dias anteriores)
  Map<String, double> get _variacaoSinistrosPorRamo {
    final agora = DateTime.now();
    final ultimos30 = agora.subtract(Duration(days: _periodoDias));
    final dias30Anteriores = agora.subtract(Duration(days: _periodoDias * 2));

    final Map<String, double> variacoes = {};

    for (final ramo in _claimsByRamo.keys) {
      final estasPeriodo = _recentClaims
          .where((c) => 
            c.ramoSinistro == ramo &&
            c.dataAbertura.isAfter(ultimos30)
          )
          .length;

      final passadaPeriodo = _recentClaims
          .where((c) => 
            c.ramoSinistro == ramo &&
            c.dataAbertura.isAfter(dias30Anteriores) &&
            c.dataAbertura.isBefore(ultimos30)
          )
          .length;

      if (passadaPeriodo == 0) {
        variacoes[ramo] = estasPeriodo > 0 ? 100.0 : 0.0;
      } else {
        variacoes[ramo] = ((estasPeriodo - passadaPeriodo) / passadaPeriodo * 100);
      }
    }

    return variacoes;
  }

  // Retorna status e cor baseado na variação percentual
  Map<String, dynamic> _getStatusRamo(double variacao) {
    if (variacao >= 30) {
      return {
        'status': 'Em alta',
        'cor': Colors.red,
        'icon': '⚠️',
      };
    } else if (variacao >= 10) {
      return {
        'status': 'Em crescimento',
        'cor': Colors.orange,
        'icon': '📈',
      };
    } else if (variacao <= -10) {
      return {
        'status': 'Em redução',
        'cor': Colors.blue,
        'icon': '📉',
      };
    } else {
      return {
        'status': 'Estável',
        'cor': Colors.green,
        'icon': '✓',
      };
    }
  }

  // Sinistros críticos (SLA vencido ou vence em 24h)
  List<Claim> get _criticalClaims {
    return _recentClaims.where((c) {
      if (c.slaPrevisto == null || c.statusAtual == 'Concluído') return false;
      final diasRestantes = c.slaPrevisto!.difference(DateTime.now()).inDays;
      return diasRestantes < 1; // 🔴 Vencido ou vence hoje
    }).toList();
  }

  // Sinistros com atenção (SLA em 1-3 dias)
  List<Claim> get _attentionClaims {
    return _recentClaims.where((c) {
      if (c.slaPrevisto == null || c.statusAtual == 'Concluído') return false;
      final diasRestantes = c.slaPrevisto!.difference(DateTime.now()).inDays;
      return diasRestantes >= 1 && diasRestantes <= 3; // 🟠 Atenção (1-3 dias)
    }).toList();
  }

  // Sinistros em dia
  List<Claim> get _okClaims {
    return _recentClaims.where((c) {
      final daysOpen = DateTime.now().difference(c.dataAbertura).inDays;
      return daysOpen <= 10;
    }).toList();
  }

  // Sinistrios Parados
  List<Claim> get _semAtualizacao {
    return _recentClaims.where((c) {
      final dias = DateTime.now().difference(c.dataUltimaAtualizacao).inDays;
      return dias > 3 && c.statusAtual != 'Concluído';
    }).toList();
  }

  // CALCULO DE PRIORIDADE DE SINISTRO
  double calculatePriorityScore(Claim c) {
    final diasAberto = DateTime.now().difference(c.dataAbertura).inDays;
    final diasSemAtualizacao =
        DateTime.now().difference(c.dataUltimaAtualizacao).inDays;

    double score = 0;

    // 💰 Valor (peso alto)
    score += c.valorTotalSinistro / 1000;

    // ⏳ Tempo aberto
    score += diasAberto * 2;

    // 🧊 Sem atualização (CRÍTICO)
    score += diasSemAtualizacao * 5;

    // 🚨 Status crítico
    if (c.statusAtual == 'Aguardando Peças') score += 20;
    if (c.statusAtual == 'Aberto') score += 10;

    return score;
  }

  // GERAR PRIORIDADES
  List<Claim> getTopPriorities(List<Claim> claims, {int limit = 5}) {
    final sorted = [...claims];

    sorted.sort((a, b) =>
        calculatePriorityScore(b).compareTo(calculatePriorityScore(a)));

    return sorted.take(limit).toList();
  }

  Widget _buildTopPriorities() {
    final priorities = getTopPriorities(_recentClaims);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔥 PRIORIDADES DO DIA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          ...priorities.map((c) {
            final dias = DateTime.now().difference(c.dataUltimaAtualizacao).inDays;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${c.numeroSinistro} • ${c.clientNome}'),
              subtitle: Text(
                'R\$ ${c.valorTotalSinistro.toStringAsFixed(0)} • $dias dias sem atualização',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () {
                widget.onNavigate?.call(
                  ClaimDetailScreen(claim: c),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchRecentClaims,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SAUDAÇÃO
            _buildGreeting(),
            const SizedBox(height: 24),

            // BIG PICTURE CARD
            _buildExecutiveCardContent(),
            const SizedBox(height: 16),

            // PERFORMANCE POR RAMO
            _buildRamoPerformance(),
            const SizedBox(height: 16),

            // SEMÁFORO DE URGÊNCIA
            _buildUrgencySemaphore(),
            const SizedBox(height: 16),

            // ASSISTÊNCIAS
            _buildAssistenciasTimer(),
            const SizedBox(height: 16),

            _buildTopPriorities(),
            const SizedBox(height: 16),

            // PRÓXIMAS AÇÕES
            _buildTopTasks(),
            const SizedBox(height: 16),

            // AÇÕES RECOMENDADAS (dinâmico)
            _buildNextActions(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildGreeting() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Bom dia'
        : hour < 18
            ? 'Boa tarde'
            : 'Boa noite';

    final email = _authService.getUserEmail();
    final name =
        email.split('@').first[0].toUpperCase() + email.split('@').first.substring(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting, $name!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '${DateFormat('EEEE, d \'de\' MMMM', 'pt_BR').format(DateTime.now())} • Você tem ${_totalAbertos} sinistros ativos',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────
    Widget _buildExecutiveCardContent() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 0.5),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OVERVIEW DO NEGÓCIO',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            // 🔁 Wrap responsivo
            Wrap(
              spacing: 16,
              runSpacing: 20,
              children: [
                _KpiCard(
                  label: 'Em processamento',
                  value: _totalAbertos.toString(),
                  subtext: _variacaoAbertos == 0
                    ? 'Igual ao período anterior'
                    : _variacaoAbertos > 0
                        ? '↑ +$_variacaoAbertos vs período anterior'
                        : '↓ ${_variacaoAbertos} vs período anterior',
                  subtextColor: _variacaoAbertos > 0
                      ? Colors.orange
                      : _variacaoAbertos < 0
                          ? Colors.green
                          : Colors.grey,
                ),
                _KpiCard(
                  label: 'Prazo médio de resolução',
                  value: _prazoMedio.toStringAsFixed(1),
                  unit: 'dias',
                  subtext: _prazoMedio == 0
                      ? 'Nenhum concluído ainda'
                      : _prazoMedio <= 7
                          ? '✓ Dentro do esperado'
                          : _prazoMedio <= 14
                              ? '⚠ Acima do ideal'
                              : '⚠ Prazo elevado',
                  subtextColor: _prazoMedio <= 7
                      ? Colors.green
                      : _prazoMedio <= 14
                          ? Colors.orange
                          : Colors.red,
                ),
                _KpiCard(
                  label: 'Custo médio por sinistro',
                  value: 'R\$ ${(_custoMedio / 1000).toStringAsFixed(1)}k',
                  subtext: _custoMedio == 0
                      ? 'Sem dados de valor'
                      : 'Média da carteira ativa',
                  subtextColor: Colors.grey.shade600,
                ),
                _KpiCard(
                  label: 'SLA (≤ $_slaDias dias)',
                  value: _slaPercentage.toStringAsFixed(1),
                  unit: '%',
                  subtext: _slaPercentage >= 80
                      ? '✓ Meta atingida'
                      : _slaPercentage >= 60
                          ? '⚠ Abaixo da meta'
                          : '⚠ Crítico',
                  subtextColor: _slaPercentage >= 80
                      ? Colors.green
                      : _slaPercentage >= 60
                          ? Colors.orange
                          : Colors.red,
                  showDot: true,
                ),
                _KpiCard(
                  label: 'Taxa de Sinistralidade',
                  value: _lossRatio.toStringAsFixed(1),
                  unit: '%',
                  subtext: _clients.isEmpty
                      ? 'Cadastre clientes com valor de apólice'
                      : _lossRatio <= 60
                          ? '✓ Saudável (meta ≤ 60%)'
                          : _lossRatio <= 80
                              ? '⚠ Atenção — acima de 60%'
                              : '⚠ Crítico — acima de 80%',
                  subtextColor: _lossRatio <= 60
                      ? Colors.green
                      : _lossRatio <= 80
                          ? Colors.orange
                          : Colors.red,
                  showDot: true,
                ),
                _KpiCard(
                  label: 'NPS (Satisfação Média)',
                  value: _npsMedia.toStringAsFixed(1),
                  unit: 'pts',
                  subtext: _npsMedia == 0
                      ? 'Aguardando dados'
                      : _npsMedia >= 9
                          ? '✓ Promotor (≥9)'
                          : _npsMedia >= 7
                              ? '⚠ Neutro (7-8)'
                              : '⚠ Detrator (<7)',
                  subtextColor: _npsMedia >= 9
                      ? Colors.green
                      : _npsMedia >= 7
                          ? Colors.orange
                          : Colors.red,
                  showDot: true,
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),
          ],
        ),
      );
    }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildAssistenciasTimer() {
    if (_assistencias.isEmpty) return const SizedBox();

    // Ordena: vencidas primeiro, depois por menor tempo restante
    final sorted = [..._assistencias]..sort((a, b) {
      final slaA = a.slaAtendimento ?? a.slaPrevisto;
      final slaB = b.slaAtendimento ?? b.slaPrevisto;
      if (slaA == null && slaB == null) return 0;
      if (slaA == null) return 1;
      if (slaB == null) return -1;
      return slaA.compareTo(slaB);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
              const SizedBox(width: 6),
              Text('ATENÇÃO AOS PRAZOS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600, letterSpacing: 0.5)),
              const Spacer(),
              Text('${sorted.length} ativa${sorted.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.map((a) => _AssistTimerRow(
            assist: a,
            onTap: () => widget.onNavigate?.call(
                AssistListScreen(initialStatusFilter: ['Aberto', 'Em Andamento']),
            ),
          )),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildRamoPerformance() {
    final ramoMap = _claimsByRamo;

    // Métricas de assistência
    final totalAssist = _assistencias.length;
    final vencidas = _assistencias.where((a) {
      final sla = a.slaAtendimento ?? a.slaPrevisto;
      return sla != null && DateTime.now().isAfter(sla);
    }).length;
    final emRisco = _assistencias.where((a) {
      final sla = a.slaAtendimento ?? a.slaPrevisto;
      if (sla == null) return false;
      final min = sla.difference(DateTime.now()).inMinutes;
      return min >= 0 && min <= 15;
    }).length;

    // Cor de alerta do card de assistência
    final alertColor = vencidas > 0
        ? Colors.red
        : emRisco > 0
            ? Colors.orange
            : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE POR RAMO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Cards de ramo existentes
              ...ramoMap.entries.map((entry) {
                final ramo = entry.key;
                final claims = entry.value;
                final ticketMedio = claims.isEmpty
                    ? 0.0
                    : claims.map((c) => c.valorTotalSinistro)
                          .reduce((a, b) => a + b) / claims.length;
                final variacao = _variacaoSinistrosPorRamo[ramo] ?? 0.0;
                final statusInfo = _getStatusRamo(variacao);

                return _RamoCard(
                  ramo: ramo,
                  count: claims.length,
                  ticketMedio: ticketMedio,
                  statusInfo: statusInfo,
                  onTap: () => widget.onNavigate?.call(
                    ClaimListScreen(initialRamoFilter: ramo),
                  ),
                );
              }),

              // Card de Assistências
              GestureDetector(
                onTap: () => widget.onNavigate?.call(const AssistListScreen()),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: alertColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cabeçalho: emoji | título | badge
                      Row(
                        children: [
                          const Text('🚗', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          const Text('Assistências',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (vencidas > 0 || emRisco > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: alertColor, borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                vencidas > 0 ? '⚠️ $vencidas' : '⏱️ $emRisco',
                                style: const TextStyle(fontSize: 9, color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Métricas em 3 linhas
                      _assistRow(
                        cor: Colors.green,
                        label: 'No prazo',
                        valor: totalAssist - vencidas - emRisco,
                      ),
                      const SizedBox(height: 4),
                      _assistRow(
                        cor: Colors.orange,
                        label: 'Em risco',
                        valor: emRisco,
                      ),
                      const SizedBox(height: 4),
                      _assistRow(
                        cor: Colors.red,
                        label: 'Vencidas',
                        valor: vencidas,
                      ),
/*
                      const SizedBox(height: 10),
                      Text('Ver prazos ↓',
                          style: TextStyle(fontSize: 10, color: alertColor.withOpacity(0.7))),
*/
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

  // ─────────────────────────────────────────────────────────────────────
  Widget _buildUrgencySemaphore() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O QUE PRECISA DE AÇÃO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _UrgencySection(
            color: Colors.red,
            icon: '⚠️',
            title: 'CRÍTICO: ${_criticalClaims.length} sinistro(s) vencidos',
            claims: _criticalClaims,
          ),
          const SizedBox(height: 12),
          _UrgencySection(
            color: Colors.orange,
            icon: '🔔',
            title: 'ATENÇÃO: ${_attentionClaims.length} sinistro(s) em risco',
            claims: _attentionClaims,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // Ações recomendadas: geradas dinamicamente a partir dos dados reais
  Widget _buildNextActions() {
    // Monta lista de ações reais baseadas no estado atual
    final acoes = <Map<String, dynamic>>[];

    // Aprovações paradas há mais de 3 dias
    final aprovacoes = _recentClaims
        .where((c) =>
            c.statusAtual == 'Aguardando Aprovação' &&
            DateTime.now().difference(
              c.historicoStatus.isNotEmpty
                  ? (c.historicoStatus.last['data'] as Timestamp).toDate()
                  : c.dataAbertura,
            ).inDays >= 3)
        .toList();
    if (aprovacoes.isNotEmpty) {
      acoes.add({
        'icon': '⏳',
        'title': '${aprovacoes.length} aprovação(ões) parada(s) há 3+ dias',
        'claim': aprovacoes.first,
      });
    }

    // Reparos prolongados > 7 dias
    final reparos = _recentClaims
        .where((c) =>
            c.statusAtual == 'Reparo em Andamento' &&
            DateTime.now().difference(
              c.historicoStatus.isNotEmpty
                  ? (c.historicoStatus.last['data'] as Timestamp).toDate()
                  : c.dataAbertura,
            ).inDays >= 7)
        .toList();
    if (reparos.isNotEmpty) {
      acoes.add({
        'icon': '🔧',
        'title': '${reparos.length} veículo(s) em reparo há 7+ dias — risco de reserva',
        'claim': reparos.first,
      });
    }

    // Contratos com apólices vencendo em 7 dias
    final now = DateTime.now();
    final setenDias = now.add(const Duration(days: 7));
    final vencendo = _clients
        .where((c) {
          return c.apolices.any((a) =>
            a.dataFim.isAfter(now) && a.dataFim.isBefore(setenDias)
          );
        })
        .toList();
    if (vencendo.isNotEmpty) {
      acoes.add({
        'icon': '📅',
        'title': '${vencendo.length} contrato(s) vence(m) esta semana — contatar clientes',
        'claim': null,
      });
    }

    // Top prioridade por score (se não vier das categorias acima)
    final topPriority = getTopPriorities(_recentClaims, limit: 1);
    if (topPriority.isNotEmpty && acoes.isEmpty) {
      final c = topPriority.first;
      final dias = DateTime.now()
          .difference(c.dataUltimaAtualizacao)
          .inDays;
      acoes.add({
        'icon': '🔥',
        'title':
            '${c.numeroSinistro} · ${c.clientNome} — $dias dias sem atualização',
        'claim': c,
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AÇÕES RECOMENDADAS AGORA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (acoes.isEmpty)
            Text(
              'Tudo em dia! Nenhuma ação urgente no momento.',
              style: TextStyle(color: Colors.green.shade600),
            )
          else
            ...acoes.map((a) {
              final claim = a['claim'] as Claim?;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActionButton(
                  icon: a['icon'] as String,
                  title: a['title'] as String,
                  onTap: () {
                    if (claim != null) {
                      widget.onNavigate?.call(
                          ClaimDetailScreen(claim: claim));
                    }
                  },
                ),
              );
            }),
        ],
      ),
    );
  }

  // WIDGET PARA FORMATAR LINHAS NO CARD DE ASSISTÊNCIA
  Widget _assistRow({required Color cor, required String label, required int valor}) {
    return Row(
      children: [
        Container(width: 8, height: 8,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700))),
        Text(valor.toString(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cor)),
      ],
    );
  }

}

// ═════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═════════════════════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String subtext;
  final Color subtextColor;
  final bool showDot;

  const _KpiCard({
    required this.label,
    required this.value,
    this.unit = '',
    required this.subtext,
    required this.subtextColor,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200, // largura fixa responsiva – ajuste conforme necessário
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (showDot) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                unit.isEmpty ? value : '$value $unit',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtext,
            style: TextStyle(fontSize: 11, color: subtextColor),
          ),
        ],
      ),
    );
  }
}

class _RamoCard extends StatelessWidget {
  final String ramo;
  final int count;
  final double ticketMedio;
  final Map<String, dynamic> statusInfo; // 🆕 SUBSTITUI variacao
  final VoidCallback onTap;

  const _RamoCard({
    required this.ramo,
    required this.count,
    required this.ticketMedio,
    required this.statusInfo, // 🆕 NOVO
    required this.onTap,
  });

  String get _emoji {
    switch (ramo) {
      case 'Frota':
        return '🚗';
      case 'Transporte':
        return '📦';
      case 'Residencial':
        return '🏠';
      case 'Vidas':
        return '👤';
      default:
        return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$_emoji $ramo',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 8),
              Text('$count abertos',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 4),
              Text(
                'Ticket: R\$ ${(ticketMedio / 1000).toStringAsFixed(1)}k',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                '${statusInfo['icon']} ${statusInfo['status']}',
                style: TextStyle(
                  fontSize: 10, 
                  color: statusInfo['cor'] as Color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencySection extends StatelessWidget {
  final Color color;
  final String icon;
  final String title;
  final List<Claim> claims;
  final Function(Widget)? onNavigate;

  const _UrgencySection({
    required this.color,
    required this.icon,
    required this.title,
    required this.claims,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color == Colors.red
        ? Colors.red.shade50
        : color == Colors.orange
            ? Colors.orange.shade50
            : Colors.green.shade50;

    final hasAction = claims.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: hasAction
          ? () {
              if (claims.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClaimDetailScreen(claim: claims.first),
                  ),
                );
              }
            }
          : null,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 HEADER
              Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  if (hasAction)
                    Icon(Icons.arrow_forward_ios,
                        size: 12, color: color.withOpacity(0.7)),
                ],
              ),

              // 🔥 LISTA RESUMIDA (máx 3)
              if (claims.isNotEmpty) ...[
                const SizedBox(height: 8),

                ...claims.take(3).map((claim) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${claim.numeroSinistro} · ${claim.clientNome}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  );
                }).toList(),

                // 🔥 MAIS ITENS
                if (claims.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '+${claims.length - 3} outros...',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String title;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200, width: 0.5),
          ),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text('→',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistTimerRow extends StatefulWidget {
  final Claim assist;
  final VoidCallback onTap;
  const _AssistTimerRow({required this.assist, required this.onTap});

  @override
  State<_AssistTimerRow> createState() => _AssistTimerRowState();
}

class _AssistTimerRowState extends State<_AssistTimerRow> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sla = widget.assist.slaAtendimento ?? widget.assist.slaPrevisto;
    final agora = DateTime.now();
    final diff = sla != null ? sla.difference(agora) : null;
    final vencido = diff != null && diff.isNegative;
    final minutos = diff != null ? diff.inMinutes.abs() : null;
    final horas = minutos != null ? minutos ~/ 60 : null;
    final mins = minutos != null ? minutos % 60 : null;

    // Cor baseada no tempo restante
    Color cor;
    if (diff == null) {
      cor = Colors.grey;
    } else if (vencido) {
      cor = Colors.red;
    } else if (diff.inMinutes <= 15) {
      cor = Colors.orange;
    } else {
      cor = Colors.green;
    }

    final tipoLabel = TipoAssistencia.values
        .firstWhere((t) => t.value == widget.assist.tipoAssistencia,
            orElse: () => TipoAssistencia.outro)
        .label;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            // Mini-relógio digital
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  Text(
                    diff == null
                        ? '--:--'
                        : '${horas!.toString().padLeft(2, '0')}:${mins!.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: cor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    vencido ? 'ATRASADO' : 'restante',
                    style: TextStyle(fontSize: 8, color: cor,
                        fontWeight: FontWeight.w600, letterSpacing: 0.3),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.assist.clientNome,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '$tipoLabel • ${widget.assist.statusAtual}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                  if (widget.assist.localOcorrencia.isNotEmpty)
                    Text(
                      widget.assist.localOcorrencia,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}