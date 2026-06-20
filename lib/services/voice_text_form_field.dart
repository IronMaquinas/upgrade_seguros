import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceTextFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;

  const VoiceTextFormField({
    Key? key,
    required this.controller,
    required this.labelText,
  }) : super(key: key);

  @override
  State<VoiceTextFormField> createState() => _VoiceTextFormFieldState();
}

class _VoiceTextFormFieldState extends State<VoiceTextFormField> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _hasSpeech = false;

  final TextEditingController _tempController = TextEditingController();

  // ✅ Mapa para traduzir palavras de pontuação para símbolos
  final Map<String, String> _punctuationMap = {
    'PONTO': '.',
    'PONTO FINAL': '.',
    'VÍRGULA': ',',
    'DOIS PONTOS': ':',
    'PONTO E VÍRGULA': ';',
    'INTERROGAÇÃO': '?',
    'EXCLAMAÇÃO': '!',
  };

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        debugPrint('Status do reconhecimento: $status');
      },
      onError: (error) {
        debugPrint('Erro no reconhecimento de voz: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $error')),
        );
      },
      debugLogging: true,
    );

    if (mounted) {
      setState(() {
        _hasSpeech = available;
      });
    }
  }

  void _toggleListening() async {
    if (!_hasSpeech) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reconhecimento de voz não disponível')),
      );
      return;
    }

    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      _tempController.clear();

      setState(() {
        _isListening = true;
      });

      _speech.listen(
        listenFor: const Duration(seconds: 90),
        pauseFor: const Duration(seconds: 3),
        localeId: 'pt_BR',
        cancelOnError: false,
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _tempController.text = result.recognizedWords.toUpperCase();

            if (result.finalResult) {
              // ✅ Processa o texto para adicionar pontuação antes de salvar
              final processedText = _processRecognizedText(result.recognizedWords.toUpperCase());
              
              if (widget.controller.text.isEmpty) {
                widget.controller.text = processedText;
              } else {
                // ✅ Adiciona um espaço antes da nova palavra se não for pontuação
                if (_punctuationMap.values.contains(processedText)) {
                  widget.controller.text += processedText;
                } else {
                  widget.controller.text += ' ' + processedText;
                }
              }
              _tempController.clear();
            }
          });
        },
      );
    }
  }

  // ✅ Nova função para processar o texto e adicionar pontuação
  String _processRecognizedText(String text) {
    // Verifica se a última palavra é uma chave no nosso mapa de pontuação
    if (_punctuationMap.containsKey(text)) {
      return _punctuationMap[text]!;
    }
    // Retorna o texto original se não for uma pontuação
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.labelText,
            suffixIcon: IconButton(
              icon: Icon(
                _isListening ? Icons.mic_off : Icons.mic,
                color: _isListening ? Colors.red : null,
              ),
              onPressed: _hasSpeech ? _toggleListening : null,
            ),
          ),
          maxLines: 5,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Campo obrigatório';
            return null;
          },
        ),
        const SizedBox(height: 8),
        if (_isListening && _tempController.text.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: Text(
              _tempController.text,
              style: const TextStyle(
                color: Colors.blue,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}