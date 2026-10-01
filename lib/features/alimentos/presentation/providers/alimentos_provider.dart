import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/fotos.dart';
import 'package:foodzy/features/alimentos/data/alimentos_db.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';

import 'package:foodzy/features/alimentos/domain/cantidad.dart';

final alimentosRepositoryProvider = Provider<AlimentosRepository>((ref) {
  return AlimentosDB.instance;
});

class AlimentosNotifier extends AsyncNotifier<List<Alimento>> {
  @override
  Future<List<Alimento>> build() async {
    final repo = ref.read(alimentosRepositoryProvider);
    final items = await repo.obtenerTodos();
    
    if (items.isEmpty) {
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

      for (var d in dummies) {
        await repo.guardar(d);
      }
      return repo.obtenerTodos();
    }
    
    return items;
  }

  Future<void> recargar() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(alimentosRepositoryProvider).obtenerTodos();
    });
  }

  Future<void> agregar(Alimento alimento) async {
    await ref.read(alimentosRepositoryProvider).guardar(alimento);
    await recargar();
  }

  Future<void> actualizar(Alimento alimento) async {
    await ref.read(alimentosRepositoryProvider).guardar(alimento);
    await recargar();
  }

  Future<void> eliminar(String id) async {
    await ref.read(alimentosRepositoryProvider).eliminar(id);
    await recargar();
  }

  /// Borra varios alimentos de una vez y limpia las fotos que queden sin uso.
  /// Devuelve cuántos se borraron.
  Future<int> eliminarVarios(Iterable<Alimento> aBorrar) async {
    final lista = aBorrar.toList();
    if (lista.isEmpty) return 0;
    final repo = ref.read(alimentosRepositoryProvider);
    for (final a in lista) {
      await repo.eliminar(a.id);
    }
    final restantes = await repo.obtenerTodos();
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

  return activos.whenData((alimentos) {
    final ahora = DateTime.now();
    return alimentos.where((a) {
      final pasa = switch (filtro) {
        FiltroEstado.todos => true,
        FiltroEstado.vigentes => !a.estaVencido(ahora) || a.sinFechaVencimiento,
        FiltroEstado.vencidos => a.estaVencido(ahora) && !a.sinFechaVencimiento,
      };
      if (!pasa) return false;
      if (busqueda.isEmpty) return true;
      return a.nombre.toLowerCase().contains(busqueda) ||
          a.categoria.toLowerCase().contains(busqueda);
    }).toList();
  });
});
