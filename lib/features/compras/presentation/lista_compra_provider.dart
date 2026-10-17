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
    // Si la nube no responde (sin internet o base sin crear), se usa el teléfono.
    final hogar = await ref.watch(hogarProvider.future).then<Hogar?>((h) => h, onError: (_) => null);
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

  int _ultimoId = 0;

  /// Un id por producto, distinto incluso si se añaden varios seguidos.
  String _nuevoId() {
    var t = DateTime.now().microsecondsSinceEpoch;
    if (t <= _ultimoId) t = _ultimoId + 1;
    _ultimoId = t;
    return t.toString();
  }

  /// Añade un producto; ignora duplicados que aún no se han comprado.
  /// Devuelve `true` si lo añadió.
  Future<bool> agregar(String nombre, {String? cantidad}) async {
    final limpio = nombre.trim();
    if (limpio.isEmpty) return false;
    final actuales = state.value ?? const <ItemCompra>[];
    final clave = claveNombre(limpio);
    if (actuales.any((i) => !i.comprado && claveNombre(i.nombre) == clave)) return false;
    await _repo.guardar(ItemCompra(
      id: _nuevoId(),
      nombre: limpio,
      cantidad: cantidad,
      creado: DateTime.now(),
    ));
    await _recargar();
    return true;
  }

  /// Añade varios productos (por ejemplo, lo que le falta a una receta).
  /// Devuelve cuántos eran nuevos; los que ya estaban en la lista se omiten.
  Future<int> agregarVarios(
    Iterable<({String nombre, String? cantidad})> productos,
  ) async {
    await future; // Que la lista ya esté cargada, para detectar repetidos.
    var nuevos = 0;
    for (final p in productos) {
      if (await agregar(p.nombre, cantidad: p.cantidad)) nuevos++;
    }
    return nuevos;
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
