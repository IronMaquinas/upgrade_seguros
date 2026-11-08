// lib/widgets/apolice_visualizacao_dialog.dart
//
// Etapa 08: visualização da apólice (somente leitura), componente único.
// Usado no Detalhes do Cliente e no Cadastro do Cliente (antes ficava só dentro
// do diálogo de edição do cadastro, com a flag somenteLeitura).
//
// Mesmo visual do diálogo "Editar Apólice": campos com borda e rótulo, valor e
// gatilho lado a lado, vigência, bens segurados com os dados de cada tipo.
//
// Retorna true quando o usuário clica em "Editar" (quem chamou decide como
// editar: no cadastro abre o diálogo de edição; no detalhe abre o cadastro).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/apolice_model.dart';
import '../models/bem_segurado_model.dart';
import '../utils/formatters.dart';
import '../utils/gatilho.dart';

Future<bool> mostrarApoliceVisualizacao(
  BuildContext context, {
  required Apolice apolice,
  required double percentualGatilho,
  String emojiRamo = '📋',
  bool podeEditar = true,
}) async {
  final editar = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ApoliceVisualizacaoDialog(
      apolice: apolice,
      percentualGatilho: percentualGatilho,
      emojiRamo: emojiRamo,
      podeEditar: podeEditar,
    ),
  );
  return editar == true;
}

class _ApoliceVisualizacaoDialog extends StatelessWidget {
  final Apolice apolice;
  final double percentualGatilho;
  final String emojiRamo;
  final bool podeEditar;

  const _ApoliceVisualizacaoDialog({
    required this.apolice,
    required this.percentualGatilho,
    required this.emojiRamo,
    required this.podeEditar,
  });

  String _moeda(double v) => v > 0 ? BRFormatters.formatarMoeda(v) : '—';
  String _data(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final gatilho = apolice.gatilhoEfetivo(percentualGatilho);
    final legendaGatilho = apolice.gatilhoInformado
        ? 'Valor do contrato'
        : '${GatilhoApolice.formatarPercentual(percentualGatilho)}% do valor da apólice';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Apólice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
              ),
              const SizedBox(height: 4),
              Text(
                'Dados da apólice e seus bens segurados',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Campo(
                        rotulo: 'Ramo',
                        prefixo: Text(emojiRamo, style: const TextStyle(fontSize: 18)),
                        valor: apolice.ramo,
                      ),
                      const SizedBox(height: 12),
                      _Campo(rotulo: 'Seguradora', valor: apolice.seguradora),
                      const SizedBox(height: 12),
                      _Campo(rotulo: 'Número da Apólice', valor: apolice.numeroApolice),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Campo(rotulo: 'Valor da Apólice', valor: _moeda(apolice.valorApolice))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Campo(
                              rotulo: 'Valor do Gatilho',
                              valor: _moeda(gatilho),
                              legenda: gatilho > 0 ? legendaGatilho : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _Data(rotulo: 'Início', valor: _data(apolice.dataInicio))),
                          const SizedBox(width: 12),
                          Expanded(child: _Data(rotulo: 'Fim', valor: _data(apolice.dataFim))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Bens Segurados', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (apolice.bensSegurados.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text('Nenhum bem cadastrado',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                          ),
                        )
                      else
                        ...apolice.bensSegurados.map((bem) => _BemCard(bem: bem)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      child: const Text('Fechar'),
                    ),
                  ),
                  if (podeEditar) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo somente leitura com o mesmo visual dos TextField do diálogo de edição.
class _Campo extends StatelessWidget {
  final String rotulo;
  final String valor;
  final String? legenda;
  final Widget? prefixo;

  const _Campo({required this.rotulo, required this.valor, this.legenda, this.prefixo});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: rotulo,
        helperText: legenda,
        helperMaxLines: 2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: prefixo == null
            ? null
            : Padding(padding: const EdgeInsets.only(left: 12, right: 8), child: prefixo),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      child: SelectableText(
        valor.trim().isEmpty ? '—' : valor,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}

class _Data extends StatelessWidget {
  final String rotulo;
  final String valor;
  const _Data({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(valor, style: const TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w600)),
      subtitle: Text(rotulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      trailing: const Icon(Icons.calendar_today, size: 20),
      tileColor: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _BemCard extends StatelessWidget {
  final BemSegurado bem;
  const _BemCard({required this.bem});

  bool _tem(String? v) => v != null && v.trim().isNotEmpty;

  List<String> _dados() {
    final d = <String>[];
    void add(String? v, [String prefixo = '']) {
      if (_tem(v)) d.add('$prefixo$v');
    }

    switch (bem.tipo) {
      case 'Veículo Individual':
      case 'Civil Ônibus (RCO)':
        add(bem.placa);
        add(bem.marca);
        add(bem.modelo);
        add(bem.cor);
        if ((bem.ano ?? 0) > 0) d.add('${bem.ano}');
        if ((bem.anoModelo ?? 0) > 0) d.add('${bem.anoModelo}');
        break;
      case 'Frota':
        add(bem.placaCavalo);
        add(bem.marcaCavalo);
        add(bem.modeloCavalo);
        add(bem.placaCarreta, '🚛 ');
        add(bem.marcaCarreta);
        add(bem.modeloCarreta);
        break;
      case 'Máquinas':
        add(bem.modeloEquipamento);
        add(bem.numeroSerie, 'SN: ');
        add(bem.fabricante);
        break;
      case 'Empresarial':
        if (_tem(bem.nomeEmpresa)) {
          add(bem.nomeEmpresa);
          add(bem.enderecoEmpresa);
          add(bem.cnpjEmpresa, 'CNPJ: ');
        } else if (bem.businessData != null) {
          add(bem.businessData!.nomeEmpresa);
          add(bem.businessData!.enderecoEmpresa);
          add(bem.businessData!.cnpjEmpresa, 'CNPJ: ');
        }
        break;
      case 'Residencial':
        if (_tem(bem.logradouro)) d.add('${bem.logradouro}, ${bem.numero ?? ''}');
        add(bem.bairro);
        add(bem.cidade);
        add(bem.numeroDocumento, 'Doc: ');
        break;
      case 'Vida':
        add(bem.descricao);
        add(bem.cpfVida, 'CPF: ');
        if (bem.dataVida != null) d.add('Nasc: ${DateFormat('dd/MM/yyyy').format(bem.dataVida!)}');
        if ((bem.capitalSegurado ?? 0) > 0) d.add('Capital: ${BRFormatters.formatarMoeda(bem.capitalSegurado!)}');
        break;
      default:
        add(bem.descricao);
    }
    return d;
  }

  Future<void> _abrir(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Link copiado para a área de transferência')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final docs = bem.documentosUrls ?? const <String>[];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: _dados()
                .map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(t, style: TextStyle(fontSize: 11, color: Colors.grey.shade800)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          Text(bem.tipo, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: docs.map((url) {
                final nome = Uri.decodeComponent(url.split('/').last.split('?').first).split('/').last;
                final ext = nome.split('.').last.toLowerCase();
                final icone = ext == 'pdf'
                    ? Icons.picture_as_pdf
                    : (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext) ? Icons.image : Icons.insert_drive_file);
                return ActionChip(
                  avatar: Icon(icone, size: 14),
                  label: Text(nome.length > 24 ? '${nome.substring(0, 24)}…' : nome,
                      style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _abrir(context, url),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
