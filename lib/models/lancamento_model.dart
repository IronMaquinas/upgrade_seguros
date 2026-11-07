// lib/models/lancamento_model.dart
//
// Lançamentos de valor do sinistro (Etapa 02).
//
// Cada custo do sinistro vira um lançamento com data, tipo, valor, a quem se
// refere (segurado ou um terceiro), notas fiscais/evidências e quem registrou.
// O "Valor Total do Sinistro" passa a ser a SOMA dos lançamentos ativos
// (segurado + terceiros) — é ele que alimenta sinistralidade, dashboard e
// relatórios, então nada muda para quem lê `valor_total_sinistro`.
//
// Rastreabilidade: lançamento nunca é apagado nem editado. Errou? Cancela com
// motivo (fica riscado no histórico com quem/quando) e lança o correto.
//
// Este arquivo é Dart puro (sem Flutter/Firebase) para poder ser testado
// isoladamente — ver test/lancamento_model_test.dart.

import 'dart:math';

/// Tipos oferecidos no formulário de lançamento.
class TiposLancamento {
  static const reparo = 'Reparo';
  static const pecas = 'Peças';
  static const maoDeObra = 'Mão de obra';
  static const indenizacao = 'Indenização';
  static const guincho = 'Guincho / Remoção';
  static const locacao = 'Locação de veículo';
  static const honorarios = 'Honorários / Perícia';
  static const outro = 'Outro';

  /// Gerados pelo sistema (não aparecem na lista do formulário).
  static const abertura = 'Valor informado na abertura';
  static const anteriorAoHistorico = 'Valor registrado antes do histórico';

  static const manuais = <String>[
    reparo,
    pecas,
    maoDeObra,
    indenizacao,
    guincho,
    locacao,
    honorarios,
    outro,
  ];
}

/// De onde veio o lançamento.
class OrigemLancamento {
  static const manual = 'manual';
  static const abertura = 'abertura';
  static const anteriorAoHistorico = 'anterior_ao_historico';
}

class BeneficiarioLancamento {
  static const segurado = 'segurado';
  static const terceiro = 'terceiro';
}

/// Nota fiscal / evidência anexada ao lançamento.
class AnexoLancamento {
  final String nome;
  final String url;

  const AnexoLancamento({required this.nome, required this.url});

  Map<String, dynamic> toMap() => {'nome': nome, 'url': url};

  factory AnexoLancamento.fromMap(dynamic raw) {
    if (raw is String) {
      // Tolerante: aceita só a URL.
      final semQuery = raw.split('?').first;
      final nome = Uri.decodeComponent(semQuery.split('/').last.split('%2F').last);
      return AnexoLancamento(nome: nome, url: raw);
    }
    final map = Map<String, dynamic>.from((raw as Map?) ?? const {});
    return AnexoLancamento(
      nome: (map['nome'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
    );
  }
}

/// Converte o que vier do Firestore (Timestamp, DateTime, millis, ISO) em DateTime.
DateTime? lerDataLancamento(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  try {
    // Timestamp do cloud_firestore (sem importar o pacote aqui).
    final d = (v as dynamic).toDate();
    if (d is DateTime) return d;
  } catch (_) {}
  return null;
}

double _lerValor(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
  return 0.0;
}

class LancamentoSinistro {
  final String id;

  /// Data do evento (ex.: data do reparo / da nota fiscal).
  final DateTime data;
  final String tipo;
  final String descricao;
  final double valor;

  /// [BeneficiarioLancamento.segurado] ou [BeneficiarioLancamento.terceiro].
  final String beneficiario;
  final String? terceiroId;

  /// Nome do terceiro no momento do lançamento (para o histórico continuar
  /// legível mesmo que o cadastro do terceiro mude ou seja removido).
  final String? terceiroNome;

  final List<AnexoLancamento> anexos;
  final String origem;

  final String registradoPor;
  final String registradoPorEmail;
  final DateTime registradoEm;

  final bool cancelado;
  final String? motivoCancelamento;
  final String? canceladoPor;
  final String? canceladoPorEmail;
  final DateTime? canceladoEm;

  const LancamentoSinistro({
    required this.id,
    required this.data,
    required this.tipo,
    this.descricao = '',
    required this.valor,
    this.beneficiario = BeneficiarioLancamento.segurado,
    this.terceiroId,
    this.terceiroNome,
    this.anexos = const [],
    this.origem = OrigemLancamento.manual,
    required this.registradoPor,
    this.registradoPorEmail = '',
    required this.registradoEm,
    this.cancelado = false,
    this.motivoCancelamento,
    this.canceladoPor,
    this.canceladoPorEmail,
    this.canceladoEm,
  });

  bool get isTerceiro => beneficiario == BeneficiarioLancamento.terceiro;
  bool get isAtivo => !cancelado;

  /// Texto de "a quem se refere", para listas e PDF.
  String get beneficiarioLabel {
    if (!isTerceiro) return 'Segurado';
    final nome = (terceiroNome ?? '').trim();
    return nome.isEmpty ? 'Terceiro' : 'Terceiro — $nome';
  }

  /// Gera um id curto e único o bastante para um lançamento dentro do sinistro.
  static String novoId() {
    final r = Random();
    final aleatorio = List.generate(4, (_) => r.nextInt(36).toRadixString(36)).join();
    return 'L${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$aleatorio';
  }

  /// Valida os dados de um lançamento novo. Retorna a mensagem de erro ou null.
  static String? validar({
    required double valor,
    required String tipo,
    required String beneficiario,
    String? terceiroId,
    DateTime? data,
  }) {
    if (valor <= 0) return 'Informe um valor maior que zero.';
    if (tipo.trim().isEmpty) return 'Escolha o tipo do lançamento.';
    if (data == null) return 'Informe a data.';
    if (beneficiario == BeneficiarioLancamento.terceiro && (terceiroId ?? '').isEmpty) {
      return 'Escolha o terceiro.';
    }
    return null;
  }

  /// Devolve uma cópia cancelada. O original não muda.
  LancamentoSinistro cancelar({
    required String motivo,
    required String por,
    String porEmail = '',
    DateTime? em,
  }) {
    return LancamentoSinistro(
      id: id,
      data: data,
      tipo: tipo,
      descricao: descricao,
      valor: valor,
      beneficiario: beneficiario,
      terceiroId: terceiroId,
      terceiroNome: terceiroNome,
      anexos: anexos,
      origem: origem,
      registradoPor: registradoPor,
      registradoPorEmail: registradoPorEmail,
      registradoEm: registradoEm,
      cancelado: true,
      motivoCancelamento: motivo.trim(),
      canceladoPor: por,
      canceladoPorEmail: porEmail,
      canceladoEm: em ?? DateTime.now(),
    );
  }

  /// [codificarData] converte DateTime para o formato do banco (Timestamp no
  /// app). Sem ele, grava o DateTime (útil em testes).
  Map<String, dynamic> toMap({Object Function(DateTime d)? codificarData}) {
    Object cod(DateTime d) => codificarData != null ? codificarData(d) : d;
    return {
      'id': id,
      'data': cod(data),
      'tipo': tipo,
      'descricao': descricao,
      'valor': valor,
      'beneficiario': beneficiario,
      if (terceiroId != null) 'terceiro_id': terceiroId,
      if (terceiroNome != null) 'terceiro_nome': terceiroNome,
      'anexos': anexos.map((a) => a.toMap()).toList(),
      'origem': origem,
      'registrado_por': registradoPor,
      'registrado_por_email': registradoPorEmail,
      'registrado_em': cod(registradoEm),
      'cancelado': cancelado,
      if (motivoCancelamento != null) 'motivo_cancelamento': motivoCancelamento,
      if (canceladoPor != null) 'cancelado_por': canceladoPor,
      if (canceladoPorEmail != null) 'cancelado_por_email': canceladoPorEmail,
      if (canceladoEm != null) 'cancelado_em': cod(canceladoEm!),
    };
  }

  factory LancamentoSinistro.fromMap(Map<String, dynamic> map) {
    final agora = DateTime.now();
    String? textoOpcional(String chave) {
      final v = map[chave];
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return LancamentoSinistro(
      id: (map['id'] ?? '').toString(),
      data: lerDataLancamento(map['data']) ?? lerDataLancamento(map['registrado_em']) ?? agora,
      tipo: (map['tipo'] ?? TiposLancamento.outro).toString(),
      descricao: (map['descricao'] ?? '').toString(),
      valor: _lerValor(map['valor']),
      beneficiario: map['beneficiario'] == BeneficiarioLancamento.terceiro
          ? BeneficiarioLancamento.terceiro
          : BeneficiarioLancamento.segurado,
      terceiroId: textoOpcional('terceiro_id'),
      terceiroNome: textoOpcional('terceiro_nome'),
      anexos: ((map['anexos'] as List?) ?? const [])
          .map((a) => AnexoLancamento.fromMap(a))
          .where((a) => a.url.isNotEmpty)
          .toList(),
      origem: (map['origem'] ?? OrigemLancamento.manual).toString(),
      registradoPor: (map['registrado_por'] ?? '').toString(),
      registradoPorEmail: (map['registrado_por_email'] ?? '').toString(),
      registradoEm: lerDataLancamento(map['registrado_em']) ?? agora,
      cancelado: map['cancelado'] == true,
      motivoCancelamento: textoOpcional('motivo_cancelamento'),
      canceladoPor: textoOpcional('cancelado_por'),
      canceladoPorEmail: textoOpcional('cancelado_por_email'),
      canceladoEm: lerDataLancamento(map['cancelado_em']),
    );
  }

  /// Lê a lista gravada no sinistro, tolerante a nulos e itens inválidos.
  static List<LancamentoSinistro> listaDoMapa(dynamic raw) {
    if (raw is! List) return [];
    final lista = <LancamentoSinistro>[];
    for (final item in raw) {
      if (item is Map) lista.add(LancamentoSinistro.fromMap(Map<String, dynamic>.from(item)));
    }
    return lista;
  }

  /// Ordem do histórico: data do evento, depois ordem de registro.
  static List<LancamentoSinistro> ordenar(List<LancamentoSinistro> lista) {
    final copia = [...lista];
    copia.sort((a, b) {
      final c = a.data.compareTo(b.data);
      return c != 0 ? c : a.registradoEm.compareTo(b.registradoEm);
    });
    return copia;
  }
}

/// Totais calculados a partir dos lançamentos ativos (cancelados não somam).
class ResumoValores {
  final double segurado;
  final double terceiros;

  /// Total por terceiro (chave = id do terceiro).
  final Map<String, double> porTerceiro;
  final int ativos;
  final int cancelados;

  const ResumoValores({
    this.segurado = 0.0,
    this.terceiros = 0.0,
    this.porTerceiro = const {},
    this.ativos = 0,
    this.cancelados = 0,
  });

  double get total => _arredondar(segurado + terceiros);

  factory ResumoValores.calcular(List<LancamentoSinistro> lancamentos) {
    var seg = 0.0;
    var ter = 0.0;
    var ativos = 0;
    var cancelados = 0;
    final porTerceiro = <String, double>{};
    for (final l in lancamentos) {
      if (l.cancelado) {
        cancelados++;
        continue;
      }
      ativos++;
      if (l.isTerceiro) {
        ter += l.valor;
        final chave = l.terceiroId ?? '';
        porTerceiro[chave] = _arredondar((porTerceiro[chave] ?? 0) + l.valor);
      } else {
        seg += l.valor;
      }
    }
    return ResumoValores(
      segurado: _arredondar(seg),
      terceiros: _arredondar(ter),
      porTerceiro: porTerceiro,
      ativos: ativos,
      cancelados: cancelados,
    );
  }

  static double _arredondar(double v) => (v * 100).roundToDouble() / 100;
}
