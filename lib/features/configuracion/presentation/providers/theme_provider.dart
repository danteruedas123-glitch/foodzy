import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Proveedor de SharedPreferences (se sobreescribe en main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class ThemeSettings {
  ThemeSettings({required this.primaryColor, required this.fontFamily});

  final Color primaryColor;
  final String fontFamily;

  ThemeSettings copyWith({Color? primaryColor, String? fontFamily}) {
    return ThemeSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeSettings> {
  static const _colorKey = 'theme_color';
  static const _fontKey = 'theme_font';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    // Cargar valores guardados o usar valores por defecto
    final colorValue = prefs.getInt(_colorKey) ?? Colors.green.toARGB32();
    final fontName = prefs.getString(_fontKey) ?? 'Roboto';

    return ThemeSettings(primaryColor: Color(colorValue), fontFamily: fontName);
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
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeSettings>(
  ThemeNotifier.new,
);
