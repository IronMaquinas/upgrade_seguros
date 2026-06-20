import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticateWithBiometrics() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        // Dispositivo não suporta biometria
        return false;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Autentique-se para acessar o app',
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      return authenticated;
    } catch (e) {
      print("Erro na autenticação biométrica: $e");
      return false;
    }
  }
}