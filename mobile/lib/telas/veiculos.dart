import 'package:flutter/material.dart';

import '../api.dart';
import 'detalhe_veiculo.dart';

class TelaVeiculos extends StatefulWidget {
  const TelaVeiculos({super.key});

  @override
  State<TelaVeiculos> createState() => _TelaVeiculosState();
}

class _TelaVeiculosState extends State<TelaVeiculos> {
  late Future<List<Veiculo>> _futuro;

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
        'ativo' => Colors.red,
        'recuperado' => Colors.green,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Veiculo>>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Erro: ${snap.error}'));
        }
        final veiculos = snap.data!;
        return RefreshIndicator(
          onRefresh: _recarregar,
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: veiculos.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final v = veiculos[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _corStatus(v.status),
                    child: const Icon(Icons.directions_car,
                        color: Colors.white),
                  ),
                  title: Text(v.placa,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  subtitle: Text('${v.descricao}\nB.O. ${v.boletim}'),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(v.status,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white)),
                    backgroundColor: _corStatus(v.status),
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TelaDetalheVeiculo(veiculo: v)),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
