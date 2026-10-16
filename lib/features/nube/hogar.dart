/// El grupo (familia, pareja, compañeros) que comparte una despensa.
class Hogar {
  const Hogar({required this.id, required this.codigo, required this.miembros});

  final String id;

  /// Código corto que se comparte para invitar a otra persona.
  final String codigo;
  final int miembros;
}

class HogarError implements Exception {
  const HogarError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Dónde se guardan los hogares: Firestore en la app, memoria en las pruebas.
abstract interface class HogarRepository {
  /// El hogar asignado a [uid], o `null` si no tiene o ya no es miembro.
  Future<Hogar?> hogarDe(String uid);

  /// Crea un hogar nuevo con [uid] como único miembro y se lo asigna.
  Future<Hogar> crear({required String uid, String? nombre, String? email});

  /// El id del hogar al que invita [codigo], o `null` si no existe.
  Future<String?> hogarIdPorCodigo(String codigo);

  Future<void> agregarMiembro(String hogarId, String uid);
  Future<void> quitarMiembro(String hogarId, String uid);

  /// Guarda cuál es el hogar actual de [uid].
  Future<void> asignar(String uid, String hogarId);
}

/// Copia la despensa de un hogar a otro.
typedef CopiarDespensa = Future<void> Function(String desdeHogarId, String haciaHogarId);

/// Reglas para entrar, salir y crear hogares. No sabe nada de Firebase.
class HogarService {
  HogarService(this._repo);

  final HogarRepository _repo;

  /// El hogar de la persona; si no tiene, le crea uno propio.
  Future<Hogar> asegurar({required String uid, String? nombre, String? email}) async =>
      await _repo.hogarDe(uid) ?? await _repo.crear(uid: uid, nombre: nombre, email: email);

  /// Une a [uid] al hogar de [codigo] y lo saca de [actual].
  ///
  /// Si algo falla después de entrar al hogar nuevo, se deshace la entrada y
  /// la persona queda como estaba, en vez de quedar en dos hogares a la vez.
  /// Con [copiar] lleva la despensa del hogar actual al nuevo.
  Future<void> unirse({
    required String uid,
    required Hogar actual,
    required String codigo,
    CopiarDespensa? copiar,
  }) async {
    final limpio = codigo.trim().toUpperCase();
    if (limpio.length < 4) throw const HogarError('Escribe el código completo.');

    final nuevoId = await _repo.hogarIdPorCodigo(limpio);
    if (nuevoId == null) {
      throw const HogarError('Ese código no existe. Revísalo con quien te invitó.');
    }
    if (nuevoId == actual.id) throw const HogarError('Ya perteneces a ese hogar.');

    // Se entra primero al hogar nuevo (lo permiten las reglas de seguridad).
    await _repo.agregarMiembro(nuevoId, uid);
    try {
      if (copiar != null) await copiar(actual.id, nuevoId);
      await _repo.asignar(uid, nuevoId);
    } catch (_) {
      try {
        await _repo.quitarMiembro(nuevoId, uid);
      } catch (_) {
        // Si tampoco se puede deshacer, el error de abajo sigue siendo cierto.
      }
      throw const HogarError(
          'No pude unirte al hogar. Todo quedó como estaba; intenta de nuevo.');
    }

    // Ya se está en el hogar nuevo. Si salir del anterior falla, no se
    // revierte nada: la persona ya usa el hogar nuevo.
    try {
      await _repo.quitarMiembro(actual.id, uid);
    } catch (_) {}
  }

  /// Saca a [uid] del hogar [actual] y le crea uno propio, vacío.
  ///
  /// Si es la única persona del hogar no hay de qué salir: devuelve [actual]
  /// sin crear nada, para no dejar hogares abandonados.
  Future<Hogar> salir({
    required String uid,
    required Hogar actual,
    String? nombre,
    String? email,
  }) async {
    if (actual.miembros <= 1) return actual;

    final nuevo = await _repo.crear(uid: uid, nombre: nombre, email: email);
    try {
      await _repo.quitarMiembro(actual.id, uid);
    } catch (_) {
      // Ya tiene su hogar propio asignado; ver el comentario de [unirse].
    }
    return nuevo;
  }
}
