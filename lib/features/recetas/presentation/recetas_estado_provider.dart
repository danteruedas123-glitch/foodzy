import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

/// Gustos y restricciones al cocinar (dieta, alergias, tiempo).
class PreferenciasNotifier extends Notifier<PreferenciasCulinarias> {
  static const _key = 'recetas_preferencias';

  @override
  PreferenciasCulinarias build() {
    final t = ref.watch(sharedPreferencesProvider).getString(_key);
    if (t == null) return const PreferenciasCulinarias();
    try {
      return PreferenciasCulinarias.fromJson(jsonDecode(t) as Map<String, dynamic>);
    } catch (_) {
      return const PreferenciasCulinarias();
    }
  }

  Future<void> cambiar(PreferenciasCulinarias nuevas) async {
    await ref.read(sharedPreferencesProvider).setString(_key, jsonEncode(nuevas.toJson()));
    state = nuevas;
  }
}

final preferenciasProvider =
    NotifierProvider<PreferenciasNotifier, PreferenciasCulinarias>(PreferenciasNotifier.new);

/// Recetas guardadas con el corazón.
class FavoritasNotifier extends Notifier<List<Receta>> {
  static const _key = 'recetas_favoritas';

  @override
  List<Receta> build() {
    final t = ref.watch(sharedPreferencesProvider).getString(_key);
    if (t == null) return [];
    try {
      return [
        for (final r in jsonDecode(t) as List) Receta.fromJson(Map<String, dynamic>.from(r as Map)),
      ];
    } catch (_) {
      return [];
    }
  }

  bool esFavorita(Receta r) => state.any((f) => f.clave == r.clave);

  Future<void> alternar(Receta r) async {
    final nuevas = esFavorita(r)
        ? state.where((f) => f.clave != r.clave).toList()
        : [r, ...state];
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(nuevas.map((e) => e.toJson()).toList()));
    state = nuevas;
  }
}

final favoritasProvider =
    NotifierProvider<FavoritasNotifier, List<Receta>>(FavoritasNotifier.new);

/// Menú semanal generado por la IA; se conserva al cerrar la app.
class PlanSemanalNotifier extends Notifier<AsyncValue<List<DiaPlan>>?> {
  static const _key = 'plan_semanal';

  @override
  AsyncValue<List<DiaPlan>>? build() {
    final t = ref.read(sharedPreferencesProvider).getString(_key);
    if (t == null) return null;
    try {
      return AsyncData([
        for (final d in jsonDecode(t) as List) DiaPlan.fromJson(Map<String, dynamic>.from(d as Map)),
      ]);
    } catch (_) {
      return null;
    }
  }

  Future<void> generar() async {
    state = const AsyncLoading();
    final despensa = ref.read(alimentosProvider).value ?? const <Alimento>[];
    final prefs = ref.read(preferenciasProvider);
    state = await AsyncValue.guard(() async {
      final plan =
          await ref.read(recetasServiceProvider).planSemanal(despensa, preferencias: prefs);
      await ref
          .read(sharedPreferencesProvider)
          .setString(_key, jsonEncode(plan.map((d) => d.toJson()).toList()));
      return plan;
    });
  }
}

final planSemanalProvider =
    NotifierProvider<PlanSemanalNotifier, AsyncValue<List<DiaPlan>>?>(PlanSemanalNotifier.new);
