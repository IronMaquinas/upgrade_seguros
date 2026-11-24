// lib/utils/modulos.dart — Etapa 23: catálogo de módulos (uma lista só)
//
// O que pode ser ligado/desligado por corretora. Usado pelo app (esconder e
// travar), pelo portal (escolher) e espelhado em functions/modulos.js (o
// verificador confere que as duas listas são iguais: ids e dependências).
//
// Fora daqui (sempre ligado): Início, Sinistros, Clientes e apólices,
// Configurações, Usuários e "Meu plano".
//
// Onde cada módulo trava (tela + servidor):
//   assistencias               menu Assistências, "Novo registro → Assistência"; regra: grava assistencias
//   videos                     vídeos na abertura e no detalhe do sinistro; regra do Storage (videos/)
//   oficinas                   oficina no detalhe do sinistro, aba Oficinas; regra: grava workshops
//   importar_contrato          botão "Importar contrato (PDF)" no cliente
//   tarefas                    menu Tarefas, tarefas no atendimento, tarefas automáticas; regra: grava tasks
//   relatorios                 menu Relatórios (gráficos, rankings)
//   relatorios_personalizados  "Exportar relatório" (modelos); regra: grava modelos_relatorio
//   nps                        "Enviar pesquisa" na assistência; regra: grava nps_pesquisas
//   telegram                   avisos de assistência atrasada no Telegram (servidor)

class Modulo {
  final String id;
  final String nome;
  final String area;
  final String descricao;
  final List<String> dependeDe;

  const Modulo(this.id, this.nome, this.area, this.descricao, {this.dependeDe = const []});
}

class Modulos {
  Modulos._();

  static const areas = ['Atendimento', 'Carteira', 'Gestão', 'Comunicação'];

  static const catalogo = <Modulo>[
    Modulo('assistencias', 'Assistências', 'Atendimento', 'Abertura e acompanhamento de assistências (guincho, chaveiro, residencial…), com valores.'),
    Modulo('videos', 'Vídeos do sinistro', 'Atendimento', 'Envio de vídeos na abertura e no detalhe do sinistro, com conversão automática.'),
    Modulo('oficinas', 'Oficinas', 'Atendimento', 'Cadastro de oficinas e acompanhamento do reparo no sinistro.'),
    Modulo('importar_contrato', 'Importar contrato (PDF)', 'Carteira', 'Lê a apólice em PDF e preenche o cadastro do cliente.'),
    Modulo('tarefas', 'Tarefas', 'Gestão', 'Tarefas da equipe, prazos e tarefas automáticas ligadas aos atendimentos.'),
    Modulo('relatorios', 'Relatórios gerenciais', 'Gestão', 'Gráficos mensais, sinistralidade e rankings de clientes.'),
    Modulo('relatorios_personalizados', 'Relatórios personalizados', 'Gestão', 'Modelos de relatório salvos, exportados em PDF e Excel.'),
    Modulo('nps', 'Pesquisa de satisfação (NPS)', 'Comunicação', 'Envio de pesquisa ao cliente depois do atendimento.', dependeDe: ['assistencias']),
    Modulo('telegram', 'Avisos no Telegram', 'Comunicação', 'Aviso de assistência atrasada no Telegram da equipe.', dependeDe: ['assistencias']),
    // Etapa 28
    Modulo('beta', 'Beta — assistente', 'Comunicação', 'Assistente que responde no chat contatos, veículos e situação dos atendimentos, direto do banco.'),
  ];

  static final Map<String, Modulo> _porId = {for (final m in catalogo) m.id: m};

  static Modulo? porId(String id) => _porId[id];

  static Set<String> get todos => {for (final m in catalogo) m.id};

  /// Só os ids que existem, e sem os que dependem de um módulo desligado.
  static Set<String> efetivos(Iterable<String> marcados) {
    var r = {for (final id in marcados) if (_porId.containsKey(id)) id};
    var mudou = true;
    while (mudou) {
      final antes = r.length;
      r = {for (final id in r) if (_porId[id]!.dependeDe.every(r.contains)) id};
      mudou = r.length != antes;
    }
    return r;
  }

  /// Ao marcar um módulo, marca também o que ele exige.
  static Set<String> marcar(Set<String> atuais, String id) {
    final r = {...atuais, id};
    for (final d in _porId[id]?.dependeDe ?? const <String>[]) {
      r.addAll(marcar(r, d));
    }
    return r;
  }

  /// Ao desmarcar, desmarca também o que dependia dele.
  static Set<String> desmarcar(Set<String> atuais, String id) => efetivos({...atuais}..remove(id));

  /// Módulos ligados pela conta da plataforma (plataforma_contas/{e}).
  /// null = tudo ligado (sem conta, ou plano "tudo ligado").
  static Set<String>? ligadosDaConta(Map<String, dynamic>? conta) {
    if (conta == null) return null;
    final plano = conta['plano'] is Map ? Map<String, dynamic>.from(conta['plano'] as Map) : const <String, dynamic>{};
    final tipo = (plano['tipo'] ?? 'tudo_ligado') as String;
    if (tipo == 'tudo_ligado') return null;
    return efetivos([for (final x in (conta['modulos'] as List? ?? const [])) '$x']);
  }
}
