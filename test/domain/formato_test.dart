import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/core/formato.dart';

void main() {
  group('fmtNum', () {
    test('un número entero se escribe sin ".0"', () {
      expect(fmtNum(1.0), '1');
      expect(fmtNum(30), '30');
    });

    test('los decimales se conservan hasta dos', () {
      expect(fmtNum(0.25), '0.25');
      expect(fmtNum(12.5), '12.5');
    });

    test('el error de los decimales no se ve en pantalla', () {
      expect(fmtNum(1.0 - 0.7), '0.3');
      expect(fmtNum(0.1 + 0.2), '0.3');
    });
  });

  test('fmtCantidad junta número y unidad', () {
    expect(fmtCantidad(1.0, 'kg'), '1 kg');
    expect(fmtCantidad(0.25, 'kg'), '0.25 kg');
    expect(fmtCantidad(300, 'g'), '300 g');
  });

  group('pasoPara', () {
    test('las unidades van de una en una', () {
      expect(pasoPara('u', 6), 1);
    });

    test('kilos y litros van de 50 en 50 gramos o mililitros', () {
      expect(pasoPara('kg', 1), 0.05);
      expect(pasoPara('L', 2), 0.05);
    });

    test('gramos y mililitros van de 5 en 5 si hay 100 o más', () {
      expect(pasoPara('g', 500), 5);
      expect(pasoPara('ml', 50), 1);
    });
  });
}
