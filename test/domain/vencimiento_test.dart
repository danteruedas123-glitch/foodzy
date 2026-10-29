import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';

Alimento conFecha(DateTime fecha) => Alimento(
      id: 'leche',
      nombre: 'Leche',
      categoria: 'Lácteos',
      cantidad: const Cantidad(valor: 1, unidad: 'L'),
      fechaVencimiento: fecha,
      estado: Disponible(DateTime(2026, 10, 1)),
    );

/// Como queda al guardarlo y volver a leerlo de la base o de la nube.
Alimento guardadoYLeido(Alimento a) =>
    Alimento.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);

void main() {
  final hoy = DateTime(2026, 10, 30, 15, 45);

  group('una sola regla de vencido (por días)', () {
    test('el día del vencimiento "vence hoy" y no está vencido', () {
      final a = conFecha(DateTime(2026, 10, 30));
      expect(a.estaVencido(hoy), isFalse);
      expect(diasParaVencer(a, hoy), 0);
      expect(venceEn(a, -1), isFalse);
    });

    test('al día siguiente sí está vencido, para todas las pantallas', () {
      final a = conFecha(DateTime(2026, 10, 29));
      expect(a.estaVencido(hoy), isTrue);
      expect(diasParaVencer(a, hoy), -1);
    });

    test('la regla no cambia al guardar y volver a leer (fecha en UTC)', () {
      final a = guardadoYLeido(conFecha(DateTime(2026, 10, 30)));
      expect(a.estaVencido(hoy), isFalse);
      expect(diasParaVencer(a, hoy), 0);
    });
  });

  group('sin fecha y no vence', () {
    test('un alimento sin fecha nunca está vencido', () {
      expect(conFecha(Alimento.sinFecha).estaVencido(hoy), isFalse);
    });

    test('sigue siendo "sin fecha" después de guardarlo y leerlo', () {
      final a = guardadoYLeido(conFecha(Alimento.sinFecha));
      expect(a.sinFechaVencimiento, isTrue);
      expect(a.estaVencido(hoy), isFalse);
    });

    test('lo que no vence nunca está vencido, ni después de guardarlo', () {
      final a = guardadoYLeido(conFecha(Alimento.nuncaVence));
      expect(a.noVence, isTrue);
      expect(a.estaVencido(hoy), isFalse);
    });
  });
}
