// lib/widgets/recomendacao_chip.dart
//
// Etapa 09: selo da recomendação do cliente (cores por rótulo), usado na lista
// de clientes e no Detalhes do Cliente. A conta fica em
// lib/utils/recomendacao_cliente.dart (via lib/services/recomendacao_service.dart).

import 'package:flutter/material.dart';

import '../utils/recomendacao_cliente.dart';

Color corFundoRecomendacao(String rotulo) {
  switch (rotulo) {
    case RecomendacaoCliente.otimo:
      return Colors.green.shade100;
    case RecomendacaoCliente.regular:
      return Colors.amber.shade100;
    case RecomendacaoCliente.atencao:
      return Colors.orange.shade100;
    case RecomendacaoCliente.naoRecomendado:
      return Colors.red.shade100;
    default: // Sem apólice vigente / Apólice sem valor
      return Colors.grey.shade200;
  }
}

Color corTextoRecomendacao(String rotulo) {
  switch (rotulo) {
    case RecomendacaoCliente.otimo:
      return Colors.green.shade900;
    case RecomendacaoCliente.regular:
      return Colors.amber.shade900;
    case RecomendacaoCliente.atencao:
      return Colors.orange.shade900;
    case RecomendacaoCliente.naoRecomendado:
      return Colors.red.shade900;
    default:
      return Colors.grey.shade800;
  }
}

class RecomendacaoChip extends StatelessWidget {
  final String rotulo;
  const RecomendacaoChip(this.rotulo, {super.key});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(rotulo),
      backgroundColor: corFundoRecomendacao(rotulo),
      labelStyle: TextStyle(color: corTextoRecomendacao(rotulo)),
    );
  }
}
