import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_detalle.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';

/// Despensa en memoria: guarda los cambios en su propia lista.
class DespensaFalsa extends AlimentosNotifier {
  DespensaFalsa(this._inicial);

  final List<Alimento> _inicial;

  @override
  Future<List<Alimento>> build() async => _inicial;

  @override
  Future<void> actualizar(Alimento alimento) async {
    state = AsyncData([
      for (final a in state.value!) a.id == alimento.id ? alimento : a,
    ]);
  }

  Alimento buscar(String id) => state.value!.firstWhere((a) => a.id == id);
}

Alimento huevos(double valor) => Alimento(
      id: 'huevos',
      nombre: 'Huevos',
      categoria: 'Huevos',
      cantidad: Cantidad(valor: valor, unidad: 'u'),
      fechaVencimiento: DateTime.now().add(const Duration(days: 10)),
      estado: Disponible(DateTime(2026, 10, 1)),
    );

void main() {
  late DespensaFalsa despensa;

  /// Abre el detalle de [a] encima de una pantalla mínima, como en la app.
  Future<void> abrirDetalle(WidgetTester t, Alimento a) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    despensa = DespensaFalsa([a]);
    final contenedor = ProviderContainer(overrides: [
      alimentosProvider.overrideWith(() => despensa),
    ]);
    addTearDown(contenedor.dispose);
    await contenedor.read(alimentosProvider.future);

    await t.pumpWidget(UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => PantallaDetalle(alimento: a),
                )),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
  }

  testWidgets('desechar cierra el detalle, avisa y "Deshacer" lo devuelve', (t) async {
    final original = huevos(6);
    await abrirDetalle(t, original);

    await t.tap(find.text('Desechar'));
    await t.pumpAndSettle();

    expect(despensa.buscar('huevos').estado, isA<Desechado>());
    expect(find.text('Detalle del Alimento'), findsNothing, reason: 'se cerró');
    expect(find.text('Huevos pasó al historial como desechado.'), findsOneWidget);

    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();

    expect(despensa.buscar('huevos'), original, reason: 'quedó como estaba');
  });

  testWidgets('consumir una parte dice cuánto queda y se puede deshacer', (t) async {
    final original = huevos(6);
    await abrirDetalle(t, original);

    await t.tap(find.text('Consumir'));
    await t.pumpAndSettle();
    expect(find.text('Tienes 6 u. ¿Cuánto vas a consumir?'), findsOneWidget);

    await t.tap(find.text('Confirmar')); // propone 1 unidad
    await t.pumpAndSettle();

    expect(despensa.buscar('huevos').cantidad.valor, 5);
    expect(find.text('Usaste 1 u de Huevos. Quedan 5 u.'), findsOneWidget);

    await t.tap(find.text('Deshacer'));
    await t.pumpAndSettle();

    expect(despensa.buscar('huevos'), original);
  });

  testWidgets('consumir lo último lo pasa al historial como consumido', (t) async {
    await abrirDetalle(t, huevos(1));

    await t.tap(find.text('Consumir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmar'));
    await t.pumpAndSettle();

    expect(despensa.buscar('huevos').estado, isA<Consumido>());
    expect(find.text('Huevos pasó al historial como consumido.'), findsOneWidget);
  });

  testWidgets('cancelar el consumo no cambia nada', (t) async {
    final original = huevos(6);
    await abrirDetalle(t, original);

    await t.tap(find.text('Consumir'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();

    expect(despensa.buscar('huevos'), original);
    expect(find.text('Detalle del Alimento'), findsOneWidget, reason: 'sigue abierto');
  });
}
