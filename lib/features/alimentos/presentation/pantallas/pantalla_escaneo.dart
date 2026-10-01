import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/scanner_service.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/opciones_fecha.dart';
import 'package:image_picker/image_picker.dart';

enum ModoEscaneo {
  compra('Revisión de compra', 'La IA está identificando tus alimentos...'),
  factura('Revisión de factura', 'Leyendo los productos de tu factura...');

  const ModoEscaneo(this.titulo, this.cargando);
  final String titulo;
  final String cargando;
}

/// Analiza una foto (compra o factura) y deja revisar y editar lo detectado
/// antes de guardarlo en la despensa.
class PantallaEscaneo extends ConsumerStatefulWidget {
  const PantallaEscaneo({
    super.key,
    required this.imageFile,
    this.modo = ModoEscaneo.compra,
  });

  final XFile imageFile;
  final ModoEscaneo modo;

  @override
  ConsumerState<PantallaEscaneo> createState() => _PantallaEscaneoState();
}

class _PantallaEscaneoState extends ConsumerState<PantallaEscaneo> {
  List<AlimentoDetectado>? _items;
  bool _procesando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _procesar();
  }

  Future<void> _procesar() async {
    setState(() {
      _procesando = true;
      _error = null;
    });
    try {
      final scanner = ref.read(scannerServiceProvider);
      final r = widget.modo == ModoEscaneo.factura
          ? await scanner.analizarFactura(widget.imageFile)
          : await scanner.analizarCompra(widget.imageFile);
      if (!mounted) return;
      setState(() {
        _items = r;
        _procesando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ScannerException ? e.mensaje : e.toString();
        _procesando = false;
      });
    }
  }

  bool get _todosListos =>
      _items != null &&
      _items!.isNotEmpty &&
      !_items!.any((i) => i.alimento.sinFechaVencimiento);

  Future<void> _elegirFecha(int i) async {
    final actual = _items![i];
    final nuevo = await editarFechaAlimento(context, ref, actual.alimento);
    if (nuevo == null || !mounted) return;
    setState(() => _items![i] = AlimentoDetectado(alimento: nuevo));
  }

  Future<void> _guardar() async {
    final notifier = ref.read(alimentosProvider.notifier);
    var n = 0;
    for (final d in _items!) {
      final a = d.alimento;
      await notifier.agregar(Alimento(
        id: '${DateTime.now().microsecondsSinceEpoch}-${n++}',
        nombre: a.nombre,
        categoria: a.categoria,
        cantidad: a.cantidad,
        fechaVencimiento: a.fechaVencimiento,
        estado: a.estado,
        fotos: [widget.imageFile.path],
        origenFecha: a.origenFecha,
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se guardaron ${_items!.length} alimentos en tu despensa.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.modo.titulo)),
      body: Column(
        children: [
          _Vista(imagen: widget.imageFile),
          Expanded(child: _contenido(theme)),
        ],
      ),
      bottomNavigationBar: (_items != null && _items!.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: _todosListos ? _guardar : null,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(_todosListos
                      ? 'Guardar ${_items!.length} alimentos'
                      : 'Completa las fechas que faltan'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _contenido(ThemeData theme) {
    if (_procesando) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
                width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 4)),
            const SizedBox(height: 18),
            Text(widget.modo.cargando, style: theme.textTheme.titleSmall),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 52, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: _procesar,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items!.isEmpty) {
      return const Center(child: Text('No detecté ningún alimento en la imagen.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _FilaDetectada(
        item: _items![i],
        onFecha: () => _elegirFecha(i),
        onEliminar: () => setState(() => _items!.removeAt(i)),
      ),
    );
  }
}

class _Vista extends StatelessWidget {
  const _Vista({required this.imagen});
  final XFile imagen;

  @override
  Widget build(BuildContext context) {
    final provider = kIsWeb
        ? NetworkImage(imagen.path)
        : FileImage(File(imagen.path)) as ImageProvider;
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(image: provider, fit: BoxFit.cover),
      ),
    );
  }
}

class _FilaDetectada extends StatelessWidget {
  const _FilaDetectada({
    required this.item,
    required this.onFecha,
    required this.onEliminar,
  });

  final AlimentoDetectado item;
  final VoidCallback onFecha;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = item.alimento;
    final falta = a.sinFechaVencimiento;
    final color = falta ? theme.colorScheme.error : theme.colorScheme.primary;
    final valor = a.cantidad.valor == a.cantidad.valor.roundToDouble()
        ? a.cantidad.valor.toInt().toString()
        : a.cantidad.valor.toStringAsFixed(1);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: falta ? 0.6 : 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FotoAlimento(alimento: a, tamano: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.nombre,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('${a.categoria} · $valor ${a.cantidad.unidad}',
                      style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  ActionChip(
                    avatar: Icon(
                      falta
                          ? Icons.event_busy_rounded
                          : a.noVence
                              ? Icons.all_inclusive_rounded
                              : Icons.event_available_rounded,
                      size: 16,
                      color: color,
                    ),
                    label: Text(
                      falta
                          ? 'Falta la fecha — toca para ponerla'
                          : describirFecha(a),
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                    onPressed: onFecha,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Quitar',
              onPressed: onEliminar,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
