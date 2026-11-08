// Testes do SLA de sinistro por ramo (Etapa 08).
// Rodar no Mac: flutter test test/config_sla_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/models/config_model.dart';

void main() {
  group('SLA de sinistro por ramo', () {
    test('documento antigo (6 ramos) ganha RCO = 7 e Empresarial = 10', () {
      final sla = AppConfig.fromMap({
        'slaSinistrosPorRamo': {
          'Veículo Individual': 10,
          'Frota': 3,
          'Transporte': 5,
          'Máquinas': 10,
          'Residencial': 10,
          'Vida': 10,
        },
      }).slaSinistrosPorRamo;
      expect(sla['Civil Ônibus (RCO)'], 7);
      expect(sla['Empresarial'], 10);
      expect(sla['Frota'], 3); // o que está salvo vale
      expect(sla.length, 8);
    });

    test('a tela mostra os ramos na ordem padrão', () {
      final sla = AppConfig.fromMap({}).slaSinistrosPorRamo;
      expect(sla.keys.toList(), [
        'Veículo Individual',
        'Frota',
        'Civil Ônibus (RCO)',
        'Transporte',
        'Máquinas',
        'Residencial',
        'Empresarial',
        'Vida',
      ]);
    });

    test('o mapa lido pode ser alterado (a tela salva por cima)', () {
      final sla = AppConfig.fromMap({}).slaSinistrosPorRamo;
      sla['Empresarial'] = 12;
      expect(sla['Empresarial'], 12);
    });

    test('"Vidas" (ramo do sinistro) usa o SLA de "Vida"', () {
      expect(AppConfig.chaveSlaRamo('Vidas'), 'Vida');
      expect(AppConfig.chaveSlaRamo('Frota'), 'Frota');
      final sla = AppConfig.fromMap({
        'slaSinistrosPorRamo': {'Vidas': 4},
      }).slaSinistrosPorRamo;
      expect(sla['Vida'], 4);
      expect(sla.containsKey('Vidas'), false);
    });
  });
}
