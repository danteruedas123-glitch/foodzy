import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/historial.dart';
import 'package:foodzy/features/alimentos/presentation/providers/reposicion_provider.dart';
import 'package:foodzy/features/compras/domain/item_compra.dart';
import 'package:foodzy/features/compras/presentation/lista_compra_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Lista de compras con casillas, sugerencias de lo que se acabó y botón para
/// compartirla por WhatsApp u otra app.
class PantallaListaCompra extends ConsumerStatefulWidget {
  const PantallaListaCompra({super.key});

  @override
  ConsumerState<PantallaListaCompra> createState() => _PantallaListaCompraState();
}

class _PantallaListaCompraState extends ConsumerState<PantallaListaCompra> {
  final _nuevo = TextEditingController();

  @override
  void dispose() {
    _nuevo.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final t = _nuevo.text;
    if (t.trim().isEmpty) return;
    _nuevo.clear();
    await ref.read(listaCompraProvider.notifier).agregar(t);
  }

  Future<void> _compartir(List<ItemCompra> items) async {
    final pendientes = items.where((i) => !i.comprado).toList();
    if (pendientes.isEmpty) return;
    final texto = StringBuffer('🛒 Lista de compras (Foodzy)\n\n');
    for (final i in pendientes) {
      texto.writeln('• ${i.nombre}${i.cantidad != null ? ' (${i.cantidad})' : ''}');
    }
    await SharePlus.instance.share(ShareParams(text: texto.toString().trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lista = ref.watch(listaCompraProvider);
    final items = lista.value ?? const <ItemCompra>[];
    final notifier = ref.read(listaCompraProvider.notifier);

    // Sugerencias: lo que se acabó y todavía no está en la lista.
    final enLista = {for (final i in items) if (!i.comprado) claveNombre(i.nombre)};
    final sugerencias =
        ref.watch(porReponerProvider).where((s) => !enLista.contains(s.clave)).toList();

    final pendientes = items.where((i) => !i.comprado).toList();
    final comprados = items.where((i) => i.comprado).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            onPressed: pendientes.isEmpty ? null : () => _compartir(items),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          if (comprados.isNotEmpty)
            IconButton(
              tooltip: 'Quitar los comprados',
              onPressed: notifier.limpiarComprados,
              icon: const Icon(Icons.cleaning_services_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          TextField(
            controller: _nuevo,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _agregar(),
            decoration: InputDecoration(
              hintText: 'Añadir un producto...',
              prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
              suffixIcon: IconButton(
                onPressed: _agregar,
                icon: const Icon(Icons.add_circle_rounded),
              ),
            ),
          ),
          if (sugerencias.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Se te acabó', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in sugerencias.take(10))
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: Text(s.alimento.nombre),
                    onPressed: () => notifier.agregar(s.alimento.nombre),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (lista.isLoading && items.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('📝', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text('Tu lista está vacía', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Añade productos arriba o toca una sugerencia.', textAlign: TextAlign.center),
                ],
              ),
            ),
          for (final i in pendientes) _Fila(item: i),
          if (comprados.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Comprados', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final i in comprados) _Fila(item: i),
          ],
        ],
      ),
    );
  }
}

class _Fila extends ConsumerWidget {
  const _Fila({required this.item});
  final ItemCompra item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(listaCompraProvider.notifier);
    return Dismissible(
      key: ValueKey('compra_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_rounded, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => notifier.eliminar(item.id),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: item.comprado,
        onChanged: (_) => notifier.alternar(item),
        title: Text(
          item.nombre,
          style: TextStyle(
            decoration: item.comprado ? TextDecoration.lineThrough : null,
            color: item.comprado ? theme.colorScheme.outline : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: item.cantidad == null ? null : Text(item.cantidad!),
      ),
    );
  }
}
