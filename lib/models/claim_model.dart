import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:upgrade_seguros/models/house_model.dart';
import 'package:upgrade_seguros/models/life_model.dart';
import 'package:upgrade_seguros/models/machinery_model.dart';
import 'package:upgrade_seguros/models/third_party_model.dart';
import 'package:upgrade_seguros/models/transport_model.dart';
import 'package:upgrade_seguros/models/vehicle_model.dart';
import 'package:upgrade_seguros/models/workshop_model.dart';

// Enum para tipos de atendimento
enum TipoAtendimento {
  sinistro('sinistro', 'Sinistro'),
  assistencia('assistencia', 'Assistência');

  final String value;
  final String label;
  const TipoAtendimento(this.value, this.label);

  factory TipoAtendimento.fromString(String? value) {
    return TipoAtendimento.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoAtendimento.sinistro,
    );
  }
}

// Enum para tipos de assistência
enum TipoAssistencia {
  guincho('guincho', 'Guincho'),
  vidro('vidro', 'Vidro Quebrado'),
  combustivel('combustivel', 'Combustível'),
  paneEletrica('pane_eletrica', 'Pane Elétrica'),
  cargaBateria('carga_bateria', 'Carga de Bateria'),
  falta('falta', 'Falta de Peça'),
  reboque('reboque', 'Reboque'),
  outro('outro', 'Outro');

  final String value;
  final String label;
  const TipoAssistencia(this.value, this.label);

  factory TipoAssistencia.fromString(String? value) {
    return TipoAssistencia.values.firstWhere(
      (e) => e.value == value,
      orElse: () => TipoAssistencia.outro,
    );
  }
}

class Claim {
  String id;
  String? responsavelId;
  String idCliente;
  String numeroSinistro;
  String tipoOcorrencia;
  String ramoSinistro;
  DateTime dataOcorrencia;
  DateTime dataAviso;
  String localOcorrencia;
  String relatoEvento;
  String statusAtual;
  String tipoPerda;
  bool requerAprovacaoGerencial;
  bool aprovadoPorGerente;
  DateTime dataAbertura;
  DateTime dataUltimaAtualizacao;
  DateTime? dataPrevisaoConclusao;
  List<String> fotosUrls;
  List<String> arquivosLaudosUrls;
  List<Map<String, dynamic>> historicoStatus;
  List<Map<String, dynamic>> anotacoes;
  List<ThirdParty> terceiros;
  Vehicle? veiculoSelecionado;
  Transport? transporte;
  Machinery? maquinaria;  // 🆕 Novo campo para Máquinas
  double valorTotalSinistro;
  String clientNome;
  String clientCnpjCpf;
  String numeroSeguradora;
  String seguradora;
  String status;
  final House? house;
  final Life? life;
  final Workshop? workshop;
  List<Workshop> oficinas;
  String enderecoTerceiro;
  String? localDestino;         // destino do bem segurado (ex: oficina) — só assistência
  String? nomeContato;
  String? telefoneCliente;      // telefone do cliente copiado no momento da abertura
  String? telefoneContatoLocal;
  String? protocoloSeguradora;
  double valorFranquia;
  DateTime? dataAgendamento;   // data do agendamento da assistência
  String? horaAgendamento;     // hora no formato 'HH:mm'

  // 🆕 CAMPOS NOVOS PARA SINISTRO × ASSISTÊNCIA
  String tipo; // "sinistro" ou "assistencia"
  String? tipoAssistencia; // "guincho", "vidro", "combustivel", etc. (só para assistência)
  DateTime? slaPrevisto; // Data/hora prevista para resolução da assistência
  DateTime? slaAlertadoEm; // Quando o alerta foi acionado
  DateTime? slaAtendimento;
  bool slaExcedido; // Flag para fácil filtragem
  int? tempoSlaMinutos; // Tempo configurado para este tipo de assistência
  String? nomeContatoOficina;
  String? telefoneContatoOficina;
  bool npsAvaliada;
  double? npsSatisfacao;
  String? npsCategoria;
  int totalReagendamentos;
  Timestamp? dataConclusao;

  Claim({
    this.id = '',
    this.responsavelId,
    required this.idCliente,
    required this.numeroSinistro,
    required this.tipoOcorrencia,
    required this.ramoSinistro,
    required this.dataOcorrencia,
    required this.dataAviso,
    required this.localOcorrencia,
    required this.relatoEvento,
    this.statusAtual = 'Aberto',
    this.tipoPerda = 'PARCIAL',
    this.requerAprovacaoGerencial = false,
    this.aprovadoPorGerente = false,
    required this.dataAbertura,
    required this.dataUltimaAtualizacao,
    this.fotosUrls = const [],
    this.arquivosLaudosUrls = const [],
    this.historicoStatus = const [],
    this.anotacoes = const [],
    this.terceiros = const [],
    this.veiculoSelecionado,
    this.transporte,
    this.workshop,
    this.maquinaria,
    this.valorTotalSinistro = 0.0,
    required this.clientNome,
    required this.clientCnpjCpf,
    required this.numeroSeguradora,
    required this.seguradora,
    required this.status,
    this.telefoneContatoLocal,
    this.house,
    this.life,
    this.oficinas = const [],
    required this.enderecoTerceiro,
    this.localDestino,
    this.nomeContato,
    this.telefoneCliente,
    this.protocoloSeguradora,
    this.valorFranquia = 0.0,
    this.dataAgendamento,
    this.horaAgendamento,
    this.slaAtendimento,
    // 🆕 NOVOS PARÂMETROS
    this.tipo = 'sinistro',
    this.tipoAssistencia,
    this.slaPrevisto,
    this.slaAlertadoEm,
    this.slaExcedido = false,
    this.tempoSlaMinutos,
    this.nomeContatoOficina,
    this.telefoneContatoOficina,
    this.totalReagendamentos = 0,
    this.npsAvaliada = false,
    this.npsSatisfacao,
    this.npsCategoria,
    this.dataConclusao,
  });

  // Helper para verificar se é sinistro
  bool get isSinistro => tipo == 'sinistro';

  // Helper para verificar se é assistência
  bool get isAssistencia => tipo == 'assistencia';

  // Helper para calcular se SLA foi excedido
  bool get slaPassed {
    if (slaPrevisto == null) return false;
    return DateTime.now().isAfter(slaPrevisto!);
  }

  // Helper para calcular tempo restante em minutos
  int? get minutosRestantes {
    if (slaPrevisto == null) return null;
    final diff = slaPrevisto!.difference(DateTime.now());
    return diff.inMinutes;
  }

  // Helper para calcular percentual de SLA decorrido
  double? get percentualSlaDecorrido {
    if (dataAbertura == null || slaPrevisto == null || tempoSlaMinutos == null) {
      return null;
    }
    final totalMinutos = slaPrevisto!.difference(dataAbertura).inMinutes;
    if (totalMinutos == 0) return 0;
    final decorrido = DateTime.now().difference(dataAbertura).inMinutes;
    return (decorrido / totalMinutos).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() {
    return {
      'id_cliente': idCliente,
      'responsavel_id': responsavelId,
      'numero_sinistro': numeroSinistro,
      'tipo_ocorrencia': tipoOcorrencia,
      'ramo_sinistro': ramoSinistro,
      'data_ocorrencia': Timestamp.fromDate(dataOcorrencia),
      'data_aviso': Timestamp.fromDate(dataAviso),
      'local_ocorrencia': localOcorrencia,
      'relatoEvento': relatoEvento,
      'status_atual': statusAtual,
      'tipoPerda': tipoPerda,
      'requer_aprovacao_gerencial': requerAprovacaoGerencial,
      'aprovado_por_gerente': aprovadoPorGerente,
      'data_abertura': Timestamp.fromDate(dataAbertura),
      'data_ultima_atualizacao': Timestamp.fromDate(dataUltimaAtualizacao),
      'data_previsao_conclusao': dataPrevisaoConclusao,
      'fotos_urls': fotosUrls,
      'arquivos_laudos_urls': arquivosLaudosUrls,
      'historico_status': historicoStatus,
      'anotacoes': anotacoes,
      'terceiros': terceiros.map((tp) => tp.toMap()).toList(),
      'veiculo_selecionado': veiculoSelecionado?.toMap(),
      'transporte': transporte?.toMap(),
      'workshop': workshop?.toMap(),
      if (maquinaria != null) 'maquinaria': maquinaria!.toMap(),  // 🆕
      'valor_total_sinistro': valorTotalSinistro,
      'client_nome': clientNome,
      'client_cnpj_cpf': clientCnpjCpf,
      'numero_seguradora': numeroSeguradora,
      'seguradora': seguradora,
      if (telefoneContatoLocal != null) 'telefone_contato_local': telefoneContatoLocal,
      'status': status,
      'oficinas': oficinas.map((o) => o.toMap()).toList(),
      if (house != null) 'house': house!.toMap(),
      if (life != null) 'life': life!.toMap(),
      'endereco_terceiro': enderecoTerceiro,
      if (localDestino != null) 'local_destino': localDestino,
      if (nomeContato != null) 'nome_contato': nomeContato,
      if (telefoneCliente != null) 'telefone_cliente': telefoneCliente,
      if (protocoloSeguradora != null) 'protocolo_seguradora': protocoloSeguradora,
      if (valorFranquia > 0) 'valor_franquia': valorFranquia,
      if (dataAgendamento != null) 'data_agendamento': Timestamp.fromDate(dataAgendamento!),
      if (horaAgendamento != null) 'hora_agendamento': horaAgendamento,
      if (slaAtendimento != null) 'sla_atendimento': Timestamp.fromDate(slaAtendimento!),
      // 🆕 NOVOS CAMPOS
      'tipo': tipo,
      if (tipoAssistencia != null) 'tipo_assistencia': tipoAssistencia,
      if (slaPrevisto != null) 'sla_previsto': Timestamp.fromDate(slaPrevisto!),
      if (slaAlertadoEm != null) 'sla_alertado_em': Timestamp.fromDate(slaAlertadoEm!),
      'sla_excedido': slaExcedido,
      if (tempoSlaMinutos != null) 'tempo_sla_minutos': tempoSlaMinutos,
      if (nomeContatoOficina != null) 'nome_contato_oficina': nomeContatoOficina,
      if (telefoneContatoOficina != null) 'telefone_contato_oficina': telefoneContatoOficina,
      'total_reagendamentos': totalReagendamentos,
      'nps_avaliada': npsAvaliada,
      if (npsSatisfacao != null) 'nps_satisfacao': npsSatisfacao,
      if (npsCategoria != null) 'nps_categoria': npsCategoria,
      'dataConclusao': dataConclusao,
    };
  }

  factory Claim.fromMap(Map<String, dynamic> map) {
    return Claim(
      id: map['id'] ?? '',
      responsavelId: map['responsavel_id'],
      idCliente: map['id_cliente'] ?? '',
      numeroSinistro: map['numero_sinistro'] ?? '',
      tipoOcorrencia: map['tipo_ocorrencia'] ?? '',
      ramoSinistro: map['ramo_sinistro'] ?? '',
      dataOcorrencia: (map['data_ocorrencia'] as Timestamp).toDate(),
      dataAviso: map['data_aviso'] != null
          ? (map['data_aviso'] as Timestamp).toDate()
          : (map['data_ocorrencia'] as Timestamp).toDate(),
      localOcorrencia: map['local_ocorrencia'] ?? '',
      relatoEvento: map['relatoEvento'] ?? '',
      statusAtual: map['status_atual'] ?? 'Aberto',
      tipoPerda: (map['tipoPerda'] ?? 'PARCIAL').toString().toUpperCase(),
      requerAprovacaoGerencial: map['requer_aprovacao_gerencial'] ?? false,
      aprovadoPorGerente: map['aprovado_por_gerente'] ?? false,
      dataAbertura: (map['data_abertura'] as Timestamp).toDate(),
      dataUltimaAtualizacao: (map['data_ultima_atualizacao'] as Timestamp).toDate(),
      fotosUrls: (map['fotos_urls'] as List<dynamic>?)
              ?.map((url) => url.toString())
              .toList() ?? [],
      arquivosLaudosUrls: (map['arquivos_laudos_urls'] as List<dynamic>?)
              ?.map((url) => url.toString())
              .toList() ?? [],
      historicoStatus: (map['historico_status'] as List<dynamic>?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ?? [],
      anotacoes: (map['anotacoes'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ?? [],
      terceiros: (map['terceiros'] as List<dynamic>?)
              ?.map((tp) => ThirdParty.fromMap(tp as Map<String, dynamic>))
              .toList() ?? [],
      veiculoSelecionado: map['veiculo_selecionado'] != null
          ? Vehicle.fromMap(Map<String, dynamic>.from(map['veiculo_selecionado']))
          : null,
      transporte: map['transporte'] != null
          ? Transport.fromMap(Map<String, dynamic>.from(map['transporte']))
          : null,
      workshop: map['workshop'] != null ? Workshop.fromMap(map['workshop']) : null,
      maquinaria: map['maquinaria'] != null
    ? Machinery.fromMap(map['maquinaria'] as Map<String, dynamic>)
    : null,  // 🆕
      valorTotalSinistro: (map['valor_total_sinistro'] ?? 0.0).toDouble(),
      clientNome: map['client_nome'] ?? '',
      clientCnpjCpf: map['client_cnpj_cpf'] ?? '',
      numeroSeguradora: map['numero_seguradora'] ?? '',
      seguradora: map['seguradora'] ?? '',
      telefoneContatoLocal: map['telefone_contato_local'],
      status: map['status'] ?? '',
      house: map['house'] != null ? House.fromMap(map['house']) : null,
      life: map['life'] != null ? Life.fromMap(map['life']) : null,
      oficinas: (map['oficinas'] as List<dynamic>?)
              ?.map((o) => Workshop.fromMap(o as Map<String, dynamic>))
              .toList() ?? [],
      enderecoTerceiro: map['endereco_terceiro'] ?? '',
      localDestino: map['local_destino'],
      nomeContato: map['nome_contato'],
      telefoneCliente: map['telefone_cliente'],
      protocoloSeguradora: map['protocolo_seguradora'],
      valorFranquia: (map['valor_franquia'] ?? 0.0).toDouble(),
      dataAgendamento: map['data_agendamento'] != null
          ? (map['data_agendamento'] as Timestamp).toDate()
          : null,
      horaAgendamento: map['hora_agendamento'],
      slaAtendimento: map['sla_atendimento'] != null
          ? (map['sla_atendimento'] as Timestamp).toDate() : null,
      // 🆕 NOVOS CAMPOS
      tipo: map['tipo'] ?? 'sinistro',
      tipoAssistencia: map['tipo_assistencia'],
      slaPrevisto: map['sla_previsto'] != null
          ? (map['sla_previsto'] as Timestamp).toDate()
          : null,
      slaAlertadoEm: map['sla_alertado_em'] != null
          ? (map['sla_alertado_em'] as Timestamp).toDate()
          : null,
      slaExcedido: map['sla_excedido'] ?? false,
      tempoSlaMinutos: map['tempo_sla_minutos'],
      nomeContatoOficina: map['nome_contato_oficina'],
      telefoneContatoOficina: map['telefone_contato_oficina'],
      totalReagendamentos: (map['total_reagendamentos'] ?? 0).toInt(),
      npsAvaliada: map['nps_avaliada'] ?? false,
      npsSatisfacao: (map['nps_satisfacao'] as num?)?.toDouble(),
      npsCategoria: map['nps_categoria'],
      dataConclusao: map['dataConclusao'] as Timestamp?,
    );
  }

  factory Claim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Claim.fromMap({
      ...data,
      'id': doc.id,
    });
  }
}