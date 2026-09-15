import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_alimentos.dart';
import 'package:foodzy/features/auth/presentation/pantallas/pantalla_login.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializamos SharedPreferences de forma asíncrona antes de arrancar
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const FoodzyApp(),
    ),
  );
}

class FoodzyApp extends ConsumerWidget {
  const FoodzyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    // Seleccionamos dinámicamente el TextTheme
    TextTheme currentTextTheme;
    switch (themeSettings.fontFamily) {
      case 'Lato':
        currentTextTheme = GoogleFonts.latoTextTheme();
        break;
      case 'Montserrat':
        currentTextTheme = GoogleFonts.montserratTextTheme();
        break;
      case 'Poppins':
        currentTextTheme = GoogleFonts.poppinsTextTheme();
        break;
      case 'Roboto':
      default:
        currentTextTheme = GoogleFonts.robotoTextTheme();
        break;
    }

    return MaterialApp(
      title: 'Foodzy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: themeSettings.primaryColor,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey.shade50,
        textTheme: currentTextTheme,
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
        ),
      ),
      home: authState.isAuthenticated
          ? const PantallaAlimentos()
          : const PantallaLogin(),
    );
  }
}
