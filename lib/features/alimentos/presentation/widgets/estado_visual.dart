import 'package:flutter/material.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// Cómo se muestra el estado de un alimento: texto corto, color e ícono.
class EstadoVisual {
  const EstadoVisual(this.texto, this.color, this.icono);
  final String texto;
  final Color color;
  final IconData icono;
}

int _diasHasta(DateTime fecha, DateTime ahora) {
  final a = DateTime(ahora.year, ahora.month, ahora.day);
  final b = DateTime(fecha.year, fecha.month, fecha.day);
  return b.difference(a).inDays;
}

/// Días que faltan para vencer (negativo si ya venció).
int diasParaVencer(Alimento a, [DateTime? ahora]) =>
    _diasHasta(a.fechaVencimiento, ahora ?? DateTime.now());

/// `true` si está disponible y vence en [dias] días o menos (o ya venció).
bool venceEn(Alimento a, int dias) =>
    a.estado is Disponible &&
    !a.sinFechaVencimiento &&
    diasParaVencer(a) <= dias;

EstadoVisual estadoVisual(Alimento a) {
  final estado = a.estado;
  if (estado is Consumido) {
    return EstadoVisual(
      'Consumido el ${fechaCorta(estado.fechaConsumo)}',
      const Color(0xFF3B82F6),
      Icons.check_circle_rounded,
    );
  }
  if (estado is Desechado) {
    return EstadoVisual('Desechado', const Color(0xFF78716C), Icons.delete_rounded);
  }
  if (a.sinFechaVencimiento) {
    return const EstadoVisual('Sin fecha', Color(0xFF8B5CF6), Icons.event_busy_rounded);
  }
  final dias = diasParaVencer(a);
  if (dias < 0) {
    return EstadoVisual(
      dias == -1 ? 'Venció ayer' : 'Venció hace ${-dias} días',
      const Color(0xFFEF4444),
      Icons.warning_rounded,
    );
  }
  if (dias == 0) {
    return const EstadoVisual('Vence hoy', Color(0xFFF97316), Icons.timer_rounded);
  }
  if (dias <= 3) {
    return EstadoVisual(
      dias == 1 ? 'Vence mañana' : 'Vence en $dias días',
      const Color(0xFFF59E0B),
      Icons.schedule_rounded,
    );
  }
  return EstadoVisual('Vence en $dias días', const Color(0xFF22C55E), Icons.eco_rounded);
}

/// Emoji según la categoría, para que la tarjeta se vea viva sin foto.
String emojiCategoria(String categoria, [String nombre = '']) {
  final t = '${categoria.toLowerCase()} ${nombre.toLowerCase()}';
  bool tiene(List<String> ps) => ps.any(t.contains);
  if (tiene(['lácteo', 'lacteo', 'leche', 'queso', 'yogur'])) return '🥛';
  if (tiene(['fruta', 'manzana', 'banano', 'naranja', 'fresa', 'uva'])) return '🍎';
  if (tiene(['verdura', 'hortaliza', 'tomate', 'lechuga', 'cebolla', 'zanahoria'])) return '🥬';
  if (tiene(['carne', 'pollo', 'res', 'cerdo', 'embutido'])) return '🥩';
  if (tiene(['pescado', 'atún', 'atun', 'marisco'])) return '🐟';
  if (tiene(['pan', 'panad', 'galleta'])) return '🍞';
  if (tiene(['huevo'])) return '🥚';
  if (tiene(['bebida', 'jugo', 'gaseosa', 'agua'])) return '🧃';
  if (tiene(['enlatado', 'conserva', 'lata'])) return '🥫';
  if (tiene(['cereal', 'arroz', 'pasta', 'grano', 'harina'])) return '🌾';
  if (tiene(['snack', 'dulce', 'chocolate'])) return '🍫';
  if (tiene(['congelad', 'helado'])) return '🧊';
  return '🍽️';
}

/// "10 ene 2026": legible sin depender de la configuración regional.
String fechaCorta(DateTime f) {
  const meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];
  return '${f.day} ${meses[f.month - 1]} ${f.year}';
}
