import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/models/claim_model.dart';
import 'package:upgrade_seguros/services/notification_service.dart';

class SlaMonitorService {
  static final SlaMonitorService _instance = SlaMonitorService._internal();
  factory SlaMonitorService() => _instance;
  SlaMonitorService._internal();

  Timer? _timer;
  List<Claim> _assistencias = [];
  List<Map<String, dynamic>> _tasks = [];
  final Set<String> _alertadosRecentemente = {};
  // Etapa 14: controle do aviso de tarefas atrasadas (um aviso agrupado).
  int _ultimoTotalAtrasadas = 0;
  DateTime? _ultimoAvisoTarefas;

  bool get isRunning => _timer != null;

  void startMonitoring() {
    if (_timer != null) return;
    _loadDataAndCheck(); // verifica imediatamente
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _loadDataAndCheck();
    });
    print('🟢 SlaMonitorService iniciado');
  }

  void stopMonitoring() {
    _timer?.cancel();
    _timer = null;
    print('🔴 SlaMonitorService parado');
  }

  Future<void> _loadDataAndCheck() async {
    await _fetchAssistencias();
    await _fetchTasks();
    _checkAlerts();
  }

  Future<void> _fetchAssistencias() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('assistencias')
          .where('status_atual', whereNotIn: ['Concluído', 'Cancelado'])
          .get();
      _assistencias = snapshot.docs
          .map((doc) => Claim.fromMap({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Erro ao buscar assistências: $e');
    }
  }

  Future<void> _fetchTasks() async {
    try {
      // Etapa 14: só as abertas — antes lia TODAS as tarefas a cada 30 s
      // (cada documento lido é cobrado pelo Firestore).
      final snapshot = await FirebaseFirestore.instance
          .collection('tasks')
          .where('status', isNotEqualTo: 'Concluída')
          .get();
      _tasks = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        if (data['prazo'] is Timestamp) {
          data['prazo'] = (data['prazo'] as Timestamp).toDate();
        }
        return data;
      }).toList();
    } catch (e) {
      print('Erro ao buscar tasks: $e');
    }
  }

  void _checkAlerts() {
    final agora = DateTime.now();

    for (final a in _assistencias) {
      final sla = a.slaAtendimento ?? a.slaPrevisto;
      if (sla == null) continue;
      final diff = sla.difference(agora).inMinutes;
      final chave = '${a.id}_${diff < 0 ? 'vencido' : 'risco'}';
      if (_alertadosRecentemente.contains(chave)) continue;

      if (diff < 0) {
        _alertadosRecentemente.add(chave);
        _showAlert(
          titulo: '🚨 Assistência Vencida!',
          corpo: '${a.clientNome} — ${_getTipoAssistLabel(a.tipoAssistencia)} está ${diff.abs()}min atrasada.',
          claimId: a.id,
          tipo: 'assistencia',
        );
        Future.delayed(const Duration(seconds: 120), () => _alertadosRecentemente.remove(chave));
      } else if (diff <= 15) {
        _alertadosRecentemente.add(chave);
        _showAlert(
          titulo: '⚠️ Assistência em Risco!',
          corpo: '${a.clientNome} — ${_getTipoAssistLabel(a.tipoAssistencia)} vence em ${diff}min.',
          claimId: a.id,
          tipo: 'assistencia',
        );
        Future.delayed(const Duration(seconds: 120), () => _alertadosRecentemente.remove(chave));
      }
    }

    // Etapa 14: o alerta de tarefa atrasada nunca disparava (procurava o campo
    // 'taskId', que não existe no documento — o id vem em 'id'). Ligado agora,
    // mas sem enxurrada: UM aviso com o total de tarefas atrasadas de QUEM ESTÁ
    // LOGADO, quando o total aumenta ou no máximo uma vez por hora.
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      final emailUsuario = (usuario.email ?? '').toLowerCase();
      final atrasadas = _tasks.where((t) {
        final prazo = t['prazo'] as DateTime?;
        final status = t['status'] as String? ?? '';
        if (prazo == null || status == 'Concluída') return false;
        final id = t['responsavelId'] as String? ?? '';
        final email = (t['responsavelEmail'] as String? ?? '').toLowerCase();
        final minha = id == usuario.uid || (id.isEmpty && email.isNotEmpty && email == emailUsuario);
        return minha && agora.isAfter(DateTime(prazo.year, prazo.month, prazo.day, 23, 59, 59));
      }).toList();

      final total = atrasadas.length;
      final ultimo = _ultimoAvisoTarefas;
      final passouUmaHora = ultimo == null || agora.difference(ultimo).inMinutes >= 60;
      if (total > 0 && (total > _ultimoTotalAtrasadas || passouUmaHora)) {
        _ultimoAvisoTarefas = agora;
        final primeira = atrasadas.first;
        _showAlert(
          titulo: '📋 Tarefa Atrasada!',
          corpo: total == 1
              ? '${primeira['descricao'] ?? 'Tarefa'} está fora do prazo.'
              : 'Você tem $total tarefas fora do prazo. Veja em Tarefas.',
          claimId: primeira['claimId'] as String? ?? '',
          tipo: primeira['tipo'] as String? ?? 'sinistro',
        );
      }
      _ultimoTotalAtrasadas = total;
    }
  }

  void _showAlert({
    required String titulo,
    required String corpo,
    required String claimId,
    required String tipo,
  }) {
    // Exibe notificação flutuante global
    NotificationService.showFloatingNotification(
      titulo,
      corpo,
      backgroundColor: titulo.contains('Vencido') ? Colors.red : Colors.orange,
    );

    // (opcional) notificação nativa do navegador
    // ... seu código JS aqui
  }

  String _getTipoAssistLabel(String? tipo) {
    const map = {
      'guincho': 'Guincho',
      'vidro': 'Vidros',
      'combustivel': 'Combustível',
      'pane_eletrica': 'Pane Elétrica',
      'carga_bateria': 'Carga de Bateria',
      'falta': 'Falta de Peça',
      'reboque': 'Reboque',
      'outro': 'Outro',
    };
    return map[tipo] ?? 'Assistência';
  }
}