import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/presentation/providers/reposicion_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';

/// Lista de compras inteligente: lo que consumiste y ya no tienes.
class PantallaPorReponer extends ConsumerWidget {
  const PantallaPorReponer({super.key});

  String _hace(DateTime f) {
    final d = DateTime.now().difference(f).inDays;
    if (d <= 0) return 'hoy';
    if (d == 1) return 'ayer';
    return 'hace $d días';
  }

  Future<void> _noVolver(
      BuildContext context, WidgetRef ref, SugerenciaReposicion s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿No volver a comprar ${s.alimento.nombre}?'),
        content: const Text(
            'Dejará de sugerirse y se borrará su historial. Si lo escaneas otra vez, volverá a aparecer normalmente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, quitarlo')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(reposicionProvider.notifier).noVolverAComprar(s.clave);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lista = ref.watch(porReponerProvider);
    final notifier = ref.read(reposicionProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Por reponer')),
      body: lista.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✅', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 10),
                    Text('No falta nada por reponer',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(
                      'Cuando consumas un producto por completo, te lo sugerimos aquí para tu próxima compra.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              itemCount: lista.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final s = lista[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FotoAlimento(alimento: s.alimento, tamano: 52),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.alimento.nombre,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800)),
                                Text(
                                  'Se acabó ${_hace(s.ultimaVez)}'
                                  '${s.veces > 1 ? ' · lo has consumido ${s.veces} veces' : ''}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: () => notifier.yaLoCompre(s.clave),
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Ya lo compré'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => _noVolver(context, ref, s),
                            child: Text('No volver a comprar',
                                style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
