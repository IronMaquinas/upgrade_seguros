class Machinery {
  String descricao;
  String numeroSerie;
  String modelo;
  String descricaoSinistro;
  final List<String> fotosUrls;
  final List<String> documentosUrls;

  Machinery({
    required this.descricao,
    required this.numeroSerie,
    required this.modelo,
    required this.descricaoSinistro,
    required this.fotosUrls,
    required this.documentosUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'descricao': descricao,
      'numeroSerie': numeroSerie,
      'modelo': modelo,
      'descricaoSinistro': descricaoSinistro,
      'fotosUrls': fotosUrls,
      'documentosUrls': documentosUrls,
    };
  }

  factory Machinery.fromMap(Map<String, dynamic> map) {
    return Machinery(
      descricao: map['descricao'] ?? '',
      numeroSerie: map['numeroSerie'] ?? '',
      modelo: map['modelo'] ?? '',
      descricaoSinistro: map['descricaoSinistro'] ?? '',
      fotosUrls: List<String>.from(map['fotosUrls'] ?? []),
      documentosUrls: List<String>.from(map['documentosUrls'] ?? []),
    );
  }
}