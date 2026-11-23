// lib/utils/relatorio_modelo.dart
//
// Etapa 19b: relatórios de sinistros e assistências montados por MODELOS
// salvos pela corretora ("Cliente A — simples", "Águia Branca — mensal"…).
//
// Este arquivo é Dart puro (testado em test/relatorio_modelo_test.dart):
//   • CatalogoRelatorio — todos os campos que podem entrar num relatório,
//     agrupados por seção, com a largura de cada um no PDF;
//   • ModeloRelatorio — o que a corretora salva (nome, tipo, campos em ordem);
//   • OcupacaoPdf — quanto da largura da folha A4 deitada o modelo ocupa e,
//     com isso, o formato do PDF (tabela, tabela compacta ou ficha);
//   • FiltroRelatorio / RegistroRelatorio / RelatorioMontado — filtrar,
//     ordenar, formatar, totalizar e gerar o CSV (Excel).
// Quem transforma um sinistro/assistência em RegistroRelatorio é
// lib/services/relatorio_atendimentos.dart.

/// Como o valor é mostrado.
enum FormatoCampo { texto, data, dataHora, moeda, numero }

class CampoRelatorio {
  final String id;
  final String rotulo;
  final String secao;

  /// Largura relativa no PDF (1 ≈ 60 pontos ≈ 2,1 cm na folha deitada).
  final double largura;
  final FormatoCampo formato;

  /// Somado na linha de TOTAL (valores e quantidades).
  final bool soma;

  /// 'sinistro', 'assistencia' ou os dois.
  final Set<String> tipos;

  const CampoRelatorio(
    this.id,
    this.rotulo,
    this.secao, {
    this.largura = 1.2,
    this.formato = FormatoCampo.texto,
    this.soma = false,
    this.tipos = const {'sinistro', 'assistencia'},
  });

  bool get alinharDireita => formato == FormatoCampo.moeda || formato == FormatoCampo.numero;
}

class CatalogoRelatorio {
  CatalogoRelatorio._();

  static const _s = {'sinistro'};
  static const _a = {'assistencia'};

  static const secoes = <String>[
    'Ocorrência',
    'Cliente',
    'Bem / veículo',
    'Proprietário (CRLV)',
    'Condutor',
    'Terceiros',
    'Atendimento da assistência',
    'Valores',
  ];

  static const todos = <CampoRelatorio>[
    // Ocorrência
    CampoRelatorio('numero', 'Nº da ocorrência', 'Ocorrência', largura: 1.2),
    CampoRelatorio('numero_seguradora', 'Nº na seguradora', 'Ocorrência', largura: 1.3),
    CampoRelatorio('seguradora', 'Seguradora', 'Ocorrência', largura: 1.3),
    CampoRelatorio('data_ocorrencia', 'Data da ocorrência', 'Ocorrência', largura: 1.0, formato: FormatoCampo.data),
    CampoRelatorio('data_abertura', 'Abertura (data e hora)', 'Ocorrência', largura: 1.2, formato: FormatoCampo.dataHora),
    CampoRelatorio('tipo_atendimento', 'Tipo', 'Ocorrência', largura: 1.3),
    CampoRelatorio('ramo', 'Ramo', 'Ocorrência', largura: 1.1, tipos: _s),
    CampoRelatorio('status', 'Status', 'Ocorrência', largura: 1.0),
    CampoRelatorio('data_conclusao', 'Concluído em', 'Ocorrência', largura: 1.0, formato: FormatoCampo.data),
    CampoRelatorio('local', 'Local da ocorrência', 'Ocorrência', largura: 2.2),
    CampoRelatorio('relato', 'Relato', 'Ocorrência', largura: 3.0),
    CampoRelatorio('responsavel', 'Responsável', 'Ocorrência', largura: 1.6),
    // Cliente
    CampoRelatorio('cliente_nome', 'Cliente', 'Cliente', largura: 2.0),
    CampoRelatorio('cliente_documento', 'CNPJ/CPF do cliente', 'Cliente', largura: 1.3),
    // Bem / veículo
    CampoRelatorio('placa', 'Placa', 'Bem / veículo', largura: 0.9),
    CampoRelatorio('veiculo', 'Veículo (marca/modelo)', 'Bem / veículo', largura: 1.7),
    CampoRelatorio('ano', 'Ano', 'Bem / veículo', largura: 0.7),
    CampoRelatorio('cor', 'Cor', 'Bem / veículo', largura: 0.8),
    CampoRelatorio('chassi', 'Chassi', 'Bem / veículo', largura: 1.5),
    // Proprietário
    CampoRelatorio('proprietario_nome', 'Proprietário', 'Proprietário (CRLV)', largura: 1.8),
    CampoRelatorio('proprietario_cpf', 'CPF/CNPJ do proprietário', 'Proprietário (CRLV)', largura: 1.3),
    // Condutor
    CampoRelatorio('condutor_nome', 'Condutor', 'Condutor', largura: 1.8),
    CampoRelatorio('condutor_cpf', 'CPF do condutor', 'Condutor', largura: 1.2),
    CampoRelatorio('condutor_cnh', 'CNH do condutor', 'Condutor', largura: 1.1),
    // Terceiros
    CampoRelatorio('houve_terceiro', 'Houve terceiro?', 'Terceiros', largura: 0.8, tipos: _s),
    CampoRelatorio('qtd_terceiros', 'Qtd. terceiros', 'Terceiros', largura: 0.7, formato: FormatoCampo.numero, soma: true, tipos: _s),
    CampoRelatorio('terceiros_nomes', 'Terceiros (nomes)', 'Terceiros', largura: 2.0, tipos: _s),
    CampoRelatorio('terceiros_placas', 'Terceiros (placas)', 'Terceiros', largura: 1.2, tipos: _s),
    CampoRelatorio('terceiros_condutores', 'Terceiros (condutores)', 'Terceiros', largura: 2.0, tipos: _s),
    // Assistência
    CampoRelatorio('destino', 'Destino', 'Atendimento da assistência', largura: 2.0, tipos: _a),
    CampoRelatorio('prestador', 'Oficina / prestador', 'Atendimento da assistência', largura: 1.6, tipos: _a),
    CampoRelatorio('agendamento', 'Agendamento', 'Atendimento da assistência', largura: 1.1, tipos: _a),
    // Valores
    CampoRelatorio('valor_total', 'Valor total', 'Valores', largura: 1.1, formato: FormatoCampo.moeda, soma: true),
    CampoRelatorio('valores_detalhe', 'Composição do valor', 'Valores', largura: 2.6),
    CampoRelatorio('franquia', 'Franquia', 'Valores', largura: 1.0, formato: FormatoCampo.moeda, soma: true),
    CampoRelatorio('qtd_lancamentos', 'Qtd. lançamentos', 'Valores', largura: 0.8, formato: FormatoCampo.numero, soma: true),
  ];

  static CampoRelatorio? porId(String id) {
    for (final c in todos) {
      if (c.id == id) return c;
    }
    return null;
  }

  static List<CampoRelatorio> paraTipo(String tipo) => todos.where((c) => c.tipos.contains(tipo)).toList();

  /// Campos de uma seção para o tipo (só seções que têm campo para ele).
  static Map<String, List<CampoRelatorio>> porSecao(String tipo) {
    final r = <String, List<CampoRelatorio>>{};
    for (final s in secoes) {
      final l = paraTipo(tipo).where((c) => c.secao == s).toList();
      if (l.isNotEmpty) r[s] = l;
    }
    return r;
  }

  /// Sugestão para um modelo novo.
  static List<String> padrao(String tipo) => tipo == 'assistencia'
      ? const ['numero', 'data_abertura', 'placa', 'veiculo', 'tipo_atendimento', 'valor_total']
      : const ['numero', 'numero_seguradora', 'data_ocorrencia', 'cliente_nome', 'placa', 'status', 'valor_total'];
}

class ModeloRelatorio {
  final String id;
  final String nome;

  /// 'sinistro' ou 'assistencia'
  final String tipo;
  final List<String> campos;
  final String criadoPor;
  final String atualizadoPor;
  final DateTime? atualizadoEm;

  const ModeloRelatorio({
    this.id = '',
    required this.nome,
    required this.tipo,
    required this.campos,
    this.criadoPor = '',
    this.atualizadoPor = '',
    this.atualizadoEm,
  });

  /// Campos válidos para o tipo, na ordem salva (ignora campo que deixou de existir).
  List<CampoRelatorio> get camposValidos => [
        for (final id in campos)
          if (CatalogoRelatorio.porId(id) != null && CatalogoRelatorio.porId(id)!.tipos.contains(tipo))
            CatalogoRelatorio.porId(id)!,
      ];

  /// Mensagem de erro, ou null se dá para salvar.
  String? validar() {
    if (nome.trim().isEmpty) return 'Dê um nome ao modelo.';
    if (tipo != 'sinistro' && tipo != 'assistencia') return 'Tipo inválido.';
    if (camposValidos.isEmpty) return 'Escolha pelo menos um campo.';
    return null;
  }

  ModeloRelatorio copiar({String? id, String? nome, List<String>? campos}) => ModeloRelatorio(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        tipo: tipo,
        campos: campos ?? this.campos,
        criadoPor: criadoPor,
        atualizadoPor: atualizadoPor,
        atualizadoEm: atualizadoEm,
      );

  /// O que vai para o banco (a data de atualização é posta pelo serviço).
  Map<String, dynamic> toMap() => {
        'nome': nome.trim(),
        'tipo': tipo,
        'campos': campos,
        'criadoPor': criadoPor,
        'atualizadoPor': atualizadoPor,
      };

  factory ModeloRelatorio.fromMap(String id, Map<String, dynamic> m, {DateTime? atualizadoEm}) => ModeloRelatorio(
        id: id,
        nome: (m['nome'] ?? '').toString(),
        tipo: (m['tipo'] ?? 'sinistro').toString(),
        campos: [for (final c in (m['campos'] as List? ?? const [])) c.toString()],
        criadoPor: (m['criadoPor'] ?? '').toString(),
        atualizadoPor: (m['atualizadoPor'] ?? '').toString(),
        atualizadoEm: atualizadoEm,
      );
}

/// Formato do PDF conforme a largura que o modelo ocupa.
enum LayoutPdf { tabela, tabelaCompacta, ficha }

class OcupacaoPdf {
  /// Unidades de largura que cabem na A4 deitada com letra normal / compacta.
  static const capacidadeNormal = 13.0;
  static const capacidadeCompacta = 16.0;

  final double unidades;
  const OcupacaoPdf(this.unidades);

  factory OcupacaoPdf.de(List<CampoRelatorio> campos) =>
      OcupacaoPdf(campos.fold<double>(0, (s, c) => s + c.largura));

  /// 0–100+ (% da largura da folha, com letra normal).
  double get percentual => unidades / capacidadeNormal * 100;

  LayoutPdf get layout {
    if (unidades <= capacidadeNormal) return LayoutPdf.tabela;
    if (unidades <= capacidadeCompacta) return LayoutPdf.tabelaCompacta;
    return LayoutPdf.ficha;
  }

  String get descricao {
    switch (layout) {
      case LayoutPdf.tabela:
        return 'Cabe na folha deitada: PDF em tabela.';
      case LayoutPdf.tabelaCompacta:
        return 'Apertado: PDF em tabela com letra menor.';
      case LayoutPdf.ficha:
        return 'Não cabe em tabela: o PDF sai em ficha (um bloco por ocorrência). O Excel sai completo.';
    }
  }
}

/// Uma ocorrência pronta para o relatório (valores já extraídos do sinistro/assistência).
class RegistroRelatorio {
  final String id;
  final String tipo;
  final DateTime dataAbertura;
  final DateTime dataOcorrencia;
  final String status;
  final String clienteId;
  final String clienteNome;
  final String seguradora;
  final String tipoAtendimento;
  final Map<String, Object?> valores;

  const RegistroRelatorio({
    required this.id,
    required this.tipo,
    required this.dataAbertura,
    required this.dataOcorrencia,
    this.status = '',
    this.clienteId = '',
    this.clienteNome = '',
    this.seguradora = '',
    this.tipoAtendimento = '',
    this.valores = const {},
  });
}

class FiltroRelatorio {
  final DateTime? de;
  final DateTime? ate;

  /// true = filtra pela data da ocorrência; false = pela data de abertura.
  final bool pelaOcorrencia;
  final Set<String> status;
  final String? clienteId;
  final String? seguradora;
  final String? tipoAtendimento;

  const FiltroRelatorio({
    this.de,
    this.ate,
    this.pelaOcorrencia = false,
    this.status = const {},
    this.clienteId,
    this.seguradora,
    this.tipoAtendimento,
  });

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  bool aceita(RegistroRelatorio r) {
    final d = _dia(pelaOcorrencia ? r.dataOcorrencia : r.dataAbertura);
    if (de != null && d.isBefore(_dia(de!))) return false;
    if (ate != null && d.isAfter(_dia(ate!))) return false;
    if (status.isNotEmpty && !status.contains(r.status)) return false;
    if ((clienteId ?? '').isNotEmpty && r.clienteId != clienteId) return false;
    if ((seguradora ?? '').isNotEmpty && r.seguradora != seguradora) return false;
    if ((tipoAtendimento ?? '').isNotEmpty && r.tipoAtendimento != tipoAtendimento) return false;
    return true;
  }

  /// Texto para o cabeçalho do PDF / nome do arquivo.
  /// [incluirCliente]: false quando o cliente vai em linha própria (19b.1).
  String descrever({String? nomeCliente, bool incluirCliente = true}) {
    String f(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final partes = <String>[
      if (de != null || ate != null)
        '${pelaOcorrencia ? 'Ocorrência' : 'Abertura'}: ${de == null ? 'início' : f(de!)} a ${ate == null ? 'hoje' : f(ate!)}',
      if (incluirCliente && (clienteId ?? '').isNotEmpty) 'Cliente: ${nomeCliente ?? clienteId}',
      if (status.isNotEmpty) 'Status: ${status.join(', ')}',
      if ((seguradora ?? '').isNotEmpty) 'Seguradora: $seguradora',
      if ((tipoAtendimento ?? '').isNotEmpty) 'Tipo: $tipoAtendimento',
    ];
    return partes.join(' · ');
  }
}

class RelatorioMontado {
  final ModeloRelatorio modelo;
  final List<CampoRelatorio> colunas;
  final List<RegistroRelatorio> registros;

  /// Texto de cada célula, já formatado (linhas × colunas).
  final List<List<String>> linhas;

  /// Totais dos campos que somam (id → total).
  final Map<String, double> totais;

  const RelatorioMontado(this.modelo, this.colunas, this.registros, this.linhas, this.totais);

  int get quantidade => registros.length;

  /// Monta o relatório: filtra, ordena pela data (mais antiga primeiro), formata e soma.
  static RelatorioMontado montar(ModeloRelatorio modelo, List<RegistroRelatorio> todos, FiltroRelatorio filtro) {
    final colunas = modelo.camposValidos;
    final regs = todos.where((r) => r.tipo == modelo.tipo && filtro.aceita(r)).toList()
      ..sort((a, b) {
        final da = filtro.pelaOcorrencia ? a.dataOcorrencia : a.dataAbertura;
        final db = filtro.pelaOcorrencia ? b.dataOcorrencia : b.dataAbertura;
        return da.compareTo(db);
      });
    final totais = <String, double>{for (final c in colunas) if (c.soma) c.id: 0};
    final linhas = <List<String>>[];
    for (final r in regs) {
      linhas.add([for (final c in colunas) formatar(c, r.valores[c.id])]);
      for (final c in colunas) {
        if (!c.soma) continue;
        final v = r.valores[c.id];
        if (v is num) totais[c.id] = totais[c.id]! + v.toDouble();
      }
    }
    return RelatorioMontado(modelo, colunas, regs, linhas, totais);
  }

  /// Linha de TOTAL (texto por coluna; vazio onde não soma).
  List<String> get linhaTotal => [
        for (var i = 0; i < colunas.length; i++)
          colunas[i].soma
              ? formatar(colunas[i], totais[colunas[i].id])
              : (i == 0 ? 'TOTAL ($quantidade)' : ''),
      ];

  /// CSV para o Excel: separador ";", vírgula decimal, BOM (acentos certos),
  /// valores em número (sem "R$") para dar para somar na planilha.
  String paraCsv() {
    String cel(String v) => (v.contains(';') || v.contains('"') || v.contains('\n'))
        ? '"${v.replaceAll('"', '""')}"'
        : v;
    String bruto(CampoRelatorio c, Object? v) {
      if (c.formato == FormatoCampo.moeda) return v is num ? v.toStringAsFixed(2).replaceAll('.', ',') : '';
      if (c.formato == FormatoCampo.numero) return v is num ? (v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',')) : '';
      return formatar(c, v);
    }

    final b = StringBuffer('﻿');
    b.writeln(colunas.map((c) => cel(c.rotulo)).join(';'));
    for (final r in registros) {
      b.writeln(colunas.map((c) => cel(bruto(c, r.valores[c.id]))).join(';'));
    }
    if (colunas.any((c) => c.soma)) {
      b.writeln([
        for (var i = 0; i < colunas.length; i++)
          colunas[i].soma ? bruto(colunas[i], totais[colunas[i].id]) : (i == 0 ? 'TOTAL ($quantidade)' : ''),
      ].map(cel).join(';'));
    }
    return b.toString();
  }

  // ─── formatação ──────────────────────────────────────────────────────────
  static String _2(int n) => n.toString().padLeft(2, '0');

  static String moeda(double v) {
    final neg = v < 0;
    final c = (v.abs() * 100).round();
    final inteiro = (c ~/ 100).toString();
    final cent = _2(c % 100);
    final b = StringBuffer();
    for (var i = 0; i < inteiro.length; i++) {
      if (i > 0 && (inteiro.length - i) % 3 == 0) b.write('.');
      b.write(inteiro[i]);
    }
    return '${neg ? '-' : ''}R\$ $b,$cent';
  }

  static String formatar(CampoRelatorio c, Object? v) {
    if (v == null) return '';
    switch (c.formato) {
      case FormatoCampo.data:
        return v is DateTime ? '${_2(v.day)}/${_2(v.month)}/${v.year}' : v.toString();
      case FormatoCampo.dataHora:
        return v is DateTime ? '${_2(v.day)}/${_2(v.month)}/${v.year} ${_2(v.hour)}:${_2(v.minute)}' : v.toString();
      case FormatoCampo.moeda:
        return v is num ? moeda(v.toDouble()) : v.toString();
      case FormatoCampo.numero:
        return v is num ? (v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',')) : v.toString();
      case FormatoCampo.texto:
        if (v is bool) return v ? 'Sim' : 'Não';
        if (v is List) return v.where((e) => e.toString().trim().isNotEmpty).join('; ');
        return v.toString().trim();
    }
  }
}

/// Nome do tipo de assistência ("guincho" → "Guincho"; "vidro:para-brisa" → "Vidro (para-brisa)").
String rotuloTipoAssistencia(String? codigo, {String? outro}) {
  const nomes = {
    'guincho': 'Guincho',
    'vidro': 'Vidro',
    'combustivel': 'Combustível',
    'pane_eletrica': 'Pane elétrica',
    'carga_bateria': 'Carga de bateria',
    'chaveiro': 'Chaveiro',
    'falta': 'Falta de peça',
    'reboque': 'Reboque',
    // residencial
    'eletricista': 'Eletricista',
    'encanador': 'Encanador',
    'reparo_equipamentos': 'Reparo de equipamentos',
    'vidraceiro': 'Vidraceiro',
    'pintura': 'Pintura',
    'limpeza': 'Limpeza',
    'outro': 'Outro',
  };
  final c = (codigo ?? '').trim();
  if (c.isEmpty) return '';
  if (c.startsWith('vidro:')) {
    final tipos = c.substring(6).split(',').map((s) => s.trim().replaceAll('_', '-')).where((s) => s.isNotEmpty).join(', ');
    return tipos.isEmpty ? 'Vidro' : 'Vidro ($tipos)';
  }
  if (c == 'outro' && (outro ?? '').trim().isNotEmpty) return 'Outro: ${outro!.trim()}';
  final n = nomes[c.toLowerCase()];
  if (n != null) return n;
  final s = c.replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

/// 19b.1: cliente na busca do relatório (digitar nome ou CNPJ/CPF).
class ClienteDoRelatorio {
  final String id;
  final String nome;
  final String documento;
  const ClienteDoRelatorio(this.id, this.nome, this.documento);

  static String _semAcento(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ';
    const para = 'aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = de.indexOf(ch);
      b.write(i < 0 ? ch : para[i]);
    }
    return b.toString().toLowerCase();
  }

  /// Até [limite] clientes cujo nome contém o texto (sem acento/maiúscula) ou
  /// cujo CNPJ/CPF contém os dígitos digitados. Texto vazio: nenhum.
  static List<ClienteDoRelatorio> buscar(List<ClienteDoRelatorio> todos, String texto, {int limite = 20}) {
    final t = _semAcento(texto.trim());
    if (t.isEmpty) return const [];
    final digitos = texto.replaceAll(RegExp(r'\D'), '');
    return todos
        .where((c) =>
            _semAcento(c.nome).contains(t) ||
            (digitos.length >= 3 && c.documento.replaceAll(RegExp(r'\D'), '').contains(digitos)))
        .take(limite)
        .toList();
  }
}

/// 19b.1: parte do nome do arquivo depois da corretora:
/// "Águia Branca - Mensal - 2026-11-23" (sem cliente: "Todos os clientes - …").
String nomeDoRelatorio({String? cliente, required String modelo, required DateTime quando}) {
  final d = '${quando.year}-${quando.month.toString().padLeft(2, '0')}-${quando.day.toString().padLeft(2, '0')}';
  final c = (cliente ?? '').trim().isEmpty ? 'Todos os clientes' : cliente!.trim();
  return '$c - ${modelo.trim()} - $d';
}
