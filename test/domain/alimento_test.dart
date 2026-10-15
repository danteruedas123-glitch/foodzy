import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/core/json.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';

Alimento ejemplo({EstadoAlimento? estado, List<String>? fotos}) => Alimento(
      id: 'ali-001',
      nombre: 'Leche deslactosada',
      categoria: 'Lácteos',
      cantidad: const Cantidad(valor: 1.0, unidad: 'litro'),
      fechaVencimiento: DateTime.utc(2026, 8, 25, 0, 0),
      estado: estado ?? Disponible(DateTime.utc(2026, 8, 10, 14, 30)),
      fotos: fotos ?? const <String>[],
    );

void main() {
  group('serialización', () {
    test('un alimento sobrevive la ida y vuelta a JSON sin perder nada', () {
      final original = ejemplo(
        estado: Consumido(DateTime.utc(2026, 8, 12, 9, 15)),
        fotos: const ['https://ejemplo.co/f/1.jpg'],
      );

      final texto = jsonEncode(original.toJson());
      final vuelta = Alimento.fromJson(jsonDecode(texto) as Map<String, dynamic>);

      expect(vuelta, equals(original));
    });

    test('un alimento sin la clave fotos se lee con la lista vacía', () {
      final json = ejemplo().toJson()..remove('fotos');
      expect(Alimento.fromJson(json).fotos, isEmpty);
    });

    test('un alimento sin nombre dice QUÉ campo falló, no solo que falló', () {
      final json = ejemplo().toJson()..remove('nombre');

      expect(
        () => Alimento.fromJson(json),
        throwsA(
          isA<CampoInvalido>().having((e) => e.campo, 'campo', 'nombre'),
        ),
      );
    });

    test('una fecha que no es ISO 8601 se rechaza', () {
      final json = ejemplo().toJson()..['fechaVencimiento'] = '25 de agosto';
      expect(() => Alimento.fromJson(json), throwsA(isA<CampoInvalido>()));
    });

    test('la hora se conserva en UTC y no se corre cinco horas', () {
      final json = ejemplo().toJson();
      expect(json['fechaVencimiento'], '2026-08-25T00:00:00.000Z');
    });
  });

  group('fecha de vencimiento', () {
    test('el origen de la fecha sobrevive la ida y vuelta a JSON', () {
      final a = ejemplo().conFecha(DateTime.utc(2026, 9, 1), origen: FechaOrigen.estimada);
      final vuelta = Alimento.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(vuelta.origenFecha, FechaOrigen.estimada);
      expect(vuelta, equals(a));
    });

    test('un alimento guardado antes de existir el origen se lee como manual', () {
      final json = ejemplo().toJson()..remove('origenFecha');
      expect(Alimento.fromJson(json).origenFecha, FechaOrigen.manual);
    });

    test('un producto que no vence nunca está vencido y sobrevive a JSON', () {
      final a = ejemplo().sinVencimiento();
      expect(a.noVence, isTrue);
      expect(a.estaVencido(DateTime.utc(2100)), isFalse);
      final vuelta = Alimento.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);
      expect(vuelta.noVence, isTrue);
    });

    test('copyWith conserva el origen de la fecha', () {
      final a = ejemplo().conFecha(DateTime.utc(2026, 9, 1), origen: FechaOrigen.leida);
      expect(a.copyWith(nombre: 'Otra').origenFecha, FechaOrigen.leida);
    });
  });

  group('igualdad', () {
    test('dos alimentos con los mismos datos son iguales', () {
      expect(ejemplo(), equals(ejemplo()));
    });

    test('dos alimentos con los mismos datos comparten hashCode', () {
      expect(ejemplo().hashCode, equals(ejemplo().hashCode));
      expect({ejemplo(), ejemplo()}.length, 1);
    });

    test('dos alimentos con fotos distintas NO son iguales', () {
      expect(ejemplo(fotos: const ['a']), isNot(equals(ejemplo(fotos: const ['b']))));
    });

    test('copyWith cambia solo lo que se le pasa', () {
      final original = ejemplo();
      final copia = original.copyWith(nombre: 'Otro nombre');

      expect(copia.nombre, 'Otro nombre');
      expect(copia.id, original.id);
      expect(copia.fechaVencimiento, original.fechaVencimiento);
    });
  });

  group('reglas de negocio', () {
    test('un alimento consumido ya no es consumible', () {
      expect(ejemplo(estado: Consumido(DateTime.now())).esConsumible, isFalse);
    });

    test('un alimento disponible sí es consumible', () {
      expect(ejemplo(estado: Disponible(DateTime.now())).esConsumible, isTrue);
    });

    test('un alimento vencido indica estar vencido si se pasa de la fecha', () {
      final ahora = DateTime.utc(2026, 8, 26);
      expect(ejemplo().estaVencido(ahora), isTrue);
    });

    test('la etiqueta de un desecho incluye el motivo', () {
      expect(
        const Desechado('Huele mal').etiqueta,
        contains('Huele mal'),
      );
    });
  });
}
