import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Widget reutilizável para seleção de datas de vigência (início e fim)
/// com auto-preenchimento automático (+1 ano) e suporte a digitação manual
class VigenciaDateRangeWidget extends StatefulWidget {
  final DateTime? initialVigenciaInicio;
  final DateTime? initialVigenciaFim;
  final Function(DateTime?, DateTime?) onDatesChanged;

  const VigenciaDateRangeWidget({
    Key? key,
    this.initialVigenciaInicio,
    this.initialVigenciaFim,
    required this.onDatesChanged,
  }) : super(key: key);

  @override
  State<VigenciaDateRangeWidget> createState() =>
      _VigenciaDateRangeWidgetState();
}

class _VigenciaDateRangeWidgetState extends State<VigenciaDateRangeWidget> {
  late DateTime? _vigenciaInicio;
  late DateTime? _vigenciaFim;
  late TextEditingController _inicioController;
  late TextEditingController _fimController;

  final DateFormat dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _vigenciaInicio = widget.initialVigenciaInicio;
    _vigenciaFim = widget.initialVigenciaFim;

    _inicioController = TextEditingController(
      text: _vigenciaInicio != null ? dateFormat.format(_vigenciaInicio!) : '',
    );
    _fimController = TextEditingController(
      text: _vigenciaFim != null ? dateFormat.format(_vigenciaFim!) : '',
    );
  }

  @override
  void dispose() {
    _inicioController.dispose();
    _fimController.dispose();
    super.dispose();
  }

  /// Tenta fazer parse de uma data no formato dd/MM/yyyy
  DateTime? _parseDate(String value) {
    try {
      return dateFormat.parseStrict(value);
    } catch (e) {
      return null;
    }
  }

  /// Atualiza a data de início e calcula automaticamente a data de fim (+1 ano)
  void _setVigenciaInicio(DateTime? newDate) {
    if (newDate == null) return;

    setState(() {
      _vigenciaInicio = newDate;
      _inicioController.text = dateFormat.format(newDate);

      // ✨ Auto-preencher data de fim com +1 ano (365 dias)
      _vigenciaFim = newDate.add(const Duration(days: 365));
      _fimController.text = dateFormat.format(_vigenciaFim!);
    });

    widget.onDatesChanged(_vigenciaInicio, _vigenciaFim);
  }

  /// Atualiza a data de fim manualmente
  void _setVigenciaFim(DateTime? newDate) {
    if (newDate == null) return;

    setState(() {
      _vigenciaFim = newDate;
      _fimController.text = dateFormat.format(newDate);
    });

    widget.onDatesChanged(_vigenciaInicio, _vigenciaFim);
  }

  /// Trata input manual de data de início
  void _onInicioTextChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _vigenciaInicio = null;
        _vigenciaFim = null;
        _fimController.clear();
      });
      widget.onDatesChanged(null, null);
      return;
    }

    final parsed = _parseDate(value);
    if (parsed != null) {
      _setVigenciaInicio(parsed);
    }
  }

  /// Trata input manual de data de fim
  void _onFimTextChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _vigenciaFim = null;
      });
      widget.onDatesChanged(_vigenciaInicio, null);
      return;
    }

    final parsed = _parseDate(value);
    if (parsed != null) {
      _setVigenciaFim(parsed);
    }
  }

  /// Abre date picker para vigência de início
  Future<void> _pickVigenciaInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigenciaInicio ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      _setVigenciaInicio(picked);
    }
  }

  /// Abre date picker para vigência de fim
  Future<void> _pickVigenciaFim() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vigenciaFim ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      _setVigenciaFim(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ─── VIGÊNCIA INÍCIO
        Expanded(
          child: InkWell(
            onTap: _pickVigenciaInicio,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Vigência Início',
                suffixIcon: Icon(Icons.calendar_today, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: TextField(
                controller: _inicioController,
                onChanged: _onInicioTextChanged,
                decoration: InputDecoration(
                  hintText: 'dd/MM/yyyy',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ─── VIGÊNCIA FIM
        Expanded(
          child: InkWell(
            onTap: _pickVigenciaFim,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Vigência Fim',
                suffixIcon: Icon(Icons.calendar_today, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: TextField(
                controller: _fimController,
                onChanged: _onFimTextChanged,
                decoration: InputDecoration(
                  hintText: 'dd/MM/yyyy',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
