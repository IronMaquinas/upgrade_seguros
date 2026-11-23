// lib/utils/perfil_corretora.dart
//
// Etapa 17: textos do cabeçalho e do rodapé padrão dos PDFs, a partir do
// cadastro da corretora (corretoras/{id}) e da assinatura configurada.
// Sem Firebase e sem pdf: só texto, para ser testado.

import '../models/corretora_model.dart';

class PerfilCorretora {
  PerfilCorretora._();

  /// Nome que aparece em destaque (nome fantasia; se vazio, razão social).
  static String nome(Corretora? c) {
    final n = (c?.nome ?? '').trim();
    if (n.isNotEmpty) return n;
    final r = (c?.razaoSocial ?? '').trim();
    return r.isNotEmpty ? r : 'Corretora de Seguros';
  }

  /// "12.345.678/0001-90" a partir de só números; outro formato fica como veio.
  static String formatarCnpj(String? cnpj) {
    final s = (cnpj ?? '').trim();
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.length != 14) return s;
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
  }

  /// Linhas menores abaixo do nome, sem campos vazios:
  ///   1. razão social (se diferente do nome) · CNPJ · SUSEP
  ///   2. endereço
  ///   3. telefone · e-mail · site
  static List<String> linhasCabecalho(Corretora? c) {
    if (c == null) return const [];
    String t(String? v) => (v ?? '').trim();
    final razao = t(c.razaoSocial);
    final l1 = [
      if (razao.isNotEmpty && razao.toLowerCase() != nome(c).toLowerCase()) razao,
      if (t(c.cnpj).isNotEmpty) 'CNPJ ${formatarCnpj(c.cnpj)}',
      if (t(c.susep).isNotEmpty) 'SUSEP ${t(c.susep)}',
    ];
    final l3 = [
      if (t(c.telefone).isNotEmpty) t(c.telefone),
      if (t(c.email).isNotEmpty) t(c.email),
      if (t(c.site).isNotEmpty) t(c.site),
    ];
    return [
      if (l1.isNotEmpty) l1.join(' · '),
      if (t(c.endereco).isNotEmpty) t(c.endereco),
      if (l3.isNotEmpty) l3.join(' · '),
    ];
  }

  /// Rodapé: "Gerado por Ana Souza · (11) 99999-0000 · ana@x.com · 23/11/2026 10:45".
  /// [assinatura] = SignatureDataHelper.getSignatureData (nome/telefone/email).
  static String linhaRodape(Map<String, String?>? assinatura, DateTime quando) {
    String t(String? v) => (v ?? '').trim();
    final a = assinatura ?? const {};
    final dd = quando.day.toString().padLeft(2, '0');
    final mm = quando.month.toString().padLeft(2, '0');
    final hh = quando.hour.toString().padLeft(2, '0');
    final mi = quando.minute.toString().padLeft(2, '0');
    final partes = [
      if (t(a['nome']).isNotEmpty) 'Gerado por ${t(a['nome'])}' else 'Gerado',
      if (t(a['telefone']).isNotEmpty) t(a['telefone']),
      if (t(a['email']).isNotEmpty) t(a['email']),
      '$dd/$mm/${quando.year} $hh:$mi',
    ];
    return partes.join(' · ');
  }

  /// Nome de arquivo seguro: "Upgrade Seguros - SN123.pdf".
  static String nomeArquivo(Corretora? c, String resto, String extensao) {
    final base = '${nome(c)} - $resto'.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').replaceAll(RegExp(r'\s+'), ' ').trim();
    return '$base.$extensao';
  }

  /// Logo aceita no PDF: PNG ou JPG, até 2 MB.
  static const maxBytesLogo = 2 * 1024 * 1024;
  static bool logoAceita(String nomeArquivo, int bytes) {
    final ext = nomeArquivo.toLowerCase().split('.').last;
    return ['png', 'jpg', 'jpeg'].contains(ext) && bytes > 0 && bytes <= maxBytesLogo;
  }
}
