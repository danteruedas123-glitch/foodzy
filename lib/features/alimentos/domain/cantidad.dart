import 'package:foodzy/core/json.dart';

/// La cantidad de un alimento, ej. 500 gramos, 1 litro.
///
/// Es un **objeto de valor**: dos cantidades con el mismo valor y unidad son
/// la misma cantidad, así que no lleva `id` y se compara por contenido.
class Cantidad {
  const Cantidad({
    required this.valor,
    required this.unidad,
  }) : assert(valor > 0, 'La cantidad debe ser mayor a cero');

  factory Cantidad.fromJson(Map<String, dynamic> json) => Cantidad(
        valor: leerDecimal(json, 'valor'),
        unidad: leerTexto(json, 'unidad'),
      );

  final double valor;
  final String unidad;

  Map<String, dynamic> toJson() => {
        'valor': valor,
        'unidad': unidad,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cantidad &&
          other.valor == valor &&
          other.unidad == unidad;

  @override
  int get hashCode => Object.hash(valor, unidad);

  @override
  String toString() => 'Cantidad($valor $unidad)';
}
