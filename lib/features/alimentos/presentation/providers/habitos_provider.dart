import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

/// Recuerda cuánto usa la persona de cada producto, para sugerirlo la próxima
/// vez que lo saque (ej. "siempre uso 45 g de Milo").
class HabitosNotifier extends Notifier<Map<String, double>> {
  static const _key = 'habitos_porcion';

  @override
  Map<String, double> build() {
    final texto = ref.watch(sharedPreferencesProvider).getString(_key);
    if (texto == null) return {};
    try {
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      return mapa.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static String _clave(String nombre, String unidad) =>
      '${nombre.trim().toLowerCase()}|$unidad';

  double? porcionHabitual(String nombre, String unidad) =>
      state[_clave(nombre, unidad)];

  Future<void> recordar(String nombre, String unidad, double cantidad) async {
    final nuevo = {...state, _clave(nombre, unidad): cantidad};
    state = nuevo;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(nuevo));
  }
}

final habitosProvider = NotifierProvider<HabitosNotifier, Map<String, double>>(
  HabitosNotifier.new,
);
