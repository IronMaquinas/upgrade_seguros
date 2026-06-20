import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateUserDialog extends StatefulWidget {
  const CreateUserDialog({super.key});

  @override
  State<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<CreateUserDialog> {
  final _emailCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _nomeCtrl = TextEditingController();

  String _perfil = 'user';
  bool _loading = false;

  Future<void> _criar() async {
    setState(() => _loading = true);

    try {
      final email = _emailCtrl.text.trim();
      final matricula = _matriculaCtrl.text.trim();
      final nome = _nomeCtrl.text.trim();

      final firestore = FirebaseFirestore.instance;

      // 🔒 valida matrícula
      final exists = await firestore
          .collection('users')
          .where('matricula', isEqualTo: matricula)
          .get();

      if (exists.docs.isNotEmpty) {
        throw Exception('Matrícula já cadastrada');
      }

      // 🔥 cria no Auth (senha temporária)
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: '123456',
      );

      // 💾 salva no Firestore
      await firestore.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'nome': nome,
        'matricula': matricula,
        'role': _perfil,
        'ativo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 🔥 envia reset de senha
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);

      if (mounted) Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Usuário'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _nomeCtrl, decoration: const InputDecoration(labelText: 'Nome')),
          TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _matriculaCtrl, decoration: const InputDecoration(labelText: 'Matrícula')),

          DropdownButton<String>(
            value: _perfil,
            items: ['admin', 'gestor', 'user']
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _perfil = v!),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _loading ? null : _criar,
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Criar'),
        ),
      ],
    );
  }
}