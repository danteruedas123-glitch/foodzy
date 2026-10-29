import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:foodzy/core/firebase_opciones.dart';

/// Estado de la conexión con Firebase.
///
/// La app funciona de dos formas:
/// - **Modo nube**: hay un proyecto de Firebase configurado (`google-services.json`
///   en Android; en iPhone y web, `firebase_opciones.dart`). Hay cuentas
///   reales, copia de seguridad y hogar compartido.
/// - **Modo local**: sin Firebase. Todo vive en el teléfono, como antes.
class Nube {
  Nube._();

  /// `true` si Firebase se inició correctamente.
  static bool disponible = false;

  /// Intenta iniciar Firebase. Si el proyecto no está configurado, la app
  /// sigue en modo local sin romperse.
  static Future<void> iniciar() async {
    final opciones = FirebaseOpciones.actual;
    if (opciones == null && FirebaseOpciones.necesariaAqui) {
      disponible = false;
      debugPrint('Firebase aún no está configurado para esta plataforma; se usa el modo local.');
      return;
    }
    try {
      await Firebase.initializeApp(options: opciones);
      disponible = true;
    } catch (e) {
      disponible = false;
      debugPrint('Firebase no está configurado; se usa el modo local. ($e)');
    }
  }
}
