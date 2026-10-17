import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/recetas/domain/receta_texto.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

Receta receta({
  int porciones = 2,
  String descripcion = 'Rápido y fácil',
  List<IngredienteReceta>? ingredientes,
  List<String> pasos = const ['Cocinar el arroz', 'Servir'],
}) =>
    Receta(
      titulo: 'Arroz con huevo',
      descripcion: descripcion,
      minutos: 20,
      porciones: porciones,
      ingredientes: ingredientes ??
          const [
            IngredienteReceta(nombre: 'Arroz', cantidad: '200 g', enDespensa: true),
            IngredienteReceta(nombre: 'Huevos', cantidad: '2 unidades', enDespensa: false),
          ],
      pasos: pasos,
    );

void main() {
  group('textoParaCompartir', () {
    test('incluye título, tiempo, ingredientes y pasos numerados', () {
      final t = textoParaCompartir(receta());

      expect(t, contains('🍳 Arroz con huevo'));
      expect(t, contains('⏱ 20 min · 2 porciones'));
      expect(t, contains('- Arroz · 200 g'));
      expect(t, contains('1. Cocinar el arroz'));
      expect(t, contains('2. Servir'));
      expect(t, endsWith('Hecha con Foodzy'));
    });

    test('marca lo que hay que conseguir y no lo que ya se tiene', () {
      final t = textoParaCompartir(receta());

      expect(t, contains('- Huevos · 2 unidades (por conseguir)'));
      expect(t, isNot(contains('Arroz · 200 g (por conseguir)')));
    });

    test('dice "1 porción" en singular', () {
      expect(textoParaCompartir(receta(porciones: 1)), contains('1 porción'));
      expect(textoParaCompartir(receta(porciones: 1)), isNot(contains('1 porciones')));
    });

    test('omite la descripción si está vacía', () {
      final t = textoParaCompartir(receta(descripcion: '   '));

      expect(t, isNot(contains('Rápido')));
      expect(t, isNot(contains('\n\n\n')), reason: 'no deja huecos de más');
    });

    test('un ingrediente sin cantidad no deja un "·" suelto', () {
      final t = textoParaCompartir(receta(ingredientes: const [
        IngredienteReceta(nombre: 'Sal', cantidad: '', enDespensa: true),
      ]));

      expect(t, contains('- Sal\n'));
      expect(t, isNot(contains('Sal ·')));
    });
  });
}
