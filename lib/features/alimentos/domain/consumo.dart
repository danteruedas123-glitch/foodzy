import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// Por debajo de esto se considera que ya no queda nada.
const _casiNada = 0.0001;

/// Lo que queda de [a] después de usar [usado], redondeado a tres decimales
/// para no arrastrar el error de los decimales (1 - 0.7 = 0.30000000000000004).
double restanteTras(Alimento a, double usado) =>
    double.parse((a.cantidad.valor - usado).toStringAsFixed(3));

/// El alimento después de usar [usado]: con la cantidad que queda o, si no
/// queda nada, marcado como consumido en [ahora].
///
/// Es la única cuenta de consumo de la app: la usan el detalle y "Sacar comida".
Alimento consumir(Alimento a, double usado, DateTime ahora) {
  final restante = restanteTras(a, usado);
  if (restante <= _casiNada) return a.copyWith(estado: Consumido(ahora));
  return a.copyWith(
    cantidad: Cantidad(valor: restante, unidad: a.cantidad.unidad),
  );
}
