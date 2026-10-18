import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/notificaciones.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/auth/presentation/pantallas/pantalla_login.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/home/presentation/pantalla_principal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();
  await Nube.iniciar();
  await NotificacionesService.instancia.iniciar();

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

  ThemeData _tema(ThemeSettings s, Brightness brillo) {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: s.primaryColor,
        brightness: brillo,
      ),
      useMaterial3: true,
    );
    final textTheme = switch (s.fontFamily) {
      'Lato' => GoogleFonts.latoTextTheme(base.textTheme),
      'Montserrat' => GoogleFonts.montserratTextTheme(base.textTheme),
      'Roboto' => GoogleFonts.robotoTextTheme(base.textTheme),
      _ => GoogleFonts.poppinsTextTheme(base.textTheme),
    };
    final scheme = base.colorScheme;

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(themeProvider);
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'Foodzy',
      debugShowCheckedModeBanner: false,
      themeMode: s.themeMode,
      theme: _tema(s, Brightness.light),
      darkTheme: _tema(s, Brightness.dark),
      home: auth.isAuthenticated
          ? const PantallaPrincipal()
          : const PantallaLogin(),
    );
  }
}
