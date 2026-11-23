// test/perfil_corretora_test.dart — Etapa 17
import 'package:flutter_test/flutter_test.dart';
import 'package:upgrade_seguros/models/corretora_model.dart';
import 'package:upgrade_seguros/utils/perfil_corretora.dart';

void main() {
  final completa = Corretora(
    nome: 'Upgrade Seguros',
    razaoSocial: 'Upgrade Corretora de Seguros Ltda.',
    cnpj: '12345678000190',
    susep: '202012345',
    endereco: 'Av. Paulista, 1000 - São Paulo/SP',
    telefone: '(11) 3000-0000',
    email: 'contato@upgrade.com.br',
    site: 'upgrade.com.br',
  );

  group('cabeçalho', () {
    test('nome: fantasia, senão razão social, senão genérico', () {
      expect(PerfilCorretora.nome(completa), 'Upgrade Seguros');
      expect(PerfilCorretora.nome(Corretora(nome: ' ', razaoSocial: 'X Ltda')), 'X Ltda');
      expect(PerfilCorretora.nome(null), 'Corretora de Seguros');
    });
    test('linhas completas', () {
      expect(PerfilCorretora.linhasCabecalho(completa), [
        'Upgrade Corretora de Seguros Ltda. · CNPJ 12.345.678/0001-90 · SUSEP 202012345',
        'Av. Paulista, 1000 - São Paulo/SP',
        '(11) 3000-0000 · contato@upgrade.com.br · upgrade.com.br',
      ]);
    });
    test('campos vazios não aparecem; razão igual ao nome não repete', () {
      final c = Corretora(nome: 'ABC', razaoSocial: 'abc', email: 'a@b.com');
      expect(PerfilCorretora.linhasCabecalho(c), ['a@b.com']);
      expect(PerfilCorretora.linhasCabecalho(Corretora(nome: 'ABC')), <String>[]);
      expect(PerfilCorretora.linhasCabecalho(null), <String>[]);
    });
    test('CNPJ: formata só se tiver 14 dígitos', () {
      expect(PerfilCorretora.formatarCnpj('12.345.678/0001-90'), '12.345.678/0001-90');
      expect(PerfilCorretora.formatarCnpj('123'), '123');
    });
  });

  group('CNPJ (17.1)', () {
    test('dígitos verificadores', () {
      expect(PerfilCorretora.cnpjValido('11.222.333/0001-81'), true);
      expect(PerfilCorretora.cnpjValido('11222333000181'), true);
      expect(PerfilCorretora.cnpjValido('11.222.333/0001-82'), false); // erro de digitação
      expect(PerfilCorretora.cnpjValido('00.000.000/0000-00'), false); // todos iguais
      expect(PerfilCorretora.cnpjValido('123'), false);
      expect(PerfilCorretora.cnpjValido(null), false);
    });
    test('resposta da Receita → razão social, endereço e telefone', () {
      final d = PerfilCorretora.lerReceita({
        'razao_social': 'UPGRADE CORRETORA DE SEGUROS LTDA',
        'nome_fantasia': 'UPGRADE SEGUROS',
        'descricao_situacao_cadastral': 'ATIVA',
        'descricao_tipo_de_logradouro': 'AVENIDA',
        'logradouro': 'NOSSA SENHORA DA PENHA',
        'numero': '100',
        'complemento': 'SALA 2',
        'bairro': 'PRAIA DO CANTO',
        'municipio': 'VITORIA',
        'uf': 'ES',
        'cep': '29055000',
        'ddd_telefone_1': '2733334444',
      });
      expect(d.razaoSocial, 'UPGRADE CORRETORA DE SEGUROS LTDA');
      expect(d.nomeFantasia, 'UPGRADE SEGUROS');
      expect(d.endereco, 'AVENIDA NOSSA SENHORA DA PENHA, 100, SALA 2 - PRAIA DO CANTO - VITORIA/ES - CEP 29055-000');
      expect(d.telefone, '(27) 3333-4444');
      expect(d.ativa, true);
    });
    test('campos ausentes e empresa baixada', () {
      final d = PerfilCorretora.lerReceita({'razao_social': 'X LTDA', 'descricao_situacao_cadastral': 'BAIXADA', 'numero': null});
      expect(d.endereco, '');
      expect(d.telefone, '');
      expect(d.ativa, false);
    });
  });

  group('rodapé', () {
    final quando = DateTime(2026, 11, 23, 9, 5);
    test('com funcionário', () {
      expect(
        PerfilCorretora.linhaRodape({'nome': 'Ana', 'telefone': '(11) 9', 'email': 'ana@x.com'}, quando),
        'Gerado por Ana · (11) 9 · ana@x.com · 23/11/2026 09:05',
      );
    });
    test('sem assinatura', () {
      expect(PerfilCorretora.linhaRodape(null, quando), 'Gerado · 23/11/2026 09:05');
      expect(PerfilCorretora.linhaRodape({'nome': ' ', 'email': null}, quando), 'Gerado · 23/11/2026 09:05');
    });
  });

  group('arquivo e logo', () {
    test('nome do arquivo sem caracteres proibidos', () {
      expect(PerfilCorretora.nomeArquivo(completa, 'SN 2026/11', 'pdf'), 'Upgrade Seguros - SN 2026-11.pdf');
    });
    test('logo: PNG/JPG até 2 MB', () {
      expect(PerfilCorretora.logoAceita('logo.PNG', 1000), true);
      expect(PerfilCorretora.logoAceita('logo.jpeg', PerfilCorretora.maxBytesLogo), true);
      expect(PerfilCorretora.logoAceita('logo.svg', 1000), false);
      expect(PerfilCorretora.logoAceita('logo.png', PerfilCorretora.maxBytesLogo + 1), false);
      expect(PerfilCorretora.logoAceita('logo.png', 0), false);
    });
    test('dadosPerfil não leva data de criação nem ativa', () {
      final m = completa.dadosPerfil();
      expect(m.containsKey('dataCriacao'), false);
      expect(m.containsKey('ativa'), false);
      expect(m['cnpj'], '12345678000190');
    });
  });
}
