import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';
import 'package:foodzy/features/recetas/presentation/widgets/hoja_cocinar.dart';
import 'package:foodzy/features/recetas/presentation/widgets/receta_card.dart';

/// Recetas generadas por la IA a partir de lo que hay en la despensa. El
/// resultado se conserva al cambiar de pestaña.
class RecetasNotifier extends Notifier<AsyncValue<List<Receta>>?> {
  @override
  AsyncValue<List<Receta>>? build() => null;

  Future<void> generar() async {
    state = const AsyncValue.loading();
    final despensa = ref.read(alimentosProvider).value ?? const <Alimento>[];
    state = await AsyncValue.guard(
      () => ref.read(recetasServiceProvider).generar(despensa, cuantas: 4),
    );
  }
}

final recetasProvider =
    NotifierProvider<RecetasNotifier, AsyncValue<List<Receta>>?>(
  RecetasNotifier.new,
);

class PantallaRecetas extends ConsumerWidget {
  const PantallaRecetas({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estado = ref.watch(recetasProvider);
    final despensa = (ref.watch(alimentosProvider).value ?? const <Alimento>[])
        .where((a) => a.estado is Disponible)
        .toList();
    final urgentes = despensa.where((a) => venceEn(a, 3)).length;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          title: Text('Recetas',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('¿Qué cocino hoy?',
                      style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    despensa.isEmpty
                        ? 'Añade alimentos a tu despensa para recibir ideas.'
                        : urgentes > 0
                            ? 'La IA usará tus ${despensa.length} alimentos y priorizará los $urgentes que vencen pronto.'
                            : 'La IA armará recetas con tus ${despensa.length} alimentos.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary
                            .withValues(alpha: 0.9)),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: despensa.isEmpty || estado is AsyncLoading
                        ? null
                        : () => ref.read(recetasProvider.notifier).generar(),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.onPrimary,
                      foregroundColor: theme.colorScheme.primary,
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: Text(estado == null
                        ? 'Generar recetas'
                        : 'Generar otras'),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (estado == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _Mensaje('🥘', 'Toca el botón y te sugiero qué preparar.'),
          )
        else
          estado.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 44,
                        height: 44,
                        child: CircularProgressIndicator(strokeWidth: 4)),
                    SizedBox(height: 16),
                    Text('Creando recetas con tu despensa...'),
                  ],
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _Mensaje(
                  '😕', e is ScannerException ? e.mensaje : e.toString()),
            ),
            data: (recetas) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              sliver: SliverList.separated(
                itemCount: recetas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) =>
                    RecetaCard(
                  receta: recetas[i],
                  abierta: i == 0,
                  onCocinar: () => cocinarReceta(context, recetas[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Mensaje extends StatelessWidget {
  const _Mensaje(this.emoji, this.texto);
  final String emoji;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 10),
          Text(texto,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
