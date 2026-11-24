// lib/widgets/portao_empresa.dart
//
// Etapa 16: antes de abrir o Dashboard, descobre a corretora do usuário
// logado (users/{uid}.empresaId — ver lib/services/empresa_atual.dart).
// Todas as telas leem e gravam dentro de corretoras/{empresaId}/…, então nada
// pode acessar o banco antes disto.
//
// Também segura as telas enquanto os dados antigos não foram passados para a
// pasta da corretora (corretoras/{id}.migradoEtapa16 != true): o
// administrador vê o cartão de migração; os demais, um aviso. Assim ninguém
// trabalha com a pasta ainda vazia (ex.: um sinistro novo ganhando o nº 1).
//
// Sem corretora no cadastro: aviso + Sair (em vez de telas vazias).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/auth_screen.dart';
import '../services/auth_service.dart';
import '../services/empresa_atual.dart';
import '../services/plano_atual.dart'; // Etapa 23
import '../screens/meu_plano_screen.dart'; // Etapa 25
import '../utils/situacao_conta.dart'; // Etapa 25
import 'migracao_empresa_card.dart';

enum _Situacao { pronta, migracaoPendenteAdmin, migracaoPendente }

class PortaoEmpresa extends StatefulWidget {
  final Widget child;
  const PortaoEmpresa({super.key, required this.child});

  @override
  State<PortaoEmpresa> createState() => _PortaoEmpresaState();
}

class _PortaoEmpresaState extends State<PortaoEmpresa> {
  late Future<_Situacao> _carregando;

  @override
  void initState() {
    super.initState();
    _carregando = _verificar();
  }

  Future<_Situacao> _verificar() async {
    final id = await EmpresaAtual.carregar(forcar: true);
    await PlanoAtual.carregar(); // Etapa 23: módulos do plano (falha de leitura = tudo ligado)
    final cadastro = await FirebaseFirestore.instance.collection('corretoras').doc(id).get();
    if (cadastro.data()?['migradoEtapa16'] == true) return _Situacao.pronta;
    return await AuthService().isAdmin() ? _Situacao.migracaoPendenteAdmin : _Situacao.migracaoPendente;
  }

  void _tentarDeNovo() => setState(() => _carregando = _verificar());

  Future<void> _sair() async {
    EmpresaAtual.limpar();
    PlanoAtual.limpar(); // Etapa 23
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Widget _tela({required IconData icone, required String texto, Widget? extra}) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 48, color: Colors.grey.shade500),
                  const SizedBox(height: 16),
                  Text(texto, textAlign: TextAlign.center),
                  if (extra != null) ...[const SizedBox(height: 16), extra],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(onPressed: _tentarDeNovo, child: const Text('Tentar de novo')),
                      const SizedBox(width: 12),
                      ElevatedButton(onPressed: _sair, child: const Text('Sair')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Situacao>(
      future: _carregando,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _tela(
            icone: Icons.business_outlined,
            texto: snap.error is EmpresaNaoDefinida
                ? snap.error.toString()
                : 'Não foi possível carregar os dados da sua corretora: ${snap.error}',
          );
        }
        switch (snap.data!) {
          case _Situacao.pronta:
            return _ComAvisoDaConta(child: widget.child); // Etapa 25
          case _Situacao.migracaoPendenteAdmin:
            return _tela(
              icone: Icons.drive_file_move_outline,
              texto: 'Atualização da Etapa 16: os dados da corretora precisam ser passados para a nova '
                  'organização do banco. Clique em "Copiar" abaixo e, quando terminar, em "Tentar de novo".',
              extra: const CartaoMigracaoEmpresa(),
            );
          case _Situacao.migracaoPendente:
            return _tela(
              icone: Icons.hourglass_empty,
              texto: 'O sistema está sendo atualizado pelo gestor. Tente de novo em alguns minutos.',
            );
        }
      },
    );
  }
}

/// Etapa 25: faixa no topo com o teste grátis (dias que faltam) ou o modo só
/// leitura (teste terminou, suspensa, cancelada). Sem aviso, só o app.
class _ComAvisoDaConta extends StatelessWidget {
  final Widget child;
  const _ComAvisoDaConta({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: PlanoAtual.versao,
      builder: (context, _, __) {
        final efetiva = PlanoAtual.situacaoEfetiva;
        final texto = SituacaoConta.aviso(efetiva, PlanoAtual.testeAte);
        if (texto.isEmpty) return child;
        final grave = PlanoAtual.somenteLeitura || efetiva == 'inadimplente';
        final cor = grave ? const Color(0xFFC62828) : const Color(0xFF1565C0);
        return Column(children: [
          Material(
            color: grave ? const Color(0xFFFFEBEE) : const Color(0xFFE3F2FD),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  Icon(grave ? Icons.lock_clock_outlined : Icons.hourglass_bottom, size: 18, color: cor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(texto, style: TextStyle(fontSize: 13, color: cor, fontWeight: FontWeight.w600))),
                  TextButton(onPressed: () => abrirMeuPlano(context), child: const Text('Ver meu plano')),
                ]),
              ),
            ),
          ),
          Expanded(child: child),
        ]);
      },
    );
  }
}
