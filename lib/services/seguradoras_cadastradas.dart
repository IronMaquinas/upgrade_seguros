// lib/services/seguradoras_cadastradas.dart
//
// Etapa 20: nomes das seguradoras que podem ser usadas, lidos uma vez e
// guardados em memória para o campo de seguradora e para a conferência ao salvar.
// SeguradoraService chama invalidar() quando o cadastro muda.
//
// Etapa 22: a lista vem do CATÁLOGO ÚNICO (catalogo_seguradoras): as aprovadas +
// as pendentes que esta corretora sugeriu, menos as que a corretora marcou como
// "não trabalho com essa" (ativa = false no cadastro dela). Os apelidos do
// catálogo também valem ("AXA SEGUROS" → AXA).
// Enquanto o catálogo estiver vazio (antes da importação no portal) ou fora do
// ar, continua como na Etapa 20: o cadastro da própria corretora.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:upgrade_seguros/services/empresa_atual.dart';
import 'package:upgrade_seguros/utils/seguradoras.dart';

class SeguradorasCadastradas {
  SeguradorasCadastradas._();

  static List<String>? _nomes;
  static Future<List<String>>? _carregando;
  static Map<String, String> _apelidos = const {};
  static Set<String> _pendentes = const {};
  static bool _catalogo = false;

  /// true = a lista vem do catálogo único (Etapa 22).
  static bool get usaCatalogo => _catalogo;

  /// Nomes que podem ser usados, em ordem.
  static Future<List<String>> nomes() {
    if (_nomes != null) return Future.value(_nomes!);
    return _carregando ??= () async {
      try {
        final cadastro = (await EmpresaAtual.col('seguradoras').get()).docs;
        final doCatalogo = await _lerCatalogo();
        late final List<String> lista;
        // Só usa o catálogo depois que ele tem seguradoras APROVADAS (importação
        // feita no portal); com só uma pendente, a lista ficaria quase vazia.
        if (doCatalogo == null || !doCatalogo.any((e) => !e.pendente)) {
          _catalogo = false;
          _apelidos = const {};
          _pendentes = const {};
          lista = <String>[
            for (final d in cadastro)
              if ((d.data()['ativa'] ?? true) != false && ((d.data()['nome'] ?? '') as String).trim().isNotEmpty)
                ((d.data()['nome']) as String).trim(),
          ];
        } else {
          _catalogo = true;
          final ocultos = <String>{
            for (final d in cadastro)
              if ((d.data()['ativa'] ?? true) == false) ...[
                ((d.data()['catalogoId'] ?? '') as String),
                ((d.data()['nome'] ?? '') as String).trim(),
              ],
          }..remove('');
          final visiveis = [for (final e in doCatalogo) if (!ocultos.contains(e.id) && !ocultos.contains(e.nome)) e];
          lista = [for (final e in visiveis) e.nome];
          _pendentes = {for (final e in visiveis) if (e.pendente) e.nome};
          _apelidos = mapaDeApelidos({for (final e in visiveis) e.nome: e.apelidos});
        }
        lista.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _nomes = lista;
        return lista;
      } finally {
        _carregando = null;
      }
    }();
  }

  /// null = catálogo indisponível (regras ainda não publicadas, sem rede…).
  static Future<List<EntradaCatalogo>?> _lerCatalogo() async {
    try {
      final col = FirebaseFirestore.instance.collection('catalogo_seguradoras');
      final r = await Future.wait([
        col.where('situacao', isEqualTo: 'aprovada').get(),
        col.where('criadaPor.empresaId', isEqualTo: EmpresaAtual.id).where('situacao', isEqualTo: 'pendente').get(),
      ]);
      return [
        for (final s in r)
          for (final d in s.docs)
            if (((d.data()['nome'] ?? '') as String).trim().isNotEmpty) EntradaCatalogo.doMapa(d.id, d.data()),
      ];
    } catch (_) {
      return null;
    }
  }

  /// Já carregados (ou vazio, se ainda não).
  static List<String> get emMemoria => _nomes ?? const [];

  /// Pendente de aprovação no catálogo (sugerida por esta corretora).
  static bool ehPendente(String nome) => _pendentes.contains(nome);

  static void invalidar() {
    _nomes = null;
  }

  static String? _resolver(String texto, List<String> lista) => resolverComApelidos(texto, lista, _apelidos);

  /// Para gravar: o nome cadastrado correspondente, ou o próprio texto se não
  /// houver correspondência (quem chama decide se bloqueia).
  static String normalizar(String texto) => _resolver(texto, emMemoria) ?? texto.trim();

  /// Conferência ao salvar: '' se vazio; o nome cadastrado; ou null se o
  /// texto não corresponde a nenhuma seguradora cadastrada.
  static Future<String?> conferir(String texto) async {
    if (texto.trim().isEmpty) return '';
    final lista = await nomes();
    return _resolver(texto, lista);
  }

  /// Para o campo: o nome cadastrado que corresponde ao texto (com apelidos).
  static String? resolver(String texto) => _resolver(texto, emMemoria);

  static String mensagemForaDoCadastro(String texto) =>
      'A seguradora "${texto.trim()}" não está na lista. Escolha uma da lista '
      '(ou cadastre a nova pelo CNPJ).';
}

/// Etapa 22: uma seguradora do catálogo único.
class EntradaCatalogo {
  final String id;
  final String nome;
  final String cnpj;
  final List<String> apelidos;
  final bool pendente;

  const EntradaCatalogo({required this.id, required this.nome, this.cnpj = '', this.apelidos = const [], this.pendente = false});

  factory EntradaCatalogo.doMapa(String id, Map<String, dynamic> m) => EntradaCatalogo(
        id: id,
        nome: ((m['nome'] ?? '') as String).trim(),
        cnpj: (m['cnpj'] ?? '') as String,
        apelidos: [for (final a in (m['apelidos'] as List? ?? const [])) '$a'],
        pendente: m['situacao'] == 'pendente',
      );
}
