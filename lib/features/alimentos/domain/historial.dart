import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// `true` si el alimento ya no está en la despensa (se consumió o desechó).
bool estaEnHistorial(Alimento a) => a.estado is! Disponible;

/// Cuándo salió de la despensa. `null` si sigue disponible.
DateTime? fechaDeCierre(Alimento a) => switch (a.estado) {
      Consumido(:final fechaConsumo) => fechaConsumo,
      Desechado(:final fecha) => fecha ?? a.fechaVencimiento,
      Disponible() => null,
    };

/// Clave para reconocer "el mismo producto" aunque cambien mayúsculas,
/// tildes o espacios ("Leche  Deslactosada" == "leche deslactosada").
String claveNombre(String nombre) {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiiooooUuuun';
  var t = nombre.trim().toLowerCase();
  final b = StringBuffer();
  for (final c in t.split('')) {
    final i = de.indexOf(c);
    if (i >= 0) {
      final r = a[i];
      b.write(r == 'U' ? 'u' : r);
    } else {
      b.write(c);
    }
  }
  t = b.toString().replaceAll(RegExp(r'\s+'), ' ');
  return t;
}
