// lib/utils/constants.dart

import 'package:flutter/material.dart';

class AppStrings {
  // Títulos
  static const String appName = 'Upgrade Sinistros';
  static const String loginTitle = 'Login Upgrade Sinistros';
  static const String dashboardTitle = 'Upgrade Sinistros';
  static const String newClaimTitle = 'Abrir Novo Sinistro';
  static const String clientListTitle = 'Gestão de Clientes';
  static const String claimListTitle = 'Sinistros';
  static const String claimDetailTitle = 'Detalhes do Sinistro';
  static const String clientDetailTitle = 'Detalhes do Cliente';
  static const String reportsTitle = 'Relatórios';

  // Labels
  static const String emailLabel = 'E-mail';
  static const String passwordLabel = 'Senha';
  static const String cpfCnpjLabel = 'CPF/CNPJ do Segurado';
  static const String nameLabel = 'Nome/Razão Social';
  static const String contactLabel = 'Contato (Telefone)';
  static const String emailInputLabel = 'E-mail';
  static const String chassisLabel = 'Chassi';
  static const String brandLabel = 'Marca';
  static const String modelLabel = 'Modelo';
  static const String yearLabel = 'Ano';
  static const String plateLabel = 'Placa (Opcional)';
  static const String locationLabel = 'Local da Ocorrência';
  static const String reportLabel = 'Relato completo do evento';
  static const String addPhotoLabel = 'Adicionar Foto da Ocorrência';
  static const String attachFileLabel = 'Anexar Arquivo/Laudo';

  // Botões
  static const String signInButton = 'Entrar';
  static const String forgotPasswordButton = 'Esqueci minha senha';
  static const String searchButton = 'Buscar';
  static const String nextStepButton = 'Próximo';
  static const String finishButton = 'Finalizar';
  static const String updateStatusButton = 'Atualizar Status';
  static const String refreshReportsButton = 'Atualizar Relatórios';

  // Erros
  static const String emptyEmailError = 'Por favor, insira um e-mail.';
  static const String invalidEmailError = 'E-mail inválido.';
  static const String emptyPasswordError = 'Por favor, insira uma senha.';
  static const String emptyCpfCnpjError = 'Campo obrigatório.';
  static const String emptyNameError = 'Nome é obrigatório.';
  static const String emptyContactError = 'Contato é obrigatório.';
  static const String emptyChassisError = 'Chassi é obrigatório.';
  static const String emptyBrandError = 'Marca é obrigatória.';
  static const String emptyModelError = 'Modelo é obrigatório.';
  static const String emptyYearError = 'Ano é obrigatório.';

  // Mensagens
  static const String anonymousSignInWarning =
      'Você está logado como visitante. Faça login para acessar todos os recursos.';
  static const String noClientsFound = 'Nenhum cliente cadastrado.';
  static const String noClaimsFound = 'Nenhum sinistro registrado.';
  static const String noThirdPartiesFound = 'Nenhum terceiro envolvido.';
}

class AppColors {
  // Cores principais
  static const Color primaryColor = Colors.blueAccent;
  static const Color secondaryColor = Colors.grey;

  // Cores de status
  static const Map<String, Color> statusColors = {
    'Aberto': Colors.red,
    'Vistoria em Andamento': Colors.orange,
    'Aguardando Aprovação': Colors.yellow,
    'Aguardando Peças': Colors.blueGrey,
    'Reparo em Andamento': Colors.blue,
    'Concluído': Colors.green,
  };

  // Recomendações de manutenção
  static const Map<String, Color> maintenanceRecommendationColors = {
    'Ótimo': Colors.green,
    'Bom': Colors.blue,
    'Atenção': Colors.orange,
    'Crítico': Colors.red,
  };
}

class AppStyles {
  // Estilos de texto reutilizáveis
  static const TextStyle headlineStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subheadStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle captionStyle = TextStyle(
    fontSize: 12,
    color: Colors.grey,
  );

  static const TextStyle chipTextStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
  );
}