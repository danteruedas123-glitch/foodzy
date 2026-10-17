import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';
import 'package:foodzy/features/recetas/presentation/widgets/hoja_cocinar.dart';

/// Despensa en memoria. Guarda lo que se le pide y puede fallar a propósito.
class AlimentosFalso extends AlimentosNotifier {
  AlimentosFalso(this._lista);

  final List<Alimento> _lista;
  final guardados = <Alimento>[];

  /// El guardado número N (empezando en 1) lanza un error.
  int? fallaEnElGuardadoNumero;
  int _llamadas = 0;

  @override
  Future<List<Alimento>> build() async => _lista;

  @override
  Future<void> actualizar(Alimento alimento) async {
    _llamadas++;
    if (_llamadas == fallaEnElGuardadoNumero) throw Exception('falló la base de datos');
    guardados.add(alimento);
  }
}

Alimento alimento(String id, String nombre, double valor) => Alimento(
      id: id,
      nombre: nombre,
      categoria: 'Despensa',
      cantidad: Cantidad(valor: valor, unidad: 'g'),
      fechaVencimiento: DateTime.utc(2026, 12, 31),
      estado: Disponible(DateTime.utc(2026, 10, 1)),
    );

IngredienteReceta usa(String id, String nombre, double gramos) => IngredienteReceta(
      nombre: nombre,
      cantidad: '$gramos g',
      enDespensa: true,
      alimentoId: id,
      cantidadUsada: gramos,
    );

Receta receta(List<IngredienteReceta> ingredientes) => Receta(
      titulo: 'Arroz con lentejas',
      descripcion: '',
      minutos: 20,
      porciones: 2,
      ingredientes: ingredientes,
      pasos: const ['Cocinar'],
    );

const botonCocinar = 'Sí, la voy a cocinar y descontar';

bool botonHabilitado(WidgetTester t) => t
    .widget<FilledButton>(find.ancestor(
      of: find.text(botonCocinar),
      matching: find.bySubtype<FilledButton>(),
    ))
    .onPressed != null;

void main() {
  late AlimentosFalso despensa;

  /// Abre la hoja de cocinar sobre una pantalla mínima.
  Future<void> abrir(WidgetTester t, Receta r) async {
    t.view.physicalSize = const Size(800, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    final contenedor = ProviderContainer(overrides: [
      alimentosProvider.overrideWith(() => despensa),
    ]);
    addTearDown(contenedor.dispose);
    await contenedor.read(alimentosProvider.future); // que ya esté cargada

    await t.pumpWidget(UncontrolledProviderScope(
      container: contenedor,
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => cocinarReceta(ctx, r),
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

  setUp(() {
    despensa = AlimentosFalso([
      alimento('arroz', 'Arroz', 500),
      alimento('lentejas', 'Lentejas', 400),
    ]);
  });

  testWidgets('al confirmar descuenta de la despensa y cierra la hoja', (t) async {
    await abrir(t, receta([usa('arroz', 'Arroz', 200)]));

    await t.tap(find.text(botonCocinar));
    await t.pumpAndSettle();

    expect(despensa.guardados.single.cantidad.valor, 300);
    expect(find.text(botonCocinar), findsNothing, reason: 'la hoja se cerró');
    expect(find.textContaining('¡Buen provecho!'), findsOneWidget);
  });

  testWidgets('si falla el guardado, avisa y la hoja queda lista para reintentar', (t) async {
    despensa.fallaEnElGuardadoNumero = 1;
    await abrir(t, receta([usa('arroz', 'Arroz', 200)]));

    await t.tap(find.text(botonCocinar));
    await t.pumpAndSettle();

    expect(find.text('No pude descontar de tu despensa. Intenta de nuevo.'), findsOneWidget);
    expect(find.text(botonCocinar), findsOneWidget, reason: 'la hoja sigue abierta');
    expect(botonHabilitado(t), isTrue, reason: 'ya no está bloqueada');
    expect(despensa.guardados, isEmpty);
  });

  testWidgets('si falla a mitad dice cuántos se descontaron y reintentar no descuenta de más', (t) async {
    despensa.fallaEnElGuardadoNumero = 2;
    await abrir(t, receta([usa('arroz', 'Arroz', 200), usa('lentejas', 'Lentejas', 100)]));

    await t.tap(find.text(botonCocinar));
    await t.pumpAndSettle();

    expect(
      find.text('Solo se descontaron 1 de 2 ingredientes. Toca de nuevo para terminar.'),
      findsOneWidget,
    );
    expect(botonHabilitado(t), isTrue);
    expect(despensa.guardados.map((a) => a.id), ['arroz']);

    // Reintento: el segundo guardado ya no falla.
    await t.tap(find.text(botonCocinar));
    await t.pumpAndSettle();

    expect(find.text(botonCocinar), findsNothing, reason: 'terminó y cerró');
    final arroz = despensa.guardados.where((a) => a.id == 'arroz');
    expect(arroz.every((a) => a.cantidad.valor == 300), isTrue,
        reason: 'el arroz no se descuenta dos veces');
    expect(despensa.guardados.last.id, 'lentejas');
    expect(despensa.guardados.last.cantidad.valor, 300);
  });
}
