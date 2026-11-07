// lib/models/report_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';

class ReportData {
  final int totalSinistros;
  final double valorTotalSinistros;
  final double valorTotalApolices;
  final double sinistralidade;
  final double tempoMedioResolucao;
  final Map<String, int> porStatus;
  final Map<String, int> porFuncionario;
  final Map<String, double> tempoMedioEtapa;
  final Map<String, double> tempoMedioFuncionario;
  final List<ClaimAtraso> aprovacoesParadas;
  final List<ClaimAtraso> reparosProlongados;
  final List<ClaimAtraso> emAtraso;
  final List<Client> contratosProximos;
  final List<ClienteRisco> clientesAltoRisco;
  final double npsMedia;
  final Map<String, int> npsCategoria;
  final int totalPesquisasEnviadas;
  final int totalPesquisasRespondidas;
  final double tempoMedioSinistros;
  final double tempoMedioAssistencias;
  final Map<String, int> assistenciasPorRamo;
  final Map<String, int> assistenciasPorTipo;
  final double percentualComTerceiros;
  final Map<String, int> sinistrosPorHorario;
  final Map<int, int> sinistrosPorDia;
  final Map<String, int> sinistrosPorRamo;
  final Map<int, double> npsPoMes;
  final Map<int, int> sinistrosPoMes;
  final Map<int, int> assistenciasPoMes;
  final Map<int, double> sinistralidadePoMes;
  final Map<int, int> contratosAtivosPoMes;
  final Map<int, Map<String, int>> contratosPoRamoMes;
  final Map<int, double> valorApolicesPoMes;
  final Map<int, double> ticketMedioPoMes;
  final Map<int, double> taxaRetencaoPoMes;
  final Map<int, double> slaComplianceSinistrosPoMes;
  final Map<int, double> slaComplianceAssistenciasPoMes;
  final Map<String, int> assistenciasPorHorario;
  final Map<int, int> assistenciasPorDia;
  final Map<String, double> sinistralidadePorSeguradora;
  final Map<String, double> mixCarteira;

  const ReportData({
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
    required this.assistenciasPorHorario,
    required this.assistenciasPorDia,
    required this.sinistralidadePorSeguradora,
    required this.mixCarteira,
  });
}

class ClaimAtraso {
  final Claim claim;
  final int diasSemMovimentacao;
  const ClaimAtraso(this.claim, this.diasSemMovimentacao);
}

class ClienteRisco {
  final Client client;
  final double sinistralidade;
  final double totalSinistros;
  const ClienteRisco(this.client, this.sinistralidade, this.totalSinistros);
}