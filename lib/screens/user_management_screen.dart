import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:upgrade_seguros/services/employee_service.dart';
import 'package:upgrade_seguros/models/employee_model.dart';

// ─── Paleta (igual Seguradoras) ───────────────────────────────────────────
const _kBlue  = Color(0xFF1565C0);
const _kGreen = Color(0xFF2E7D32);
const _kRed   = Color(0xFFC62828);
const _kBg    = Color(0xFFF4F6F9);
const _kGray  = Color(0xFF546E7A);

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _service = EmployeeService();
  String _busca = '';

  // ── Abre o bottom sheet de cadastro / edição ──────────────────────────────
  Future<void> _abrirForm({Employee? employee}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UserForm(
        employee: employee,
        service: _service,
      ),
    );
  }

  // ── Toggle ativo/inativo ──────────────────────────────────────────────────
  Future<void> _toggleAtivo(Employee e) async {
    final acao = e.ativo ? 'desativar' : 'ativar';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${e.ativo ? "Desativar" : "Ativar"} usuário?'),
        content: Text('Deseja $acao "${e.nome}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              e.ativo ? 'Desativar' : 'Ativar',
              style: TextStyle(color: e.ativo ? _kRed : _kGreen),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _service.updateUser(
          e.id,
          nome: e.nome,
          email: e.email,
          role: e.perfil,
          ativo: !e.ativo,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  // ── Deletar usuário ───────────────────────────────────────────────────────
  Future<void> _deletarUsuario(Employee e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar usuário?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tem certeza que deseja deletar "${e.nome}"?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kRed.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info, color: _kRed, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'O email permanecerá bloqueado no sistema por segurança.',
                      style: TextStyle(fontSize: 12, color: _kRed),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Deletar',
              style: TextStyle(color: _kRed),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _service.deleteUser(e.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usuário "${e.nome}" deletado com sucesso'),
            backgroundColor: _kGreen,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao deletar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── HEADER ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                const Text(
                  'Usuários',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _abrirForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // ── BUSCA ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              onChanged: (v) => setState(() => _busca = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por nome, email...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                prefixIcon: const Icon(Icons.search, color: _kGray),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // ── LISTA ─────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Employee>>(
              stream: _service.getAllEmployeesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data ?? [];
                final filtered = users
                    .where((u) =>
                        u.nome.toLowerCase().contains(_busca) ||
                        u.email.toLowerCase().contains(_busca))
                    .toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Nenhum usuário encontrado'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final user = filtered[index];

                    return GestureDetector(
                      onTap: () => _abrirForm(employee: user),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // ── Avatar ────────────────────────────────────
                            CircleAvatar(
                              backgroundColor: _getColor(user.perfil),
                              radius: 24,
                              child: Text(
                                user.nome.isNotEmpty ? user.nome[0] : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            // ── Info ──────────────────────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Matrícula: ${user.cargo ?? "-"}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ── Badge Perfil ─────────────────────────────
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getColor(user.perfil).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.perfil.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getColor(user.perfil),
                                ),
                              ),
                            ),

                            // ── Status ────────────────────────────────────
                            const SizedBox(width: 8),
                            Icon(
                              user.ativo ? Icons.check_circle : Icons.cancel,
                              color: user.ativo ? _kGreen : Colors.grey.shade400,
                              size: 20,
                            ),

                            // ── Botão Delete ──────────────────────────────
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _deletarUsuario(user),
                              child: Icon(
                                Icons.delete_outline,
                                color: Colors.grey.shade400,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return _kRed;
      case 'gestor':
        return const Color(0xFFE65100);
      default:
        return _kBlue;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ─ FORM MODAL ─────────────────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════════

class _UserForm extends StatefulWidget {
  final Employee? employee;
  final EmployeeService service;

  const _UserForm({
    required this.employee,
    required this.service,
  });

  bool get _isEdit => employee != null;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _cargoCtrl;
  late final TextEditingController _telefoneCtrl;

  String _perfil = 'user';
  bool _ativo = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.employee != null) {
      _nomeCtrl = TextEditingController(text: widget.employee!.nome);
      _emailCtrl = TextEditingController(text: widget.employee!.email);
      _cargoCtrl = TextEditingController(text: widget.employee!.cargo ?? '');
      _telefoneCtrl =
          TextEditingController(text: widget.employee!.telefone ?? '');
      _perfil = widget.employee!.perfil;
      _ativo = widget.employee!.ativo;
    } else {
      _nomeCtrl = TextEditingController();
      _emailCtrl = TextEditingController();
      _cargoCtrl = TextEditingController();
      _telefoneCtrl = TextEditingController();
      _perfil = 'user';
      _ativo = true;
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _cargoCtrl.dispose();
    _telefoneCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  Future<void> _salvar() async {
    setState(() => _isSaving = true);
 
    try {
      if (widget._isEdit) {
        print('DEBUG: Editando usuário ${widget.employee!.id}');
        print('DEBUG: Nome: ${_nomeCtrl.text}');
        print('DEBUG: Email: ${_emailCtrl.text}');
        print('DEBUG: Matrícula: ${_cargoCtrl.text}');
        print('DEBUG: Telefone: ${_telefoneCtrl.text}');
        print('DEBUG: Perfil: $_perfil');
        print('DEBUG: Ativo: $_ativo');
        
        await widget.service.updateUser(
          widget.employee!.id,
          nome: _nomeCtrl.text,
          email: _emailCtrl.text,
          matricula: _cargoCtrl.text,
          role: _perfil,
          ativo: _ativo,
        );
        
        // 🆕 IMPORTANTE: Salvar telefone também!
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.employee!.id)
            .update({
              'telefone': _telefoneCtrl.text.isNotEmpty ? _telefoneCtrl.text : null,
            });
        
        print('DEBUG: Update realizado com sucesso');
      } else {
        print('DEBUG: Criando novo usuário');
        await widget.service.createUser(
          nome: _nomeCtrl.text,
          email: _emailCtrl.text,
          matricula: _cargoCtrl.text,
          role: _perfil,
        );
        print('DEBUG: Usuário criado com sucesso');
      }
 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget._isEdit ? 'Alterações salvas' : 'Usuário criado'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e, stackTrace) {
      print('ERRO: $e');
      print('STACKTRACE: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Título ────────────────────────────────────────────────────
            Text(
              widget._isEdit ? 'Editar Usuário' : 'Novo Usuário',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 18),

            // ── Nome ──────────────────────────────────────────────────────
            TextFormField(
              controller: _nomeCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: _dec('Nome *', icon: Icons.person_outline),
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Nome obrigatório' : null,
            ),

            const SizedBox(height: 12),

            // ── Email ─────────────────────────────────────────────────────
            if (!widget._isEdit) ...[
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email *', icon: Icons.email_outlined),
                validator: (v) => (v?.trim().isEmpty ?? true)
                    ? 'Email obrigatório'
                    : null,
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Em edição, mostrar email como somente leitura
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, color: _kGray, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            _emailCtrl.text,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Cargo / Matrícula ─────────────────────────────────────────
            TextFormField(
              controller: _cargoCtrl,
              decoration: _dec('Usuário ou Matrícula', icon: Icons.badge_outlined),
            ),

            const SizedBox(height: 12),

            // ── Telefone ──────────────────────────────────────────────────
            TextFormField(
              controller: _telefoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _dec('Telefone', icon: Icons.phone_outlined),
            ),

            const SizedBox(height: 14),

            // ── Perfil ────────────────────────────────────────────────────
            DropdownButtonFormField<String>(
              value: _perfil,
              items: ['admin', 'gestor', 'user']
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _perfil = v ?? 'user'),
              decoration: _dec('Perfil', icon: Icons.security_outlined),
            ),

            const SizedBox(height: 14),

            // ── Status (só em edição) ─────────────────────────────────────
            if (widget._isEdit)
              Row(
                children: [
                  Switch(
                    value: _ativo,
                    activeColor: _kGreen,
                    onChanged: (v) => setState(() => _ativo = v),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _ativo ? 'Usuário ativo' : 'Usuário desativado',
                    style: TextStyle(
                      fontSize: 13,
                      color: _ativo ? _kGreen : _kRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            // ── Botão Salvar ──────────────────────────────────────────────
            ElevatedButton(
              onPressed: _isSaving ? null : _salvar,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      widget._isEdit ? 'Salvar alterações' : 'Criar usuário',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}