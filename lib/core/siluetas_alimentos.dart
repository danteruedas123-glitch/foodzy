import 'package:flutter/painting.dart';

/// Contornos de alimentos dibujados en un cuadro de 1×1, sin relleno. Los usan
/// el fondo animado de Inicio y el indicador de carga.
abstract final class SiluetasAlimentos {
  static Path _union(List<Path> partes) =>
      partes.reduce((a, b) => Path.combine(PathOperation.union, a, b));

  static Path _circulo(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  static final manzana = Path()
    ..moveTo(0.5, 0.3)
    ..cubicTo(0.35, 0.18, 0.08, 0.22, 0.1, 0.52)
    ..cubicTo(0.12, 0.8, 0.32, 0.95, 0.5, 0.86)
    ..cubicTo(0.68, 0.95, 0.88, 0.8, 0.9, 0.52)
    ..cubicTo(0.92, 0.22, 0.65, 0.18, 0.5, 0.3)
    ..close()
    ..moveTo(0.5, 0.3)
    ..quadraticBezierTo(0.5, 0.16, 0.57, 0.07)
    ..moveTo(0.53, 0.2)
    ..quadraticBezierTo(0.66, 0.06, 0.82, 0.12)
    ..quadraticBezierTo(0.68, 0.26, 0.53, 0.2);

  static final pera = Path()
    ..moveTo(0.5, 0.18)
    ..cubicTo(0.4, 0.18, 0.38, 0.35, 0.36, 0.42)
    ..cubicTo(0.16, 0.55, 0.18, 0.93, 0.5, 0.93)
    ..cubicTo(0.82, 0.93, 0.84, 0.55, 0.64, 0.42)
    ..cubicTo(0.62, 0.35, 0.6, 0.18, 0.5, 0.18)
    ..close()
    ..moveTo(0.5, 0.18)
    ..lineTo(0.53, 0.06);

  static final zanahoria = Path()
    ..moveTo(0.36, 0.32)
    ..quadraticBezierTo(0.5, 0.26, 0.64, 0.32)
    ..quadraticBezierTo(0.6, 0.7, 0.5, 0.95)
    ..quadraticBezierTo(0.4, 0.7, 0.36, 0.32)
    ..close()
    ..moveTo(0.5, 0.28)
    ..lineTo(0.5, 0.06)
    ..moveTo(0.47, 0.29)
    ..quadraticBezierTo(0.36, 0.17, 0.3, 0.07)
    ..moveTo(0.53, 0.29)
    ..quadraticBezierTo(0.64, 0.17, 0.7, 0.07)
    ..moveTo(0.4, 0.48)
    ..lineTo(0.48, 0.5)
    ..moveTo(0.59, 0.63)
    ..lineTo(0.52, 0.65)
    ..moveTo(0.45, 0.78)
    ..lineTo(0.5, 0.79);

  static final muslo = _union([
    Path()
      ..moveTo(0.58, 0.6)
      ..cubicTo(0.36, 0.74, 0.08, 0.6, 0.1, 0.34)
      ..cubicTo(0.12, 0.08, 0.42, 0.02, 0.6, 0.18)
      ..cubicTo(0.74, 0.3, 0.72, 0.46, 0.64, 0.54)
      ..close(),
    Path()
      ..moveTo(0.6, 0.52)
      ..lineTo(0.79, 0.71)
      ..lineTo(0.73, 0.77)
      ..lineTo(0.54, 0.58)
      ..close(),
    _circulo(0.83, 0.69, 0.07),
    _circulo(0.71, 0.81, 0.07),
  ]);

  static final carne = Path()
    ..moveTo(0.2, 0.35)
    ..cubicTo(0.3, 0.12, 0.72, 0.1, 0.85, 0.3)
    ..cubicTo(0.95, 0.48, 0.85, 0.62, 0.72, 0.66)
    ..cubicTo(0.6, 0.7, 0.58, 0.88, 0.4, 0.88)
    ..cubicTo(0.16, 0.88, 0.08, 0.6, 0.2, 0.35)
    ..close()
    ..addOval(Rect.fromCircle(center: const Offset(0.4, 0.5), radius: 0.09))
    ..moveTo(0.62, 0.25)
    ..quadraticBezierTo(0.79, 0.33, 0.74, 0.5);

  static final pescado = Path()
    ..moveTo(0.08, 0.5)
    ..quadraticBezierTo(0.38, 0.2, 0.66, 0.44)
    ..lineTo(0.92, 0.28)
    ..lineTo(0.83, 0.5)
    ..lineTo(0.92, 0.72)
    ..lineTo(0.66, 0.56)
    ..quadraticBezierTo(0.38, 0.8, 0.08, 0.5)
    ..close()
    ..addOval(Rect.fromCircle(center: const Offset(0.24, 0.46), radius: 0.03))
    ..moveTo(0.36, 0.38)
    ..quadraticBezierTo(0.42, 0.5, 0.36, 0.62);

  static final platano = Path()
    ..moveTo(0.22, 0.18)
    ..cubicTo(0.12, 0.6, 0.45, 0.9, 0.88, 0.72)
    ..cubicTo(0.6, 0.72, 0.34, 0.6, 0.31, 0.2)
    ..close()
    ..moveTo(0.22, 0.18)
    ..lineTo(0.21, 0.09)
    ..lineTo(0.29, 0.09)
    ..lineTo(0.31, 0.2);

  static final cerezas = Path()
    ..addPath(_circulo(0.31, 0.72, 0.16), Offset.zero)
    ..addPath(_circulo(0.69, 0.76, 0.16), Offset.zero)
    ..moveTo(0.34, 0.56)
    ..quadraticBezierTo(0.4, 0.3, 0.6, 0.12)
    ..moveTo(0.67, 0.6)
    ..quadraticBezierTo(0.64, 0.34, 0.6, 0.12)
    ..quadraticBezierTo(0.76, 0.04, 0.88, 0.16)
    ..quadraticBezierTo(0.72, 0.22, 0.6, 0.12);

  static final champinon = Path()
    ..moveTo(0.08, 0.52)
    ..cubicTo(0.08, 0.1, 0.92, 0.1, 0.92, 0.52)
    ..close()
    ..moveTo(0.38, 0.52)
    ..lineTo(0.34, 0.86)
    ..quadraticBezierTo(0.5, 0.94, 0.66, 0.86)
    ..lineTo(0.62, 0.52)
    ..addOval(Rect.fromCircle(center: const Offset(0.32, 0.38), radius: 0.05))
    ..addOval(Rect.fromCircle(center: const Offset(0.6, 0.3), radius: 0.06));

  static final brocoli = _union([
    _circulo(0.3, 0.42, 0.17),
    _circulo(0.5, 0.28, 0.2),
    _circulo(0.71, 0.42, 0.16),
    _circulo(0.5, 0.5, 0.15),
    Path()
      ..moveTo(0.42, 0.56)
      ..lineTo(0.38, 0.93)
      ..lineTo(0.62, 0.93)
      ..lineTo(0.58, 0.56)
      ..close(),
  ]);

  static final huevo = Path()
    ..moveTo(0.5, 0.07)
    ..cubicTo(0.74, 0.07, 0.86, 0.46, 0.84, 0.64)
    ..cubicTo(0.82, 0.84, 0.68, 0.94, 0.5, 0.94)
    ..cubicTo(0.32, 0.94, 0.18, 0.84, 0.16, 0.64)
    ..cubicTo(0.14, 0.46, 0.26, 0.07, 0.5, 0.07)
    ..close();

  static final queso = Path()
    ..moveTo(0.08, 0.58)
    ..lineTo(0.78, 0.26)
    ..lineTo(0.92, 0.46)
    ..lineTo(0.92, 0.8)
    ..lineTo(0.08, 0.8)
    ..close()
    ..moveTo(0.08, 0.58)
    ..lineTo(0.92, 0.46)
    ..addOval(Rect.fromCircle(center: const Offset(0.4, 0.68), radius: 0.05))
    ..addOval(Rect.fromCircle(center: const Offset(0.72, 0.66), radius: 0.04))
    ..addOval(Rect.fromCircle(center: const Offset(0.6, 0.42), radius: 0.035));

  static final uvas = Path()
    ..addPath(_circulo(0.3, 0.32, 0.095), Offset.zero)
    ..addPath(_circulo(0.5, 0.32, 0.095), Offset.zero)
    ..addPath(_circulo(0.7, 0.32, 0.095), Offset.zero)
    ..addPath(_circulo(0.4, 0.5, 0.095), Offset.zero)
    ..addPath(_circulo(0.6, 0.5, 0.095), Offset.zero)
    ..addPath(_circulo(0.5, 0.68, 0.095), Offset.zero)
    ..moveTo(0.5, 0.22)
    ..lineTo(0.54, 0.07)
    ..moveTo(0.52, 0.15)
    ..quadraticBezierTo(0.68, 0.06, 0.8, 0.14);

  static final tomate = Path()
    ..addOval(
      Rect.fromCenter(
        center: const Offset(0.5, 0.57),
        width: 0.78,
        height: 0.66,
      ),
    )
    ..moveTo(0.34, 0.31)
    ..lineTo(0.44, 0.32)
    ..lineTo(0.41, 0.22)
    ..lineTo(0.5, 0.3)
    ..lineTo(0.59, 0.22)
    ..lineTo(0.56, 0.32)
    ..lineTo(0.66, 0.31)
    ..moveTo(0.5, 0.3)
    ..lineTo(0.5, 0.14);

  static final aguacate = Path()
    ..moveTo(0.5, 0.08)
    ..cubicTo(0.36, 0.08, 0.34, 0.3, 0.3, 0.4)
    ..cubicTo(0.14, 0.58, 0.18, 0.94, 0.5, 0.94)
    ..cubicTo(0.82, 0.94, 0.86, 0.58, 0.7, 0.4)
    ..cubicTo(0.66, 0.3, 0.64, 0.08, 0.5, 0.08)
    ..close()
    ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.66), radius: 0.14));

  static final alimentos = [
    manzana,
    pera,
    zanahoria,
    muslo,
    carne,
    pescado,
    platano,
    cerezas,
    champinon,
    brocoli,
    huevo,
    queso,
    uvas,
    tomate,
    aguacate,
  ];

  static final corona = Path()
    ..moveTo(0.14, 0.82)
    ..lineTo(0.07, 0.34)
    ..lineTo(0.3, 0.55)
    ..lineTo(0.5, 0.22)
    ..lineTo(0.7, 0.55)
    ..lineTo(0.93, 0.34)
    ..lineTo(0.86, 0.82)
    ..close()
    ..moveTo(0.15, 0.7)
    ..lineTo(0.85, 0.7)
    ..addOval(Rect.fromCircle(center: const Offset(0.07, 0.29), radius: 0.05))
    ..addOval(Rect.fromCircle(center: const Offset(0.5, 0.16), radius: 0.06))
    ..addOval(Rect.fromCircle(center: const Offset(0.93, 0.29), radius: 0.05));
}
