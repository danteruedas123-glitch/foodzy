import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/formato.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';
import 'package:foodzy/features/recetas/domain/descuento_receta.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

/// Pregunta si se va a cocinar la receta y, si se acepta, descuenta de la
/// despensa los ingredientes usados. Devuelve `true` si se descontó algo.
Future<bool> cocinarReceta(BuildContext context, Receta receta) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _HojaCocinar(receta: receta),
  );
  return ok ?? false;
}

class _Linea {
  _Linea(this.alimento, this.cantidad);
  final Alimento alimento;
  double cantidad;
  bool activa = true;

  double get total => alimento.cantidad.valor;
  String get unidad => alimento.cantidad.unidad;
}

class _HojaCocinar extends ConsumerStatefulWidget {
  const _HojaCocinar({required this.receta});
  final Receta receta;

  @override
  ConsumerState<_HojaCocinar> createState() => _HojaCocinarState();
}

class _HojaCocinarState extends ConsumerState<_HojaCocinar> {
  late final List<_Linea> _lineas;
  late final List<String> _sinMedir;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final despensa = {
      for (final a in ref.read(alimentosProvider).value ?? const <Alimento>[])
        if (a.estado is Disponible) a.id: a,
    };

    final descuento = calcularDescuento(widget.receta, despensa);
    _lineas = [
      for (final d in descuento.lineas) _Linea(d.alimento, d.cantidad),
    ];
    _sinMedir = descuento.sinMedir;
  }

  void _poner(_Linea l, double v) {
    final paso = pasoPara(l.unidad, l.total);
    var x = v.clamp(paso <= l.total ? paso : l.total, l.total).toDouble();
    x = (x / paso).round() * paso;
    if (x > l.total) x = l.total;
    setState(() => l.cantidad = double.parse(x.toStringAsFixed(3)));
  }

  Future<void> _confirmar() async {
    final activas = _lineas.where((l) => l.activa && l.cantidad > 0).toList();
    setState(() => _guardando = true);
    final notifier = ref.read(alimentosProvider.notifier);
    for (final l in activas) {
      final a = l.alimento;
      final restante = double.parse((l.total - l.cantidad).toStringAsFixed(3));
      if (restante <= 0.0001) {
        await notifier.actualizar(a.copyWith(estado: Consumido(DateTime.now())));
      } else {
        await notifier.actualizar(
          a.copyWith(cantidad: Cantidad(valor: restante, unidad: a.cantidad.unidad)),
        );
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(activas.isNotEmpty);
    if (activas.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '¡Buen provecho! Descontaste ${activas.length} ingrediente(s) de tu despensa.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faltan = widget.receta.faltantes;
    final hayActivas = _lineas.any((l) => l.activa && l.cantidad > 0);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cocinar “${widget.receta.titulo}”',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              _lineas.isEmpty
                  ? 'Esta receta no usa cantidades medibles de tu despensa.'
                  : 'Esto se descontará de tu despensa. Ajusta lo que realmente uses:',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final l in _lineas) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: l.activa
                        ? scheme.primary.withValues(alpha: 0.4)
                        : scheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: l.activa,
                      onChanged: (v) => setState(() => l.activa = v ?? false),
                    ),
                    FotoAlimento(alimento: l.alimento, tamano: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.alimento.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            l.cantidad >= l.total - 0.0001
                                ? 'Se acaba (tienes ${fmtCantidad(l.total, l.unidad)})'
                                : 'Tienes ${fmtCantidad(l.total, l.unidad)} · quedarán ${fmtCantidad(l.total - l.cantidad, l.unidad)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: l.activa
                          ? () => _poner(l, l.cantidad - pasoPara(l.unidad, l.total))
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        fmtCantidad(l.cantidad, l.unidad),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton.filledTonal(
                      visualDensity: VisualDensity.compact,
                      onPressed: l.activa
                          ? () => _poner(l, l.cantidad + pasoPara(l.unidad, l.total))
                          : null,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_sinMedir.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'No se descuenta (cantidad no medible): ${_sinMedir.join(', ')}.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (faltan.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Te falta conseguir: ${faltan.map((f) => f.nombre).join(', ')}.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _guardando
                  ? null
                  : (hayActivas || _lineas.isEmpty)
                      ? _confirmar
                      : null,
              icon: const Icon(Icons.restaurant_rounded),
              label: Text(_lineas.isEmpty
                  ? 'Listo'
                  : 'Sí, la voy a cocinar y descontar'),
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _guardando
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Ahora no'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
