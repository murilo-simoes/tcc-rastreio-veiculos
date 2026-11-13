import 'package:flutter/material.dart';

import '../api.dart';
import 'cadastro_veiculo.dart';
import 'detalhe_veiculo.dart';

class TelaVeiculos extends StatefulWidget {
  const TelaVeiculos({super.key});

  @override
  State<TelaVeiculos> createState() => _TelaVeiculosState();
}

class _TelaVeiculosState extends State<TelaVeiculos> {
  late Future<List<Veiculo>> _futuro;
  String _busca = '';
  String _filtro = 'todos';

  @override
  void initState() {
    super.initState();
    _futuro = ApiClient.instance.listarVeiculos();
  }

  Future<void> _recarregar() async {
    setState(() => _futuro = ApiClient.instance.listarVeiculos());
    await _futuro;
  }

  Color _corStatus(String status) => switch (status) {
        'ativo' => const Color(0xFFB42318),
        'recuperado' => const Color(0xFF20815A),
        _ => Colors.blueGrey,
      };

  String _rotuloStatus(String status) => switch (status) {
        'ativo' => 'Monitorando',
        'recuperado' => 'Recuperado',
        'cancelado' => 'Encerrado',
        _ => status,
      };

  Future<void> _abrirCadastro({Veiculo? veiculo}) async {
    final salvo = await mostrarCadastroVeiculo(context, veiculo: veiculo);
    if (salvo == true) await _recarregar();
  }

  Future<void> _encerrarMonitoramento(Veiculo veiculo) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar monitoramento?'),
        content: Text(
          'O veículo ${veiculo.placa} deixará de ser monitorado. '
          'Os avistamentos já registrados serão preservados no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encerrar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await ApiClient.instance.encerrarMonitoramento(veiculo.id);
      await _recarregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Monitoramento de ${veiculo.placa} encerrado.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível encerrar: $e')),
        );
      }
    }
  }

  Widget _cartao(Veiculo veiculo) {
    final cor = _corStatus(veiculo.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TelaDetalheVeiculo(veiculo: veiculo),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: cor.withValues(alpha: 0.12),
                child: Icon(Icons.directions_car, color: cor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(veiculo.placa,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            )),
                    const SizedBox(height: 2),
                    Text(veiculo.descricao),
                    const SizedBox(height: 4),
                    Text('B.O. ${veiculo.boletim}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                avatar: Icon(
                  veiculo.status == 'ativo'
                      ? Icons.warning_amber_outlined
                      : veiculo.status == 'recuperado'
                          ? Icons.check_circle_outline
                          : Icons.remove_circle_outline,
                  size: 18,
                  color: cor,
                ),
                label: Text(_rotuloStatus(veiculo.status)),
                visualDensity: VisualDensity.compact,
              ),
              if (ApiClient.instance.isAdmin) ...[
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Ações do veículo',
                  onSelected: (acao) {
                    if (acao == 'editar') _abrirCadastro(veiculo: veiculo);
                    if (acao == 'encerrar') _encerrarMonitoramento(veiculo);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar cadastro'),
                      ),
                    ),
                    if (veiculo.status != 'cancelado')
                      const PopupMenuItem(
                        value: 'encerrar',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.archive_outlined),
                          title: Text('Encerrar monitoramento'),
                        ),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: ApiClient.instance.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _abrirCadastro,
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar veículo'),
            )
          : null,
      body: FutureBuilder<List<Veiculo>>(
        future: _futuro,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text('Não foi possível consultar os veículos: ${snap.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }
          final todos = snap.data!;
          final termo = _busca.trim().toLowerCase();
          final visiveis = todos.where((v) {
            final correspondeStatus = _filtro == 'todos' || v.status == _filtro;
            final correspondeBusca = termo.isEmpty ||
                v.placa.toLowerCase().contains(termo) ||
                v.marca.toLowerCase().contains(termo) ||
                v.modelo.toLowerCase().contains(termo);
            return correspondeStatus && correspondeBusca;
          }).toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: RefreshIndicator(
                onRefresh: _recarregar,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 96),
                  itemCount: visiveis.length + 1,
                  itemBuilder: (context, index) {
                    if (index > 0) return _cartao(visiveis[index - 1]);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CADASTRO',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  letterSpacing: 1.5,
                                )),
                        const SizedBox(height: 6),
                        Text('Veículos monitorados',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 6),
                        Text('${todos.length} veículos cadastrados'),
                        const SizedBox(height: 20),
                        TextField(
                          onChanged: (valor) => setState(() => _busca = valor),
                          decoration: const InputDecoration(
                            hintText: 'Buscar por placa, marca ou modelo',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final filtro in [
                              'todos',
                              'ativo',
                              'recuperado',
                              'cancelado',
                            ])
                              ChoiceChip(
                                label: Text(switch (filtro) {
                                  'ativo' => 'Ativos',
                                  'recuperado' => 'Recuperados',
                                  'cancelado' => 'Encerrados',
                                  _ => 'Todos',
                                }),
                                selected: _filtro == filtro,
                                onSelected: (_) =>
                                    setState(() => _filtro = filtro),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (visiveis.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                                child: Text('Nenhum veículo encontrado.')),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
