import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:foodzy/core/env.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave de Gemini que el usuario guardó, leída al abrir la app con
/// [ApiKeyNotifier.cargar]; `null` si no hay ninguna.
final claveGeminiGuardadaProvider = Provider<String?>((ref) => null);

/// Clave de Gemini: la guardada por el usuario manda sobre la de compilación.
///
/// Se guarda cifrada (AES-GCM con la llave en el Android Keystore; Keychain en
/// iPhone), nunca en SharedPreferences: ese archivo es texto plano y se lee
/// con root o desde una copia de seguridad (hallazgo de seguridad H-02).
class ApiKeyNotifier extends Notifier<String> {
  static const _key = 'gemini_api_key';
  static const _almacen = FlutterSecureStorage();

  /// Lee la clave del almacenamiento seguro. Si quedó una de una versión
  /// anterior en SharedPreferences, la pasa al almacenamiento seguro y la borra.
  static Future<String?> cargar(SharedPreferences prefs) async {
    try {
      final antigua = prefs.getString(_key);
      if (antigua != null) {
        if (antigua.isNotEmpty) await _almacen.write(key: _key, value: antigua);
        await prefs.remove(_key);
      }
      return await _almacen.read(key: _key);
    } catch (e) {
      // Llave del Keystore perdida (p. ej. datos restaurados en otro teléfono):
      // se descarta y el usuario vuelve a pegar su clave.
      debugPrint('No se pudo leer la clave guardada: $e');
      await _almacen.delete(key: _key).catchError((_) {});
      return null;
    }
  }

  @override
  String build() {
    final guardada = ref.watch(claveGeminiGuardadaProvider);
    return (guardada != null && guardada.isNotEmpty)
        ? guardada
        : Env.geminiApiKey;
  }

  Future<void> guardar(String valor) async {
    final limpia = valor.trim();
    if (limpia.isEmpty) {
      await _almacen.delete(key: _key);
      state = Env.geminiApiKey;
    } else {
      await _almacen.write(key: _key, value: limpia);
      state = limpia;
    }
  }
}

final apiKeyProvider = NotifierProvider<ApiKeyNotifier, String>(
  ApiKeyNotifier.new,
);
