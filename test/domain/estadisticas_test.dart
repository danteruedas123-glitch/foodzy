import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estadisticas.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

Alimento a({
  required String id,
  String nombre = 'Leche',
  String categoria = 'Lácteos',
  double valor = 1,
  double? precio,
  DateTime? compra,
  double? inicial,
  EstadoAlimento? estado,
}) =>
    Alimento(
      id: id,
      nombre: nombre,
      categoria: categoria,
      cantidad: Cantidad(valor: valor, unidad: 'L'),
      fechaVencimiento: DateTime(2026, 12, 1),
      estado: estado ?? Disponible(compra ?? DateTime(2026, 9, 5)),
      precio: precio,
      fechaCompra: compra,
      cantidadInicial: inicial,
    );

void main() {
  final septiembre = DateTime(2026, 9, 15);

  test('el gasto suma solo lo comprado en el mes y agrupa por categoría', () {
    final r = estadisticasDelMes([
      a(id: '1', precio: 5000, compra: DateTime(2026, 9, 3)),
      a(id: '2', precio: 3000, categoria: 'Carnes', compra: DateTime(2026, 9, 20)),
      a(id: '3', precio: 9999, compra: DateTime(2026, 8, 30)), // otro mes
      a(id: '4', compra: DateTime(2026, 9, 4)), // sin precio
    ], septiembre);

    expect(r.gastado, 8000);
    expect(r.gastoPorCategoria['Lácteos'], 5000);
    expect(r.gastoPorCategoria['Carnes'], 3000);
  });

  test('desperdicio proporcional: solo cuenta lo que quedaba sin usar', () {
    final desechado = a(
      id: '1',
      precio: 10000,
      valor: 0.25, // quedaba un cuarto
      inicial: 1,
      compra: DateTime(2026, 9, 1),
      estado: Desechado('Se dañó', fecha: DateTime(2026, 9, 10)),
    );
    expect(costoDesperdicio(desechado), 2500);

    final r = estadisticasDelMes([desechado], septiembre);
    expect(r.desperdiciado, 2500);
    expect(r.desechados, 1);
    expect(r.topDesperdicio.single.$1, 'Leche');
  });

  test('sin cantidad inicial se cuenta el precio completo', () {
    final d = a(
      id: '1',
      precio: 4000,
      estado: Desechado('Vencido', fecha: DateTime(2026, 9, 2)),
    );
    expect(costoDesperdicio(d), 4000);
  });

  test('porcentaje de desperdicio y meses vacíos', () {
    final r = estadisticasDelMes([
      a(id: '1', precio: 10000, compra: DateTime(2026, 9, 1)),
      a(
        id: '2',
        precio: 2000,
        compra: DateTime(2026, 9, 1),
        estado: Desechado('Vencido', fecha: DateTime(2026, 9, 9)),
      ),
    ], septiembre);
    expect(r.gastado, 12000);
    expect(r.porcentajeDesperdicio, closeTo(2000 / 12000, 1e-9));

    final vacio = estadisticasDelMes(const [], septiembre);
    expect(vacio.vacio, isTrue);
    expect(vacio.porcentajeDesperdicio, 0);
  });

  test('ultimosMeses devuelve seis meses ordenados', () {
    final m = ultimosMeses(const [], septiembre);
    expect(m.length, 6);
    expect(m.first.mes, DateTime(2026, 4));
    expect(m.last.mes, DateTime(2026, 9));
  });
}
