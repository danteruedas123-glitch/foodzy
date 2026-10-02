class Env {
  /// Clave de Gemini en tiempo de compilación:
  /// `flutter run --dart-define=GEMINI_API_KEY=tu_clave`
  /// También se puede pegar desde Configuración dentro de la app.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Modelos multimodales para leer fotos y facturas, en orden de preferencia.
  /// Si uno está saturado o no existe, la app prueba el siguiente.
  static const List<String> geminiModelos = [
    'gemini-3.5-flash',
    'gemini-flash-lite-latest',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.1-flash-lite',
  ];

  /// Claves públicas de RevenueCat (Project settings → API keys):
  /// `--dart-define=REVENUECAT_ANDROID_KEY=goog_xxx`
  /// `--dart-define=REVENUECAT_IOS_KEY=appl_xxx`
  static const String revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const String revenueCatIosKey =
      String.fromEnvironment('REVENUECAT_IOS_KEY');

  /// Compras de mentira (no cobran nada) para probar Premium en tu celular:
  /// `--dart-define=COMPRAS_PRUEBA=true`. NO activar en la versión publicada.
  static const bool comprasDePrueba = bool.fromEnvironment('COMPRAS_PRUEBA');

  /// Nombre del "entitlement" que se crea en RevenueCat para Premium.
  static const String revenueCatEntitlement = 'premium';
}
