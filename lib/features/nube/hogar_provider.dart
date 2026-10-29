import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/nube/data/firestore_alimentos.dart';
import 'package:foodzy/features/nube/data/firestore_hogar.dart';
import 'package:foodzy/features/nube/hogar.dart';

// Quien importa este archivo sigue teniendo `Hogar` y `HogarError`.
export 'package:foodzy/features/nube/hogar.dart' show Hogar, HogarError;

final hogarRepositoryProvider =
    Provider<HogarRepository>((ref) => FirestoreHogarRepository());

final hogarServiceProvider =
    Provider<HogarService>((ref) => HogarService(ref.watch(hogarRepositoryProvider)));

/// Hogar de la persona con sesión iniciada. Cada cuenta nueva tiene el suyo
/// propio; puede unirse al de otra persona con un código.
class HogarNotifier extends AsyncNotifier<Hogar?> {
  HogarService get _servicio => ref.read(hogarServiceProvider);

  @override
  Future<Hogar?> build() async {
    // Solo depende de qué cuenta es: cambiar el nombre o la foto, o que
    // Firebase renueve la sesión, no vuelve a consultar el hogar.
    final uid = ref.watch(authProvider.select((a) => a.uid));
    if (!Nube.disponible || uid == null) return null;
    final auth = ref.read(authProvider);
    return _servicio
        .asegurar(uid: uid, nombre: auth.userName, email: auth.email)
        .timeout(const Duration(seconds: 15));
  }

  /// Une a la persona al hogar de [codigo]. Con [copiarMisDatos] lleva su
  /// despensa actual al hogar nuevo.
  Future<void> unirse(String codigo, {bool copiarMisDatos = false}) async {
    final auth = ref.read(authProvider);
    final actual = state.value;
    if (!auth.esNube || actual == null) throw const HogarError('Inicia sesión primero.');

    await _servicio.unirse(
      uid: auth.uid!,
      actual: actual,
      codigo: codigo,
      copiar: copiarMisDatos ? _copiarDespensa : null,
    );

    ref.invalidateSelf();
    await future;
  }

  static Future<void> _copiarDespensa(String desdeHogarId, String haciaHogarId) async {
    final viejos = await FirestoreAlimentosRepository(desdeHogarId).obtenerTodos();
    await FirestoreAlimentosRepository(haciaHogarId).guardarVarios(viejos);
  }

  /// Cambia el código de invitación (solo el dueño). El anterior deja de servir.
  Future<void> cambiarCodigo() async {
    final actual = state.value;
    if (actual == null) return;
    state = AsyncData(await _servicio.cambiarCodigo(actual));
  }

  /// Sale del hogar compartido y vuelve a tener uno propio, vacío.
  Future<void> salir() async {
    final auth = ref.read(authProvider);
    final actual = state.value;
    if (!auth.esNube || actual == null) return;

    state = AsyncData(await _servicio.salir(
      uid: auth.uid!,
      actual: actual,
      nombre: auth.userName,
      email: auth.email,
    ));
  }
}

final hogarProvider = AsyncNotifierProvider<HogarNotifier, Hogar?>(HogarNotifier.new);
