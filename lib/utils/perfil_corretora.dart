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

  /// Etapa 17.1: CNPJ com 14 dígitos e dígitos verificadores certos
  /// (pega erro de digitação antes de consultar a Receita).
  static bool cnpjValido(String? cnpj) {
    final d = (cnpj ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.length != 14 || RegExp(r'^(\d)\1{13}$').hasMatch(d)) return false;
    int dv(String base, List<int> pesos) {
      var soma = 0;
      for (var i = 0; i < pesos.length; i++) {
        soma += int.parse(base[i]) * pesos[i];
      }
      final r = soma % 11;
      return r < 2 ? 0 : 11 - r;
    }
    final d1 = dv(d, const [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    final d2 = dv(d, const [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]);
    return d1 == int.parse(d[12]) && d2 == int.parse(d[13]);
  }

  /// Etapa 17.1: lê a resposta da consulta de CNPJ (BrasilAPI, a mesma do
  /// cadastro de clientes). Devolve só o que veio preenchido.
  static DadosReceita lerReceita(Map<String, dynamic> j) {
    String t(Object? v) => (v ?? '').toString().trim();
    final logradouro = [t(j['descricao_tipo_de_logradouro']), t(j['logradouro'])]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final rua = [logradouro, t(j['numero']), t(j['complemento'])].where((s) => s.isNotEmpty).join(', ');
    final cidade = [t(j['municipio']), t(j['uf'])].where((s) => s.isNotEmpty).join('/');
    final cep = t(j['cep']).replaceAll(RegExp(r'\D'), '');
    final endereco = [
      rua,
      t(j['bairro']),
      cidade,
      if (cep.length == 8) 'CEP ${cep.substring(0, 5)}-${cep.substring(5)}',
    ].where((s) => s.isNotEmpty).join(' - ');
    final tel = t(j['ddd_telefone_1']).replaceAll(RegExp(r'\D'), '');
    String telefone = '';
    if (tel.length == 10) telefone = '(${tel.substring(0, 2)}) ${tel.substring(2, 6)}-${tel.substring(6)}';
    if (tel.length == 11) telefone = '(${tel.substring(0, 2)}) ${tel.substring(2, 7)}-${tel.substring(7)}';
    return DadosReceita(
      razaoSocial: t(j['razao_social']),
      nomeFantasia: t(j['nome_fantasia']).isNotEmpty ? t(j['nome_fantasia']) : t(j['nome_Fantasia']),
      situacao: t(j['descricao_situacao_cadastral']),
      endereco: endereco,
      telefone: telefone,
    );
  }

  /// Logo aceita no PDF: PNG ou JPG, até 2 MB.
  static const maxBytesLogo = 2 * 1024 * 1024;
  static bool logoAceita(String nomeArquivo, int bytes) {
    final ext = nomeArquivo.toLowerCase().split('.').last;
    return ['png', 'jpg', 'jpeg'].contains(ext) && bytes > 0 && bytes <= maxBytesLogo;
  }
}

/// Etapa 17.1: o que a consulta de CNPJ trouxe.
class DadosReceita {
  final String razaoSocial;
  final String nomeFantasia;
  final String situacao; // "ATIVA", "BAIXADA", "INAPTA"…
  final String endereco;
  final String telefone;

  const DadosReceita({
    this.razaoSocial = '',
    this.nomeFantasia = '',
    this.situacao = '',
    this.endereco = '',
    this.telefone = '',
  });

  bool get ativa => situacao.isEmpty || situacao.toUpperCase() == 'ATIVA';
}
