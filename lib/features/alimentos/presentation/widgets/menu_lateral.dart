import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/pantallas/pantalla_configuracion.dart';

class MenuLateral extends ConsumerWidget {
  const MenuLateral({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final userName = authState.userName ?? 'Usuario';
    final inicial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.tertiary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            accountName: Text(
              '¡Bienvenido a Foodzy, $userName!',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: const Text('Tu despensa inteligente'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: Text(
                inicial,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: theme.colorScheme.primary),
                  title: const Text('Apariencia y Diseños', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Cambiar estilos y colores'),
                  onTap: () {
                    Navigator.of(context).pop(); // Cerrar drawer
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PantallaConfiguracion()),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.language, color: theme.colorScheme.primary),
                  title: const Text('Idioma', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Español (Predeterminado)'),
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La función de idioma está en desarrollo.')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                  title: const Text('Datos Personales', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Actualizar tu información'),
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('La actualización de datos requiere conexión a base de datos (Próximamente).')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                  title: const Text('Cambiar Contraseña', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Esta opción requiere configuración de correo segura (Próximamente).')),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.error)),
                  onTap: () {
                    Navigator.of(context).pop(); // Cerrar drawer
                    ref.read(authProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
