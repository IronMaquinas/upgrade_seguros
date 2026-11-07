import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/employee_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployeeService {
  final _db = FirebaseFirestore.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _employees =>
      _db.collection('employees');

  CollectionReference get _users =>
      _db.collection('users');

  // ────────────────────────────────────────────────────────────────────────
  // 🔹 EMPLOYEE (antigo, mantém compatibilidade)
  // ────────────────────────────────────────────────────────────────────────

  Future<void> createEmployee(Employee employee) async {
    await _employees.doc(employee.id).set(employee.toMap());
  }

  Future<Employee?> getEmployee(String uid) async {
    final doc = await _employees.doc(uid).get();
    if (!doc.exists) return null;
    return Employee.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }

  Stream<List<Employee>> streamEmployees() {
    return _employees.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Employee.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  Future<void> updateEmployee(Employee employee) async {
    await _employees.doc(employee.id).update(employee.toMap());
  }

  Future<void> deleteEmployee(String uid) async {
    await _employees.doc(uid).delete();
  }

  Future<void> createEmployeeWithAuth({
    required String nome,
    required String email,
    required String perfil,
  }) async {
    final auth = FirebaseAuth.instance;
    final senhaTemp = '123456';

    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: senhaTemp,
    );

    final employee = Employee(
      id: cred.user!.uid,
      nome: nome,
      email: email,
      perfil: perfil,
    );

    await createEmployee(employee);
    await auth.sendPasswordResetEmail(email: email);
  }

  // ────────────────────────────────────────────────────────────────────────
  // 🔹 USERS (nova interface para o novo layout)
  // ────────────────────────────────────────────────────────────────────────

  /// Stream de todos os usuários (para UserManagementScreen)
  Stream<List<Employee>> getAllEmployeesStream() {
    return _users.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Employee(
          id: doc.id,
          nome: data['nome'] ?? '',
          email: data['email'] ?? '',
          perfil: data['role'] ?? 'user',
          cargo: data['matricula'],
          telefone: data['telefone'],
          ativo: data['ativo'] ?? true,
        );
      }).toList();
    });
  }

  /// Criar novo usuário
  Future<void> createUser({
    required String nome,
    required String email,
    String? matricula,
    required String role,
    String? telefone,  // ← ADICIONE ISTO
  }) async {
    final auth = FirebaseAuth.instance;

    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: '123456',
      );

      await _users.doc(cred.user!.uid).set({
        'nome': nome,
        'email': email,
        'matricula': matricula,
        'role': role,
        'telefone': telefone,  // ← ADICIONE ISTO
        'ativo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }

  /// Atualizar usuário
  Future<void> updateUser(
    String userId, {
    required String nome,
    String? email,
    String? matricula,
    required String role,
    bool? ativo,
  }) async {
    final updateData = {
      'nome': nome,
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (email != null) {
      updateData['email'] = email;
    }

    if (matricula != null) {
      updateData['matricula'] = matricula;
    }

    if (ativo != null) {
      updateData['ativo'] = ativo;
    }

    await _users.doc(userId).update(updateData);
  }

  /// Buscar usuário por ID
  Future<Employee?> getUserById(String userId) async {
    try {
      final doc = await _users.doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      return Employee(
        id: doc.id,
        nome: data['nome'] ?? '',
        email: data['email'] ?? '',
        perfil: data['role'] ?? 'user',
        cargo: data['matricula'],
        telefone: data['telefone'],
        ativo: data['ativo'] ?? true,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Deletar usuário
  Future<void> deleteUser(String userId) async {
    await _users.doc(userId).delete();
  }
}