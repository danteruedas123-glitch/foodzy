import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/core/recortes.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/emoji_producto.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';

Alimento alimento(String nombre, {String categoria = 'Otros', String? emoji}) => Alimento(
      id: nombre,
      nombre: nombre,
      categoria: categoria,
      cantidad: const Cantidad(valor: 1, unidad: 'u'),
      fechaVencimiento: DateTime(2026, 12, 1),
      estado: Disponible(DateTime(2026, 10, 1)),
      emoji: emoji,
    );

void main() {
  group('emoji por nombre del producto', () {
    test('reconoce productos concretos, sin importar tildes ni mayúsculas', () {
      expect(emojiPorNombre('Banano'), '🍌');
      expect(emojiPorNombre('QUESO CAMPESINO'), '🧀');
      expect(emojiPorNombre('Huevos AA x30'), '🥚');
      expect(emojiPorNombre('Limón Tahití'), '🍋');
      expect(emojiPorNombre('Pechuga de pollo'), '🍗');
    });

    test('lo más específico gana: salsa de tomate no es tomate, panela no es pan', () {
      expect(emojiPorNombre('Salsa de tomate'), '🥫');
      expect(emojiPorNombre('Jugo de naranja'), '🧃');
      expect(emojiPorNombre('Panela'), '🍬');
      expect(emojiPorNombre('Pan tajado'), '🍞');
    });

    test('las palabras completas no se confunden con otras ("sal" no es "salsa")', () {
      expect(emojiPorNombre('Sal refinada'), '🧂');
      expect(emojiPorNombre('Té verde'), '🍵');
      expect(emojiPorNombre('Tomate chonto'), '🍅');
    });

    test('si no reconoce el nombre, devuelve null', () {
      expect(emojiPorNombre('Producto raro XYZ'), isNull);
    });

    test('la miniatura usa primero el emoji de la IA, luego el nombre y luego la categoría', () {
      expect(emojiDe(alimento('Leche', emoji: '🐄')), '🐄');
      expect(emojiDe(alimento('Leche')), '🥛');
      expect(emojiDe(alimento('Algo', categoria: 'Enlatados')), '🥫');
    });
  });

  group('recorte de cada producto', () {
    test('un recuadro se vuelve un cuadrado con margen, dentro de la foto', () {
      // Foto de 1000 x 2000; producto en el centro, 200 x 100 px.
      final r = cuadroDeRecorte([475, 400, 525, 600], 1000, 2000)!;
      expect(r.width, r.height);
      expect(r.width, closeTo(240, 0.01)); // 200 px + 10% de cada lado
      expect(r.center.dx, closeTo(500, 0.01));
      expect(r.center.dy, closeTo(1000, 0.01));
    });

    test('pegado al borde, el cuadrado se corre para no salirse de la foto', () {
      final r = cuadroDeRecorte([0, 0, 100, 100], 1000, 1000)!;
      expect(r.left, 0);
      expect(r.top, 0);
    });

    test('una caja vacía o mal formada no se recorta', () {
      expect(cuadroDeRecorte([500, 500, 500, 500], 1000, 1000), isNull);
      expect(cuadroDeRecorte([1, 2, 3], 1000, 1000), isNull);
    });
  });

  test('el emoji y la factura se guardan y se leen con el alimento', () {
    final a = alimento('Leche', emoji: '🥛').conIdYFotos('x', const [], ticket: '/tmp/factura.jpg');
    final vuelta = Alimento.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, dynamic>);

    expect(vuelta.emoji, '🥛');
    expect(vuelta.ticket, '/tmp/factura.jpg');
  });
}
