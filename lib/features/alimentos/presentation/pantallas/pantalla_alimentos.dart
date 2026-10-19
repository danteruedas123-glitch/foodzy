import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_detalle.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_historial.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';

/// Pestaña "Despensa": todos los alimentos con búsqueda y filtros.
class PantallaAlimentos extends ConsumerStatefulWidget {
  const PantallaAlimentos({super.key});

  @override
  ConsumerState<PantallaAlimentos> createState() => _PantallaAlimentosState();
}

class _PantallaAlimentosState extends ConsumerState<PantallaAlimentos> {
  final _busqueda = TextEditingController();

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  static const _etiquetas = {
    FiltroEstado.todos: 'Todos',
    FiltroEstado.vigentes: 'Vigentes',
    FiltroEstado.vencidos: 'Vencidos',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alimentos = ref.watch(alimentosFiltradosProvider);
    final filtro = ref.watch(filtroEstadoProvider);

    // Si la nube rechaza un cambio, se avisa aquí. También se ve sobre el
    // detalle y "Sacar comida", que se abren encima de esta pantalla.
    ref.listen(avisoGuardadoProvider, (_, aviso) {
      if (aviso == null) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(aviso.mensaje)));
    });

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          title: Text('Mi despensa',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: 'Historial',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PantallaHistorial()),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              controller: _busqueda,
              hintText: 'Buscar alimento o categoría...',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor:
                  WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHigh),
              trailing: [
                if (_busqueda.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _busqueda.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                      setState(() {});
                    },
                  ),
              ],
              onChanged: (v) {
                ref.read(searchQueryProvider.notifier).state = v;
                setState(() {});
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in FiltroEstado.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_etiquetas[f]!),
                      selected: filtro == f,
                      onSelected: (_) =>
                          ref.read(filtroEstadoProvider.notifier).state = f,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todas las ubicaciones'),
                    selected: ref.watch(filtroUbicacionProvider) == null,
                    onSelected: (_) =>
                        ref.read(filtroUbicacionProvider.notifier).state = null,
                  ),
                ),
                for (final u in Ubicacion.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${u.emoji} ${u.etiqueta}'),
                      selected: ref.watch(filtroUbicacionProvider) == u,
                      onSelected: (_) =>
                          ref.read(filtroUbicacionProvider.notifier).state = u,
                    ),
                  ),
              ],
            ),
          ),
        ),
        alimentos.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Error al cargar:\n$e')),
          ),
          data: (lista) {
            if (lista.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _Vacio(hayFiltro: _busqueda.text.isNotEmpty || filtro != FiltroEstado.todos),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 480,
                  mainAxisExtent: 128,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final a = lista[i];
                  return AlimentoCard(
                    alimento: a,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PantallaDetalle(alimento: a)),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.hayFiltro});
  final bool hayFiltro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(hayFiltro ? '🔍' : '🧺', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          Text(
            hayFiltro ? 'Nada coincide con tu búsqueda' : 'Tu despensa está vacía',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            hayFiltro
                ? 'Prueba con otro filtro o término.'
                : 'Toca “Escanear” para añadir tu primera compra.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
