import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/client_model.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../screens/client_detail_screen.dart';
import '../screens/client_form_screen.dart';
import '../services/config_service.dart';
import '../services/recomendacao_service.dart';
import '../services/relatorio_clientes_pdf.dart';
import '../utils/relatorio_clientes.dart';
import '../widgets/recomendacao_chip.dart';

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
  bool _exportando = false;

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
      final percentualGatilho = await ConfigService().getPercentualGatilho();

      for (var client in clients) {
        final clientClaims = claims.where((claim) => claim.idCliente == client.id).toList();
        // Etapa 09: regra única (uso do gatilho da pior apólice vigente).
        client.recomendacaoManutencao = recomendarCliente(client, clientClaims, percentualGatilho).rotulo;
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

  // Etapa 09: a recomendação e as cores do selo vêm de
  // lib/services/recomendacao_service.dart e lib/widgets/recomendacao_chip.dart.

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
                  backgroundColor: corFundoRecomendacao(client.recomendacaoManutencao),
                  labelStyle: TextStyle(
                    color: corTextoRecomendacao(client.recomendacaoManutencao),
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

  // ─── Etapa 08: relatório de clientes (auditoria) ──────────────────
  // Exporta os clientes mostrados na lista (todos, ou os da busca), com os
  // sinistros e assistências de cada um. Regra em lib/utils/relatorio_clientes.dart.

  Future<void> _exportarRelatorio(String formato) async {
    final clientes = List<Client>.from(_filteredClients);
    if (clientes.isEmpty) return;
    setState(() => _exportando = true);
    try {
      final atendimentos = await _firestoreService.getAllClaims();
      final porCliente = <String, List<AtendimentoResumo>>{};
      for (final c in atendimentos) {
        if (c.idCliente.isEmpty) continue;
        porCliente.putIfAbsent(c.idCliente, () => []).add(
              AtendimentoResumo(tipo: c.tipo, status: c.statusAtual, valor: c.valorTotalSinistro),
            );
      }

      final relatorio = RelatorioClientes.montar([
        for (final cl in clientes)
          ClienteEntrada(
            nome: cl.nome,
            documento: cl.cnpjCpf,
            apolices: [
              for (final a in cl.apolices) ApoliceResumo(numero: a.numeroApolice, valor: a.valorApolice),
            ],
            atendimentos: porCliente[cl.id] ?? const [],
          ),
      ]);

      final data = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (formato == 'pdf') {
        await Printing.sharePdf(
          bytes: await RelatorioClientesPdf.gerar(relatorio),
          filename: 'relatorio_clientes_$data.pdf',
        );
      } else {
        // Mesmo caminho do CSV do sinistro (claim_detail): baixa no navegador,
        // abre o compartilhamento no celular.
        await Printing.sharePdf(
          bytes: utf8.encode(relatorio.paraCsv()),
          filename: 'relatorio_clientes_$data.csv',
        );
      }
      if (mounted && _searchController.text.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Relatório com os ${clientes.length} clientes da busca.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar o relatório: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
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
          if (_exportando)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Exportar relatório de clientes (CSV ou PDF)',
              enabled: _filteredClients.isNotEmpty,
              onSelected: _exportarRelatorio,
              // Etapa 09: texto junto do ícone, para o usuário saber o que é.
              child: _BotaoComTexto(
                icone: Icons.file_download_outlined,
                texto: MediaQuery.of(context).size.width < 600 ? 'Exportar' : 'Exportar relatório',
              ),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined, color: Color(0xFF2E7D32)),
                    title: Text('Planilha (CSV / Excel)'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFC62828)),
                    title: Text('PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
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

/// Etapa 09: ícone + texto na barra superior (o PopupMenuButton cuida do clique).
class _BotaoComTexto extends StatelessWidget {
  final IconData icone;
  final String texto;
  const _BotaoComTexto({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    final cor = IconTheme.of(context).color ?? const Color(0xFF1A1A2E);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cor.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 20, color: cor),
            const SizedBox(width: 6),
            Text(texto, style: TextStyle(color: cor, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
