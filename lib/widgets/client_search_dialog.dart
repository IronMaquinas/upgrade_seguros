// lib/widgets/client_search_dialog.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../services/firestore_service.dart';
import '../screens/client_form_screen.dart';

// ─── Resultado da busca ───────────────────────────────────────────────────────
// Mantém a API original para compatibilidade com todos os lugares que já usam.
class ClientSearchResult {
  final Client? client;
  final String? searchText;

  ClientSearchResult.client(Client this.client) : searchText = null;
  ClientSearchResult.newClient(String this.searchText) : client = null;
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
class ClientSearchDialog extends StatefulWidget {
  const ClientSearchDialog({
    super.key,
    required this.initialQuery,
    required this.onClientSelected,
  });

  final String initialQuery;

  /// Callback mantido por compatibilidade — mas o dialog agora também retorna
  /// um ClientSearchResult via Navigator.pop(), que é a forma correta de uso.
  final Function(Client?) onClientSelected;

  @override
  State<ClientSearchDialog> createState() => _ClientSearchDialogState();
}

class _ClientSearchDialogState extends State<ClientSearchDialog> {
  final _searchCtrl = TextEditingController();
  final _firestoreService = FirestoreService();

  List<Client> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  // Paleta consistente com o resto do app
  static const _blue   = Color(0xFF1565C0);
  static const _bg     = Color(0xFFF4F6F9);

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) _search(widget.initialQuery);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() { _results = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final r = await _firestoreService.searchClients(query.trim());
      if (mounted) setState(() => _results = r);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro na busca: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ── Seleciona cliente existente ───────────────────────────────────────────
  // BUG CORRIGIDO: antes retornava `client` (tipo Client) via pop(),
  // mas o chamador esperava ClientSearchResult. Agora retorna ClientSearchResult.
  void _selectClient(Client client) {
    widget.onClientSelected(client);
    Navigator.of(context).pop(ClientSearchResult.client(client));
  }

  // ── Navega para cadastro de novo cliente ─────────────────────────────────
  Future<void> _newClient() async {
    // Fecha o dialog antes de navegar para não empilhar rotas desnecessárias
    Navigator.of(context).pop();

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClientFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isWide ? 80 : 16,
        vertical: 40,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          children: [
            // ── Cabeçalho ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_search_outlined,
                        color: _blue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buscar cliente',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A2E))),
                        Text('Nome, CPF ou CNPJ',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF888888))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Color(0xFF888888)),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            // ── Campo de busca ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Digite nome, CPF ou CNPJ...',
                  hintStyle: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400),
                  prefixIcon: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _blue),
                          ),
                        )
                      : const Icon(Icons.search, color: _blue, size: 18),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 16, color: Color(0xFF888888)),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _results = []);
                          },
                          splashRadius: 16,
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 11),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300, width: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: Colors.grey.shade300, width: 0.8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: _blue, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── Resultados ────────────────────────────────────────────────
            Expanded(child: _buildResults()),

            // ── Rodapé ────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEEE), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(
                            color: Colors.grey.shade300, width: 0.8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Cancelar',
                          style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _newClient,
                      icon: const Icon(Icons.person_add_outlined, size: 16),
                      label: const Text('Novo Cliente',
                          style: TextStyle(fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    // Estado inicial — sem busca ainda
    if (_searchCtrl.text.isEmpty) {
      return _placeholder(
        icon: Icons.search,
        text: 'Digite nome, CPF ou CNPJ para buscar',
      );
    }

    // Menos de 2 caracteres
    if (_searchCtrl.text.trim().length < 2) {
      return _placeholder(
        icon: Icons.keyboard_outlined,
        text: 'Digite pelo menos 2 caracteres',
      );
    }

    // Buscando
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    // Sem resultados
    if (_results.isEmpty) {
      return _placeholder(
        icon: Icons.person_search_outlined,
        text: 'Nenhum cliente encontrado',
        sub: 'Verifique o texto ou cadastre um novo cliente abaixo',
      );
    }

    // Lista de resultados
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, i) => _ClientTile(
        client: _results[i],
        onTap: () => _selectClient(_results[i]),
      ),
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String text,
    String? sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Card de cliente no resultado ─────────────────────────────────────────────
class _ClientTile extends StatelessWidget {
  const _ClientTile({required this.client, required this.onTap});
  final Client client;
  final VoidCallback onTap;

  // Iniciais para o avatar
  String get _initials {
    final parts = client.nome.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return client.nome.isNotEmpty
        ? client.nome[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.grey.shade200, width: 0.8),
          ),
          child: Row(
            children: [
              // Avatar com iniciais
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Dados do cliente
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.nome,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A2E)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      client.cnpjCpf,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                    if (client.email.isNotEmpty)
                      Text(
                        client.email,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Ícone de seta — indica que é clicável
              Icon(Icons.chevron_right,
                  size: 16, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}