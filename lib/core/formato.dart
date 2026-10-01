/// Número sin ceros inútiles: 30 → "30", 0.25 → "0.25", 12.5 → "12.5".
String fmtNum(double v) {
  final redondeado = double.parse(v.toStringAsFixed(2));
  if (redondeado == redondeado.roundToDouble()) {
    return redondeado.toInt().toString();
  }
  return redondeado.toString();
}

/// "300 g", "1 L", "2 u".
String fmtCantidad(double v, String unidad) => '${fmtNum(v)} $unidad';

/// Salto razonable del selector según la unidad y cuánto hay.
double pasoPara(String unidad, double total) {
  switch (unidad) {
    case 'u':
      return 1;
    case 'kg':
    case 'L':
      return 0.05;
    default: // g, ml
      return total >= 100 ? 5 : 1;
  }
}
