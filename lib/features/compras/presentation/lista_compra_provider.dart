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
  // Solo importa quién es la cuenta: no se reconstruye cuando Firebase
  // renueva la sesión (cada hora) ni cuando cambia el nombre o la foto.
  if (Nube.disponible && ref.watch(authProvider.select((a) => a.esNube))) {
    // Si la nube no responde (sin internet o base sin crear), se usa el teléfono.
    final hogar = await ref.watch(hogarProvider.future).then<Hogar?>((h) => h, onError: (_) => null);
    if (hogar != null) return FirestoreListaCompraRepository(hogar.id);
  }
  return ListaCompraLocal(ref.watch(sharedPreferencesProvider));
});

class ListaCompraNotifier extends AsyncNotifier<List<ItemCompra>> {
  late ListaCompraRepository _repo;

  bool get _enNube => _repo is FirestoreListaCompraRepository;

  @override
  Future<List<ItemCompra>> build() async {
    _repo = await ref.watch(listaCompraRepositoryProvider.future);

    // En la nube la lista llega por el flujo en tiempo real: el primer evento
    // es la carga inicial y los siguientes, los cambios de cualquier persona
    // del hogar. Cada evento ya trae la lista, así que no se vuelve a leer la
    // colección entera tras cada cambio.
    if (_repo case final FirestoreListaCompraRepository nube) {
      final inicial = Completer<List<ItemCompra>>();
      final sub = nube.flujo().listen(
        (l) {
          if (inicial.isCompleted) {
            state = AsyncData(_ordenar(l));
          } else {
            inicial.complete(_ordenar(l));
          }
        },
        onError: (Object e, StackTrace st) {
          if (!inicial.isCompleted) inicial.completeError(e, st);
        },
      );
      ref.onDispose(sub.cancel);
      return inicial.future;
    }
    return _ordenar(await _repo.obtener());
  }

  List<ItemCompra> _ordenar(List<ItemCompra> l) => l
    ..sort((a, b) {
      if (a.comprado != b.comprado) return a.comprado ? 1 : -1;
      return b.creado.compareTo(a.creado);
    });

  List<ItemCompra> get _actuales => state.value ?? const <ItemCompra>[];

  /// Aplica un cambio sin volver a leer la lista. En el teléfono se guarda y
  /// luego se muestra; en la nube se muestra al instante y Firestore confirma
  /// después (con mala señal, esperar al servidor congelaba la pantalla). Si
  /// la nube lo rechaza, el flujo en tiempo real devuelve la lista a como estaba.
  Future<void> _aplicar(
    List<ItemCompra> nueva,
    Future<void> Function() escribir,
  ) async {
    if (_enNube) {
      state = AsyncData(_ordenar(nueva));
      unawaited(escribir().catchError((Object _) {}));
      return;
    }
    await escribir();
    state = AsyncData(_ordenar(nueva));
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
    final actuales = _actuales;
    final clave = claveNombre(limpio);
    if (actuales.any((i) => !i.comprado && claveNombre(i.nombre) == clave)) return false;
    final item = ItemCompra(
      id: _nuevoId(),
      nombre: limpio,
      cantidad: cantidad,
      creado: DateTime.now(),
    );
    await _aplicar([...actuales, item], () => _repo.guardar(item));
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
    final cambiado = item.conComprado(!item.comprado);
    await _aplicar(
      [for (final i in _actuales) i.id == item.id ? cambiado : i],
      () => _repo.guardar(cambiado),
    );
  }

  Future<void> eliminar(String id) async {
    await _aplicar(
      _actuales.where((i) => i.id != id).toList(),
      () => _repo.eliminar(id),
    );
  }

  Future<void> limpiarComprados() async {
    final ids = [for (final i in _actuales) if (i.comprado) i.id];
    if (ids.isEmpty) return;
    await _aplicar(
      _actuales.where((i) => !i.comprado).toList(),
      () async {
        if (_repo case final FirestoreListaCompraRepository nube) {
          return nube.eliminarVarios(ids);
        }
        for (final id in ids) {
          await _repo.eliminar(id);
        }
      },
    );
  }

  /// Al registrar una compra, tacha de la lista lo que ya se compró.
  Future<int> marcarCompradosPorNombre(Iterable<String> nombres) async {
    final claves = nombres.map(claveNombre).toSet();
    final tachados = [
      for (final i in _actuales)
        if (!i.comprado && claves.contains(claveNombre(i.nombre))) i.conComprado(true),
    ];
    if (tachados.isEmpty) return 0;
    final porId = {for (final i in tachados) i.id: i};
    await _aplicar(
      [for (final i in _actuales) porId[i.id] ?? i],
      () async {
        if (_repo case final FirestoreListaCompraRepository nube) {
          return nube.guardarVarios(tachados);
        }
        for (final i in tachados) {
          await _repo.guardar(i);
        }
      },
    );
    return tachados.length;
  }
}

final listaCompraProvider =
    AsyncNotifierProvider<ListaCompraNotifier, List<ItemCompra>>(
  ListaCompraNotifier.new,
);
