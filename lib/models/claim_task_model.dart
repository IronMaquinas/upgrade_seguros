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
    );
  }
}