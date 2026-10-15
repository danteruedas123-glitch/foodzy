import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/fotos.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/alimentos/data/alimentos_db.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
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
  if (Nube.disponible && ref.watch(authProvider).esNube) {
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
      var items = await nube.obtenerTodos();

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

      // Cambios de otros miembros del hogar, en tiempo real. El primer evento
      // es la carga inicial, que ya tenemos.
      final sub = nube.flujo().skip(1).listen((l) => state = AsyncData(l));
      ref.onDispose(sub.cancel);
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

  Future<void> agregar(Alimento alimento) async {
    if (_enNube) {
      // Sin esperar al servidor: con mala señal el guardado en cadena (una
      // factura con varios productos) se quedaba trabado en el primero.
      final actual = state.value ?? const <Alimento>[];
      state = AsyncData([...actual.where((a) => a.id != alimento.id), alimento]);
      unawaited(_repo.guardar(alimento).catchError((_) {}));
      return;
    }
    await _repo.guardar(alimento);
    await recargar();
  }

  Future<void> actualizar(Alimento alimento) async {
    if (_enNube) {
      // El cambio se ve al instante; Firestore confirma después (con mala
      // señal la espera por el servidor dejaba la pantalla "congelada").
      final actual = state.value;
      if (actual != null) {
        state = AsyncData([for (final a in actual) a.id == alimento.id ? alimento : a]);
      }
      unawaited(_repo.guardar(alimento).catchError((_) {}));
      return;
    }
    await _repo.guardar(alimento);
    await recargar();
  }

  Future<void> eliminar(String id) async {
    if (_enNube) {
      final actual = state.value;
      if (actual != null) {
        state = AsyncData(actual.where((a) => a.id != id).toList());
      }
      unawaited(_repo.eliminar(id).catchError((_) {}));
      return;
    }
    await _repo.eliminar(id);
    await recargar();
  }

  /// Borra varios alimentos de una vez y limpia las fotos que queden sin uso.
  /// Devuelve cuántos se borraron.
  Future<int> eliminarVarios(Iterable<Alimento> aBorrar) async {
    final lista = aBorrar.toList();
    if (lista.isEmpty) return 0;
    for (final a in lista) {
      await _repo.eliminar(a.id);
    }
    final restantes = await _repo.obtenerTodos();
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
  final busqueda = ref.watch(searchQueryProvider).toLowerCase();
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
      if (busqueda.isEmpty) return true;
      return a.nombre.toLowerCase().contains(busqueda) ||
          a.categoria.toLowerCase().contains(busqueda);
    }).toList();
  });
});
