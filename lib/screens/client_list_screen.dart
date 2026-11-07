import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client_model.dart';
import '../models/claim_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../screens/client_detail_screen.dart';
import '../screens/client_form_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key, this.onNavigate});
  final void Function(Widget screen)? onNavigate;

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClients);
    _searchController.dispose();
    super.dispose();
  }

  // ─── Busca e Filtros ─────────────────────────────────────────────

  Future<void> _fetchClients() async {
    setState(() => _isLoading = true);

    final userId = _authService.getUserId();
    if (userId == 'anonymous_user') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado. Faça login.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final clients = await _firestoreService.getClients(userId);
      final claims = await _firestoreService.getClaims();

      for (var client in clients) {
        final clientClaims = claims.where((claim) => claim.idCliente == client.id).toList();
        client.recomendacaoManutencao = calcularRecomendacaoManutencao(
          client.valorTotalApolicesAtivas,
          clientClaims,
        );
        client.totalSinistrosAcionados = clientClaims.length;
      }

      setState(() {
        _clients = clients;
        _filteredClients = clients;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar clientes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterClients() {
    final query = _searchController.text.toLowerCase().trim();
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');

    setState(() {
      _filteredClients = _clients.where((client) {
        final telefoneDigits = client.contatoTelefone.replaceAll(RegExp(r'\D'), '');
        final nomeMatch = client.nome.toLowerCase().contains(query);
        final cpfMatch = client.cnpjCpf.toLowerCase().contains(query);
        final telefoneMatch = queryDigits.isNotEmpty && telefoneDigits.contains(queryDigits);

        // Log para debug (opcional)
        // if (telefoneMatch) {
        //   print('✅ Match por telefone: ${client.nome} - $telefoneDigits');
        // }

        return nomeMatch || cpfMatch || telefoneMatch;
      }).toList();
    });
  }

  // ─── Helpers de UI ────────────────────────────────────────────────

  String calcularRecomendacaoManutencao(double valorApolice, List<Claim> claims) {
    final totalSinistros = claims.fold<double>(0.0, (sum, c) => sum + c.valorTotalSinistro);
    if (valorApolice <= 0) return 'Não recomendado';

    final percentual = totalSinistros / valorApolice;
    if (percentual < 0.5) return 'Ótimo';
    if (percentual >= 0.5 && percentual < 0.75) return 'Regular';
    if (percentual >= 0.75 && percentual < 1.0) return 'Atenção';
    return 'Não recomendado';
  }

  Color _getRecommendationColor(String recommendation) {
    switch (recommendation) {
      case 'Ótimo': return Colors.green.shade100;
      case 'Regular': return Colors.amber.shade100;
      case 'Atenção': return Colors.orange.shade100;
      case 'Não recomendado': return Colors.red.shade100;
      default: return Colors.grey.shade100;
    }
  }

  Color _getRecommendationTextColor(String recommendation) {
    switch (recommendation) {
      case 'Ótimo': return Colors.green.shade900;
      case 'Regular': return Colors.amber.shade900;
      case 'Atenção': return Colors.orange.shade900;
      case 'Não recomendado': return Colors.red.shade900;
      default: return Colors.grey.shade900;
    }
  }

  // ─── Widgets de Card ─────────────────────────────────────────────

  Widget _buildClientCard(Client client) {
    final now = DateTime.now();
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    final apolicesVencendo = client.apolices.where((a) =>
      a.dataFim.isAfter(now) && a.dataFim.isBefore(thirtyDaysFromNow)
    ).toList();
    final isExpiringSoon = apolicesVencendo.isNotEmpty;
    
    final apoliceProxVencer = client.apolices.isEmpty ? null : 
      client.apolices.reduce((a, b) => a.dataFim.isBefore(b.dataFim) ? a : b);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.blueAccent.withOpacity(0.2),
                    child: const Icon(Icons.person, size: 18, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      client.nome,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                client.cnpjCpf,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Sinistros: ${client.totalSinistrosAcionados}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  if (apoliceProxVencer != null)
                    Text(
                      'Vigência: ${DateFormat('dd/MM/yyyy').format(apoliceProxVencer.dataFim)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isExpiringSoon ? Colors.red : Colors.grey,
                        fontWeight: isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  if (isExpiringSoon)
                    const Icon(Icons.warning, color: Colors.red, size: 16),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  label: Text(
                    client.recomendacaoManutencao,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: _getRecommendationColor(client.recomendacaoManutencao),
                  labelStyle: TextStyle(
                    color: _getRecommendationTextColor(client.recomendacaoManutencao),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Gestão de Clientes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _fetchClients,
            tooltip: 'Atualizar',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por Nome, CPF/CNPJ ou Telefone',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 0.8),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_filteredClients.isEmpty) {
            return Center(
              child: Text(
                _searchController.text.isEmpty
                    ? 'Nenhum cliente cadastrado.'
                    : 'Nenhum cliente encontrado com os filtros aplicados.',
                style: const TextStyle(fontSize: 16),
              ),
            );
          }

          if (constraints.maxWidth > 600) {
            final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 180,
                ),
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) => _buildClientCard(_filteredClients[index]),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _fetchClients,
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) => _buildClientCard(_filteredClients[index]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ClientFormScreen(
                onSaved: () {
                  _fetchClients();
                },
              ),
            ),
          );
          if (result == true) {
            _fetchClients();
          }
        },
        child: const Icon(Icons.person_add),
        tooltip: 'Cadastrar novo cliente',
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
    );
  }
}