import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

class AuthState {
  final bool isAuthenticated;
  final String? userName;

  AuthState({this.isAuthenticated = false, this.userName});
}

class AuthNotifier extends Notifier<AuthState> {
  static const _authKey = 'is_authenticated';
  static const _userNameKey = 'user_name';

  @override
  AuthState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isAuth = prefs.getBool(_authKey) ?? false;
    final userName = prefs.getString(_userNameKey);
    return AuthState(isAuthenticated: isAuth, userName: userName);
  }

  Future<void> login(String email, String password) async {
    // Simulación de retraso de red
    await Future.delayed(const Duration(seconds: 1));

    // Aquí iría la lógica real de Firebase/Supabase
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_authKey, true);
    await prefs.setString(_userNameKey, email.split('@').first);
    state = AuthState(isAuthenticated: true, userName: email.split('@').first);
  }

  Future<void> register(String name, String email, String password) async {
    // Simulación de retraso de red
    await Future.delayed(const Duration(seconds: 1));

    // Aquí se guardaría el usuario en la BD.
    // Por ahora solo guardamos el nombre sugerido para el login futuro si se desea.
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_userNameKey, name);

    // NOTA: NO cambiamos el estado a autenticado para que la UI
    // redirija al login.
  }

  Future<void> logout() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_authKey);
    await prefs.remove(_userNameKey);
    state = AuthState(isAuthenticated: false, userName: null);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
