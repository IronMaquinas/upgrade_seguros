// lib/parsers/parser_factory.dart
import 'package:upgrade_seguros/models/contrato_dto.dart';
import 'tokio_marine_parser.dart';
import 'porto_seguro_parser.dart';
import 'ezze_parser.dart';
import 'axa_parser.dart';
 
class ParserFactory {
  static ContratoDTO parseContrato(String texto) {
    if (texto.contains('Tokio Marine')) {
      return TokioMarineParser.parse(texto);
    } else if (texto.contains('Porto Seguro') || texto.contains('PortoSeguro')) {
      return PortoSeguroParser.parse(texto);
    } else if (texto.contains('EZZE SEGUROS') || texto.contains('Ezze')) {
      return EzzeParser.parse(texto);
    } else if (texto.contains('AXA') || texto.contains('AXA Seguros')) {
      return AxaParser.parse(texto);
    }
    throw Exception('❌ Seguradora não reconhecida...');
  }
}