import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuración de Firebase para iPhone y web.
///
/// En Android el plugin la lee de `android/app/google-services.json`. En
/// iPhone y en web va aquí, sacada de la consola de Firebase (proyecto
/// `fooddzy`): la de iPhone, del `GoogleService-Info.plist`; la de web, del
/// bloque `firebaseConfig`. No son datos secretos: Firebase los incluye en
/// toda app, y lo que protege los datos son las reglas de Firestore.
///
/// Mientras una plataforma no tenga su configuración, usa el modo local.
abstract final class FirebaseOpciones {
  static const _proyecto = 'fooddzy';
  static const _remitente = '235830420548';
  static const _bucket = 'fooddzy.firebasestorage.app';

  // iPhone (GoogleService-Info.plist): API_KEY, GOOGLE_APP_ID y CLIENT_ID.
  static const _iosApiKey = '';
  static const _iosAppId = '';

  /// Para entrar con Google en iPhone. Su versión invertida va también en
  /// `ios/Runner/Info.plist` (CFBundleURLSchemes).
  static const iosClientId = '';
  static const iosBundleId = 'com.foodzy.app';

  // Web (bloque firebaseConfig): apiKey y appId.
  static const _webApiKey = '';
  static const _webAppId = '';

  static bool get _esIphone => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// `true` si esta plataforma necesita la configuración de este archivo.
  static bool get necesariaAqui => kIsWeb || _esIphone;

  /// La configuración de esta plataforma; `null` en Android (usa
  /// google-services.json) o si aún no se ha completado.
  static FirebaseOptions? get actual {
    if (kIsWeb) {
      if (_webAppId.isEmpty) return null;
      return const FirebaseOptions(
        apiKey: _webApiKey,
        appId: _webAppId,
        messagingSenderId: _remitente,
        projectId: _proyecto,
        authDomain: '$_proyecto.firebaseapp.com',
        storageBucket: _bucket,
      );
    }
    if (_esIphone) {
      if (_iosAppId.isEmpty) return null;
      return FirebaseOptions(
        apiKey: _iosApiKey,
        appId: _iosAppId,
        messagingSenderId: _remitente,
        projectId: _proyecto,
        storageBucket: _bucket,
        iosBundleId: iosBundleId,
        iosClientId: iosClientId.isEmpty ? null : iosClientId,
      );
    }
    return null;
  }
}
