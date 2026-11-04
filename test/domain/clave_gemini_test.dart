import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // Hallazgo de seguridad H-02: la clave no puede quedar en SharedPreferences.
  group('clave de Gemini en almacenamiento seguro', () {
    test('una clave antigua en SharedPreferences pasa al almacenamiento seguro '
        'y se borra de SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'gemini_api_key': 'clave-de-prueba'});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final cargada = await ApiKeyNotifier.cargar(prefs);

      expect(cargada, 'clave-de-prueba');
      expect(prefs.getString('gemini_api_key'), isNull);
      expect(
        await const FlutterSecureStorage().read(key: 'gemini_api_key'),
        'clave-de-prueba',
      );
    });

    test('guardar escribe en el almacenamiento seguro, nunca en SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final contenedor = ProviderContainer();
      addTearDown(contenedor.dispose);

      await contenedor.read(apiKeyProvider.notifier).guardar('  nueva-clave  ');

      expect(contenedor.read(apiKeyProvider), 'nueva-clave');
      expect(prefs.getKeys(), isEmpty);
      expect(
        await const FlutterSecureStorage().read(key: 'gemini_api_key'),
        'nueva-clave',
      );
    });
  });
}
