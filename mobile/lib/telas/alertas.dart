import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';

/// Lista de alertas com atualização automática a cada 5 segundos.
///
/// Na PoC o app consulta a API periodicamente (polling); em produção
/// seria substituído por notificações push (Firebase Cloud Messaging).
class TelaAlertas extends StatefulWidget {
  const TelaAlertas({super.key});

  @override
  State<TelaAlertas> createState() => _TelaAlertasState();
}

class _TelaAlertasState extends State<TelaAlertas> {
  List<Alerta>? _alertas;
  String? _erro;
  Timer? _timer;
  final _fmt = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final alertas = await ApiClient.instance.listarAlertas();
      if (mounted) {
        setState(() {
          _alertas = alertas;
          _erro = null;
        });
      }
    } catch (e) {
      // captura também erros de conversão de dados, não só exceções de rede
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  Future<void> _visualizar(Alerta a) async {
    await ApiClient.instance.marcarAlertaVisualizado(a.id);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) return Center(child: Text('Erro: $_erro'));
    if (_alertas == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_alertas!.isEmpty) {
      return const Center(child: Text('Nenhum alerta registrado'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _alertas!.length,
      separatorBuilder: (context, i) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final a = _alertas![i];
        final novo = a.status != 'visualizado';
        return Card(
          color: novo ? Colors.red.shade50 : null,
          child: ListTile(
            leading: Icon(
              novo ? Icons.warning_amber : Icons.check_circle_outline,
              color: novo ? Colors.red : Colors.green,
              size: 32,
            ),
            title: Text('Alerta #${a.id} — câmera ${a.avistamento.idCamera}',
                style: TextStyle(
                    fontWeight: novo ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(
                'Avistamento em ${_fmt.format(a.avistamento.dataHora)}\n'
                'Confiança da leitura: '
                '${a.avistamento.confianca.toStringAsFixed(0)}%'),
            isThreeLine: true,
            trailing: novo
                ? TextButton(
                    onPressed: () => _visualizar(a),
                    child: const Text('Confirmar'))
                : Text(a.status,
                    style: const TextStyle(color: Colors.green)),
          ),
        );
      },
    );
  }
}
