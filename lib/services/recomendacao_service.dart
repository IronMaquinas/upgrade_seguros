// lib/services/recomendacao_service.dart
//
// Etapa 09: ponte entre os modelos do app (Client, Claim) e a regra única da
// recomendação do cliente (lib/utils/recomendacao_cliente.dart). Usado pela
// lista de clientes, pelo Detalhes do Cliente e pelo encerramento do sinistro
// (FirestoreService.atualizarRecomendacaoManutencao).

import '../models/claim_model.dart';
import '../models/client_model.dart';
import '../utils/recomendacao_cliente.dart';

/// Recomendação do cliente. [claims] pode trazer qualquer coisa: só entram os
/// sinistros deste cliente (assistências não consomem gatilho).
ResultadoRecomendacao recomendarCliente(Client cliente, List<Claim> claims, double percentualGatilho) {
  return RecomendacaoCliente.calcular(
    percentualGatilho: percentualGatilho,
    apolices: [
      for (final a in cliente.apolices)
        ApoliceParaRecomendacao(
          id: a.id,
          numero: a.numeroApolice,
          ramo: a.ramo,
          inicio: a.dataInicio,
          fim: a.dataFim,
          valorApolice: a.valorApolice,
          valorGatilho: a.valorGatilho,
        ),
    ],
    sinistros: [
      for (final c in claims)
        if (c.tipo == 'sinistro' && c.idCliente == cliente.id)
          SinistroParaRecomendacao(
            apoliceId: c.apoliceId,
            ramo: c.ramoSinistro,
            dataOcorrencia: c.dataOcorrencia,
            status: c.statusAtual,
            valor: c.valorTotalSinistro,
          ),
    ],
  );
}
