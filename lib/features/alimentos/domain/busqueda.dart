import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';

/// `true` si [a] coincide con lo escrito en el buscador, por nombre o por
/// categoría, sin importar mayúsculas, tildes ni espacios de más
/// ("lacteos" encuentra "Lácteos"). Un texto vacío coincide con todo.
bool coincideBusqueda(Alimento a, String texto) {
  final buscado = claveNombre(texto);
  if (buscado.isEmpty) return true;
  return claveNombre(a.nombre).contains(buscado) ||
      claveNombre(a.categoria).contains(buscado);
}
