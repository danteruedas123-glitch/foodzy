import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/cargando_alimentos.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';
import 'package:foodzy/features/recetas/presentation/recetas_estado_provider.dart';
import 'package:foodzy/features/recetas/presentation/widgets/hoja_cocinar.dart';
import 'package:foodzy/features/recetas/presentation/widgets/receta_card.dart';

/// Recetas generadas por la IA a partir de lo que hay en la despensa. El
/// resultado se conserva al cambiar de pestaña.
class RecetasNotifier extends Notifier<AsyncValue<List<Receta>>?> {
  @override
  AsyncValue<List<Receta>>? build() => null;

  /// Pide recetas para la comida elegida; con "Cualquiera" trae de las tres
  /// para que luego se puedan filtrar sin volver a llamar a la IA.
  Future<void> generar() async {
    state = const AsyncValue.loading();
    final despensa = ref.read(alimentosProvider).value ?? const <Alimento>[];
    final prefs = ref.read(preferenciasProvider);
    final momento = ref.read(momentoProvider);
    state = await AsyncValue.guard(
      () => ref.read(recetasServiceProvider).generar(despensa,
          cuantas: momento == null ? 6 : 4, momento: momento, preferencias: prefs),
    );
  }
}

/// Comida del día por la que se filtran las recetas; `null` = cualquiera.
class MomentoNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void elegir(String? momento) => state = momento;
}

final momentoProvider =
    NotifierProvider<MomentoNotifier, String?>(MomentoNotifier.new);

final recetasProvider =
    NotifierProvider<RecetasNotifier, AsyncValue<List<Receta>>?>(
  RecetasNotifier.new,
);

enum _Vista { sugeridas, favoritas, plan }

class PantallaRecetas extends ConsumerStatefulWidget {
  const PantallaRecetas({super.key});

  @override
  ConsumerState<PantallaRecetas> createState() => _PantallaRecetasState();
}

class _PantallaRecetasState extends ConsumerState<PantallaRecetas> {
  _Vista _vista = _Vista.sugeridas;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = ref.watch(preferenciasProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          title: Text('Recetas',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'Mis preferencias',
              onPressed: () => _mostrarPreferencias(context),
              icon: Badge(
                isLabelVisible: prefs.hayRestricciones,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_Vista>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _Vista.sugeridas, label: Text('Sugeridas'), icon: Icon(Icons.auto_awesome_rounded)),
                ButtonSegment(value: _Vista.favoritas, label: Text('Favoritas'), icon: Icon(Icons.favorite_rounded)),
                ButtonSegment(value: _Vista.plan, label: Text('Semana'), icon: Icon(Icons.calendar_month_rounded)),
              ],
              selected: {_vista},
              onSelectionChanged: (s) => setState(() => _vista = s.first),
            ),
          ),
        ),
        switch (_vista) {
          _Vista.sugeridas => const _Sugeridas(),
          _Vista.favoritas => const _Favoritas(),
          _Vista.plan => const _Plan(),
        },
      ],
    );
  }

  void _mostrarPreferencias(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const _HojaPreferencias(),
    );
  }
}

// ── Sugeridas ──────────────────────────────────────────────────────────────

class _Sugeridas extends ConsumerWidget {
  const _Sugeridas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(recetasProvider);
    final favoritas = ref.watch(favoritasProvider);
    final despensa = (ref.watch(alimentosProvider).value ?? const <Alimento>[])
        .where((a) => a.estado is Disponible)
        .toList();
    final urgentes = despensa.where((a) => venceEn(a, 3)).length;
    final momento = ref.watch(momentoProvider);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              children: [
                for (final m in const [
                  (null, 'Cualquiera', '🍽️'),
                  ('Desayuno', 'Desayuno', '🥐'),
                  ('Almuerzo', 'Almuerzo', '☀️'),
                  ('Cena', 'Cena', '🌙'),
                ])
                  ChoiceChip(
                    label: Text('${m.$3} ${m.$2}'),
                    selected: momento == m.$1,
                    onSelected: (_) => ref.read(momentoProvider.notifier).elegir(m.$1),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _Cabecera(
              titulo: momento == null
                  ? '¿Qué cocino hoy?'
                  : '¿Qué preparo para ${momento == 'Cena' ? 'la' : 'el'} ${momento.toLowerCase()}?',
              texto: despensa.isEmpty
                  ? 'Añade alimentos a tu despensa para recibir ideas.'
                  : urgentes > 0
                      ? 'La IA usará tus ${despensa.length} alimentos y priorizará los $urgentes que vencen pronto.'
                      : 'La IA armará recetas con tus ${despensa.length} alimentos.',
              boton: estado == null ? 'Generar recetas' : 'Generar otras',
              onPressed: despensa.isEmpty || estado is AsyncLoading
                  ? null
                  : () => ref.read(recetasProvider.notifier).generar(),
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
              child: _Cargando('Creando recetas con tu despensa...'),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _Mensaje('😕', e is ScannerException ? e.mensaje : e.toString()),
            ),
            data: (todas) {
              final recetas = momento == null
                  ? todas
                  : todas.where((r) => r.momento == momento).toList();
              if (recetas.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _Mensaje('🍳',
                      'No hay recetas de ${momento?.toLowerCase()} entre las sugeridas.\nToca "Generar otras" y te traigo algunas.'),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                sliver: SliverList.separated(
                  itemCount: recetas.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => RecetaCard(
                    receta: recetas[i],
                    abierta: i == 0,
                    favorita: favoritas.any((f) => f.clave == recetas[i].clave),
                    onFavorita: () => ref.read(favoritasProvider.notifier).alternar(recetas[i]),
                    onCocinar: () => cocinarReceta(context, recetas[i]),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ── Favoritas ──────────────────────────────────────────────────────────────

class _Favoritas extends ConsumerWidget {
  const _Favoritas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritas = ref.watch(favoritasProvider);
    if (favoritas.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _Mensaje('💛', 'Aún no tienes favoritas.\nToca "Guardar en favoritas" en una receta que te guste.'),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      sliver: SliverList.separated(
        itemCount: favoritas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => RecetaCard(
          receta: favoritas[i],
          favorita: true,
          onFavorita: () => ref.read(favoritasProvider.notifier).alternar(favoritas[i]),
          onCocinar: () => cocinarReceta(context, favoritas[i]),
        ),
      ),
    );
  }
}

// ── Plan semanal ───────────────────────────────────────────────────────────

class _Plan extends ConsumerWidget {
  const _Plan();

  Future<void> _verReceta(BuildContext context, WidgetRef ref, ComidaPlan c) async {
    final despensa = ref.read(alimentosProvider).value ?? const <Alimento>[];
    final prefs = ref.read(preferenciasProvider);
    final mensajero = ScaffoldMessenger.of(context);
    mensajero.showSnackBar(SnackBar(
      content: Text('Preparando la receta de ${c.titulo}...'),
      duration: const Duration(seconds: 40),
    ));
    try {
      final receta = await ref
          .read(recetasServiceProvider)
          .detallar(c.titulo, despensa, preferencias: prefs);
      mensajero.hideCurrentSnackBar();
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        constraints: const BoxConstraints(maxWidth: 560),
        builder: (ctx) => Consumer(
          builder: (ctx, ref, _) {
            final fav = ref.watch(favoritasProvider).any((f) => f.clave == receta.clave);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: RecetaCard(
                receta: receta,
                abierta: true,
                favorita: fav,
                onFavorita: () => ref.read(favoritasProvider.notifier).alternar(receta),
                onCocinar: () => cocinarReceta(context, receta),
              ),
            );
          },
        ),
      );
    } catch (e) {
      mensajero.hideCurrentSnackBar();
      mensajero.showSnackBar(
          SnackBar(content: Text(e is ScannerException ? e.mensaje : e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final estado = ref.watch(planSemanalProvider);
    final hayDespensa = (ref.watch(alimentosProvider).value ?? const <Alimento>[])
        .any((a) => a.estado is Disponible);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _Cabecera(
              titulo: 'Tu menú de la semana',
              texto: 'Almuerzo y cena de 7 días, aprovechando primero lo que vence antes.',
              boton: estado == null ? 'Armar mi menú' : 'Armar otro menú',
              onPressed: !hayDespensa || estado is AsyncLoading
                  ? null
                  : () => ref.read(planSemanalProvider.notifier).generar(),
            ),
          ),
        ),
        if (estado == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _Mensaje('🗓️', 'Te armo un menú completo con lo que tienes.'),
          )
        else
          estado.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: _Cargando('Planeando tu semana...'),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _Mensaje('😕', e is ScannerException ? e.mensaje : e.toString()),
            ),
            data: (plan) => SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              sliver: SliverList.separated(
                itemCount: plan.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan[i].dia,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      for (final c in plan[i].comidas)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Text(c.momento.toLowerCase().startsWith('c') ? '🌙' : '☀️'),
                          ),
                          title: Text(c.titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${c.momento} · ${c.descripcion}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _verReceta(context, ref, c),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Piezas comunes ─────────────────────────────────────────────────────────

class _Cabecera extends StatelessWidget {
  const _Cabecera({
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onPressed,
  });

  final String titulo;
  final String texto;
  final String boton;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
          Text(titulo,
              style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(texto,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.9))),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.onPrimary,
              foregroundColor: theme.colorScheme.primary,
            ),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(boton),
          ),
        ],
      ),
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CargandoAlimentos(),
            const SizedBox(height: 16),
            Text(texto),
          ],
        ),
      );
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
          Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _HojaPreferencias extends ConsumerStatefulWidget {
  const _HojaPreferencias();

  @override
  ConsumerState<_HojaPreferencias> createState() => _HojaPreferenciasState();
}

class _HojaPreferenciasState extends ConsumerState<_HojaPreferencias> {
  late final TextEditingController _alergias;

  @override
  void initState() {
    super.initState();
    _alergias = TextEditingController(text: ref.read(preferenciasProvider).alergias);
  }

  @override
  void dispose() {
    _alergias.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = ref.watch(preferenciasProvider);
    final n = ref.read(preferenciasProvider.notifier);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tus preferencias',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('La IA las respeta en todas las recetas y menús.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Text('Tipo de alimentación', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final d in PreferenciasCulinarias.dietas)
                ChoiceChip(
                  label: Text(d),
                  selected: p.dieta == d,
                  onSelected: (_) => n.cambiar(p.copyWith(dieta: d)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Alergias o lo que no comes', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _alergias,
            decoration: const InputDecoration(hintText: 'Ej. maní, mariscos'),
            onChanged: (v) => n.cambiar(p.copyWith(alergias: v)),
          ),
          const SizedBox(height: 16),
          Text('Tiempo máximo de preparación', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final t in const [0, 15, 30, 45, 60])
                ChoiceChip(
                  label: Text(t == 0 ? 'Sin límite' : '$t min'),
                  selected: p.tiempoMax == t,
                  onSelected: (_) => n.cambiar(p.copyWith(tiempoMax: t)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
