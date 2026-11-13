import 'package:flutter/material.dart';

import '../api.dart';
import 'alertas.dart';
import 'login.dart';
import 'usuarios.dart';
import 'veiculos.dart';

/// Navegação compacta no celular e lateral no navegador amplo.
class TelaInicio extends StatefulWidget {
  const TelaInicio({super.key});

  @override
  State<TelaInicio> createState() => _TelaInicioState();
}

class _TelaInicioState extends State<TelaInicio> {
  int _aba = 0;

  List<Widget> get _telas => [
        const TelaVeiculos(),
        const TelaAlertas(),
        if (ApiClient.instance.isAdmin) const TelaUsuarios(),
      ];

  List<String> get _titulos => [
        'Veículos monitorados',
        'Alertas',
        if (ApiClient.instance.isAdmin) 'Usuários',
      ];

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
      final telas = _telas;
      final titulos = _titulos;
      final destinos = <NavigationDestination>[
        const NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: 'Veículos',
        ),
        const NavigationDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications_active),
          label: 'Alertas',
        ),
        if (ApiClient.instance.isAdmin)
          const NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Usuários',
          ),
      ];
      final destinosRail = <NavigationRailDestination>[
        const NavigationRailDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: Text('Veículos'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.notifications_outlined),
          selectedIcon: Icon(Icons.notifications_active),
          label: Text('Alertas'),
        ),
        if (ApiClient.instance.isAdmin)
          const NavigationRailDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Text('Usuários'),
          ),
      ];
      return Scaffold(
        appBar: AppBar(
          title: Text(amplo
              ? 'Rastreio de veículos  /  ${titulos[_aba]}'
              : titulos[_aba]),
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
                    destinations: destinosRail,
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: telas[_aba]),
                ],
              )
            : telas[_aba],
        bottomNavigationBar: amplo
            ? null
            : NavigationBar(
                selectedIndex: _aba,
                onDestinationSelected: (i) => setState(() => _aba = i),
                destinations: destinos,
              ),
      );
    });
  }
}
