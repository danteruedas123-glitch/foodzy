import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/captura.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_detalle.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_escaneo.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_estadisticas.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_por_reponer.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_retiro.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/providers/reposicion_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/compras/presentation/pantalla_lista_compra.dart';

/// Pestaña "Inicio": resumen, accesos rápidos y lo que vence pronto.
class PantallaInicio extends ConsumerWidget {
  const PantallaInicio({
    super.key,
    required this.irADespensa,
    required this.irARecetas,
  });

  final VoidCallback irADespensa;
  final VoidCallback irARecetas;

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final nombre = ref.watch(authProvider).userName ?? 'chef';
    final async = ref.watch(alimentosProvider);

    final lista = async.value ?? const <Alimento>[];
    final porReponer = ref.watch(porReponerProvider);
    final disponibles = lista.where((a) => a.estado is Disponible).toList();
    final vencidos = disponibles.where((a) => venceEn(a, -1)).length;
    final porVencer =
        disponibles.where((a) => venceEn(a, 3) && !venceEn(a, -1)).length;
    final sanos = disponibles.length - vencidos - porVencer;

    final urgentes = disponibles.where((a) => venceEn(a, 7)).toList()
      ..sort((a, b) => a.fechaVencimiento.compareTo(b.fechaVencimiento));

    Future<void> abrir(Widget Function(dynamic img) pantalla) async {
      final img = await capturarImagen(context);
      if (img != null && context.mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla(img)));
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 24, 20, 28),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_saludo()},',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.85))),
                Text(nombre,
                    style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 22),
                Row(
                  children: [
                    _Stat('${disponibles.length}', 'En despensa', Icons.kitchen_rounded),
                    const SizedBox(width: 10),
                    _Stat('$porVencer', 'Por vencer', Icons.schedule_rounded),
                    const SizedBox(width: 10),
                    _Stat('$vencidos', 'Vencidos', Icons.warning_amber_rounded),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (porReponer.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Material(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PantallaPorReponer())),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Text('🛒', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                porReponer.length == 1
                                    ? '1 producto por reponer'
                                    : '${porReponer.length} productos por reponer',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                porReponer.take(3).map((s) => s.alimento.nombre).join(', ') +
                                    (porReponer.length > 3 ? '…' : ''),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (porVencer + vencidos > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Material(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: irARecetas,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Text('🍳', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                porVencer + vencidos == 1
                                    ? '1 alimento necesita tu atención'
                                    : '${porVencer + vencidos} alimentos necesitan tu atención',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text('Mira recetas para aprovecharlos a tiempo',
                                  style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 6),
            child: Text('Acciones rápidas',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Accion(
                  icono: Icons.shopping_basket_rounded,
                  texto: 'Compra',
                  color: const Color(0xFF16A34A),
                  onTap: () => abrir((img) => PantallaEscaneo(imageFile: img)),
                ),
                const SizedBox(width: 10),
                _Accion(
                  icono: Icons.receipt_long_rounded,
                  texto: 'Factura',
                  color: const Color(0xFF2563EB),
                  onTap: () => abrir(
                      (img) => PantallaEscaneo(imageFile: img, modo: ModoEscaneo.factura)),
                ),
                const SizedBox(width: 10),
                _Accion(
                  icono: Icons.outbox_rounded,
                  texto: 'Sacar',
                  color: const Color(0xFFEA580C),
                  onTap: () => abrir((img) => PantallaRetiro(imageFile: img)),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _Atajo(
                  emoji: '📝',
                  texto: 'Lista de compras',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PantallaListaCompra())),
                ),
                const SizedBox(width: 10),
                _Atajo(
                  emoji: '📊',
                  texto: 'Tus números',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PantallaEstadisticas())),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text('Vence pronto',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                TextButton(onPressed: irADespensa, child: const Text('Ver todo')),
              ],
            ),
          ),
        ),
        if (async.isLoading && lista.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (urgentes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 8),
                  Text(
                    sanos > 0
                        ? 'Nada vence esta semana. ¡Todo en orden!'
                        : 'Aún no hay alimentos. ¡Escanea tu primera compra!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 480,
                mainAxisExtent: 128,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: urgentes.length > 6 ? 6 : urgentes.length,
              itemBuilder: (context, i) => AlimentoCard(
                alimento: urgentes[i],
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PantallaDetalle(alimento: urgentes[i]))),
              ),
            ),
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.valor, this.etiqueta, this.icono);
  final String valor;
  final String etiqueta;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final onP = Theme.of(context).colorScheme.onPrimary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: onP.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: onP, size: 20),
            const SizedBox(height: 6),
            Text(valor,
                style: TextStyle(color: onP, fontSize: 26, fontWeight: FontWeight.w900)),
            Text(etiqueta,
                style: TextStyle(color: onP.withValues(alpha: 0.85), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.texto,
    required this.color,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color,
                  child: Icon(icono, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(texto, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Atajo extends StatelessWidget {
  const _Atajo({required this.emoji, required this.texto, required this.onTap});

  final String emoji;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(texto,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
