class Employee {
  final String id;
  final String nome;
  final String email;
  final String perfil;
  final String? telefone;
  final String? cargo;
  final bool ativo;

  // Cartão de visita
  final String? assinaturaNome;
  final String? assinaturaCargo;
  final String? assinaturaTelefone;
  final String? assinaturaEmail;

  Employee({
    required this.id,
    required this.nome,
    required this.email,
    required this.perfil,
    this.telefone,
    this.cargo,
    this.ativo = true,
    this.assinaturaNome,
    this.assinaturaCargo,
    this.assinaturaTelefone,
    this.assinaturaEmail,
  });

  factory Employee.fromMap(Map<String, dynamic> map, String id) {
    return Employee(
      id: id,
      nome: map['nome'] ?? '',
      email: map['email'] ?? '',
      perfil: map['perfil'] ?? 'user',
      telefone: map['telefone'],
      cargo: map['cargo'],
      ativo: map['ativo'] ?? true,
      assinaturaNome: map['assinaturaNome'],
      assinaturaCargo: map['assinaturaCargo'],
      assinaturaTelefone: map['assinaturaTelefone'],
      assinaturaEmail: map['assinaturaEmail'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'perfil': perfil,
      'telefone': telefone,
      'cargo': cargo,
      'ativo': ativo,
      'assinaturaNome': assinaturaNome,
      'assinaturaCargo': assinaturaCargo,
      'assinaturaTelefone': assinaturaTelefone,
      'assinaturaEmail': assinaturaEmail,
    };
  }
}