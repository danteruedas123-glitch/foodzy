import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:foodzy/core/firebase_opciones.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.userName,
    this.email,
    this.uid,
    this.fotoUrl,
  });

  final bool isAuthenticated;
  final String? userName;
  final String? email;

  /// Foto de perfil de la cuenta (por ejemplo, la de Google), si tiene.
  final String? fotoUrl;

  /// Id de la cuenta en Firebase; `null` en modo local.
  final String? uid;

  bool get esNube => uid != null;

  // Comparar por valor evita avisar a toda la app cuando Firebase vuelve a
  // emitir el mismo usuario (al suscribirse y al renovar la sesión cada hora).
  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      other.isAuthenticated == isAuthenticated &&
      other.userName == userName &&
      other.email == email &&
      other.uid == uid &&
      other.fotoUrl == fotoUrl;

  @override
  int get hashCode => Object.hash(isAuthenticated, userName, email, uid, fotoUrl);
}

/// Error de autenticación con un mensaje listo para mostrar.
class AuthError implements Exception {
  const AuthError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

String _traducir(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'El correo no es válido.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return 'Correo o contraseña incorrectos.';
    case 'email-already-in-use':
      return 'Ya existe una cuenta con ese correo.';
    case 'weak-password':
      return 'La contraseña es muy débil (mínimo 6 caracteres).';
    case 'user-disabled':
      return 'Esta cuenta está deshabilitada.';
    case 'too-many-requests':
      return 'Demasiados intentos. Espera un momento e inténtalo de nuevo.';
    case 'network-request-failed':
      return 'Sin conexión a internet.';
    case 'popup-blocked':
      return 'El navegador bloqueó la ventana de Google. Permite ventanas emergentes e intenta de nuevo.';
    case 'operation-not-allowed':
      return 'El acceso con correo no está activado en Firebase.';
    default:
      return 'No se pudo completar la acción (${e.code}).';
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _authKey = 'is_authenticated';
  static const _userNameKey = 'user_name';

  @override
  AuthState build() {
    if (Nube.disponible) return _construirNube();
    return _construirLocal();
  }

  /// Solo se avisa si algo cambió de verdad.
  @override
  bool updateShouldNotify(AuthState previous, AuthState next) => previous != next;

  // ── Modo nube (Firebase) ────────────────────────────────────────────────

  AuthState _construirNube() {
    final auth = FirebaseAuth.instance;
    final sub = auth.userChanges().listen((u) => state = _deUsuario(u));
    ref.onDispose(sub.cancel);
    return _deUsuario(auth.currentUser);
  }

  AuthState _deUsuario(User? u) {
    if (u == null) return const AuthState();
    final nombre = (u.displayName != null && u.displayName!.trim().isNotEmpty)
        ? u.displayName!.trim()
        : (u.email ?? 'Usuario').split('@').first;
    return AuthState(
      isAuthenticated: true,
      userName: nombre,
      email: u.email,
      uid: u.uid,
      fotoUrl: u.photoURL,
    );
  }

  // ── Modo local (simulado, como antes) ───────────────────────────────────

  AuthState _construirLocal() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AuthState(
      isAuthenticated: prefs.getBool(_authKey) ?? false,
      userName: prefs.getString(_userNameKey),
    );
  }

  // ── Acciones ────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    if (Nube.disponible) {
      try {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email.trim(), password: password);
      } on FirebaseAuthException catch (e) {
        throw AuthError(_traducir(e));
      }
      return;
    }
    await Future.delayed(const Duration(milliseconds: 600));
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_authKey, true);
    await prefs.setString(_userNameKey, email.split('@').first);
    state = AuthState(isAuthenticated: true, userName: email.split('@').first);
  }

  bool _googleListo = false;

  /// Entra (o crea la cuenta) con Google. Solo modo nube.
  /// Devuelve `false` si la persona cerró la ventana sin elegir cuenta.
  Future<bool> loginConGoogle() async {
    if (!Nube.disponible) {
      throw const AuthError('Entrar con Google requiere el modo nube.');
    }
    // En la web, Firebase abre su propia ventana de Google.
    if (kIsWeb) {
      try {
        await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
        return true;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
          return false;
        }
        throw AuthError(_traducir(e));
      }
    }
    try {
      final google = GoogleSignIn.instance;
      if (!_googleListo) {
        // En iPhone, Google necesita el id de cliente de iOS de Firebase.
        final iphone = defaultTargetPlatform == TargetPlatform.iOS &&
            FirebaseOpciones.iosClientId.isNotEmpty;
        await google.initialize(clientId: iphone ? FirebaseOpciones.iosClientId : null);
        _googleListo = true;
      }
      final cuenta = await google.authenticate();
      final idToken = cuenta.authentication.idToken;
      if (idToken == null) {
        throw const AuthError('Google no devolvió las credenciales. Intenta de nuevo.');
      }
      await FirebaseAuth.instance.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      throw AuthError('No se pudo entrar con Google (${e.code.name}).');
    } on FirebaseAuthException catch (e) {
      throw AuthError(_traducir(e));
    }
  }

  Future<void> register(String name, String email, String password) async {
    if (Nube.disponible) {
      try {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email.trim(), password: password);
        await cred.user?.updateDisplayName(name.trim());
        await cred.user?.reload();
        state = _deUsuario(FirebaseAuth.instance.currentUser);
      } on FirebaseAuthException catch (e) {
        throw AuthError(_traducir(e));
      }
      return;
    }
    await Future.delayed(const Duration(milliseconds: 600));
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_userNameKey, name);
    // En modo local no se inicia sesión: la pantalla vuelve al login.
  }

  /// Envía un correo para restablecer la contraseña (solo modo nube).
  Future<void> recuperarContrasena(String email) async {
    if (!Nube.disponible) {
      throw const AuthError('La recuperación de contraseña requiere el modo nube.');
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthError(_traducir(e));
    }
  }

  Future<void> logout() async {
    if (Nube.disponible) {
      await FirebaseAuth.instance.signOut();
      return;
    }
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_authKey);
    await prefs.remove(_userNameKey);
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
