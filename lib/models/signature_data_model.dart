// lib/models/signature_data_model.dart

/// Modelo para armazenar dados formatados de uma assinatura em PDF
class SignatureData {
  final String nome;
  final String? telefone;
  final String? email;
  final String? rodape;

  SignatureData({
    required this.nome,
    this.telefone,
    this.email,
    this.rodape,
  });

  /// Gera texto formatado da assinatura
  String toFormattedString() {
    final buffer = StringBuffer();

    buffer.writeln('Atenciosamente,');
    buffer.writeln('');
    buffer.writeln(nome);

    if (telefone != null && telefone!.isNotEmpty) {
      buffer.writeln('📞 $telefone');
    }

    if (email != null && email!.isNotEmpty) {
      buffer.writeln('📧 $email');
    }

    if (rodape != null && rodape!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(rodape);
    }

    return buffer.toString();
  }

  /// Gera HTML para inserir em PDF
  String toHtmlString() {
    final buffer = StringBuffer();

    buffer.write('<div style="text-align: left; margin-top: 20px; '
        'font-family: Arial, sans-serif; font-size: 11px;">\n');

    buffer.write('<p>Atenciosamente,</p>\n');
    buffer.write('<p><strong>$nome</strong></p>\n');

    if (telefone != null && telefone!.isNotEmpty) {
      buffer.write('<p>📞 $telefone</p>\n');
    }

    if (email != null && email!.isNotEmpty) {
      buffer.write('<p>📧 <a href="mailto:$email">$email</a></p>\n');
    }

    if (rodape != null && rodape!.isNotEmpty) {
      buffer.write('<p style="margin-top: 10px; color: #666;">$rodape</p>\n');
    }

    buffer.write('</div>\n');

    return buffer.toString();
  }

  @override
  String toString() => 'SignatureData(nome: $nome, telefone: $telefone, email: $email)';
}
