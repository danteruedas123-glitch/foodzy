import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/data/alimentos_db.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

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
}

final alimentosProvider =
    AsyncNotifierProvider<AlimentosNotifier, List<Alimento>>(
  AlimentosNotifier.new,
);

final searchQueryProvider = StateProvider<String>((ref) => '');

enum FiltroEstado { todos, disponibles, vencidos, otros }

final filtroEstadoProvider = StateProvider<FiltroEstado>((ref) => FiltroEstado.todos);

final alimentosFiltradosProvider = Provider<AsyncValue<List<Alimento>>>((ref) {
  final alimentosAsync = ref.watch(alimentosProvider);
  final searchQuery = ref.watch(searchQueryProvider).toLowerCase();
  final filtroEstado = ref.watch(filtroEstadoProvider);

  return alimentosAsync.whenData((alimentos) {
    return alimentos.where((alimento) {
      // Filtrar por estado
      final ahora = DateTime.now();
      bool pasaFiltroEstado = true;
      switch (filtroEstado) {
        case FiltroEstado.todos:
          break;
        case FiltroEstado.disponibles:
          pasaFiltroEstado = alimento.estado is Disponible && !alimento.estaVencido(ahora);
          break;
        case FiltroEstado.vencidos:
          pasaFiltroEstado = alimento.estado is Disponible && alimento.estaVencido(ahora);
          break;
        case FiltroEstado.otros:
          pasaFiltroEstado = alimento.estado is! Disponible;
          break;
      }

      if (!pasaFiltroEstado) return false;

      // Filtrar por búsqueda
      if (searchQuery.isEmpty) return true;
      return alimento.nombre.toLowerCase().contains(searchQuery) ||
             alimento.categoria.toLowerCase().contains(searchQuery);
    }).toList();
  });
});
