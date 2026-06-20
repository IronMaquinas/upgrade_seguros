// lib/widgets/nps_send_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:upgrade_seguros/services/nps_service.dart';

class NpsSendDialog extends StatefulWidget {
  final String claimId;
  final String numeroSinistro;
  final String clienteId;
  final String clienteNome;
  final String clienteTelefone;
  final String clienteEmail;
  final String tipo; // 'sinistro' ou 'assistencia'

  const NpsSendDialog({
    super.key,
    required this.claimId,
    required this.numeroSinistro,
    required this.clienteId,
    required this.clienteNome,
    required this.clienteTelefone,
    required this.clienteEmail,
    required this.tipo,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required String claimId,
    required String numeroSinistro,
    required String clienteId,
    required String clienteNome,
    required String clienteTelefone,
    required String clienteEmail,
    required String tipo,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NpsSendDialog(
        claimId: claimId,
        numeroSinistro: numeroSinistro,
        clienteId: clienteId,
        clienteNome: clienteNome,
        clienteTelefone: clienteTelefone,
        clienteEmail: clienteEmail,
        tipo: tipo,
      ),
    );
  }

  @override
  State<NpsSendDialog> createState() => _NpsSendDialogState();
}

class _NpsSendDialogState extends State<NpsSendDialog> {
  final _npsService = NpsService();

  static const _primary  = Color(0xFF6B5DF8);
  static const _bg       = Color(0xFFF7F7FB);
  static const _border   = Color(0xFFEEEEF5);
  static const _textDark = Color(0xFF1A1A2E);
  static const _muted    = Color(0xFF8888AA);

  bool _gerando  = false;
  String? _link;
  String? _erro;

  Future<void> _gerarLink() async {
    setState(() { _gerando = true; _erro = null; });
    try {
      final link = await _npsService.gerarLinkNps(
        claimId: widget.claimId,
        numeroSinistro: widget.numeroSinistro,
        clienteId: widget.clienteId,
        clienteNome: widget.clienteNome,
        tipo: widget.tipo,
      );
      setState(() { _link = link; _gerando = false; });
    } catch (e) {
      setState(() {
        _erro = 'Erro ao gerar link: $e';
        _gerando = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _gerarLink();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.8,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.star_rounded,
                            color: _primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pesquisa de Satisfação',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            )),
                          Text('${widget.numeroSinistro} · ${widget.clienteNome}',
                            style: const TextStyle(
                                fontSize: 12, color: _muted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: _border),
                  const SizedBox(height: 16),

                  if (_gerando) ...[
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: _primary),
                          SizedBox(height: 12),
                          Text('Gerando link único...',
                            style: TextStyle(color: _muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ] else if (_erro != null) ...[
                    Text(_erro!,
                      style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _gerarLink,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ] else if (_link != null) ...[

                    // Link gerado
                    const Text('Link gerado com sucesso!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E),
                      )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_link!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded,
                                size: 18, color: _primary),
                            tooltip: 'Copiar link',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _link!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Link copiado!')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botões de envio
                    const Text('Enviar para o cliente:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textDark,
                      )),
                    const SizedBox(height: 12),

                    // WhatsApp
                    _buildBotaoEnvio(
                      icon: Icons.chat_rounded,
                      label: 'Enviar via WhatsApp',
                      sublabel: widget.clienteTelefone,
                      cor: const Color(0xFF22C55E),
                      onTap: () async {
                        await _npsService.enviarViaWhatsApp(
                          telefone:        widget.clienteTelefone,
                          nomeCliente:     widget.clienteNome,
                          numeroSinistro:  widget.numeroSinistro,
                          link:            _link!,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Email
                    _buildBotaoEnvio(
                      icon: Icons.email_rounded,
                      label: 'Enviar via Email',
                      sublabel: widget.clienteEmail,
                      cor: const Color(0xFF3B82F6),
                      onTap: () async {
                        await _npsService.enviarViaEmail(
                          email:           widget.clienteEmail,
                          nomeCliente:     widget.clienteNome,
                          numeroSinistro:  widget.numeroSinistro,
                          link:            _link!,
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 10),

                    // Só copiar
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _link!));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Link copiado! Envie manualmente.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded,
                          size: 18),
                      label: const Text('Copiar link e fechar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _muted,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotaoEnvio({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: cor,
                    )),
                  if (sublabel.isNotEmpty)
                    Text(sublabel,
                      style: const TextStyle(
                          fontSize: 11, color: _muted)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: cor),
          ],
        ),
      ),
    );
  }
}