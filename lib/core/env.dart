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
}
