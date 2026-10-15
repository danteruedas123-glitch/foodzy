import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/recetas/domain/descuento_receta.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

Alimento alimento(String id, String nombre, double valor, {String unidad = 'g'}) =>
    Alimento(
      id: id,
      nombre: nombre,
      categoria: 'Despensa',
      cantidad: Cantidad(valor: valor, unidad: unidad),
      fechaVencimiento: DateTime.utc(2026, 12, 31),
      estado: Disponible(DateTime.utc(2026, 10, 1)),
    );

IngredienteReceta ingrediente(
  String nombre, {
  String? alimentoId,
  double? usada,
}) =>
    IngredienteReceta(
      nombre: nombre,
      cantidad: '',
      enDespensa: alimentoId != null,
      alimentoId: alimentoId,
      cantidadUsada: usada,
    );

Receta receta(List<IngredienteReceta> ingredientes) => Receta(
      titulo: 'Prueba',
      descripcion: '',
      minutos: 10,
      porciones: 2,
      ingredientes: ingredientes,
      pasos: const ['Cocinar'],
    );

void main() {
  final arroz = alimento('arroz', 'Arroz', 500);
  final huevos = alimento('huevos', 'Huevos', 6, unidad: 'u');
  final despensa = {'arroz': arroz, 'huevos': huevos};

  group('calcularDescuento', () {
    test('descuenta lo que usa cada ingrediente de la despensa', () {
      final d = calcularDescuento(
        receta([
          ingrediente('Arroz', alimentoId: 'arroz', usada: 200),
          ingrediente('Huevos', alimentoId: 'huevos', usada: 2),
        ]),
        despensa,
      );

      expect(d.lineas, hasLength(2));
      expect(d.lineas[0].alimento.id, 'arroz');
      expect(d.lineas[0].cantidad, 200);
      expect(d.lineas[1].alimento.id, 'huevos');
      expect(d.lineas[1].cantidad, 2);
      expect(d.sinMedir, isEmpty);
    });

    test('suma los ingredientes que salen del mismo alimento', () {
      final d = calcularDescuento(
        receta([
          ingrediente('Arroz blanco', alimentoId: 'arroz', usada: 150),
          ingrediente('Arroz para decorar', alimentoId: 'arroz', usada: 50),
        ]),
        despensa,
      );

      expect(d.lineas, hasLength(1));
      expect(d.lineas.single.cantidad, 200);
    });

    test('la suma nunca supera lo que hay en la despensa', () {
      final d = calcularDescuento(
        receta([
          ingrediente('Arroz', alimentoId: 'arroz', usada: 400),
          ingrediente('Más arroz', alimentoId: 'arroz', usada: 400),
        ]),
        despensa,
      );

      expect(d.lineas.single.cantidad, 500);
    });

    test('un ingrediente sin cantidad medible no se descuenta y se avisa', () {
      final d = calcularDescuento(
        receta([
          ingrediente('Arroz', alimentoId: 'arroz', usada: null),
          ingrediente('Huevos', alimentoId: 'huevos', usada: 0),
        ]),
        despensa,
      );

      expect(d.lineas, isEmpty);
      expect(d.sinMedir, ['Arroz', 'Huevos']);
    });

    test('ignora ingredientes que no vienen de la despensa', () {
      final d = calcularDescuento(
        receta([
          ingrediente('Trufa'),
          ingrediente('Fantasma', alimentoId: 'no-esta', usada: 3),
        ]),
        despensa,
      );

      expect(d.lineas, isEmpty);
      expect(d.sinMedir, isEmpty);
    });

    test('una receta sin ingredientes no descuenta nada', () {
      final d = calcularDescuento(receta(const []), despensa);

      expect(d.lineas, isEmpty);
      expect(d.sinMedir, isEmpty);
    });
  });
}
