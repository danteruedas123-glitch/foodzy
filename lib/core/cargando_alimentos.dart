import 'dart:math';

import 'package:flutter/material.dart';
import 'package:foodzy/core/siluetas_alimentos.dart';

/// Indicador de carga propio: la silueta de un alimento gira como una moneda
/// y, justo cuando queda de canto, se convierte en el siguiente alimento.
class CargandoAlimentos extends StatefulWidget {
  const CargandoAlimentos({super.key, this.tamano = 56, this.color});

  final double tamano;

  /// Color del contorno; por defecto, el primario del tema.
  final Color? color;

  @override
  State<CargandoAlimentos> createState() => _CargandoAlimentosState();
}

class _CargandoAlimentosState extends State<CargandoAlimentos>
    with SingleTickerProviderStateMixin {
  // Cada vuelta: un rato quieto y luego el giro de media vuelta.
  static const _quieto = 0.35;

  late final AnimationController _vuelta = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..addListener(_contarVuelta);

  final _formas = SiluetasAlimentos.alimentos;
  late int _indice = Random().nextInt(_formas.length);
  double _ultimo = 0;

  /// Cuando la animación vuelve a empezar, el alimento que entró girando pasa
  /// a ser el actual.
  void _contarVuelta() {
    if (_vuelta.value < _ultimo) _indice = _siguiente(_indice);
    _ultimo = _vuelta.value;
  }

  // Saltos de 7 (coprimo con 15): recorre todos sin repetir seguidos.
  int _siguiente(int i) => (i + 7) % _formas.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir movimiento": se queda quieto en un alimento.
    if (MediaQuery.disableAnimationsOf(context)) {
      _vuelta.stop();
    } else if (!_vuelta.isAnimating) {
      _vuelta.repeat();
    }
  }

  @override
  void dispose() {
    _vuelta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'Cargando',
      child: SizedBox.square(
        dimension: widget.tamano,
        child: AnimatedBuilder(
          animation: _vuelta,
          builder: (context, _) {
            final t = _vuelta.value <= _quieto
                ? 0.0
                : Curves.easeInOutCubic
                    .transform((_vuelta.value - _quieto) / (1 - _quieto));
            final angulo = t * pi;
            // Pasada la mitad se dibuja el siguiente alimento, que termina de
            // girar hasta quedar de frente (sin verse al revés).
            final segundaMitad = angulo > pi / 2;
            final forma =
                _formas[segundaMitad ? _siguiente(_indice) : _indice];
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(segundaMitad ? angulo - pi : angulo)
                // Se encoge un poco al quedar de canto, para dar profundidad.
                ..scaleByDouble(
                    1 - sin(angulo) * 0.12, 1 - sin(angulo) * 0.12, 1, 1),
              child: CustomPaint(
                painter: _PintorSilueta(forma, color),
                size: Size.square(widget.tamano),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PintorSilueta extends CustomPainter {
  const _PintorSilueta(this.forma, this.color);

  final Path forma;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.shortestSide;
    canvas.scale(escala);
    canvas.drawPath(
      forma,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6 / escala
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PintorSilueta old) =>
      old.forma != forma || old.color != color;
}
