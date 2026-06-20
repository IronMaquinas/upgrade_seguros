// lib/screens/nps_response_screen.dart
// Página pública — cliente acessa via link único
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/services/nps_service.dart';

class NpsResponseScreen extends StatefulWidget {
  final String claimId;
  final String token;

  const NpsResponseScreen({
    super.key,
    required this.claimId,
    required this.token,
  });
  
  @override
  State<NpsResponseScreen> createState() => _NpsResponseScreenState();
}

class _NpsResponseScreenState extends State<NpsResponseScreen>
    with SingleTickerProviderStateMixin {
  final _npsService = NpsService();
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  // ── Estado
  _Etapa _etapa = _Etapa.carregando;
  String _clienteNome = '';
  String _numeroSinistro    = '';
  String _clienteLogoUrl = '';  // ✨ NOVO
  String _descricaoCarga = '';  // ✨ NOVO
  String _clienteEmpresa = '';  // ✨ NOVO

  // ── Respostas
  int? _nota;
  final List<String> _pontosFortes  = [];
  final List<String> _pontosFracos  = [];
  final _reclamacoesCtrl = TextEditingController();
  final _sugestoesCtrl   = TextEditingController();
  bool _enviando = false;

  // ── Opções de pontos fortes/fracos
  static const _opcoesFortes = [
    'Agilidade no atendimento', 'Comunicação clara',
    'Profissionalismo', 'Resolução eficiente',
    'Cortesia', 'Acompanhamento do processo',
    'Organização do processo', 'Preço justo',
  ];
  static const _opcoesFracos = [
    'Demora no atendimento', 'Falta de comunicação',
    'Dificuldade no processo', 'Desorganização',
    'Falta de transparência', 'Preço elevado',
    'Dificuldade de contato', 'Outros',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _carregarPesquisa();
  }

  @override
  void dispose() {
    _animController.dispose();
    _reclamacoesCtrl.dispose();
    _sugestoesCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarPesquisa() async {
    final resultado = await _npsService.verificarPesquisa(
      claimId: widget.claimId,   // ← era osId
      token: widget.token,
    );

    if (resultado == null) {
      setState(() => _etapa = _Etapa.invalida);
    } else if (resultado['jaRespondida'] == true) {
      setState(() => _etapa = _Etapa.jaRespondida);
    } else {
      setState(() {
        _clienteNome    = resultado['clienteNome'] ?? '';
        _numeroSinistro = resultado['numeroSinistro'] ?? '';  // ← era osNumero
        _clienteLogoUrl = resultado['clienteLogoUrl'] ?? '';
        _descricaoCarga = resultado['descricaoCarga'] ?? '';
        _clienteEmpresa = resultado['clienteEmpresa'] ?? _clienteNome;
        _etapa          = _Etapa.nota;
      });
    }
    _animController.forward();
  }

  Future<void> _enviar() async {
    if (_nota == null) return;
    setState(() => _enviando = true);

    final sucesso = await _npsService.salvarResposta(
      claimId:      widget.claimId, 
      token:        widget.token,
      nota:         _nota!,
      pontosFortes: _pontosFortes,
      pontosFracos: _pontosFracos,
      reclamacoes:  _reclamacoesCtrl.text.trim(),
      sugestoes:    _sugestoesCtrl.text.trim(),
    );

    setState(() {
      _enviando = false;
      _etapa    = sucesso ? _Etapa.obrigado : _Etapa.erro;
    });
    _animController
      ..reset()
      ..forward();
  }

  // ── Helpers
  Color get _corNota {
    if (_nota == null)  return const Color(0xFF6B5DF8);
    if (_nota! >= 9)    return const Color(0xFF22C55E);
    if (_nota! >= 7)    return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildEtapa(),
        ),
      ),
    );
  }

  Widget _buildEtapa() {
    switch (_etapa) {
      case _Etapa.carregando:
        return _buildCarregando();
      case _Etapa.nota:
        return _buildEtapaNota();
      case _Etapa.detalhes:
        return _buildEtapaDetalhes();
      case _Etapa.obrigado:
        return _buildEtapaObrigado();
      case _Etapa.jaRespondida:
        return _buildEtapaJaRespondida();
      case _Etapa.invalida:
        return _buildEtapaInvalida();
      case _Etapa.erro:
        return _buildEtapaErro();
    }
  }

  Widget _buildCarregando() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Color(0xFF6B5DF8),
          ),
          SizedBox(height: 16),
          Text('Carregando pesquisa...'),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ETAPA 1 — NOTA
  // ════════════════════════════════════════════════
  Widget _buildEtapaNota() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          
          // ✨ NOVO: Logo do cliente (ou ícone padrão)
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF6B5DF8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _clienteLogoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _clienteLogoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  )
                : const Icon(Icons.local_shipping_rounded,
                    color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          
          // Nome do cliente
          Text(
            'Olá, $_clienteNome!',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // ✨ NOVO: Descrição da carga
          Text(
          'Gostaríamos de saber como foi sua experiência com o atendimento $_numeroSinistro.\n\n'
          'Sua avaliação nos ajuda a melhorar continuamente nossos serviços.',
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF8888AA),
          ),
          textAlign: TextAlign.center,
        ),
          const SizedBox(height: 40),

          // Pergunta principal
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEF5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Em uma escala de 0 a 10, qual a probabilidade de você\nrecomendar nosso serviço a um amigo ou colega?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                // Grid de notas
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: List.generate(11, (i) {
                    final isSelected = _nota == i;
                    Color bgColor;
                    Color textColor;
                    if (i <= 3) {
                      bgColor = Colors.red.withOpacity(isSelected ? 1 : 0.08);
                      textColor = Colors.red;
                    } else if (i <= 5) {
                      bgColor = Colors.orange.withOpacity(isSelected ? 1 : 0.08);
                      textColor = Colors.orange;
                    } else if (i <= 7) {
                      bgColor = Colors.amber.withOpacity(isSelected ? 1 : 0.08);
                      textColor = Colors.amber[700]!;
                    } else {
                      bgColor = Colors.green.withOpacity(isSelected ? 1 : 0.08);
                      textColor = Colors.green;
                    }

                    return GestureDetector(
                      onTap: () => setState(() => _nota = i),
                      child: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: textColor.withOpacity(0.3),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$i',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('😞 Nada provável',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
                    Text('😍 Muito provável',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8888AA))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botão próximo
          if (_nota != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _etapa = _Etapa.detalhes),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _corNota,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continuar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ETAPA 2 — DETALHES
  // ════════════════════════════════════════════════
  Widget _buildEtapaDetalhes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _etapa = _Etapa.nota),
                child: const Icon(Icons.arrow_back,
                  color: Color(0xFF6B5DF8), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Conte-nos mais',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pontos fortes
          const Text(
            'O que saiu bem?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _opcoesFortes.map((opcao) {
              final isSelected = _pontosFortes.contains(opcao);
              return FilterChip(
                label: Text(opcao),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _pontosFortes.add(opcao);
                    } else {
                      _pontosFortes.remove(opcao);
                    }
                  });
                },
                backgroundColor: Colors.grey[100],
                selectedColor: const Color(0xFF22C55E),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Pontos fracos
          const Text(
            'O que poderia melhorar?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _opcoesFracos.map((opcao) {
              final isSelected = _pontosFracos.contains(opcao);
              return FilterChip(
                label: Text(opcao),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _pontosFracos.add(opcao);
                    } else {
                      _pontosFracos.remove(opcao);
                    }
                  });
                },
                backgroundColor: Colors.grey[100],
                selectedColor: const Color(0xFFEF4444),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          // Reclamações
          const Text(
            'Teve algum problema? (Opcional)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reclamacoesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Descreva o problema...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sugestões
          const Text(
            'Alguma sugestão para melhorar? (Opcional)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _sugestoesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Sua sugestão...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Botões
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _etapa = _Etapa.nota),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corNota,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Enviar',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ETAPA 3 — OBRIGADO
  // ════════════════════════════════════════════════
  Widget _buildEtapaObrigado() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Obrigada!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sua avaliação foi registrada com sucesso.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ajudará muito a melhorar nossos serviços!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Text(
              'Você pode fechar esta página.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ETAPA 4 — JÁ RESPONDIDA
  // ════════════════════════════════════════════════
  Widget _buildEtapaJaRespondida() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.info_rounded,
                  color: Colors.blue[600], size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pesquisa já respondida',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Você já respondeu esta pesquisa.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Text(
              'Obrigada pela sua participação!',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ETAPA 5 — LINK INVÁLIDO
  // ════════════════════════════════════════════════
  Widget _buildEtapaInvalida() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.error_outline,
                  color: Colors.red[600], size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Link inválido',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Este link de pesquisa não é válido ou expirou.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════
  // ETAPA 6 — ERRO
  // ════════════════════════════════════════════════
  Widget _buildEtapaErro() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.warning_rounded,
                  color: Colors.orange[600], size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Erro ao enviar',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ocorreu um erro ao registrar sua avaliação.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => setState(() => _etapa = _Etapa.detalhes),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Etapa { carregando, nota, detalhes, obrigado, jaRespondida, invalida, erro }