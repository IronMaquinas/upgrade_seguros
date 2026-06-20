class Life {
  final String localLife;
  final String nomeSegurado;
  final String cpfSegurado;
  final int idadeSegurado;
  final String? telefone;
  final String? email;
  final String? parentesco;
  final String causaMorte;
  final List<String> fotosUrls;
  final List<String> documentosUrls;

  Life({
    required this.localLife,
    required this.nomeSegurado,
    required this.cpfSegurado,
    required this.idadeSegurado,
    this.telefone,
    this.email,
    this.parentesco,
    required this.causaMorte,
    required this.fotosUrls,
    required this.documentosUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'localLife': localLife,
      'nomeSegurado': nomeSegurado,
      'cpfSegurado': cpfSegurado,
      'idadeSegurado': idadeSegurado,
      if (telefone != null) 'telefone': telefone,
      if (email != null) 'email': email,
      if (parentesco != null) 'parentesco': parentesco,
      'causaMorte': causaMorte,
      'fotosUrls': fotosUrls,
      'documentosUrls': documentosUrls,
    };
  }

  factory Life.fromMap(Map<String, dynamic> map) {
    return Life(
      localLife: map['localLife'],
      nomeSegurado: map['nomeSegurado'],
      cpfSegurado: map['cpfSegurado'],
      idadeSegurado: map['idadeSegurado'],
      telefone: map['telefone'],
      email: map['email'],
      parentesco: map['parentesco'],
      causaMorte: map['causaMorte'],
      fotosUrls: List<String>.from(map['fotosUrls'] ?? []),
      documentosUrls: List<String>.from(map['documentosUrls'] ?? []),
    );
  }
}