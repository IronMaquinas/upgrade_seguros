import 'package:flutter/material.dart';
import '../services/employee_service.dart';

class UserFormModal extends StatefulWidget {
  final String? userId;
  final Map<String, dynamic>? data;

  const UserFormModal({
    super.key,
    this.userId,
    this.data,
  });

  bool get isEdit => userId != null;

  @override
  State<UserFormModal> createState() => _UserFormModalState();
}

class _UserFormModalState extends State<UserFormModal> {
  final _nomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();

  String _role = 'user';
  bool _isSaving = false;

  final _service = EmployeeService();

  @override
  void initState() {
    super.initState();

    if (widget.data != null) {
      _nomeCtrl.text = widget.data!['nome'] ?? '';
      _emailCtrl.text = widget.data!['email'] ?? '';
      _matriculaCtrl.text = widget.data!['matricula'] ?? '';
      _role = widget.data!['role'] ?? 'user';
    }
  }

  Future<void> _salvar() async {
    setState(() => _isSaving = true);

    try {
      if (widget.isEdit) {
        await _service.updateUser(
          widget.userId!,
          nome: _nomeCtrl.text,
          matricula: _matriculaCtrl.text,
          role: _role,
        );
      } else {
        await _service.createUser(
          nome: _nomeCtrl.text,
          email: _emailCtrl.text,
          matricula: _matriculaCtrl.text,
          role: _role,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // HANDLE
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // TÍTULO
          Text(
            widget.isEdit ? 'Editar Usuário' : 'Novo Usuário',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 18),

          // NOME
          TextField(
            controller: _nomeCtrl,
            decoration: const InputDecoration(labelText: 'Nome *'),
          ),

          const SizedBox(height: 12),

          // EMAIL (só criação)
          if (!widget.isEdit)
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email *'),
            ),

          if (!widget.isEdit) const SizedBox(height: 12),

          // MATRÍCULA
          TextField(
            controller: _matriculaCtrl,
            decoration: const InputDecoration(labelText: 'Matrícula'),
          ),

          const SizedBox(height: 12),

          // PERFIL
          DropdownButtonFormField<String>(
            value: _role,
            items: ['admin', 'gestor', 'user']
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e.toUpperCase()),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _role = v!),
            decoration: const InputDecoration(labelText: 'Perfil'),
          ),

          const SizedBox(height: 20),

          // BOTÃO
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _salvar,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : Text(widget.isEdit ? 'Salvar alterações' : 'Criar usuário'),
            ),
          ),
        ],
      ),
    );
  }
}