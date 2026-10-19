import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

Alimento alimento(String id, String nombre, {double valor = 500, String unidad = 'g'}) =>
    Alimento(
      id: id,
      nombre: nombre,
      categoria: 'Granos',
      cantidad: Cantidad(valor: valor, unidad: unidad),
      fechaVencimiento: DateTime.utc(2026, 12, 31),
      estado: Disponible(DateTime.utc(2026, 10, 1)),
    );

Map<String, dynamic> recetaIA({
  Object? ingredientes,
  Object? pasos,
  Map<String, dynamic> extra = const {},
}) =>
    {
      'titulo': 'Arroz con huevo',
      'descripcion': 'Rápido y fácil',
      'minutos': 20,
      'porciones': 2,
      'ingredientes': ingredientes ??
          [
            {
              'nombre': 'Arroz',
              'cantidad': '200 g',
              'alimento_id': 'arroz-1',
              'cantidad_usada': 200,
            },
          ],
      'pasos': pasos ?? ['Cocinar el arroz', 'Servir'],
      ...extra,
    };

void main() {
  final servicio = RecetasService(GeminiClient(apiKey: ''));
  final despensa = {
    'arroz-1': alimento('arroz-1', 'Arroz', valor: 500),
    'huevo-1': alimento('huevo-1', 'Huevos', valor: 6, unidad: 'u'),
  };

  group('RecetasService.parsear', () {
    test('lee una receta válida y marca los ingredientes de la despensa', () {
      final recetas = servicio.parsear([recetaIA()], despensa);

      expect(recetas, hasLength(1));
      final r = recetas.single;
      expect(r.titulo, 'Arroz con huevo');
      expect(r.minutos, 20);
      expect(r.pasos, ['Cocinar el arroz', 'Servir']);
      expect(r.ingredientes.single.enDespensa, isTrue);
      expect(r.ingredientes.single.alimentoId, 'arroz-1');
      expect(r.ingredientes.single.cantidadUsada, 200);
    });

    test('acepta un solo objeto en vez de una lista (caso de detallar)', () {
      final recetas = servicio.parsear(recetaIA(), despensa);
      expect(recetas, hasLength(1));
    });

    test('un alimento_id inventado por la IA no cuenta como de la despensa', () {
      final recetas = servicio.parsear([
        recetaIA(ingredientes: [
          {
            'nombre': 'Trufa',
            'cantidad': '1 u',
            'alimento_id': 'no-existe',
            'cantidad_usada': 1,
          },
        ]),
      ], despensa);

      final ing = recetas.single.ingredientes.single;
      expect(ing.enDespensa, isFalse);
      expect(ing.alimentoId, isNull);
      expect(ing.cantidadUsada, isNull);
      expect(recetas.single.faltantes, hasLength(1));
    });

    test('la cantidad usada nunca supera lo que hay en la despensa', () {
      final recetas = servicio.parsear([
        recetaIA(ingredientes: [
          {
            'nombre': 'Arroz',
            'cantidad': '2 kg',
            'alimento_id': 'arroz-1',
            'cantidad_usada': 2000,
          },
        ]),
      ], despensa);

      expect(recetas.single.ingredientes.single.cantidadUsada, 500);
    });

    test('una cantidad usada de cero, negativa o nula no se descuenta', () {
      for (final usada in [0, -3, null]) {
        final recetas = servicio.parsear([
          recetaIA(ingredientes: [
            {
              'nombre': 'Arroz',
              'cantidad': 'al gusto',
              'alimento_id': 'arroz-1',
              'cantidad_usada': usada,
            },
          ]),
        ], despensa);

        expect(recetas.single.ingredientes.single.cantidadUsada, isNull,
            reason: 'cantidad_usada = $usada');
      }
    });

    test('descarta recetas sin ingredientes o sin pasos', () {
      final recetas = servicio.parsear([
        recetaIA(ingredientes: <Object>[]),
        recetaIA(pasos: <Object>[]),
        recetaIA(),
      ], despensa);

      expect(recetas, hasLength(1));
    });

    test('ignora elementos que no son objetos', () {
      final recetas = servicio.parsear(
        ['texto suelto', 42, null, recetaIA()],
        despensa,
      );
      expect(recetas, hasLength(1));
    });

    test('ignora ingredientes que no son objetos pero conserva los demás', () {
      final recetas = servicio.parsear([
        recetaIA(ingredientes: [
          'sal',
          {'nombre': 'Arroz', 'cantidad': '100 g', 'alimento_id': 'arroz-1'},
        ]),
      ], despensa);

      expect(recetas.single.ingredientes, hasLength(1));
    });

    test('usa valores por defecto cuando faltan título, minutos y porciones', () {
      final recetas = servicio.parsear([
        {
          'ingredientes': [
            {'nombre': 'Arroz', 'cantidad': '100 g'},
          ],
          'pasos': ['Cocinar'],
        },
      ], despensa);

      final r = recetas.single;
      expect(r.titulo, 'Receta');
      expect(r.minutos, 30);
      expect(r.porciones, 2);
      expect(r.aprovecha, isNull);
    });

    test('una respuesta vacía o de tipo inesperado da una lista vacía', () {
      expect(servicio.parsear(null, despensa), isEmpty);
      expect(servicio.parsear('error', despensa), isEmpty);
      expect(servicio.parsear(<Object>[], despensa), isEmpty);
    });

    test('normaliza la comida del día que dice la IA para poder filtrar', () {
      final recetas = servicio.parsear([
        recetaIA(extra: {'momento': 'desayuno'}),
        recetaIA(extra: {'momento': ' Cena '}),
        recetaIA(extra: {'momento': 'merienda'}),
        recetaIA(),
      ], despensa);

      expect(recetas.map((r) => r.momento), ['Desayuno', 'Cena', null, null]);
    });

    test('si se pidieron para una comida, todas quedan con esa comida', () {
      final recetas = servicio.parsear([
        recetaIA(extra: {'momento': 'Almuerzo'}),
        recetaIA(),
      ], despensa, momento: 'Cena');

      expect(recetas.map((r) => r.momento), ['Cena', 'Cena']);
    });
  });

  group('Receta', () {
    test('sobrevive la ida y vuelta a JSON (se usa para guardar favoritas)', () {
      final original = servicio.parsear([recetaIA()], despensa).single;

      final vuelta = Receta.fromJson(original.toJson());

      expect(vuelta.titulo, original.titulo);
      expect(vuelta.pasos, original.pasos);
      expect(vuelta.ingredientes.single.alimentoId, 'arroz-1');
      expect(vuelta.ingredientes.single.cantidadUsada, 200);
      expect(vuelta.clave, 'arroz con huevo');
      expect(Receta.fromJson(
              servicio.parsear([recetaIA(extra: {'momento': 'Cena'})], despensa).single.toJson())
          .momento, 'Cena');
    });
  });
}
