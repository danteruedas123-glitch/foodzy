import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/compras/data/lista_compra_local.dart';
import 'package:foodzy/features/compras/domain/item_compra.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/nube/data/firestore_lista_compra.dart';
import 'package:foodzy/features/nube/hogar_provider.dart';

/// Dónde vive la lista: compartida con el hogar si hay cuenta en la nube, o
/// solo en este teléfono si no.
final listaCompraRepositoryProvider =
    FutureProvider<ListaCompraRepository>((ref) async {
  if (Nube.disponible && ref.watch(authProvider).esNube) {
    final hogar = await ref.watch(hogarProvider.future);
    if (hogar != null) return FirestoreListaCompraRepository(hogar.id);
  }
  return ListaCompraLocal(ref.watch(sharedPreferencesProvider));
});

class ListaCompraNotifier extends AsyncNotifier<List<ItemCompra>> {
  late ListaCompraRepository _repo;

  @override
  Future<List<ItemCompra>> build() async {
    _repo = await ref.watch(listaCompraRepositoryProvider.future);

    // Si otra persona del hogar cambia la lista, se actualiza sola.
    if (_repo case final FirestoreListaCompraRepository nube) {
      final sub = nube.cambios().skip(1).listen((_) => _recargar());
      ref.onDispose(sub.cancel);
    }
    return _ordenar(await _repo.obtener());
  }

  List<ItemCompra> _ordenar(List<ItemCompra> l) => l
    ..sort((a, b) {
      if (a.comprado != b.comprado) return a.comprado ? 1 : -1;
      return b.creado.compareTo(a.creado);
    });

  Future<void> _recargar() async {
    state = AsyncData(_ordenar(await _repo.obtener()));
  }

  /// Añade un producto; ignora duplicados que aún no se han comprado.
  Future<void> agregar(String nombre, {String? cantidad}) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return;
    final actuales = state.value ?? const <ItemCompra>[];
    final clave = claveNombre(limpio);
    if (actuales.any((i) => !i.comprado && claveNombre(i.nombre) == clave)) return;
    await _repo.guardar(ItemCompra(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: limpio,
      cantidad: cantidad,
      creado: DateTime.now(),
    ));
    await _recargar();
  }

  Future<void> alternar(ItemCompra item) async {
    await _repo.guardar(item.conComprado(!item.comprado));
    await _recargar();
  }

  Future<void> eliminar(String id) async {
    await _repo.eliminar(id);
    await _recargar();
  }

  Future<void> limpiarComprados() async {
    for (final i in (state.value ?? const <ItemCompra>[]).where((i) => i.comprado)) {
      await _repo.eliminar(i.id);
    }
    await _recargar();
  }

  /// Al registrar una compra, tacha de la lista lo que ya se compró.
  Future<int> marcarCompradosPorNombre(Iterable<String> nombres) async {
    final claves = nombres.map(claveNombre).toSet();
    var n = 0;
    for (final i in state.value ?? const <ItemCompra>[]) {
      if (!i.comprado && claves.contains(claveNombre(i.nombre))) {
        await _repo.guardar(i.conComprado(true));
        n++;
      }
    }
    if (n > 0) await _recargar();
    return n;
  }
}

final listaCompraProvider =
    AsyncNotifierProvider<ListaCompraNotifier, List<ItemCompra>>(
  ListaCompraNotifier.new,
);
