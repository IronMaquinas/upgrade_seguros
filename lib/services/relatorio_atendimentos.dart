// lib/services/relatorio_atendimentos.dart
//
// Etapa 19b: liga os relatórios com modelos (lib/utils/relatorio_modelo.dart)
// ao banco:
//   • modelos salvos em corretoras/{id}/modelos_relatorio — todos da
//     corretora veem, usam, editam e excluem (se alguém sai de férias, outro
//     exporta o relatório do cliente);
//   • leitura dos sinistros/assistências e conversão de cada um em
//     RegistroRelatorio (os valores de todos os campos do catálogo).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/claim_model.dart';
import '../models/lancamento_model.dart';
import '../utils/relatorio_modelo.dart';
import 'empresa_atual.dart';

class RelatorioAtendimentosService {
  CollectionReference<Map<String, dynamic>> get _modelos => EmpresaAtual.col('modelos_relatorio');

  // ─── modelos ────────────────────────────────────────────────────────────
  Future<List<ModeloRelatorio>> listarModelos(String tipo) async {
    if (!EmpresaAtual.carregada) await EmpresaAtual.carregar();
    final snap = await _modelos.where('tipo', isEqualTo: tipo).get();
    final lista = [
      for (final d in snap.docs)
        ModeloRelatorio.fromMap(d.id, d.data(), atualizadoEm: (d.data()['atualizadoEm'] as Timestamp?)?.toDate()),
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return lista;
  }

  /// Cria (id vazio) ou atualiza. Devolve o id.
  Future<String> salvarModelo(ModeloRelatorio m) async {
    final erro = m.validar();
    if (erro != null) throw Exception(erro);
    if (!EmpresaAtual.carregada) await EmpresaAtual.carregar();
    final quem = FirebaseAuth.instance.currentUser?.email ?? '';
    final dados = {
      ...m.toMap(),
      'atualizadoPor': quem,
      'atualizadoEm': FieldValue.serverTimestamp(),
    };
    if (m.id.isEmpty) {
      final ref = await _modelos.add({...dados, 'criadoPor': quem, 'criadoEm': FieldValue.serverTimestamp()});
      return ref.id;
    }
    await _modelos.doc(m.id).set(dados, SetOptions(merge: true));
    return m.id;
  }

  Future<void> excluirModelo(String id) => _modelos.doc(id).delete();

  // ─── dados ──────────────────────────────────────────────────────────────
  /// Todos os sinistros (tipo 'sinistro') ou assistências ('assistencia') da corretora.
  Future<List<RegistroRelatorio>> carregarRegistros(String tipo) async {
    if (!EmpresaAtual.carregada) await EmpresaAtual.carregar();
    final snap = await EmpresaAtual.col(tipo == 'assistencia' ? 'assistencias' : 'sinistros').get();
    return [
      for (final d in snap.docs) registroDe(Claim.fromMap({...d.data(), 'id': d.id})..id = d.id, tipo: tipo),
    ];
  }

  /// Valores de todos os campos do catálogo para um sinistro/assistência.
  static RegistroRelatorio registroDe(Claim c, {String? tipo}) {
    final t = tipo ?? (c.tipo == 'assistencia' ? 'assistencia' : 'sinistro');
    final v = c.veiculoSelecionado;
    String txt(String? s) => (s ?? '').trim();
    final ativos = c.lancamentos.where((l) => !l.cancelado).toList();
    final tipoAtendimento = t == 'assistencia'
        ? rotuloTipoAssistencia(c.tipoOcorrencia, outro: c.tipoOcorrenciaOutro)
        : txt(c.tipoOcorrencia);
    final terceiros = c.terceiros;

    // Composição: "Serviço (guincho / remoção): R$ 350,00; Km excedente: R$ 80,00"
    final composicao = <String>[
      for (final l in LancamentoSinistro.ordenar(ativos))
        '${l.tipo}: ${RelatorioMontado.moeda(l.valor)}${txt(l.descricao).isEmpty ? '' : ' (${txt(l.descricao)})'}',
    ];
    if (composicao.isEmpty && c.valorTotalSinistro > 0) composicao.add('Valor informado: ${RelatorioMontado.moeda(c.valorTotalSinistro)}');

    final valores = <String, Object?>{
      'numero': c.numeroSinistro,
      'numero_seguradora': t == 'assistencia' ? (txt(c.protocoloSeguradora).isNotEmpty ? c.protocoloSeguradora : c.numeroSeguradora) : c.numeroSeguradora,
      'seguradora': c.seguradora,
      'data_ocorrencia': c.dataOcorrencia,
      'data_abertura': c.dataAbertura,
      'tipo_atendimento': tipoAtendimento,
      'ramo': c.ramoSinistro,
      'status': c.statusAtual,
      'data_conclusao': c.dataConclusao?.toDate(),
      'local': c.localOcorrencia,
      'relato': c.relatoEvento,
      'responsavel': c.responsavelEmail ?? '',
      'cliente_nome': c.clientNome,
      'cliente_documento': c.clientCnpjCpf,
      'placa': v?.placa ?? '',
      'veiculo': v == null ? '' : [v.marca, v.modelo].where((s) => s.trim().isNotEmpty).join(' '),
      'ano': v == null || v.ano == 0 ? '' : (v.anomodelo != 0 && v.anomodelo != v.ano ? '${v.ano}/${v.anomodelo}' : '${v.ano}'),
      'cor': v?.cor ?? '',
      'chassi': v?.chassi ?? '',
      'proprietario_nome': v?.nomeCondutor ?? '',
      'proprietario_cpf': v?.cpfCondutor ?? '',
      'condutor_nome': v?.nomeCondutorMotorista ?? '',
      'condutor_cpf': v?.cpfCondutorMotorista ?? '',
      'condutor_cnh': v?.cnhCondutorMotorista ?? '',
      'houve_terceiro': terceiros.isNotEmpty,
      'qtd_terceiros': terceiros.length,
      'terceiros_nomes': [for (final tp in terceiros) tp.nome],
      'terceiros_placas': [for (final tp in terceiros) tp.placa],
      'terceiros_condutores': [
        for (final tp in terceiros) tp.motoristaMesmoProprietario ? tp.nome : tp.nomeMotorista,
      ],
      'destino': c.localDestino ?? '',
      'prestador': txt(c.nomeOficina).isNotEmpty ? c.nomeOficina : (c.nomeContatoOficina ?? ''),
      'agendamento': c.dataAgendamento == null
          ? ''
          : '${RelatorioMontado.formatar(const CampoRelatorio('x', '', '', formato: FormatoCampo.data), c.dataAgendamento)}'
              '${txt(c.horaAgendamento).isEmpty ? '' : ' ${c.horaAgendamento}'}',
      'valor_total': c.valorTotalCalculado,
      'valores_detalhe': composicao,
      'franquia': c.valorFranquia,
      'qtd_lancamentos': ativos.length,
    };

    return RegistroRelatorio(
      id: c.id,
      tipo: t,
      dataAbertura: c.dataAbertura,
      dataOcorrencia: c.dataOcorrencia,
      status: c.statusAtual,
      clienteId: c.idCliente,
      clienteNome: c.clientNome,
      seguradora: c.seguradora,
      tipoAtendimento: tipoAtendimento,
      ramo: c.ramoSinistro, // 19b.3: filtro por ramo
      valores: valores,
    );
  }
}
