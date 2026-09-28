import 'package:flutter/material.dart';

import '../api.dart';
import 'alertas.dart';
import 'login.dart';
import 'veiculos.dart';

/// Navegação compacta no celular e lateral no navegador amplo.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  int _aba = 0;

  static const _telas = [TelaVeiculos(), TelaAlertas()];
  static const _titulos = ['Veículos monitorados', 'Alertas'];

  void _sair() {
    ApiClient.instance.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TelaLogin()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final amplo = constraints.maxWidth >= 850;
      final railEstendido = constraints.maxWidth >= 1100;
      return Scaffold(
        appBar: AppBar(
          title: Text(amplo
              ? 'Rastreio de veículos  /  ${_titulos[_aba]}'
              : _titulos[_aba]),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sair da conta',
              onPressed: _sair,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: amplo
            ? Row(
                children: [
                  NavigationRail(
                    extended: railEstendido,
                    labelType: railEstendido
                        ? NavigationRailLabelType.none
                        : NavigationRailLabelType.all,
                    selectedIndex: _aba,
                    onDestinationSelected: (i) => setState(() => _aba = i),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Icon(Icons.local_police_outlined,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.directions_car_outlined),
                        selectedIcon: Icon(Icons.directions_car),
                        label: Text('Veículos'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.notifications_outlined),
                        selectedIcon: Icon(Icons.notifications_active),
                        label: Text('Alertas'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: _telas[_aba]),
                ],
              )
            : _telas[_aba],
        bottomNavigationBar: amplo
            ? null
            : NavigationBar(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.directions_car_outlined),
                    selectedIcon: Icon(Icons.directions_car),
                    label: 'Veículos',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.notifications_outlined),
                    selectedIcon: Icon(Icons.notifications_active),
                    label: 'Alertas',
                  ),
                ],
              ),
      );
    });
  }
}
