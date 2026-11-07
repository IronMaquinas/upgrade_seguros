// lib/services/lancamentos_service.dart
//
// Grava e cancela lançamentos de valor do sinistro (Etapa 02).
//
// Tudo passa por transação do Firestore: lê o sinistro, aplica a mudança e
// grava `lancamentos` + `valor_total_sinistro` + `valor_segurado` +
// `valor_terceiros` juntos. Assim dois usuários lançando ao mesmo tempo não
// apagam o lançamento um do outro e o total nunca fica diferente da soma.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';

import '../models/lancamento_model.dart';
import '../models/third_party_model.dart';
import 'firestore_service.dart';

class LancamentosService {
  LancamentosService({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();

  final FirestoreService _firestoreService;

  DocumentReference<Map<String, dynamic>> _doc(String claimId) =>
      _firestoreService.getSinistrosCollection().doc(claimId);

  static Object _ts(DateTime d) => Timestamp.fromDate(d);

  /// Envia as notas fiscais / evidências para o Storage.
  Future<List<AnexoLancamento>> enviarAnexos(String numeroSinistro, List<PlatformFile> arquivos) async {
    if (arquivos.isEmpty) return [];
    final pasta = 'sinistros/${numeroSinistro.replaceAll('/', '_')}/lancamentos';
    final urls = await _firestoreService.uploadArquivosEmPasta(pasta, arquivos);
    return [
      for (var i = 0; i < urls.length; i++) AnexoLancamento(nome: arquivos[i].name, url: urls[i]),
    ];
  }

  /// Acrescenta um lançamento ao sinistro.
  ///
  /// [terceiroIndex]: posição do terceiro na lista do sinistro quando o
  /// lançamento é de terceiro. Terceiros cadastrados antes da Etapa 02 não têm
  /// id; nesse caso o id é criado aqui e gravado no terceiro, na mesma
  /// transação.
  ///
  /// Se o sinistro tinha um valor digitado antes do histórico existir, esse
  /// valor vira o primeiro lançamento ("Valor registrado antes do histórico"),
  /// para o total continuar batendo.
  Future<void> adicionar({
    required String claimId,
    required LancamentoSinistro lancamento,
    int? terceiroIndex,
  }) async {
    final ref = _doc(claimId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final dados = snap.data();
      if (dados == null) throw Exception('Sinistro não encontrado.');

      final lista = LancamentoSinistro.listaDoMapa(dados['lancamentos']);
      final updates = <String, dynamic>{};

      if (lista.isEmpty) {
        final anterior = ((dados['valor_total_sinistro'] ?? 0) as num).toDouble();
        if (anterior > 0) {
          final abertura = lerDataLancamento(dados['data_abertura']) ?? DateTime.now();
          lista.add(LancamentoSinistro(
            id: LancamentoSinistro.novoId(),
            data: abertura,
            tipo: TiposLancamento.anteriorAoHistorico,
            descricao: 'Valor que estava no campo "Valor Total do Sinistro" antes do histórico de lançamentos.',
            valor: anterior,
            origem: OrigemLancamento.anteriorAoHistorico,
            registradoPor: 'Sistema',
            registradoEm: DateTime.now(),
          ));
        }
      }

      var novo = lancamento;
      if (novo.isTerceiro && terceiroIndex != null) {
        final terceiros = ((dados['terceiros'] as List?) ?? const [])
            .map((t) => Map<String, dynamic>.from(t as Map))
            .toList();
        if (terceiroIndex < 0 || terceiroIndex >= terceiros.length) {
          throw Exception('Terceiro não encontrado no sinistro.');
        }
        var id = (terceiros[terceiroIndex]['id'] ?? '').toString();
        if (id.isEmpty) {
          id = ThirdParty.novoId();
          terceiros[terceiroIndex]['id'] = id;
          updates['terceiros'] = terceiros;
        }
        novo = LancamentoSinistro(
          id: novo.id,
          data: novo.data,
          tipo: novo.tipo,
          descricao: novo.descricao,
          valor: novo.valor,
          beneficiario: novo.beneficiario,
          terceiroId: id,
          terceiroNome: novo.terceiroNome,
          anexos: novo.anexos,
          origem: novo.origem,
          registradoPor: novo.registradoPor,
          registradoPorEmail: novo.registradoPorEmail,
          registradoEm: novo.registradoEm,
        );
      }

      lista.add(novo);
      updates.addAll(_camposDaLista(lista));
      tx.update(ref, updates);
    });
  }

  /// Cancela um lançamento (fica no histórico, riscado, com motivo).
  Future<void> cancelar({
    required String claimId,
    required String lancamentoId,
    required String motivo,
    required String usuarioNome,
    String usuarioEmail = '',
  }) async {
    if (motivo.trim().isEmpty) throw Exception('Informe o motivo do cancelamento.');
    final ref = _doc(claimId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final dados = snap.data();
      if (dados == null) throw Exception('Sinistro não encontrado.');

      final lista = LancamentoSinistro.listaDoMapa(dados['lancamentos']);
      final i = lista.indexWhere((l) => l.id == lancamentoId);
      if (i < 0) throw Exception('Lançamento não encontrado.');
      if (lista[i].cancelado) throw Exception('Este lançamento já foi cancelado.');

      lista[i] = lista[i].cancelar(motivo: motivo, por: usuarioNome, porEmail: usuarioEmail);
      tx.update(ref, _camposDaLista(lista));
    });
  }

  Map<String, dynamic> _camposDaLista(List<LancamentoSinistro> lista) {
    final resumo = ResumoValores.calcular(lista);
    return {
      'lancamentos': lista.map((l) => l.toMap(codificarData: _ts)).toList(),
      'valor_total_sinistro': resumo.total,
      'valor_segurado': resumo.segurado,
      'valor_terceiros': resumo.terceiros,
      'data_ultima_atualizacao': Timestamp.now(),
    };
  }
}
