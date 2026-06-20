class House {
  final String localHouse;
  final String? tipoImovel;
  final double? valorImovel;
  final List<String> fotosUrls;
  final List<String> documentosUrls;

  House({
    required this.localHouse,
    this.tipoImovel,
    this.valorImovel,
    required this.fotosUrls,
    required this.documentosUrls,
  });

  Map<String, dynamic> toMap() {
    return {
      'localHouse': localHouse,
      if (tipoImovel != null) 'tipoImovel': tipoImovel,
      if (valorImovel != null) 'valorImovel': valorImovel,
      'fotosUrls': fotosUrls,
      'documentosUrls': documentosUrls,
    };
  }

  factory House.fromMap(Map<String, dynamic> map) {
    return House(
      localHouse: map['localHouse'],
      tipoImovel: map['tipoImovel'],
      valorImovel: map['valorImovel'],
      fotosUrls: List<String>.from(map['fotosUrls'] ?? []),
      documentosUrls: List<String>.from(map['documentosUrls'] ?? []),
    );
  }
}