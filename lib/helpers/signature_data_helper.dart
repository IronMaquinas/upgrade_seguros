// lib/helpers/signature_data_helper.dart

import 'package:upgrade_seguros/models/pdf_signature_model.dart';
import 'package:upgrade_seguros/models/employee_model.dart';
import 'package:upgrade_seguros/models/corretora_model.dart';

class SignatureDataHelper {
  static Map<String, String?> getSignatureData({
    required SignatureSource nomeSource,
    required SignatureSource telefoneSource,
    required SignatureSource emailSource,
    required Employee? currentEmployee,
    required Corretora? corretora,
    required String nomeController,
    required String telefoneController,
    required String emailController,
  }) {
    String? nome;
    String? telefone;
    String? email;

    // Nome
    if (nomeSource == SignatureSource.funcionario) {
      nome = currentEmployee?.nome;
    } else {
      nome = nomeController.isNotEmpty ? nomeController : corretora?.nome;
    }

    // Telefone
    if (telefoneSource == SignatureSource.funcionario) {
      telefone = currentEmployee?.telefone;
    } else {
      telefone = telefoneController.isNotEmpty ? telefoneController : corretora?.telefone;
    }

    // Email
    if (emailSource == SignatureSource.funcionario) {
      email = currentEmployee?.email;
    } else {
      email = emailController.isNotEmpty ? emailController : corretora?.email;
    }

    return {
      'nome': nome,
      'telefone': telefone,
      'email': email,
    };
  }
}