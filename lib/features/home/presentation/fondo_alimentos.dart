import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:foodzy/core/siluetas_alimentos.dart';

/// Fondo liso (negro en tema oscuro, claro en tema claro) con siluetas de
/// alimentos que caen en cascada. Los contornos se recortan del fondo, así que
/// lo que se ve a través de ellos es lo que haya detrás (el degradado del
/// encabezado). Los Premium ven también coronas.
class FondoAlimentos extends StatefulWidget {
  const FondoAlimentos({super.key, this.premium = false});

  final bool premium;

  @override
  State<FondoAlimentos> createState() => _FondoAlimentosState();
}

class _FondoAlimentosState extends State<FondoAlimentos>
    with SingleTickerProviderStateMixin {
  final _segundos = ValueNotifier<double>(0);

  /// Tiempo ya recorrido antes de la última pausa: al reanudar, la cascada
  /// sigue donde iba en vez de volver al principio.
  double _base = 0;
  late final Ticker _ticker = createTicker(
    (t) => _segundos.value =
        _base + t.inMicroseconds / Duration.microsecondsPerSecond,
  );

  bool _quieto = false;
  bool _visible = true;
  ScrollPosition? _posicion;

  /// Se guarda entre reconstrucciones para no recalcular la rejilla de
  /// siluetas cada vez que la pantalla de inicio se redibuja.
  _PintorCascada? _pintor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir movimiento": el patrón se queda quieto.
    _quieto = MediaQuery.disableAnimationsOf(context);

    // Al desplazar la pantalla, se pausa mientras el encabezado no se ve.
    final posicion = Scrollable.maybeOf(context)?.position;
    if (posicion != _posicion) {
      _posicion?.removeListener(_revisarVisible);
      _posicion = posicion?..addListener(_revisarVisible);
    }
    _actualizarTicker();
  }

  void _revisarVisible() {
    final caja = context.findRenderObject();
    if (caja is! RenderBox || !caja.attached || !caja.hasSize) return;
    final arriba = caja.localToGlobal(Offset.zero).dy;
    final visible = arriba + caja.size.height > 0 &&
        arriba < MediaQuery.sizeOf(context).height;
    if (visible == _visible) return;
    _visible = visible;
    _actualizarTicker();
  }

  void _actualizarTicker() {
    final animar = !_quieto && _visible;
    if (animar && !_ticker.isActive) {
      _ticker.start();
    } else if (!animar && _ticker.isActive) {
      _base = _segundos.value;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _posicion?.removeListener(_revisarVisible);
    _ticker.dispose();
    _segundos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final relleno = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0B0B)
        : theme.colorScheme.surfaceContainerHigh;
    final anterior = _pintor;
    final pintor = anterior != null &&
            anterior.premium == widget.premium &&
            anterior.relleno == relleno
        ? anterior
        : _PintorCascada(_segundos, premium: widget.premium, relleno: relleno);
    _pintor = pintor;
    return RepaintBoundary(child: CustomPaint(painter: pintor));
  }
}

class _Silueta {
  const _Silueta({
    required this.forma,
    required this.columna,
    required this.dx,
    required this.y0,
    required this.tamano,
    required this.giro,
    required this.fase,
  });

  final Path forma;
  final int columna;

  /// Desplazamiento horizontal dentro de la columna (fracción de su ancho).
  final double dx;
  final double y0;
  final double tamano;
  final double giro;
  final double fase;
}

class _PintorCascada extends CustomPainter {
  _PintorCascada(
    this.segundos, {
    required this.premium,
    required this.relleno,
  }) : super(repaint: segundos);

  final ValueNotifier<double> segundos;
  final bool premium;
  final Color relleno;

  static const _celda = 54.0;
  static const _grosor = 1.8;

  Size? _tamanoCache;
  late List<_Silueta> _siluetas;
  late List<double> _velocidades;
  late double _largo;

  /// Reparte las siluetas en una rejilla con algo de desorden. Usa una semilla
  /// fija para que el patrón no cambie cada vez que se reconstruye.
  void _armar(Size size) {
    final rnd = Random(7);
    final columnas = max(1, (size.width / _celda).round());
    final filas = ((size.height + _celda) / _celda).ceil();
    _largo = filas * _celda;
    _velocidades = [
      for (var c = 0; c < columnas; c++) 7 + rnd.nextDouble() * 9,
    ];
    // Cada columna recorre los alimentos a saltos de 7 (coprimo con 15) desde
    // un inicio distinto, así no se repite el mismo alimento dentro de ella.
    final n = SiluetasAlimentos.alimentos.length;
    final inicios = [for (var c = 0; c < columnas; c++) rnd.nextInt(n)];
    _siluetas = [
      for (var c = 0; c < columnas; c++)
        for (var f = 0; f < filas; f++)
          _Silueta(
            forma: premium && rnd.nextDouble() < 0.08
                ? SiluetasAlimentos.corona
                : SiluetasAlimentos.alimentos[(inicios[c] + f * 7) % n],
            columna: c,
            dx: 0.5 + (rnd.nextDouble() - 0.5) * 0.3,
            y0:
                f * _celda +
                rnd.nextDouble() * _celda * 0.3 +
                (c.isOdd ? _celda / 2 : 0),
            tamano: _celda * (0.4 + rnd.nextDouble() * 0.45),
            giro: (rnd.nextDouble() - 0.5) * 1.2,
            fase: rnd.nextDouble() * pi * 2,
          ),
    ];
    _tamanoCache = size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_tamanoCache != size) _armar(size);

    final t = segundos.value;
    final ancho = size.width / _velocidades.length;
    final rect = Offset.zero & size;

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = relleno);

    final trazo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..blendMode = BlendMode.dstOut;

    for (final s in _siluetas) {
      final y = (s.y0 + t * _velocidades[s.columna]) % _largo - _celda;
      final x = (s.columna + s.dx) * ancho;
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(s.giro + sin(t * 0.35 + s.fase) * 0.18)
        ..scale(s.tamano)
        ..translate(-0.5, -0.5);
      trazo.strokeWidth = _grosor / s.tamano;
      canvas.drawPath(s.forma, trazo);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorCascada old) =>
      old.segundos != segundos ||
      old.premium != premium ||
      old.relleno != relleno;
}
