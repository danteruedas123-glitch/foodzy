import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

/// Cuánto se descuenta de un alimento de la despensa al cocinar una receta.
class DescuentoAlimento {
  const DescuentoAlimento(this.alimento, this.cantidad);

  final Alimento alimento;

  /// En la misma unidad del alimento. Nunca supera lo que hay.
  final double cantidad;
}

/// Lo que cocinar una receta le quita a la despensa.
class DescuentoReceta {
  const DescuentoReceta({required this.lineas, required this.sinMedir});

  /// Un renglón por alimento de la despensa.
  final List<DescuentoAlimento> lineas;

  /// Nombres de ingredientes que salen de la despensa pero no se pueden medir
  /// (al gusto, una pizca), así que no se descuentan.
  final List<String> sinMedir;
}

/// Calcula qué se descuenta de [despensa] (alimentos por id) al cocinar
/// [receta].
///
/// - Si dos ingredientes salen del mismo alimento, sus cantidades se suman.
/// - La suma nunca supera lo disponible.
/// - Los ingredientes que no están en la despensa se ignoran.
DescuentoReceta calcularDescuento(Receta receta, Map<String, Alimento> despensa) {
  final sumas = <String, double>{};
  final sinMedir = <String>[];

  for (final ingrediente in receta.ingredientes) {
    final id = ingrediente.alimentoId;
    final alimento = id == null ? null : despensa[id];
    if (alimento == null) continue;

    final usada = ingrediente.cantidadUsada;
    if (usada == null || usada <= 0) {
      sinMedir.add(ingrediente.nombre);
      continue;
    }
    sumas[alimento.id] = (sumas[alimento.id] ?? 0) + usada;
  }

  return DescuentoReceta(
    lineas: [
      for (final e in sumas.entries)
        DescuentoAlimento(
          despensa[e.key]!,
          e.value.clamp(0.0, despensa[e.key]!.cantidad.valor).toDouble(),
        ),
    ],
    sinMedir: sinMedir,
  );
}
