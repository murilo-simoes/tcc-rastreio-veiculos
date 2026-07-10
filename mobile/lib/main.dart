import 'package:flutter/material.dart';

import 'telas/login.dart';

void main() => runApp(const RastreioApp());

class RastreioApp extends StatelessWidget {
  const RastreioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rastreio de Veículos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A3A6B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const TelaLogin(),
    );
  }
}
