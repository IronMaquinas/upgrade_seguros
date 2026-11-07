// Third_party_model.dart file in lib/models
//
// Um terceiro (reclamado) é identificado por três personagens (Etapa 02):
//   • Proprietário do veículo — dados do CRLV: nome, CPF, telefone, e-mail,
//     placa, chassi, marca, modelo, cor, anos. São os campos históricos
//     (nome, cpf, contato, email…), então sinistros antigos continuam iguais.
//   • Motorista (condutor no momento do sinistro) — pode ser o próprio
//     proprietário (motoristaMesmoProprietario = true).
//   • Contato — quem a corretora aciona para tratar do sinistro do terceiro.
// Os valores pagos ao terceiro ficam nos lançamentos do sinistro
// (Claim.lancamentos), ligados pelo `id` do terceiro.
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'vehicle_model.dart';

class ThirdParty {
  /// Identificador estável do terceiro dentro do sinistro (liga os lançamentos
  /// de valor a ele). Terceiros cadastrados antes da Etapa 02 vêm com '' e
  /// recebem um id no primeiro lançamento.
  String id;

  // ── Proprietário (CRLV) ────────────────────────────────────────────────────
  String nome;
  String cpf;
  String contato; // telefone do proprietário
  String email;
  Vehicle veiculo;
  String relato;
  String placa;
  String chassi;
  String cor;
  String marcaTerceiro;
  String modeloTerceiro;
  String anoFabricacaoTerceiro;
  String anoModeloTerceiro;
  String numeroSinistroTerceiro;
  String enderecoTerceiro;

  // ── Motorista ──────────────────────────────────────────────────────────────
  bool motoristaMesmoProprietario;
  String nomeMotorista;
  String cpfMotorista;
  String emailMotorista;
  String telefoneMotorista;
  /// CNH do motorista (Etapa 03). Vale mesmo quando o motorista é o
  /// proprietário — o CRLV não traz a CNH.
  String cnhMotorista;

  // propriedades
  List<XFile>? fotos;        // fotos locais (não vai pro Firestore)
  List<String>? fotosUrls;  // urls salvas no Firestore
  List<XFile>? documentos;   // documentos locais
  List<String>? documentosUrls; // urls dos documentos no Firestore
  double franquia; // valor da franquia

  // ── Contato ────────────────────────────────────────────────────────────────
  String? nomeContatoTerceiro;
  String? telefoneContatoTerceiro;
  String? registroSeguradoraTerceiro;

  ThirdParty({
    this.id = '',
    required this.nome,
    required this.cpf,
    required this.contato,
    required this.email,
    required this.veiculo,
    required this.relato,
    required this.placa,
    required this.chassi,
    this.marcaTerceiro = '',
    this.modeloTerceiro = '',
    this.anoFabricacaoTerceiro = '',
    this.anoModeloTerceiro = '',
    this.numeroSinistroTerceiro = '',
    this.cor = '',
    this.motoristaMesmoProprietario = false,
    this.nomeMotorista = '',
    this.cpfMotorista = '',
    this.emailMotorista = '',
    this.telefoneMotorista = '',
    this.cnhMotorista = '',
    this.fotos,
    this.fotosUrls,
    this.documentos,
    this.documentosUrls,
    this.franquia = 0.0,
    required this.enderecoTerceiro,
    this.nomeContatoTerceiro,
    this.telefoneContatoTerceiro,
    this.registroSeguradoraTerceiro,
  });

  /// Gera um id para um terceiro novo (ex.: "Tm3k9x2a1b").
  static String novoId() {
    final r = Random();
    final aleatorio = List.generate(4, (_) => r.nextInt(36).toRadixString(36)).join();
    return 'T${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$aleatorio';
  }

  // Motorista efetivo: quando é o próprio proprietário, repete os dados dele.
  String get motoristaNome => motoristaMesmoProprietario ? nome : nomeMotorista;
  String get motoristaCpf => motoristaMesmoProprietario ? cpf : cpfMotorista;
  String get motoristaEmail => motoristaMesmoProprietario ? email : emailMotorista;
  String get motoristaTelefone => motoristaMesmoProprietario ? contato : telefoneMotorista;

  /// Há algum dado de motorista para mostrar?
  bool get temMotorista =>
      motoristaMesmoProprietario ||
      nomeMotorista.isNotEmpty ||
      cpfMotorista.isNotEmpty ||
      emailMotorista.isNotEmpty ||
      telefoneMotorista.isNotEmpty ||
      cnhMotorista.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'cpf': cpf,
      'contato': contato,
      'email': email,
      'placa': placa,
      'chassi': chassi,
      'cor': cor,
      'marcaTerceiro': marcaTerceiro,
      'modeloTerceiro': modeloTerceiro,
      'anoFabricacaoTerceiro': anoFabricacaoTerceiro,
      'anoModeloTerceiro': anoModeloTerceiro,
      'numeroSinistroTerceiro': numeroSinistroTerceiro,
      'motoristaMesmoProprietario': motoristaMesmoProprietario,
      'nomeMotorista': nomeMotorista,
      'cpfMotorista': cpfMotorista,
      'emailMotorista': emailMotorista,
      'telefoneMotorista': telefoneMotorista,
      'cnhMotorista': cnhMotorista,
      'veiculo': veiculo.toMap(),
      'relato': relato,
      'fotosUrls': fotosUrls ?? [],
      'documentosUrls': documentosUrls ?? [],
      'franquia': franquia,
      'endereco_terceiro': enderecoTerceiro,
      'nomeContatoTerceiro': nomeContatoTerceiro,
      'telefoneContatoTerceiro': telefoneContatoTerceiro,
      'registroSeguradoraTerceiro': registroSeguradoraTerceiro,
    };
  }

  factory ThirdParty.fromMap(Map<String, dynamic> map) {
    final veiculoMap = Map<String, dynamic>.from((map['veiculo'] as Map?) ?? const {});
    final veiculo = Vehicle.fromMap(veiculoMap);
    String texto(String chave) => (map[chave] ?? '').toString();

    return ThirdParty(
      id: texto('id'),
      nome: texto('nome'),
      cpf: texto('cpf'),
      contato: texto('contato'),
      email: texto('email'),
      placa: texto('placa'),
      chassi: texto('chassi'),
      cor: texto('cor'),
      // Sinistros editados antes da Etapa 02 podem ter marca/modelo/anos só
      // dentro de `veiculo` (o diálogo de edição antigo não gravava os campos
      // do terceiro). Cai para `veiculo` quando o campo próprio está vazio.
      marcaTerceiro: texto('marcaTerceiro').isNotEmpty ? texto('marcaTerceiro') : veiculo.marca,
      modeloTerceiro: texto('modeloTerceiro').isNotEmpty ? texto('modeloTerceiro') : veiculo.modelo,
      anoFabricacaoTerceiro: texto('anoFabricacaoTerceiro').isNotEmpty
          ? texto('anoFabricacaoTerceiro')
          : (veiculo.ano > 0 ? veiculo.ano.toString() : ''),
      anoModeloTerceiro: texto('anoModeloTerceiro').isNotEmpty
          ? texto('anoModeloTerceiro')
          : (veiculo.anomodelo > 0 ? veiculo.anomodelo.toString() : ''),
      numeroSinistroTerceiro: texto('numeroSinistroTerceiro'),
      motoristaMesmoProprietario: map['motoristaMesmoProprietario'] == true,
      nomeMotorista: texto('nomeMotorista'),
      cpfMotorista: texto('cpfMotorista'),
      emailMotorista: texto('emailMotorista'),
      telefoneMotorista: texto('telefoneMotorista'),
      cnhMotorista: texto('cnhMotorista'),
      veiculo: veiculo,
      relato: texto('relato'),
      fotosUrls: map['fotosUrls'] != null ? List<String>.from(map['fotosUrls']) : [],
      documentosUrls: map['documentosUrls'] != null ? List<String>.from(map['documentosUrls']) : [],
      franquia: ((map['franquia'] ?? 0.0) as num).toDouble(),
      enderecoTerceiro: texto('endereco_terceiro'),
      nomeContatoTerceiro: map['nomeContatoTerceiro'] as String?,
      telefoneContatoTerceiro: map['telefoneContatoTerceiro'] as String?,
      registroSeguradoraTerceiro: map['registroSeguradoraTerceiro'] as String?,
    );
  }
}
