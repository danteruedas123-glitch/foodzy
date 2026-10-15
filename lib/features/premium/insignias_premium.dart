import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/premium/premium_provider.dart';

/// Paleta dorada de Premium: igual en tema claro y oscuro, para que se
/// reconozca en cualquier pantalla.
abstract final class OroPremium {
  static const claro = Color(0xFFFFF1B8);
  static const brillo = Color(0xFFF8D86A);
  static const medio = Color(0xFFE2B33C);
  static const profundo = Color(0xFFB8860B);
  static const tinta = Color(0xFF4A3200);

  static const degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brillo, medio, profundo, medio],
    stops: [0, 0.4, 0.75, 1],
  );

  static const aro = SweepGradient(
    colors: [brillo, profundo, medio, claro, medio, profundo, brillo],
  );
}

/// Foto (o inicial) del usuario. Si es Premium lleva un aro dorado y una
/// corona sobre el borde.
class AvatarUsuario extends ConsumerWidget {
  const AvatarUsuario({super.key, this.radio = 28});

  final double radio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final auth = ref.watch(authProvider);
    final premium = ref.watch(premiumProvider.select((p) => p.premium));
    final nombre = auth.userName ?? '';
    final foto = auth.fotoUrl;

    final avatar = CircleAvatar(
      radius: radio,
      backgroundColor: cs.primaryContainer,
      foregroundImage: foto == null ? null : NetworkImage(foto),
      onForegroundImageError: foto == null ? null : (_, _) {},
      child: Text(
        nombre.isEmpty ? 'U' : nombre[0].toUpperCase(),
        style: TextStyle(
          fontSize: radio * 0.8,
          fontWeight: FontWeight.w900,
          color: cs.onPrimaryContainer,
        ),
      ),
    );

    if (!premium) return avatar;

    final grosor = (radio * 0.1).clamp(2.0, 4.0);
    final corona = radio * 0.85;
    return Semantics(
      label: 'Usuario Premium',
      child: SizedBox(
        width: (radio + grosor * 2) * 2,
        height: (radio + grosor * 2) * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.all(grosor),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: OroPremium.aro,
                boxShadow: [
                  BoxShadow(
                    color: OroPremium.medio.withValues(alpha: 0.45),
                    blurRadius: radio * 0.5,
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.all(grosor * 0.7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surface,
                ),
                child: avatar,
              ),
            ),
            Positioned(
              top: -corona * 0.42,
              right: -corona * 0.18,
              child: Transform.rotate(
                angle: 0.45,
                child: CoronaPremium(tamano: corona),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corona dorada dibujada a mano (no hay ícono de corona en Material).
class CoronaPremium extends StatelessWidget {
  const CoronaPremium({super.key, this.tamano = 24});

  final double tamano;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(tamano, tamano * 0.8),
    painter: _PintorCorona(Theme.of(context).colorScheme.surface),
  );
}

class _PintorCorona extends CustomPainter {
  const _PintorCorona(this.contorno);

  /// Borde del color del fondo para que la corona se despegue del aro.
  final Color contorno;

  @override
  void paint(Canvas canvas, Size size) {
    final m = size.width * 0.1;
    final w = size.width - m * 2;
    final h = size.height - m * 2;
    Offset p(double x, double y) => Offset(m + w * x, m + h * y);

    final cuerpo = Path()
      ..moveTo(p(0.1, 0.95).dx, p(0.1, 0.95).dy)
      ..lineTo(p(0.02, 0.32).dx, p(0.02, 0.32).dy)
      ..lineTo(p(0.3, 0.58).dx, p(0.3, 0.58).dy)
      ..lineTo(p(0.5, 0.1).dx, p(0.5, 0.1).dy)
      ..lineTo(p(0.7, 0.58).dx, p(0.7, 0.58).dy)
      ..lineTo(p(0.98, 0.32).dx, p(0.98, 0.32).dy)
      ..lineTo(p(0.9, 0.95).dx, p(0.9, 0.95).dy)
      ..close();
    final puntas = [p(0.02, 0.32), p(0.5, 0.1), p(0.98, 0.32)];
    final r = w * 0.085;

    final borde = Paint()
      ..color = contorno
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.12
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(cuerpo, borde);
    for (final c in puntas) {
      canvas.drawCircle(c, r + size.width * 0.06, Paint()..color = contorno);
    }

    final oro = Paint()
      ..shader = OroPremium.degradado.createShader(Offset.zero & size);
    canvas.drawPath(cuerpo, oro);
    for (final c in puntas) {
      canvas.drawCircle(c, r, oro);
    }

    // Banda inferior y una gema al centro.
    canvas.drawLine(
      p(0.12, 0.8),
      p(0.88, 0.8),
      Paint()
        ..color = OroPremium.profundo
        ..strokeWidth = size.width * 0.05,
    );
    canvas.drawCircle(p(0.5, 0.66), r * 0.75, Paint()..color = Colors.white);
    canvas.drawPath(
      cuerpo,
      Paint()
        ..color = OroPremium.profundo
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.035
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PintorCorona old) => old.contorno != contorno;
}

/// Etiqueta dorada "PREMIUM" con un destello que la recorre de vez en cuando.
class InsigniaPremium extends StatefulWidget {
  const InsigniaPremium({super.key, this.compacta = false});

  /// Versión más pequeña para textos secundarios.
  final bool compacta;

  @override
  State<InsigniaPremium> createState() => _InsigniaPremiumState();
}

class _InsigniaPremiumState extends State<InsigniaPremium>
    with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _brillo.stop();
    } else if (!_brillo.isAnimating) {
      _brillo.repeat();
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fuente = widget.compacta ? 9.0 : 11.0;
    final radio = BorderRadius.circular(999);
    return AnimatedBuilder(
      animation: _brillo,
      builder: (context, child) {
        // El destello cruza en el primer 35% del ciclo y luego descansa.
        final t = (_brillo.value / 0.35).clamp(0.0, 1.0);
        return Container(
          decoration: BoxDecoration(
            gradient: OroPremium.degradado,
            borderRadius: radio,
            border: Border.all(color: OroPremium.claro.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: OroPremium.profundo.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          foregroundDecoration: _brillo.isAnimating && t < 1
              ? BoxDecoration(
                  borderRadius: radio,
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.65),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0.35, 0.5, 0.65],
                    transform: _Deslizar(t * 2 - 1),
                  ),
                )
              : null,
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compacta ? 7 : 9,
          vertical: widget.compacta ? 2 : 3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, size: fuente + 3, color: OroPremium.tinta),
            const SizedBox(width: 3),
            Text(
              'PREMIUM',
              style: TextStyle(
                fontSize: fuente,
                height: 1.2,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
                color: OroPremium.tinta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Deslizar extends GradientTransform {
  const _Deslizar(this.avance);

  /// De -1 (fuera a la izquierda) a 1 (fuera a la derecha).
  final double avance;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * avance, 0, 0);
}

/// Nombre del usuario con la insignia al lado cuando es Premium.
class NombreConInsignia extends ConsumerWidget {
  const NombreConInsignia(this.nombre, {super.key, this.estilo});

  final String nombre;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premium = ref.watch(premiumProvider.select((p) => p.premium));
    return Row(
      children: [
        Flexible(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: estilo,
          ),
        ),
        if (premium) ...[const SizedBox(width: 8), const InsigniaPremium()],
      ],
    );
  }
}
