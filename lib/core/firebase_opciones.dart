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
  static const _iosApiKey = 'AIzaSyBLm7KWeGApvI9kgaqU7-M2JWzOz3zQnMs';
  static const _iosAppId = '1:235830420548:ios:34826c4873ab71ea9f0811';

  /// Para entrar con Google en iPhone. Su versión invertida va también en
  /// `ios/Runner/Info.plist` (CFBundleURLSchemes).
  static const iosClientId =
      '235830420548-0trukmeq0g8rito4j9mmjsb9008q02uh.apps.googleusercontent.com';
  static const iosBundleId = 'com.foodzy.app';

  // Web (bloque firebaseConfig): apiKey y appId.
  static const _webApiKey = 'AIzaSyC6OfZunrqQY-IGk1pjHDqIsN_fva8ngbk';
  static const _webAppId = '1:235830420548:web:04aceb117b94a8909f0811';

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
