import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/fotos.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/alimentos/data/alimentos_db.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
import 'package:foodzy/features/alimentos/domain/busqueda.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/nube/data/firestore_alimentos.dart';
import 'package:foodzy/features/nube/hogar_provider.dart';

/// Dónde viven los alimentos: en Firestore (compartidos con el hogar) si hay
/// cuenta en la nube, o en la base local del teléfono si no.
final alimentosRepositoryProvider = FutureProvider<AlimentosRepository>((ref) async {
  // Solo importa si hay cuenta en la nube; el hogar ya cambia si cambia la
  // cuenta. Así no se reconstruye cuando Firebase renueva la sesión.
  if (Nube.disponible && ref.watch(authProvider.select((a) => a.esNube))) {
    // Si la nube no responde (sin internet o base sin crear), se usa el teléfono.
    final hogar = await ref.watch(hogarProvider.future).then<Hogar?>((h) => h, onError: (_) => null);
    if (hogar != null) return FirestoreAlimentosRepository(hogar.id);
  }
  return AlimentosDB.instance;
});

class AlimentosNotifier extends AsyncNotifier<List<Alimento>> {
  late AlimentosRepository _repo;

  bool get _enNube => _repo is FirestoreAlimentosRepository;

  @override
  Future<List<Alimento>> build() async {
    _repo = await ref.watch(alimentosRepositoryProvider.future);
    final prefs = ref.read(sharedPreferencesProvider);

    if (_repo case final FirestoreAlimentosRepository nube) {
      // El flujo en tiempo real trae la carga inicial (su primer evento) y
      // luego los cambios de otros miembros del hogar. Antes se leía además
      // la colección por separado, así que se descargaba dos veces.
      final inicial = Completer<List<Alimento>>();
      final sub = nube.flujo().listen(
        (l) {
          if (inicial.isCompleted) {
            state = AsyncData(l);
          } else {
            inicial.complete(l);
          }
        },
        onError: (Object e, StackTrace st) {
          if (!inicial.isCompleted) inicial.completeError(e, st);
        },
        // Si el flujo termina sin datos, se pide la lista una vez.
        onDone: () {
          if (!inicial.isCompleted) inicial.complete(nube.obtenerTodos());
        },
      );
      ref.onDispose(sub.cancel);
      var items = await inicial.future;

      // Primera vez con la cuenta: se sube lo que había en el teléfono.
      final marca = 'migrado_${ref.read(authProvider).uid}';
      if (items.isEmpty && !(prefs.getBool(marca) ?? false)) {
        try {
          final locales = await AlimentosDB.instance.obtenerTodos();
          if (locales.isNotEmpty) {
            await nube.guardarVarios(locales);
            items = locales;
          }
        } catch (_) {
          // Sin datos locales o sin acceso a la base local: nada que subir.
        }
        await prefs.setBool(marca, true);
      }
      return items;
    }

    final items = await _repo.obtenerTodos();
    if (items.isNotEmpty) {
      await prefs.setBool('semilla_demo', true);
      return items;
    }

    // Datos de muestra solo la primera vez que se abre la app, nunca después.
    if (prefs.getBool('semilla_demo') ?? false) return items;
    await prefs.setBool('semilla_demo', true);
    final ahora = DateTime.now();
    final dummies = [
      Alimento(
        id: 'dummy_1',
        nombre: 'Tomates Perita',
        categoria: 'Verduras',
        cantidad: const Cantidad(valor: 1, unidad: 'kg'),
        fechaVencimiento: ahora.add(const Duration(days: 7)),
        estado: Disponible(ahora),
        fotos: ['https://images.unsplash.com/photo-1592924357228-91a4daadcfea?w=400&q=80'],
      ),
      Alimento(
        id: 'dummy_2',
        nombre: 'Leche Deslactosada',
        categoria: 'Lácteos',
        cantidad: const Cantidad(valor: 1, unidad: 'L'),
        fechaVencimiento: ahora.add(const Duration(days: 20)),
        estado: Disponible(ahora),
        fotos: ['https://images.unsplash.com/photo-1550583724-b2692b85b150?w=400&q=80'],
      ),
      Alimento(
        id: 'dummy_3',
        nombre: 'Pan de Molde',
        categoria: 'Panadería',
        cantidad: const Cantidad(valor: 1, unidad: 'u'),
        fechaVencimiento: ahora.subtract(const Duration(days: 2)), // Vencido para probar
        estado: Disponible(ahora),
        fotos: ['https://images.unsplash.com/photo-1598373182133-52452f7691ef?w=400&q=80'],
      ),
    ];
    for (final d in dummies) {
      await _repo.guardar(d);
    }
    return _repo.obtenerTodos();
  }

  /// En local se vuelve a leer tras cada cambio; en la nube lo hace el flujo
  /// en tiempo real, así que no hace falta.
  Future<void> recargar() async {
    if (_enNube) return;
    state = await AsyncValue.guard(() => _repo.obtenerTodos());
  }

  Future<void> agregar(Alimento alimento) => guardarVarios([alimento]);

  Future<void> actualizar(Alimento alimento) => guardarVarios([alimento]);

  /// Añade o reemplaza varios alimentos de una vez (por ejemplo, todos los
  /// de una factura): una sola escritura y un solo cambio en pantalla, en vez
  /// de uno por alimento.
  Future<void> guardarVarios(Iterable<Alimento> alimentos) async {
    final lista = alimentos.toList();
    if (lista.isEmpty) return;

    if (_repo case final FirestoreAlimentosRepository nube) {
      // El cambio se ve al instante y Firestore confirma después: con mala
      // señal, esperar al servidor dejaba la pantalla "congelada" y el
      // guardado en cadena se quedaba trabado en el primero.
      final actual = state.value ?? const <Alimento>[];
      state = AsyncData(_conGuardados(actual, lista));
      final escritura =
          lista.length == 1 ? nube.guardar(lista.single) : nube.guardarVarios(lista);
      unawaited(escritura.catchError(_alFallarEnNube));
      return;
    }

    final repo = _repo;
    if (repo is AlimentosDB) {
      await repo.guardarVarios(lista);
    } else {
      for (final a in lista) {
        await repo.guardar(a);
      }
    }
    await _mostrarLocal((actual) => _conGuardados(actual, lista));
  }

  Future<void> eliminar(String id) async {
    if (_enNube) {
      final actual = state.value;
      if (actual != null) {
        state = AsyncData(actual.where((a) => a.id != id).toList());
      }
      unawaited(_repo.eliminar(id).catchError(_alFallarEnNube));
      return;
    }
    await _repo.eliminar(id);
    await _mostrarLocal((actual) => actual.where((a) => a.id != id).toList());
  }

  /// En el teléfono, después de guardar se actualiza la lista que ya está en
  /// memoria en vez de volver a leer y decodificar toda la base.
  Future<void> _mostrarLocal(List<Alimento> Function(List<Alimento>) cambio) async {
    final actual = state.value;
    if (actual == null) return recargar();
    state = AsyncData(cambio(actual));
  }

  /// [actual] con [nuevos] reemplazando a los de su mismo id (en su sitio) y
  /// los que no estaban, al final.
  static List<Alimento> _conGuardados(List<Alimento> actual, List<Alimento> nuevos) {
    final porId = {for (final a in nuevos) a.id: a};
    final reemplazados = [for (final a in actual) porId.remove(a.id) ?? a];
    return [...reemplazados, ...porId.values];
  }

  /// En la nube el cambio se muestra antes de que Firestore lo confirme. Si
  /// lo rechaza (por ejemplo, por las reglas de seguridad), se avisa y se
  /// vuelve a leer la despensa para no mostrar algo que no quedó guardado.
  Future<void> _alFallarEnNube(Object _) async {
    ref.read(avisoGuardadoProvider.notifier).state = AvisoGuardado(
      'No se pudo guardar el último cambio de tu despensa en la nube. '
      'Revisa que sigas en el hogar e inténtalo de nuevo.',
    );
    try {
      state = AsyncData(await _repo.obtenerTodos());
    } catch (_) {
      // Sin respuesta de la nube: el flujo en tiempo real la corregirá.
    }
  }

  /// Borra varios alimentos de una vez y limpia las fotos que queden sin uso.
  /// Devuelve cuántos se borraron.
  Future<int> eliminarVarios(Iterable<Alimento> aBorrar) async {
    final lista = aBorrar.toList();
    if (lista.isEmpty) return 0;
    final ids = {for (final a in lista) a.id};

    final repo = _repo;
    if (repo case final FirestoreAlimentosRepository nube) {
      // Una sola escritura, sin esperar al servidor (igual que los demás
      // cambios en la nube); si la rechaza, se avisa y se corrige.
      unawaited(nube.eliminarVarios(ids).catchError(_alFallarEnNube));
    } else if (repo is AlimentosDB) {
      await repo.eliminarVarios(ids);
    } else {
      for (final id in ids) {
        await repo.eliminar(id);
      }
    }

    // Lo que queda se calcula en memoria en vez de volver a leer todo.
    final antes = state.value ?? await repo.obtenerTodos();
    final restantes = antes.where((a) => !ids.contains(a.id)).toList();
    await borrarFotosHuerfanas(
      lista.expand((a) => a.fotos),
      restantes.expand((a) => a.fotos).toSet(),
    );
    state = AsyncValue.data(restantes);
    return lista.length;
  }

  /// Quita del historial lo consumido o desechado hace más de [dias] días.
  /// Con [dias] == 0 no hace nada (la persona eligió conservarlo todo).
  Future<int> limpiarHistorial(int dias) async {
    if (dias <= 0) return 0;
    final lista = state.value ?? await future;
    final limite = DateTime.now().subtract(Duration(days: dias));
    final viejos = lista.where((a) {
      final cierre = fechaDeCierre(a);
      return cierre != null && cierre.isBefore(limite);
    });
    return eliminarVarios(viejos);
  }
}

final alimentosProvider =
    AsyncNotifierProvider<AlimentosNotifier, List<Alimento>>(
  AlimentosNotifier.new,
);

/// Un aviso para la persona cuando la nube rechaza un cambio de la despensa.
/// No es `const`: cada fallo es un objeto distinto, así que dos fallos
/// seguidos con el mismo texto se avisan las dos veces.
class AvisoGuardado {
  AvisoGuardado(this.mensaje);
  final String mensaje;
}

/// El último aviso de guardado fallido. Lo muestra la pantalla de la despensa.
final avisoGuardadoProvider = StateProvider<AvisoGuardado?>((ref) => null);

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Filtros de la despensa. La despensa solo muestra lo que sigue disponible;
/// lo consumido y desechado vive en el historial.
enum FiltroEstado { todos, vigentes, vencidos }

final filtroEstadoProvider = StateProvider<FiltroEstado>((ref) => FiltroEstado.todos);

/// Filtro por dónde se guarda (nevera, congelador, alacena). null = todas.
final filtroUbicacionProvider = StateProvider<Ubicacion?>((ref) => null);

/// Alimentos que siguen en la despensa (disponibles, vigentes o vencidos).
final despensaActivaProvider = Provider<AsyncValue<List<Alimento>>>((ref) {
  return ref.watch(alimentosProvider).whenData(
        (lista) => lista.where((a) => a.estado is Disponible).toList(),
      );
});

/// Lo que ya salió de la despensa, lo más reciente primero.
final historialProvider = Provider<AsyncValue<List<Alimento>>>((ref) {
  return ref.watch(alimentosProvider).whenData((lista) {
    final h = lista.where(estaEnHistorial).toList()
      ..sort((a, b) => (fechaDeCierre(b) ?? b.fechaVencimiento)
          .compareTo(fechaDeCierre(a) ?? a.fechaVencimiento));
    return h;
  });
});

final alimentosFiltradosProvider = Provider<AsyncValue<List<Alimento>>>((ref) {
  final activos = ref.watch(despensaActivaProvider);
  final busqueda = ref.watch(searchQueryProvider);
  final filtro = ref.watch(filtroEstadoProvider);
  final ubicacion = ref.watch(filtroUbicacionProvider);

  return activos.whenData((alimentos) {
    final ahora = DateTime.now();
    return alimentos.where((a) {
      final pasa = switch (filtro) {
        FiltroEstado.todos => true,
        FiltroEstado.vigentes => !a.estaVencido(ahora) || a.sinFechaVencimiento,
        FiltroEstado.vencidos => a.estaVencido(ahora) && !a.sinFechaVencimiento,
      };
      if (!pasa) return false;
      if (ubicacion != null && a.ubicacion != ubicacion) return false;
      return coincideBusqueda(a, busqueda);
    }).toList();
  });
});
