class Env {
  /// Modelos multimodales para leer fotos y facturas, en orden de preferencia.
  /// Si uno está saturado o no existe, la app prueba el siguiente.
  ///
  /// Primero los Flash-Lite: una factura larga obliga a escribir mucho (40
  /// productos ≈ 4.500 tokens) y en eso son varias veces más rápidos (8,8 s
  /// medidos contra más de 40 s de gemini-3.8-flash). Los Flash quedan de
  /// respaldo. Solo nombres estables de la lista oficial de Google
  /// (ai.google.dev/gemini-api/docs/models): nada de alias "-latest", que
  /// Google cambia de modelo sin avisar.
  static const List<String> geminiModelos = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.8-flash',
  ];

  /// Para respuestas cortas (leer una fecha impresa pequeña, estimar cuánto
  /// dura un producto). Antes iban primero los Flash, que leen un poco mejor,
  /// pero por Firebase AI Logic con la cuota gratuita (medido el 2026-11-17)
  /// gemini-3.6-flash responde "sin cupo" y gemini-3.8-flash tarda más de 30 s,
  /// mientras que los Flash-Lite leyeron bien la fecha de prueba en ~1 s.
  /// Los Flash quedan de respaldo.
  static const List<String> geminiModelosPrecisos = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.6-flash',
    'gemini-3.8-flash',
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
