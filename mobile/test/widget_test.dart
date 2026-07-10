import 'package:flutter_test/flutter_test.dart';
import 'package:rastreio_veiculos/main.dart';

void main() {
  testWidgets('Tela de login é exibida ao abrir o app', (tester) async {
    await tester.pumpWidget(const RastreioApp());

    expect(find.text('Rastreio de Veículos Furtados'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
