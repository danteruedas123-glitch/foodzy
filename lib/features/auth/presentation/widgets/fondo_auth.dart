import 'dart:math';

import 'package:flutter/material.dart';

/// Fondo de las pantallas de inicio de sesión y registro.
///
/// Reemplaza al video de pétalos: es un dibujo fijo (hojas, pétalos y luces
/// suaves sobre un degradado oscuro) que se pinta una sola vez. No pesa nada
/// en el APK, no gasta batería y aparece al instante.
class FondoAuth extends StatelessWidget {
  const FondoAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: SizedBox.expand(child: CustomPaint(painter: _PintorFondo())),
    );
  }
}

class _PintorFondo extends CustomPainter {
  const _PintorFondo();

  static const _verde = Color(0xFF7DD279);
  static const _hojas = [Color(0xFF66BB6A), Color(0xFF9CCC65), Color(0xFF43A047)];
  static const _petalos = [
    Color(0xFFF48FB1), // rosa
    Color(0xFFFFD54F), // amarillo
    Color(0xFFFFB74D), // durazno
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    final lado = size.shortestSide;

    // Degradado oscuro con un toque verde arriba.
    canvas.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13241A), Color(0xFF0A120D), Color(0xFF060908)],
          stops: [0, 0.55, 1],
        ).createShader(r),
    );

    // Dos resplandores grandes y difusos.
    _resplandor(canvas, Offset(size.width * 0.1, size.height * 0.08), lado * 0.9,
        _verde.withValues(alpha: 0.22));
    _resplandor(canvas, Offset(size.width * 0.95, size.height * 0.9), lado * 0.8,
        const Color(0xFFFFB74D).withValues(alpha: 0.12));

    // Semilla fija: el dibujo es siempre el mismo.
    final azar = Random(11);

    // Luces desenfocadas (bokeh).
    for (var i = 0; i < 14; i++) {
      final c = Offset(azar.nextDouble() * size.width, azar.nextDouble() * size.height);
      final radio = lado * (0.015 + azar.nextDouble() * 0.04);
      final color = (i.isEven ? const Color(0xFFFFE082) : Colors.white)
          .withValues(alpha: 0.05 + azar.nextDouble() * 0.08);
      _resplandor(canvas, c, radio, color);
    }

    // Hojas, pétalos y florecitas repartidos en una cuadrícula con algo de
    // desorden, para que cubran toda la pantalla sin amontonarse.
    const columnas = 5;
    final filas = max(6, (size.height / size.width * columnas).round());
    final anchoCelda = size.width / columnas;
    final altoCelda = size.height / filas;
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (azar.nextDouble() < 0.25) continue; // huecos para que respire
        final centro = Offset(
          (c + 0.15 + azar.nextDouble() * 0.7) * anchoCelda,
          (f + 0.15 + azar.nextDouble() * 0.7) * altoCelda,
        );
        // El centro (donde van el logo y el formulario) queda despejado, y
        // lo que está cerca se ve más tenue.
        final dx = (centro.dx / size.width - 0.5).abs() * 2;
        final dy = (centro.dy / size.height - 0.5).abs() * 2;
        final despejar = dy < 0.74 && dx < 0.95;
        final alfa = 0.3 + 0.55 * max(dx, dy);
        final giro = azar.nextDouble() * pi * 2;
        final escala = lado * (0.035 + azar.nextDouble() * 0.03);
        final tipo = azar.nextDouble();
        if (despejar) continue;
        canvas.save();
        canvas.translate(centro.dx, centro.dy);
        canvas.rotate(giro);
        if (tipo < 0.45) {
          _hoja(canvas, escala, _hojas[azar.nextInt(_hojas.length)], alfa);
        } else if (tipo < 0.85) {
          _petalo(canvas, escala * 0.8, _petalos[azar.nextInt(_petalos.length)], alfa);
        } else {
          _flor(canvas, escala * 0.45, alfa);
        }
        canvas.restore();
      }
    }

    // Velo inferior: el texto de abajo se lee mejor.
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
          stops: const [0.6, 1],
        ).createShader(r),
    );
  }

  void _resplandor(Canvas canvas, Offset centro, double radio, Color color) {
    canvas.drawCircle(
      centro,
      radio,
      Paint()
        ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: centro, radius: radio)),
    );
  }

  void _hoja(Canvas canvas, double t, Color color, double alfa) {
    final forma = Path()
      ..moveTo(0, -t)
      ..quadraticBezierTo(t * 0.75, -t * 0.2, 0, t)
      ..quadraticBezierTo(-t * 0.75, -t * 0.2, 0, -t)
      ..close();
    canvas.drawPath(forma, Paint()..color = color.withValues(alpha: alfa));
    canvas.drawLine(
      Offset(0, -t * 0.8),
      Offset(0, t * 0.85),
      Paint()
        ..color = Colors.white.withValues(alpha: alfa * 0.35)
        ..strokeWidth = max(1, t * 0.06)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _petalo(Canvas canvas, double t, Color color, double alfa) {
    final forma = Path()
      ..moveTo(0, -t)
      ..cubicTo(t * 0.9, -t * 0.6, t * 0.6, t * 0.8, 0, t * 0.6)
      ..cubicTo(-t * 0.6, t * 0.8, -t * 0.9, -t * 0.6, 0, -t)
      ..close();
    canvas.drawPath(forma, Paint()..color = color.withValues(alpha: alfa * 0.9));
  }

  void _flor(Canvas canvas, double t, double alfa) {
    final petalo = Paint()..color = const Color(0xFF90CAF9).withValues(alpha: alfa);
    for (var i = 0; i < 5; i++) {
      final a = i * 2 * pi / 5;
      canvas.drawCircle(Offset(cos(a) * t, sin(a) * t), t * 0.75, petalo);
    }
    canvas.drawCircle(
        Offset.zero, t * 0.5, Paint()..color = const Color(0xFFFFE082).withValues(alpha: alfa));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
