import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';

class PantallaConfiguracion extends ConsumerWidget {
  const PantallaConfiguracion({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeSettings = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    final colores = [
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.redAccent,
    ];

    final fuentes = ['Roboto', 'Lato', 'Montserrat', 'Poppins'];

    // Alimento de muestra para la previsualización
    final alimentoMuestra = Alimento(
      id: 'muestra',
      nombre: 'Manzana Fuji',
      categoria: 'Frutas',
      cantidad: const Cantidad(valor: 1, unidad: 'kg'),
      fechaVencimiento: DateTime.now().add(const Duration(days: 5)),
      estado: Disponible(DateTime.now()),
      fotos: const [
        'https://images.unsplash.com/photo-1560806887-1e4cd0b6faa6?w=400&q=80',
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Visual')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Color Principal',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: colores.map((c) {
              final isSelected =
                  themeSettings.primaryColor.toARGB32() == c.toARGB32();
              return GestureDetector(
                onTap: () => themeNotifier.changeColor(c),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.black87, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Text(
            'Tipografía (Fuente)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: fuentes.map((f) {
              return ChoiceChip(
                label: Text(f),
                selected: themeSettings.fontFamily == f,
                onSelected: (selected) {
                  if (selected) themeNotifier.changeFont(f);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text(
            'Previsualización',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AbsorbPointer(
            child: AlimentoCard(alimento: alimentoMuestra, onTap: () {}),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pop(); // Regresar al home, que ahora será el Login
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade100,
              foregroundColor: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
