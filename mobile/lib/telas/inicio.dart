import 'package:flutter/material.dart';

import '../api.dart';
import 'alertas.dart';
import 'login.dart';
import 'veiculos.dart';

/// Tela principal com navegação entre Veículos e Alertas.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  int _aba = 0;

  static const _telas = [TelaVeiculos(), TelaAlertas()];
  static const _titulos = ['Veículos Monitorados', 'Alertas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulos[_aba]),
        backgroundColor: const Color(0xFF1A3A6B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () {
              ApiClient.instance.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const TelaLogin()),
              );
            },
          ),
        ],
      ),
      body: _telas[_aba],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.directions_car), label: 'Veículos'),
          NavigationDestination(
              icon: Icon(Icons.notifications_active), label: 'Alertas'),
        ],
      ),
    );
  }
}
