// lib/services/seguradoras_cadastradas.dart
//
// Etapa 20: nomes das seguradoras ATIVAS de Configurações → Seguradoras, lidos
// uma vez e guardados em memória para o campo de seguradora e para a conferência
// ao salvar. SeguradoraService chama invalidar() quando o cadastro muda.

import 'package:upgrade_seguros/services/empresa_atual.dart';
import 'package:upgrade_seguros/utils/seguradoras.dart';

class SeguradorasCadastradas {
  SeguradorasCadastradas._();

  static List<String>? _nomes;
  static Future<List<String>>? _carregando;

  /// Nomes das ativas, em ordem. Documento sem o campo `ativa` conta como ativo.
  static Future<List<String>> nomes() {
    if (_nomes != null) return Future.value(_nomes!);
    return _carregando ??= () async {
      try {
        final snap = await EmpresaAtual.col('seguradoras').get();
        final lista = <String>[
          for (final d in snap.docs)
            if ((d.data()['ativa'] ?? true) != false && ((d.data()['nome'] ?? '') as String).trim().isNotEmpty)
              ((d.data()['nome']) as String).trim(),
        ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _nomes = lista;
        return lista;
      } finally {
        _carregando = null;
      }
    }();
  }

  /// Já carregados (ou vazio, se ainda não).
  static List<String> get emMemoria => _nomes ?? const [];

  static void invalidar() {
    _nomes = null;
  }

  /// Para gravar: o nome cadastrado correspondente, ou o próprio texto se não
  /// houver correspondência (quem chama decide se bloqueia).
  static String normalizar(String texto) => resolverSeguradora(texto, emMemoria) ?? texto.trim();

  /// Conferência ao salvar: '' se vazio; o nome cadastrado; ou null se o
  /// texto não corresponde a nenhuma seguradora cadastrada.
  static Future<String?> conferir(String texto) async {
    if (texto.trim().isEmpty) return '';
    final lista = await nomes();
    return resolverSeguradora(texto, lista);
  }

  static String mensagemForaDoCadastro(String texto) =>
      'A seguradora "${texto.trim()}" não está no cadastro. Escolha uma da lista '
      '(ou peça ao gestor para cadastrá-la em Configurações → Seguradoras).';
}
