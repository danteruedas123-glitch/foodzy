import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/env.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

/// Clave de Gemini: la guardada por el usuario manda sobre la de compilación.
class ApiKeyNotifier extends Notifier<String> {
  static const _key = 'gemini_api_key';

  @override
  String build() {
    final guardada = ref.watch(sharedPreferencesProvider).getString(_key);
    return (guardada != null && guardada.isNotEmpty)
        ? guardada
        : Env.geminiApiKey;
  }

  Future<void> guardar(String valor) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final limpia = valor.trim();
    if (limpia.isEmpty) {
      await prefs.remove(_key);
      state = Env.geminiApiKey;
    } else {
      await prefs.setString(_key, limpia);
      state = limpia;
    }
  }
}

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String>(
  ApiKeyNotifier.new,
);
