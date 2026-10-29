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

/// Letra con tilde → letra sin tilde, armado una sola vez.
final Map<int, int> _sinTilde = () {
  const de = 'áàäâéèëêíìïîóòöôúùüûñ';
  const a = 'aaaaeeeeiiiioooouuuun';
  return {for (var i = 0; i < de.length; i++) de.codeUnitAt(i): a.codeUnitAt(i)};
}();

final _espacios = RegExp(r'\s+');

/// Claves ya calculadas. Se piden muchas veces con los mismos nombres (en
/// cada tecla del buscador, por cada alimento), así que se recuerdan.
final _claves = <String, String>{};

/// Clave para reconocer "el mismo producto" aunque cambien mayúsculas,
/// tildes o espacios ("Leche  Deslactosada" == "leche deslactosada").
String claveNombre(String nombre) {
  final guardada = _claves[nombre];
  if (guardada != null) return guardada;
  if (_claves.length >= 2000) _claves.clear();
  final t = String.fromCharCodes(
    nombre.trim().toLowerCase().codeUnits.map((c) => _sinTilde[c] ?? c),
  ).replaceAll(_espacios, ' ');
  return _claves[nombre] = t;
}
