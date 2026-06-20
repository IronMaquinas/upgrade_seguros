// lib/widgets/client_search_dialog.dart
import 'dart:async';

import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../services/firestore_service.dart';

class ClientSearchDialog extends StatefulWidget {
  final String initialQuery;
  final Function(Client?) onClientSelected;

  const ClientSearchDialog({
    super.key,
    required this.initialQuery,
    required this.onClientSelected,
  });

  @override
  State<ClientSearchDialog> createState() => _ClientSearchDialogState();
}

class ClientSearchResult {
  final Client? client;
  final String? searchText;
  
  ClientSearchResult.client(Client this.client) : searchText = null;
  ClientSearchResult.newClient(String this.searchText) : client = null;
}

class _ClientSearchDialogState extends State<ClientSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  List<Client> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _performSearch(widget.initialQuery);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      print('Buscando clientes para: "$query"');
      final results = await _firestoreService.searchClients(query);
      print('Resultados encontrados: ${results.length}');
      
      setState(() => _searchResults = results);
    } catch (e) {
      print('Erro na busca: $e');
      // Mostrar mensagem de erro para o usuário
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na busca: $e')),
      );
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Buscar cliente por nome, CPF ou CNPJ',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? const CircularProgressIndicator()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        ),
                ),
                autofocus: true,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _buildSearchResults(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onClientSelected(null);
                      },
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Retornar para cadastrar novo cliente com o texto digitado
                        Navigator.of(context).pop();
                        widget.onClientSelected(null);
                      },
                      child: const Text('Novo Cliente'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Card de pesquisa de clientes existentes
  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Text('Digite nome, CPF ou CNPJ para buscar'),
      );
    }

    if (_searchController.text.length < 2) {
      return const Center(
        child: Text('Digite pelo menos 2 caracteres'),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Nenhum cliente encontrado para "${_searchController.text}"',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifique se digitou corretamente ou cadastre um novo cliente',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

      return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final client = _searchResults[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person, size: 20),
            ),
            title: Text(
              client.nome,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Documento: ${client.cnpjCpf}'),
                if (client.email != null && client.email!.isNotEmpty)
                  Text('Email: ${client.email}'),
              ],
            ),
            onTap: () {
              Navigator.of(context).pop(client); // Fecha o diálogo
              widget.onClientSelected(client);   // ✅ CHAMA O CALLBACK!
            },
          ),
        );
      },
    );
  }
}