import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/busqueda.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

Alimento alimento(String nombre, String categoria) => Alimento(
      id: nombre,
      nombre: nombre,
      categoria: categoria,
      cantidad: const Cantidad(valor: 1, unidad: 'u'),
      fechaVencimiento: DateTime(2027, 1, 1),
      estado: Disponible(DateTime(2026, 10, 1)),
    );

void main() {
  final leche = alimento('Leche Deslactosada', 'Lácteos');
  final jamon = alimento('Jamón de pavo', 'Carnes frías');

  test('encuentra por categoría aunque se escriba sin tilde', () {
    expect(coincideBusqueda(leche, 'lacteos'), isTrue);
  });

  test('encuentra por nombre aunque se escriba sin tilde', () {
    expect(coincideBusqueda(jamon, 'jamon'), isTrue);
  });

  test('no importan las mayúsculas', () {
    expect(coincideBusqueda(leche, 'LECHE'), isTrue);
    expect(coincideBusqueda(leche, 'deslactosada'), isTrue);
  });

  test('no importan los espacios de más', () {
    expect(coincideBusqueda(leche, '  leche  '), isTrue);
    expect(coincideBusqueda(leche, 'leche   deslactosada'), isTrue);
  });

  test('con tilde también encuentra lo escrito con tilde', () {
    expect(coincideBusqueda(leche, 'lácteos'), isTrue);
  });

  test('un texto que no aparece no coincide', () {
    expect(coincideBusqueda(leche, 'arroz'), isFalse);
    expect(coincideBusqueda(jamon, 'lacteos'), isFalse);
  });

  test('un buscador vacío o con solo espacios muestra todo', () {
    expect(coincideBusqueda(leche, ''), isTrue);
    expect(coincideBusqueda(leche, '   '), isTrue);
  });
}
