import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Proveedor de SharedPreferences (se sobreescribe en main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class ThemeSettings {
  ThemeSettings({
    required this.primaryColor,
    required this.fontFamily,
    this.themeMode = ThemeMode.system,
  });

  final Color primaryColor;
  final String fontFamily;
  final ThemeMode themeMode;

  ThemeSettings copyWith({
    Color? primaryColor,
    String? fontFamily,
    ThemeMode? themeMode,
  }) {
    return ThemeSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      fontFamily: fontFamily ?? this.fontFamily,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeSettings> {
  static const _colorKey = 'theme_color';
  static const _fontKey = 'theme_font';
  static const _modeKey = 'theme_mode';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final colorValue = prefs.getInt(_colorKey) ?? Colors.green.toARGB32();
    final fontName = prefs.getString(_fontKey) ?? 'Poppins';
    final modo = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_modeKey),
      orElse: () => ThemeMode.system,
    );

    return ThemeSettings(
      primaryColor: Color(colorValue),
      fontFamily: fontName,
      themeMode: modo,
    );
  }

  Future<void> changeColor(Color color) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_colorKey, color.toARGB32());
    state = state.copyWith(primaryColor: color);
  }

  Future<void> changeFont(String fontName) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_fontKey, fontName);
    state = state.copyWith(fontFamily: fontName);
  }

  Future<void> changeMode(ThemeMode modo) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_modeKey, modo.name);
    state = state.copyWith(themeMode: modo);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(
  ThemeNotifier.new,
);
