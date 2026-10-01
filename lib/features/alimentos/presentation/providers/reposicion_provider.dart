import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

/// Un producto que se acabó y probablemente toque volver a comprar.
class SugerenciaReposicion {
  const SugerenciaReposicion({
    required this.clave,
    required this.alimento,
    required this.ultimaVez,
    required this.veces,
  });

  final String clave;

  /// El último registro consumido (sirve para mostrar nombre, foto, unidad).
  final Alimento alimento;
  final DateTime ultimaVez;

  /// Cuántas veces lo has consumido en tu historial.
  final int veces;
}

class ReposicionState {
  const ReposicionState({
    this.noRecomprar = const {},
    this.repuestoEn = const {},
  });

  /// Productos que la persona no quiere volver a comprar.
  final Set<String> noRecomprar;

  /// Cuándo marcó "ya lo compré" por producto.
  final Map<String, DateTime> repuestoEn;
}

class ReposicionNotifier extends Notifier<ReposicionState> {
  static const _kNo = 'repo_no_recomprar';
  static const _kRep = 'repo_repuesto';

  @override
  ReposicionState build() {
    final p = ref.watch(sharedPreferencesProvider);
    final no = p.getStringList(_kNo)?.toSet() ?? <String>{};
    var rep = <String, DateTime>{};
    try {
      final texto = p.getString(_kRep);
      if (texto != null) {
        final mapa = jsonDecode(texto) as Map<String, dynamic>;
        rep = {
          for (final e in mapa.entries)
            if (DateTime.tryParse(e.value.toString()) != null)
              e.key: DateTime.parse(e.value.toString()),
        };
      }
    } catch (_) {}
    return ReposicionState(noRecomprar: no, repuestoEn: rep);
  }

  Future<void> _guardar(ReposicionState nuevo) async {
    final p = ref.read(sharedPreferencesProvider);
    await p.setStringList(_kNo, nuevo.noRecomprar.toList());
    await p.setString(
      _kRep,
      jsonEncode(
          {for (final e in nuevo.repuestoEn.entries) e.key: e.value.toIso8601String()}),
    );
    state = nuevo;
  }

  /// "Ya lo compré": deja de sugerirse hasta que vuelva a acabarse.
  Future<void> yaLoCompre(String clave) => _guardar(ReposicionState(
        noRecomprar: state.noRecomprar,
        repuestoEn: {...state.repuestoEn, clave: DateTime.now()},
      ));

  /// "No volver a comprar": sale de las sugerencias y se borra su historial.
  Future<void> noVolverAComprar(String clave) async {
    await _guardar(ReposicionState(
      noRecomprar: {...state.noRecomprar, clave},
      repuestoEn: state.repuestoEn,
    ));
    final lista = ref.read(alimentosProvider).value ?? const <Alimento>[];
    final suyos = lista
        .where((a) => estaEnHistorial(a) && claveNombre(a.nombre) == clave);
    await ref.read(alimentosProvider.notifier).eliminarVarios(suyos);
  }

  /// Permite volver a recibir sugerencias de un producto.
  Future<void> reactivar(String clave) => _guardar(ReposicionState(
        noRecomprar: {...state.noRecomprar}..remove(clave),
        repuestoEn: state.repuestoEn,
      ));
}

final reposicionProvider =
    NotifierProvider<ReposicionNotifier, ReposicionState>(
  ReposicionNotifier.new,
);

/// Productos consumidos que ya no tienes en la despensa, más reciente primero.
final porReponerProvider = Provider<List<SugerenciaReposicion>>((ref) {
  final lista = ref.watch(alimentosProvider).value ?? const <Alimento>[];
  final r = ref.watch(reposicionProvider);

  final enDespensa = {
    for (final a in lista)
      if (a.estado is Disponible) claveNombre(a.nombre),
  };

  final ultimo = <String, Alimento>{};
  final veces = <String, int>{};
  for (final a in lista) {
    final estado = a.estado;
    if (estado is! Consumido) continue;
    final k = claveNombre(a.nombre);
    veces[k] = (veces[k] ?? 0) + 1;
    final previo = ultimo[k];
    if (previo == null ||
        (estado.fechaConsumo)
            .isAfter((previo.estado as Consumido).fechaConsumo)) {
      ultimo[k] = a;
    }
  }

  final salida = <SugerenciaReposicion>[];
  for (final e in ultimo.entries) {
    final k = e.key;
    final fecha = (e.value.estado as Consumido).fechaConsumo;
    if (enDespensa.contains(k)) continue;
    if (r.noRecomprar.contains(k)) continue;
    final repuesto = r.repuestoEn[k];
    if (repuesto != null && !repuesto.isBefore(fecha)) continue;
    salida.add(SugerenciaReposicion(
      clave: k,
      alimento: e.value,
      ultimaVez: fecha,
      veces: veces[k] ?? 1,
    ));
  }
  salida.sort((a, b) => b.ultimaVez.compareTo(a.ultimaVez));
  return salida;
});
