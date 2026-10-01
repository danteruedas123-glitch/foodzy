import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

/// Cuántos días se conserva el historial (consumido o desechado).
/// 0 significa "conservarlo siempre".
class HistorialDiasNotifier extends Notifier<int> {
  static const _key = 'historial_dias';

  @override
  int build() => ref.watch(sharedPreferencesProvider).getInt(_key) ?? 90;

  Future<void> cambiar(int dias) async {
    await ref.read(sharedPreferencesProvider).setInt(_key, dias);
    state = dias;
  }
}

final historialDiasProvider =
    NotifierProvider<HistorialDiasNotifier, int>(HistorialDiasNotifier.new);
