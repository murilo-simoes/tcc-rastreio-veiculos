import 'package:flutter/material.dart';

import 'telas/login.dart';

void main() => runApp(const RastreioApp());

class RastreioApp extends StatelessWidget {
  const RastreioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cores = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1A3A6B),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'Rastreio de Veículos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: cores,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A3A6B),
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE1E6ED)),
          ),
        ),
      ),
      home: const TelaLogin(),
    );
  }
}
