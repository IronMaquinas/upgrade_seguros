import 'package:cloud_firestore/cloud_firestore.dart';
import 'vehicle_model.dart';
import 'apolice_model.dart';

class Client {
  String id;
  String nome;
  String cnpjCpf;
  final String? cnpjCpfNormalizado;
  String contato;           // nome do sócio / responsável
  String contatoTelefone;   // telefone de contato
  String email;
  DateTime dataCadastro;
  int totalSinistrosAcionados;
  List<Vehicle> veiculosSegurados;
  String recomendacaoManutencao;
  double totalReceita;
  bool isAtivo;
  List<String> ramos;  // Ex: ['Frota', 'Residencial', 'Individual']
  List<Apolice> apolices;  // 🆕 NOVO: Apólices por ramo

  Client({
    this.id = '',
    required this.nome,
    required this.cnpjCpf,
    this.cnpjCpfNormalizado,
    required this.contato,
    this.contatoTelefone = '',
    required this.email,
    required this.dataCadastro,
    this.totalSinistrosAcionados = 0,
    this.veiculosSegurados = const [],
    this.recomendacaoManutencao = 'Bom',
    this.totalReceita = 0.0,
    this.isAtivo = true,
    this.ramos = const [],
    this.apolices = const [],  // 🆕 NOVO
  });

  // 🆕 Helper: Pega a apólice ativa para um ramo específico
  Apolice? getApoliceAtiva(String ramo) {
    final agora = DateTime.now();
    return apolices.firstWhere(
      (a) => a.ramo == ramo && 
             a.dataInicio.isBefore(agora) && 
             a.dataFim.isAfter(agora),
      orElse: () => null as Apolice,
    ) as Apolice?;
  }

  // 🆕 Helper: Valor total de apólices ativas
  double get valorTotalApolicesAtivas {
    final agora = DateTime.now();
    return apolices
        .where((a) => a.dataInicio.isBefore(agora) && a.dataFim.isAfter(agora))
        .fold<double>(0, (sum, a) => sum + a.valorApolice);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cnpj_cpf': cnpjCpf,
      'cnpjCpf_normalizado': cnpjCpfNormalizado,
      'contato': contato,
      'contato_telefone': contatoTelefone,
      'email': email,
      'data_cadastro': Timestamp.fromDate(dataCadastro),
      'total_sinistros_acionados': totalSinistrosAcionados,
      'veiculos_segurados': veiculosSegurados.map((v) => v.toMap()).toList(),
      'recomendacao_manutencao': recomendacaoManutencao,
      'total_receita': totalReceita,
      'is_ativo': isAtivo,
      'ramos': ramos,
      'apolices': apolices.map((a) => a.toMap()).toList(),  // 🆕 NOVO
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] ?? '',
      nome: map['nome'] ?? '',
      cnpjCpf: map['cnpj_cpf'] ?? '',
      cnpjCpfNormalizado: map['cnpjCpf_normalizado'],
      contato: map['contato'] ?? '',
      contatoTelefone: map['contato_telefone'] ?? '',
      email: map['email'] ?? '',
      dataCadastro: (map['data_cadastro'] as Timestamp).toDate(),
      totalSinistrosAcionados: (map['total_sinistros_acionados'] ?? 0).toInt(),
      veiculosSegurados: (map['veiculos_segurados'] as List<dynamic>?)
              ?.map((v) => Vehicle.fromMap(v as Map<String, dynamic>))
              .toList() ??
          [],
      recomendacaoManutencao: map['recomendacao_manutencao'] ?? 'Bom',
      totalReceita: (map['total_receita'] ?? 0.0).toDouble(),
      isAtivo: map['is_ativo'] ?? true,
      ramos: (map['ramos'] as List<dynamic>?)?.cast<String>().toList() ?? [],
      apolices: (map['apolices'] as List<dynamic>?)  // 🆕 NOVO
              ?.map((a) => Apolice.fromMap(
                    a as Map<String, dynamic>,
                    (a as Map<String, dynamic>)['id'] ?? '',
                  ))
              .toList() ??
          [],
    );
  }
}