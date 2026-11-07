// lib/widgets/terceiro_form.dart
//
// Formulário de identificação do terceiro (Etapa 02), usado nos diálogos
// "Adicionar Terceiro" e "Editar Terceiro" do detalhe do sinistro.
//
// Agrupa os dados por personagem:
//   1. Proprietário do veículo (dados do CRLV) — nome, CPF, telefone, e-mail,
//      endereço e o veículo (placa, chassi, marca, modelo, cor, anos)
//   2. Motorista — ou "o motorista é o proprietário"
//   3. Contato — quem a corretora aciona sobre o sinistro do terceiro
//   4. Sinistro do terceiro — nº de registro na seguradora e relato
//
// Fotos e documentos continuam nos próprios diálogos.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/third_party_model.dart';
import '../models/vehicle_model.dart';
import '../utils/formatters.dart';

/// Controladores de todos os campos de identificação de um terceiro.
class TerceiroFormControllers {
  TerceiroFormControllers._({
    required this.id,
    required this.motoristaMesmoProprietario,
    required this.franquia,
    required this.numeroSinistroTerceiro,
    required Map<String, String> valores,
  }) {
    for (final campo in _campos) {
      _c[campo] = TextEditingController(text: valores[campo] ?? '');
    }
  }

  /// Formulário vazio (terceiro novo, já com id).
  factory TerceiroFormControllers.novo() => TerceiroFormControllers._(
        id: ThirdParty.novoId(),
        motoristaMesmoProprietario: false,
        franquia: 0.0,
        numeroSinistroTerceiro: '',
        valores: const {},
      );

  /// Formulário preenchido com um terceiro existente.
  factory TerceiroFormControllers.de(ThirdParty tp) => TerceiroFormControllers._(
        id: tp.id,
        motoristaMesmoProprietario: tp.motoristaMesmoProprietario,
        franquia: tp.franquia,
        numeroSinistroTerceiro: tp.numeroSinistroTerceiro,
        valores: {
          'nome': tp.nome,
          'cpf': tp.cpf,
          'telefone': tp.contato,
          'email': tp.email,
          'endereco': tp.enderecoTerceiro,
          'placa': tp.placa,
          'chassi': tp.chassi,
          'marca': tp.marcaTerceiro,
          'modelo': tp.modeloTerceiro,
          'cor': tp.cor,
          'anoFabricacao': tp.anoFabricacaoTerceiro,
          'anoModelo': tp.anoModeloTerceiro,
          'nomeMotorista': tp.nomeMotorista,
          'cpfMotorista': tp.cpfMotorista,
          'emailMotorista': tp.emailMotorista,
          'telefoneMotorista': tp.telefoneMotorista,
          'cnhMotorista': tp.cnhMotorista,
          'nomeContato': tp.nomeContatoTerceiro ?? '',
          'telefoneContato': tp.telefoneContatoTerceiro ?? '',
          'registroSeguradora': tp.registroSeguradoraTerceiro ?? '',
          'relato': tp.relato,
        },
      );

  static const _campos = [
    'nome', 'cpf', 'telefone', 'email', 'endereco',
    'placa', 'chassi', 'marca', 'modelo', 'cor', 'anoFabricacao', 'anoModelo',
    'nomeMotorista', 'cpfMotorista', 'emailMotorista', 'telefoneMotorista', 'cnhMotorista',
    'nomeContato', 'telefoneContato', 'registroSeguradora', 'relato',
  ];

  final String id;
  bool motoristaMesmoProprietario;
  final double franquia;
  final String numeroSinistroTerceiro;
  final Map<String, TextEditingController> _c = {};

  TextEditingController operator [](String campo) => _c[campo]!;
  TextEditingController get endereco => _c['endereco']!;

  String _t(String campo) => _c[campo]!.text.trim();
  String? _opcional(String campo) => _t(campo).isEmpty ? null : _t(campo);

  /// Monta o terceiro com os valores digitados.
  ThirdParty montar({
    required List<String> fotosUrls,
    required List<String> documentosUrls,
  }) {
    final mesmo = motoristaMesmoProprietario;
    return ThirdParty(
      id: id.isEmpty ? ThirdParty.novoId() : id,
      nome: _t('nome'),
      cpf: _t('cpf'),
      contato: _t('telefone'),
      email: _t('email'),
      enderecoTerceiro: _t('endereco'),
      placa: _t('placa').toUpperCase(),
      chassi: _t('chassi').toUpperCase(),
      cor: _t('cor'),
      marcaTerceiro: _t('marca'),
      modeloTerceiro: _t('modelo'),
      anoFabricacaoTerceiro: _t('anoFabricacao'),
      anoModeloTerceiro: _t('anoModelo'),
      numeroSinistroTerceiro: numeroSinistroTerceiro,
      veiculo: Vehicle(
        marca: _t('marca'),
        modelo: _t('modelo'),
        ano: int.tryParse(_t('anoFabricacao')) ?? 0,
        anomodelo: int.tryParse(_t('anoModelo')) ?? 0,
        chassi: _t('chassi').toUpperCase(),
        placa: _t('placa').toUpperCase(),
        cor: _t('cor'),
      ),
      motoristaMesmoProprietario: mesmo,
      // Quando é o proprietário, não duplica os dados (lidos pelos getters).
      nomeMotorista: mesmo ? '' : _t('nomeMotorista'),
      cpfMotorista: mesmo ? '' : _t('cpfMotorista'),
      emailMotorista: mesmo ? '' : _t('emailMotorista'),
      telefoneMotorista: mesmo ? '' : _t('telefoneMotorista'),
      cnhMotorista: _t('cnhMotorista'),
      nomeContatoTerceiro: _opcional('nomeContato'),
      telefoneContatoTerceiro: _opcional('telefoneContato'),
      registroSeguradoraTerceiro: _opcional('registroSeguradora'),
      relato: _t('relato'),
      franquia: franquia,
      fotosUrls: fotosUrls,
      documentosUrls: documentosUrls,
    );
  }

  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
  }
}

/// Campos de identificação do terceiro, agrupados por personagem.
class TerceiroIdentificacaoForm extends StatefulWidget {
  const TerceiroIdentificacaoForm({
    super.key,
    required this.controllers,
    this.enabled = true,
    this.onBuscarEndereco,
  });

  final TerceiroFormControllers controllers;
  final bool enabled;

  /// Abre a busca de endereço (Google Places). O endereço é preenchido no
  /// controlador `controllers.endereco`.
  final VoidCallback? onBuscarEndereco;

  @override
  State<TerceiroIdentificacaoForm> createState() => _TerceiroIdentificacaoFormState();
}

class _TerceiroIdentificacaoFormState extends State<TerceiroIdentificacaoForm> {
  static const _roxo = Color(0xFF6A1B9A);

  TerceiroFormControllers get c => widget.controllers;

  Widget _campo(
    String campo,
    String label, {
    List<TextInputFormatter>? formatters,
    TextInputType? teclado,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool maiusculas = false,
  }) {
    return TextFormField(
      enabled: widget.enabled,
      controller: c[campo],
      keyboardType: teclado,
      maxLines: maxLines,
      textCapitalization: maiusculas ? TextCapitalization.characters : TextCapitalization.none,
      inputFormatters: formatters,
      decoration: InputDecoration(labelText: label, isDense: true),
      validator: validator,
    );
  }

  /// Linha responsiva: lado a lado na tela larga, empilhado no celular.
  Widget _linha(List<Widget> campos) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(
          children: [
            for (final campo in campos)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: campo),
          ],
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < campos.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: campos[i]),
            ],
          ],
        ),
      );
    });
  }

  Widget _secao({
    required IconData icone,
    required String titulo,
    String? subtitulo,
    required List<Widget> filhos,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: _roxo.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _roxo.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18, color: _roxo),
              const SizedBox(width: 6),
              Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600, color: _roxo)),
              if (subtitulo != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    subtitulo,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...filhos,
        ],
      ),
    );
  }

  /// Título interno de uma seção (ex.: "Veículo" dentro do proprietário).
  Widget _subtitulo(IconData icone, String titulo) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Icon(icone, size: 16, color: _roxo),
          const SizedBox(width: 6),
          Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _roxo)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final obrigatorio = (String? v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. PROPRIETÁRIO (CRLV)
        _secao(
          icone: Icons.badge_outlined,
          titulo: 'Proprietário do veículo',
          subtitulo: 'conforme o CRLV',
          filhos: [
            _linha([
              _campo('nome', 'Nome do proprietário', validator: obrigatorio),
              _campo('cpf', 'CPF / CNPJ', formatters: [BRFormatters.cpfCnpjFormatter], teclado: TextInputType.number),
            ]),
            _linha([
              _campo('telefone', 'Telefone', formatters: [BRFormatters.telefoneFormatter], teclado: TextInputType.phone),
              _campo('email', 'E-mail', teclado: TextInputType.emailAddress),
            ]),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                enabled: widget.enabled,
                controller: c.endereco,
                readOnly: widget.onBuscarEndereco != null,
                decoration: InputDecoration(
                  labelText: 'Endereço',
                  isDense: true,
                  suffixIcon: widget.onBuscarEndereco != null ? const Icon(Icons.search) : null,
                ),
                onTap: widget.onBuscarEndereco,
                validator: obrigatorio,
              ),
            ),
            _subtitulo(Icons.directions_car_outlined, 'Veículo'),
            _linha([
              _campo('placa', 'Placa', maiusculas: true),
              _campo('chassi', 'Chassi', maiusculas: true, formatters: [LengthLimitingTextInputFormatter(17)]),
            ]),
            _linha([
              _campo('marca', 'Marca'),
              _campo('modelo', 'Modelo'),
              _campo('cor', 'Cor'),
            ]),
            _linha([
              _campo('anoFabricacao', 'Ano de fabricação',
                  teclado: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
              _campo('anoModelo', 'Ano modelo',
                  teclado: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)]),
            ]),
          ],
        ),

        // 2. MOTORISTA
        _secao(
          icone: Icons.airline_seat_recline_normal,
          titulo: 'Motorista',
          subtitulo: 'quem dirigia no momento do sinistro',
          filhos: [
            Row(
              children: [
                Checkbox(
                  value: c.motoristaMesmoProprietario,
                  onChanged: widget.enabled
                      ? (v) => setState(() => c.motoristaMesmoProprietario = v ?? false)
                      : null,
                ),
                const Flexible(
                  child: Text('O motorista é o próprio proprietário', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            if (c.motoristaMesmoProprietario)
              _linha([
                _campo('cnhMotorista', 'CNH do motorista', teclado: TextInputType.number),
                const SizedBox(),
              ])
            else ...[
              _linha([
                _campo('nomeMotorista', 'Nome do motorista'),
                _campo('cpfMotorista', 'CPF do motorista',
                    formatters: [BRFormatters.cpfCnpjFormatter], teclado: TextInputType.number),
                _campo('cnhMotorista', 'CNH do motorista', teclado: TextInputType.number),
              ]),
              _linha([
                _campo('telefoneMotorista', 'Telefone do motorista',
                    formatters: [BRFormatters.telefoneFormatter], teclado: TextInputType.phone),
                _campo('emailMotorista', 'E-mail do motorista', teclado: TextInputType.emailAddress),
              ]),
            ],
          ],
        ),

        // 3. CONTATO
        _secao(
          icone: Icons.contact_phone_outlined,
          titulo: 'Contato',
          subtitulo: 'quem a corretora aciona sobre este terceiro',
          filhos: [
            _linha([
              _campo('nomeContato', 'Nome do contato'),
              _campo('telefoneContato', 'Telefone do contato',
                  formatters: [BRFormatters.telefoneFormatter], teclado: TextInputType.phone),
            ]),
          ],
        ),

        // 4. SINISTRO DO TERCEIRO
        _secao(
          icone: Icons.description_outlined,
          titulo: 'Sinistro do terceiro',
          filhos: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextFormField(
                enabled: widget.enabled,
                controller: c['registroSeguradora'],
                decoration: InputDecoration(
                  labelText: 'Nº do registro do sinistro na seguradora do terceiro',
                  isDense: true,
                  filled: true,
                  fillColor: Colors.yellow.shade100,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _campo('relato', 'Relato do terceiro sobre o evento', maxLines: 3),
            ),
          ],
        ),
      ],
    );
  }
}
