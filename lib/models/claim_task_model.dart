import 'package:cloud_firestore/cloud_firestore.dart';

class ClaimTask {
  String id;
  String descricao;
  String status; // 'Pendente', 'Aberta', 'Concluída'
  DateTime prazo;

  String claimId;
  String numeroSinistro;

  String responsavelId;
  String responsavelEmail;

  DateTime criadoEm;

  /// Etapa 10: quando foi concluída (gravado a partir da Etapa 10).
  DateTime? concluidaEm;

  ClaimTask({
    this.id = '',
    required this.descricao,
    required this.status,
    required this.prazo,
    required this.claimId,
    required this.numeroSinistro,
    required this.responsavelId,
    required this.responsavelEmail,
    required this.criadoEm,
    this.concluidaEm,
  });

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'status': status,
      'prazo': Timestamp.fromDate(prazo),
      'claimId': claimId,
      'numeroSinistro': numeroSinistro,
      'responsavelId': responsavelId,
      'responsavelEmail': responsavelEmail,
      'criado_em': Timestamp.fromDate(criadoEm),
      if (concluidaEm != null) 'concluida_em': Timestamp.fromDate(concluidaEm!),
    };
  }

  factory ClaimTask.fromMap(Map<String, dynamic> map, String documentId) {
    return ClaimTask(
      id: documentId,
      descricao: map['descricao'] ?? '',
      status: map['status'] ?? 'Pendente',
      prazo: (map['prazo'] as Timestamp).toDate(),
      claimId: map['claimId'] ?? '',
      numeroSinistro: map['numeroSinistro'] ?? '',
      responsavelId: map['responsavelId'] ?? '',
      responsavelEmail: map['responsavelEmail'] ?? '',
      criadoEm: (map['criado_em'] as Timestamp?)?.toDate() ?? DateTime.now(),
      concluidaEm: (map['concluida_em'] as Timestamp?)?.toDate(),
    );
  }
}