import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';

Alimento queso(double valor, String unidad) => Alimento(
      id: 'queso-1',
      nombre: 'Queso',
      categoria: 'Lácteos',
      cantidad: Cantidad(valor: valor, unidad: unidad),
      fechaVencimiento: DateTime.now().add(const Duration(days: 10)),
      estado: Disponible(DateTime.now()),
    );

Future<void> mostrar(WidgetTester tester, Alimento a) => tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AlimentoCard(alimento: a))),
    );

void main() {
  testWidgets('muestra 0.25 kg completo, no redondeado a 0.3', (tester) async {
    await mostrar(tester, queso(0.25, 'kg'));

    expect(find.text('Lácteos · 0.25 kg'), findsOneWidget);
    expect(find.textContaining('0.3 kg'), findsNothing);
  });

  testWidgets('una cantidad entera se muestra sin ".0"', (tester) async {
    await mostrar(tester, queso(2, 'u'));

    expect(find.text('Lácteos · 2 u'), findsOneWidget);
  });
}
