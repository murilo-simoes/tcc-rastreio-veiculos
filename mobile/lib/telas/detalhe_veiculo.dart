import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import 'mapa_rota.dart';

/// Histórico de avistamentos do veículo + geração da rota probabilística.
class TelaDetalheVeiculo extends StatefulWidget {
  const TelaDetalheVeiculo({super.key, required this.veiculo});
  final Veiculo veiculo;

  @override
  State<TelaDetalheVeiculo> createState() => _TelaDetalheVeiculoState();
}

class _TelaDetalheVeiculoState extends State<TelaDetalheVeiculo> {
  late Future<List<Avistamento>> _futuro;
  bool _gerandoRota = false;
  final _fmt = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _futuro = ApiClient.instance.listarAvistamentos(widget.veiculo.id);
  }

  Future<void> _verRota() async {
    setState(() => _gerandoRota = true);
    try {
      final rota = await ApiClient.instance.gerarRota(widget.veiculo.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TelaMapaRota(rota: rota)),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _gerandoRota = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.veiculo;
    return Scaffold(
      appBar: AppBar(
        title: Text(v.placa),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _gerandoRota ? null : _verRota,
        icon: _gerandoRota
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.route),
        label: const Text('Rota provável'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v.descricao,
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Furtado em ${v.dataFurto} — B.O. ${v.boletim}'),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Avistamentos',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: FutureBuilder<List<Avistamento>>(
              future: _futuro,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Erro: ${snap.error}'));
                }
                final avs = snap.data!;
                if (avs.isEmpty) {
                  return const Center(
                      child: Text('Nenhum avistamento registrado'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: avs.length,
                  itemBuilder: (context, i) {
                    final a = avs[i];
                    return ListTile(
                      leading: const Icon(Icons.videocam,
                          color: Color(0xFF1A3A6B)),
                      title: Text('Câmera ${a.idCamera}'),
                      subtitle: Text(_fmt.format(a.dataHora)),
                      trailing: Text('${a.confianca.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold)),
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
}
