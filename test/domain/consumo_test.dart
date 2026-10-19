import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/consumo.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

Alimento arroz({double valor = 1, String unidad = 'kg'}) => Alimento(
      id: 'arroz-1',
      nombre: 'Arroz',
      categoria: 'Granos',
      cantidad: Cantidad(valor: valor, unidad: unidad),
      fechaVencimiento: DateTime(2027, 1, 1),
      estado: Disponible(DateTime(2026, 10, 1)),
      precio: 4500,
      fechaCompra: DateTime(2026, 10, 1),
      cantidadInicial: 1,
    );

void main() {
  final ahora = DateTime(2026, 10, 18, 12);

  test('usar una parte deja lo que queda y sigue disponible', () {
    final r = consumir(arroz(), 0.25, ahora);

    expect(r.cantidad, const Cantidad(valor: 0.75, unidad: 'kg'));
    expect(r.estado, isA<Disponible>());
    expect(r.id, 'arroz-1');
  });

  test('lo que queda sale redondeado, sin arrastrar el error de los decimales', () {
    // Así fallaba antes en el detalle: la resta directa no da 0.3.
    expect(1.0 - 0.7, isNot(0.3));

    final r = consumir(arroz(), 0.7, ahora);
    expect(r.cantidad.valor, 0.3);
  });

  test('usar todo lo marca como consumido en la fecha indicada', () {
    final r = consumir(arroz(), 1, ahora);

    expect(r.estado, Consumido(ahora));
    expect(r.estado.esConsumible, isFalse);
  });

  test('usar más de lo que hay también lo marca como consumido', () {
    expect(consumir(arroz(), 3, ahora).estado, isA<Consumido>());
  });

  test('un resto minúsculo cuenta como que ya no queda nada', () {
    expect(consumir(arroz(), 0.99996, ahora).estado, isA<Consumido>());
  });

  test('conserva la unidad, el precio y la fecha de compra', () {
    final r = consumir(arroz(valor: 500, unidad: 'g'), 120, ahora);

    expect(r.cantidad, const Cantidad(valor: 380, unidad: 'g'));
    expect(r.precio, 4500);
    expect(r.fechaCompra, DateTime(2026, 10, 1));
    expect(r.cantidadInicial, 1);
  });

  test('restanteTras redondea a tres decimales', () {
    expect(restanteTras(arroz(), 0.1 + 0.2), 0.7);
  });
}
