import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rastreio_veiculos/main.dart';

void main() {
  testWidgets('Tela de acesso mostra os campos e a ação de entrada',
      (tester) async {
    await tester.pumpWidget(const RastreioApp());

    expect(find.text('Acessar painel'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Entrar'), findsOneWidget);
  });
}
