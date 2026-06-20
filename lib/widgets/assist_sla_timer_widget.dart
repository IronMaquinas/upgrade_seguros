import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

/// Status visual do SLA
enum SlaStatus {
  ok('OK', Color(0xFF4CAF50)),          // Verde - menos de 70%
  atencao('ATENÇÃO', Color(0xFFFFC107)), // Amarelo - 70-90%
  vencido('VENCIDO', Color(0xFFF44336)); // Vermelho - mais de 90%

  final String label;
  final Color color;
  const SlaStatus(this.label, this.color);

  factory SlaStatus.fromPercentual(double percentual) {
    if (percentual < 0.7) return SlaStatus.ok;
    if (percentual < 0.9) return SlaStatus.atencao;
    return SlaStatus.vencido;
  }
}

/// Widget de relógio visual para SLA
/// Mostra um círculo de progresso com cores conforme o status
/// Atualiza a cada segundo
class AssistSlaTimerWidget extends StatefulWidget {
  /// Data de abertura do atendimento
  final DateTime dataAbertura;

  /// Tempo previsto de conclusão
  final DateTime? slaPrevisto;

  /// Se null, usa slaPrevisto automaticamente
  final Duration? duracao;

  /// Tamanho do widget em pixels
  final double size;

  /// Se deve mostrar detalhes textuais
  final bool showDetails;

  /// Callback quando SLA é excedido
  final VoidCallback? onSlaExceeded;

  /// Callback quando SLA está prestes a exceder (80%)
  final VoidCallback? onSlaWarning;

  const AssistSlaTimerWidget({
    Key? key,
    required this.dataAbertura,
    required this.slaPrevisto,
    this.duracao,
    this.size = 200,
    this.showDetails = true,
    this.onSlaExceeded,
    this.onSlaWarning,
  }) : super(key: key);

  @override
  State<AssistSlaTimerWidget> createState() => _AssistSlaTimerWidgetState();
}

class _AssistSlaTimerWidgetState extends State<AssistSlaTimerWidget> {
  late Timer _timer;
  bool _slaExceededNotified = false;
  bool _slaWarningNotified = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});

      // Notificar quando atingir 80% do SLA
      final percentual = _getPercentualDecorrido();
      if (percentual >= 0.8 &&
          percentual < 0.9 &&
          !_slaWarningNotified &&
          widget.onSlaWarning != null) {
        _slaWarningNotified = true;
        widget.onSlaWarning!();
      }

      // Notificar quando SLA for excedido
      if (percentual >= 1.0 && !_slaExceededNotified && widget.onSlaExceeded != null) {
        _slaExceededNotified = true;
        widget.onSlaExceeded!();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Calcula o percentual de SLA decorrido (0.0 a 1.0+)
  double _getPercentualDecorrido() {
    if (widget.slaPrevisto == null) return 0.0;

    final duracao = widget.slaPrevisto!.difference(widget.dataAbertura);
    if (duracao.inSeconds == 0) return 0.0;

    final decorrido = DateTime.now().difference(widget.dataAbertura);
    return decorrido.inSeconds / duracao.inSeconds;
  }

  /// Calcula o tempo restante em formato legível
  String _getTempoRestante() {
    if (widget.slaPrevisto == null) return '--:--';

    final agora = DateTime.now();
    final diferenca = widget.slaPrevisto!.difference(agora);

    if (diferenca.isNegative) {
      // SLA excedido
      final absoDiff = agora.difference(widget.slaPrevisto!);
      final horas = absoDiff.inHours;
      final minutos = absoDiff.inMinutes % 60;
      return '+${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}';
    }

    // SLA dentro do prazo
    final horas = diferenca.inHours;
    final minutos = diferenca.inMinutes % 60;
    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}';
  }

  /// Obtém o status atual
  SlaStatus _getStatus() {
    return SlaStatus.fromPercentual(_getPercentualDecorrido());
  }

  /// Obtém a cor do círculo
  Color _getCircleColor() {
    final percentual = _getPercentualDecorrido();
    if (percentual < 0.7) return const Color(0xFF4CAF50); // Verde
    if (percentual < 0.9) return const Color(0xFFFFC107); // Amarelo
    if (percentual < 1.0) return const Color(0xFFFF6B35); // Laranja
    return const Color(0xFFF44336); // Vermelho
  }

  @override
  Widget build(BuildContext context) {
    final percentual = _getPercentualDecorrido();
    final status = _getStatus();
    final tempoRestante = _getTempoRestante();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🔴 CÍRCULO VISUAL DO SLA
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Círculo de fundo (cinza)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 8,
                    ),
                  ),
                ),

                // Círculo de progresso (colorido)
                CustomPaint(
                  painter: _CircleProgressPainter(
                    progress: percentual.clamp(0.0, 1.0),
                    color: _getCircleColor(),
                    strokeWidth: 8,
                  ),
                  size: Size(widget.size, widget.size),
                ),

                // Centro do círculo com informação
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tempo restante (grande)
                      Text(
                        tempoRestante,
                        style: TextStyle(
                          fontSize: widget.size * 0.18,
                          fontWeight: FontWeight.bold,
                          color: _getCircleColor(),
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Label do status
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: widget.size * 0.1,
                          fontWeight: FontWeight.w600,
                          color: status.color,
                        ),
                      ),

                      // Percentual
                      Text(
                        '${(percentual * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: widget.size * 0.08,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 📝 DETALHES (opcional)
          if (widget.showDetails) ...[
            const SizedBox(height: 24),
            _SlaDetailsRow(
              dataAbertura: widget.dataAbertura,
              slaPrevisto: widget.slaPrevisto,
              tempoRestante: tempoRestante,
              percentual: percentual,
              status: status,
            ),
          ],
        ],
      ),
    );
  }
}

/// Painter customizado para o círculo de progresso
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Desenha o arco do progresso
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Começa no topo
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Widget para mostrar detalhes do SLA
class _SlaDetailsRow extends StatelessWidget {
  final DateTime dataAbertura;
  final DateTime? slaPrevisto;
  final String tempoRestante;
  final double percentual;
  final SlaStatus status;

  const _SlaDetailsRow({
    Key? key,
    required this.dataAbertura,
    required this.slaPrevisto,
    required this.tempoRestante,
    required this.percentual,
    required this.status,
  }) : super(key: key);

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: status.color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: status.color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Abertura: ${_formatDateTime(dataAbertura)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, color: status.color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SLA: ${slaPrevisto != null ? _formatDateTime(slaPrevisto!) : 'N/A'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.timer, color: status.color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tempo restante: $tempoRestante',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status.color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget compacto para lista (versão pequena do timer)
class AssistSlaCompactWidget extends StatefulWidget {
  final DateTime dataAbertura;
  final DateTime? slaPrevisto;
  final double size;

  const AssistSlaCompactWidget({
    Key? key,
    required this.dataAbertura,
    required this.slaPrevisto,
    this.size = 60,
  }) : super(key: key);

  @override
  State<AssistSlaCompactWidget> createState() => _AssistSlaCompactWidgetState();
}

class _AssistSlaCompactWidgetState extends State<AssistSlaCompactWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  double _getPercentualDecorrido() {
    if (widget.slaPrevisto == null) return 0.0;
    final duracao = widget.slaPrevisto!.difference(widget.dataAbertura);
    if (duracao.inSeconds == 0) return 0.0;
    final decorrido = DateTime.now().difference(widget.dataAbertura);
    return decorrido.inSeconds / duracao.inSeconds;
  }

  Color _getColor() {
    final p = _getPercentualDecorrido();
    if (p < 0.7) return const Color(0xFF4CAF50);
    if (p < 0.9) return const Color(0xFFFFC107);
    if (p < 1.0) return const Color(0xFFFF6B35);
    return const Color(0xFFF44336);
  }

  String _getLabel() {
    final p = _getPercentualDecorrido();
    if (p < 0.7) return 'OK';
    if (p < 0.9) return '⚠';
    if (p < 1.0) return '⚠⚠';
    return '✕';
  }

  @override
  Widget build(BuildContext context) {
    final percentual = _getPercentualDecorrido();
    final color = _getColor();

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(percentual * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: widget.size * 0.35,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              _getLabel(),
              style: TextStyle(fontSize: widget.size * 0.3, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
