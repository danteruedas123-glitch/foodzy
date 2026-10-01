import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';

/// Lo que ya salió de la despensa: consumido o desechado. Se puede borrar
/// uno a uno (deslizando) o todo de una vez; además se limpia solo con el
/// tiempo según lo elegido en Ajustes.
class PantallaHistorial extends ConsumerWidget {
  const PantallaHistorial({super.key});

  Future<void> _borrarTodo(
      BuildContext context, WidgetRef ref, List<Alimento> lista) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todo el historial?'),
        content: Text(
            'Se eliminarán ${lista.length} registros de alimentos ya consumidos o desechados. Tu despensa actual no se toca.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(alimentosProvider.notifier).eliminarVarios(lista);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historial = ref.watch(historialProvider);
    final lista = historial.value ?? const <Alimento>[];
    final consumidos = lista.where((a) => a.estado is Consumido).length;
    final desechados = lista.length - consumidos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          if (lista.isNotEmpty)
            IconButton(
              tooltip: 'Borrar todo',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: () => _borrarTodo(context, ref, lista),
            ),
        ],
      ),
      body: historial.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lista) {
          if (lista.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📭', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 10),
                    Text('Aún no hay historial',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      'Cuando consumas o deseches un alimento, aparecerá aquí.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            itemCount: lista.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Row(
                  children: [
                    Expanded(
                        child: _Dato('$consumidos', 'Consumidos',
                            const Color(0xFF3B82F6))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Dato('$desechados', 'Desechados',
                            const Color(0xFF78716C))),
                  ],
                );
              }
              final a = lista[i - 1];
              return Dismissible(
                key: ValueKey('hist_${a.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(Icons.delete_rounded,
                      color: theme.colorScheme.onErrorContainer),
                ),
                onDismissed: (_) =>
                    ref.read(alimentosProvider.notifier).eliminarVarios([a]),
                child: AlimentoCard(alimento: a),
              );
            },
          );
        },
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.valor, this.etiqueta, this.color);
  final String valor;
  final String etiqueta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valor,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, color: color)),
          Text(etiqueta, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
