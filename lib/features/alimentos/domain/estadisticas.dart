import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';

/// Resumen de un mes: cuánto se gastó, cuánto se desperdició y en qué.
class EstadisticasMes {
  const EstadisticasMes({
    required this.mes,
    required this.gastado,
    required this.desperdiciado,
    required this.consumidos,
    required this.desechados,
    required this.gastoPorCategoria,
    required this.topDesperdicio,
  });

  /// Primer día del mes al que corresponde.
  final DateTime mes;
  final double gastado;
  final double desperdiciado;
  final int consumidos;
  final int desechados;
  final Map<String, double> gastoPorCategoria;

  /// Lo que más dinero se desperdició: (nombre, valor), de mayor a menor.
  final List<(String, double)> topDesperdicio;

  /// Qué parte de lo gastado se perdió (0 a 1). 0 si no hay gasto.
  double get porcentajeDesperdicio =>
      gastado <= 0 ? 0 : (desperdiciado / gastado).clamp(0.0, 1.0);

  bool get vacio =>
      gastado == 0 && desperdiciado == 0 && consumidos == 0 && desechados == 0;
}

bool _mismoMes(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

/// Cuánto dinero se perdió al desechar [a]: el precio por la fracción que
/// quedaba sin usar (si se conoce la cantidad inicial) o el precio completo.
double costoDesperdicio(Alimento a) {
  final precio = a.precio;
  if (precio == null) return 0;
  final inicial = a.cantidadInicial;
  if (inicial == null || inicial <= 0) return precio;
  final fraccion = (a.cantidad.valor / inicial).clamp(0.0, 1.0);
  return precio * fraccion;
}

EstadisticasMes estadisticasDelMes(List<Alimento> alimentos, DateTime mes) {
  var gastado = 0.0;
  var desperdiciado = 0.0;
  var consumidos = 0;
  var desechados = 0;
  // Se agrupa por claveNombre para que "Leche" y "leche" (o "Lácteos" y
  // "lacteos") cuenten como lo mismo; se muestra el primer nombre que aparezca.
  final porCategoria = <String, double>{};
  final porNombre = <String, double>{};
  final nombres = <String, String>{};

  for (final a in alimentos) {
    // Gasto: lo comprado en el mes.
    final ingreso = a.ingreso;
    if (a.precio != null && ingreso != null && _mismoMes(ingreso, mes)) {
      gastado += a.precio!;
      final k = claveNombre(a.categoria);
      nombres.putIfAbsent('cat:$k', () => a.categoria.trim());
      porCategoria[k] = (porCategoria[k] ?? 0) + a.precio!;
    }

    // Consumo y desperdicio: lo que salió de la despensa en el mes.
    final cierre = fechaDeCierre(a);
    if (cierre == null || !_mismoMes(cierre, mes)) continue;
    if (a.estado is Consumido) {
      consumidos++;
    } else if (a.estado is Desechado) {
      desechados++;
      final perdido = costoDesperdicio(a);
      desperdiciado += perdido;
      if (perdido > 0) {
        final k = claveNombre(a.nombre);
        nombres.putIfAbsent('ali:$k', () => a.nombre.trim());
        porNombre[k] = (porNombre[k] ?? 0) + perdido;
      }
    }
  }

  final top = porNombre.entries
      .map((e) => (nombres['ali:${e.key}']!, e.value))
      .toList()
    ..sort((a, b) => b.$2.compareTo(a.$2));

  return EstadisticasMes(
    mes: DateTime(mes.year, mes.month),
    gastado: gastado,
    desperdiciado: desperdiciado,
    consumidos: consumidos,
    desechados: desechados,
    gastoPorCategoria: {
      for (final e in porCategoria.entries) nombres['cat:${e.key}']!: e.value,
    },
    topDesperdicio: top.take(3).toList(),
  );
}

/// Los últimos [cuantos] meses terminando en [hasta], del más antiguo al más nuevo.
List<EstadisticasMes> ultimosMeses(
  List<Alimento> alimentos,
  DateTime hasta, {
  int cuantos = 6,
}) =>
    [
      for (var i = cuantos - 1; i >= 0; i--)
        estadisticasDelMes(alimentos, DateTime(hasta.year, hasta.month - i)),
    ];
