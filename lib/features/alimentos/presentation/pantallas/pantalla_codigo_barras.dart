import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/formato.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/codigo_barras_service.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/scanner_service.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/opciones_fecha.dart';
import 'package:foodzy/features/compras/presentation/lista_compra_provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Escanea códigos de barras en serie: cada producto se busca en Open Food
/// Facts, se confirma en una hoja y se guarda; luego se sigue con el siguiente.
class PantallaCodigoBarras extends ConsumerStatefulWidget {
  const PantallaCodigoBarras({super.key});

  @override
  ConsumerState<PantallaCodigoBarras> createState() =>
      _PantallaCodigoBarrasState();
}

class _PantallaCodigoBarrasState extends ConsumerState<PantallaCodigoBarras> {
  final MobileScannerController _controlador = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _ocupado = false;
  int _agregados = 0;
  String? _ultimoCodigo;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _alDetectar(BarcodeCapture captura) async {
    if (_ocupado) return;
    final codigo =
        captura.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (codigo == null || codigo == _ultimoCodigo) return;
    await _procesar(codigo);
  }

  Future<void> _procesar(String codigo) async {
    setState(() => _ocupado = true);
    HapticFeedback.mediumImpact();

    ProductoCodigo? producto;
    String? aviso;
    try {
      producto = await ref.read(codigoBarrasServiceProvider).buscar(codigo);
      if (producto == null) {
        aviso = 'No encontré este código en la base de datos. Complétalo tú.';
      }
    } catch (e, st) {
      debugPrint('Error buscando $codigo: $e\n$st');
      aviso = 'No pude consultar el producto (¿sin internet?). Complétalo tú.';
    }
    if (!mounted) return;

    final nuevo = await showModalBottomSheet<Alimento>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _HojaProducto(producto: producto, aviso: aviso),
    );

    if (nuevo != null) {
      await ref.read(alimentosProvider.notifier).agregar(nuevo);
      await ref.read(listaCompraProvider.notifier).marcarCompradosPorNombre([nuevo.nombre]);
      if (mounted) {
        setState(() => _agregados++);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${nuevo.nombre} añadido a tu despensa'),
          duration: const Duration(seconds: 2),
        ));
      }
    }
    // Un respiro para no volver a leer el mismo código al instante.
    _ultimoCodigo = codigo;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _ocupado = false);
    Future<void>.delayed(const Duration(seconds: 4), () => _ultimoCodigo = null);
  }

  Future<void> _escribirCodigo() async {
    final c = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Escribir el código'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: 'Números debajo de las barras'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Buscar')),
        ],
      ),
    );
    if (codigo != null && codigo.length >= 6) await _procesar(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controlador,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No se pudo abrir la cámara.\nRevisa el permiso o escribe el código a mano.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          // Marco de enfoque
          Center(
            child: Container(
              width: 280,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _ocupado ? Colors.amber : Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Linterna',
                    onPressed: () => _controlador.toggleTorch(),
                    icon: const Icon(Icons.flashlight_on_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Escribir el código',
                    onPressed: _escribirCodigo,
                    icon: const Icon(Icons.keyboard_rounded),
                  ),
                ],
              ),
            ),
          ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _ocupado ? Icons.hourglass_top_rounded : Icons.qr_code_scanner_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _ocupado
                            ? 'Buscando producto...'
                            : _agregados == 0
                                ? 'Apunta al código de barras'
                                : '$_agregados añadido(s) · sigue con el siguiente',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirma un producto leído por código de barras antes de guardarlo.
class _HojaProducto extends ConsumerStatefulWidget {
  const _HojaProducto({required this.producto, this.aviso});

  final ProductoCodigo? producto;
  final String? aviso;

  @override
  ConsumerState<_HojaProducto> createState() => _HojaProductoState();
}

class _HojaProductoState extends ConsumerState<_HojaProducto> {
  late final TextEditingController _nombre;
  late final TextEditingController _contenido;
  final _precio = TextEditingController();
  late String _unidad;
  late String _categoria;
  Ubicacion? _ubicacion;
  int _paquetes = 1;

  DateTime? _fecha;
  FechaOrigen _origen = FechaOrigen.estimada;
  bool _noVence = false;
  bool _estimando = false;

  static const _unidades = ['g', 'kg', 'ml', 'L', 'u'];

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _unidad = p?.unidad ?? 'u';
    _contenido = TextEditingController(
        text: p?.cantidad != null ? fmtNum(p!.cantidad!) : '1');
    _categoria = p?.categoria ?? 'Otros';
    _ubicacion = _ubicacionSugerida(_categoria);
    if (_nombre.text.isNotEmpty) _estimar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _contenido.dispose();
    _precio.dispose();
    super.dispose();
  }

  Ubicacion _ubicacionSugerida(String categoria) {
    final c = categoria.toLowerCase();
    if (c.contains('congelad')) return Ubicacion.congelador;
    if (c.contains('lácteo') ||
        c.contains('carne') ||
        c.contains('pescado') ||
        c.contains('fruta')) {
      return Ubicacion.nevera;
    }
    return Ubicacion.alacena;
  }

  Future<void> _estimar() async {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _estimando = true);
    try {
      final est = await ref.read(scannerServiceProvider).estimarFecha(
            nombre: nombre,
            categoria: _categoria,
            ubicacion: _ubicacion,
          );
      if (!mounted) return;
      setState(() {
        _noVence = est.noVence;
        _fecha = est.fecha;
        _origen = FechaOrigen.estimada;
      });
    } catch (_) {
      // Sin estimación: la persona puede ponerla con el botón de la fecha.
    } finally {
      if (mounted) setState(() => _estimando = false);
    }
  }

  double get _total {
    final c = double.tryParse(_contenido.text.replaceAll(',', '.')) ?? 1.0;
    return (c > 0 ? c : 1.0) * _paquetes;
  }

  Alimento _borrador() {
    final ahora = DateTime.now();
    return Alimento(
      id: '${ahora.microsecondsSinceEpoch}',
      nombre: _nombre.text.trim(),
      categoria: _categoria,
      cantidad: Cantidad(valor: _total, unidad: _unidad),
      fechaVencimiento: _noVence
          ? Alimento.nuncaVence
          : (_fecha ?? Alimento.sinFecha),
      estado: Disponible(ahora),
      origenFecha: _origen,
      ubicacion: _ubicacion,
      precio: double.tryParse(_precio.text.replaceAll(',', '.').trim()),
      fechaCompra: ahora,
      cantidadInicial: _total,
    );
  }

  Future<void> _editarFecha() async {
    final nuevo = await editarFechaAlimento(context, ref, _borrador());
    if (nuevo == null || !mounted) return;
    setState(() {
      _noVence = nuevo.noVence;
      _fecha = nuevo.noVence || nuevo.sinFechaVencimiento ? null : nuevo.fechaVencimiento;
      _origen = nuevo.origenFecha;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borrador = _borrador();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.producto != null ? 'Producto encontrado' : 'Producto nuevo',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            if (widget.aviso != null) ...[
              const SizedBox(height: 6),
              Text(widget.aviso!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              onChanged: (_) => setState(() {}),
              onEditingComplete: _estimar,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _contenido,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Contenido de cada uno'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _unidad,
                    decoration: const InputDecoration(labelText: 'Unidad'),
                    items: [
                      for (final u in _unidades) DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (v) => setState(() => _unidad = v ?? _unidad),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('¿Cuántos compraste?', style: theme.textTheme.bodyMedium),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: _paquetes > 1 ? () => setState(() => _paquetes--) : null,
                  icon: const Icon(Icons.remove_rounded),
                ),
                SizedBox(
                  width: 40,
                  child: Text('$_paquetes',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                ),
                IconButton.filledTonal(
                  onPressed: () => setState(() => _paquetes++),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            Text('Total: ${fmtCantidad(_total, _unidad)}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            Text('Dónde lo guardas', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final u in Ubicacion.values)
                  ChoiceChip(
                    label: Text('${u.emoji} ${u.etiqueta}'),
                    selected: _ubicacion == u,
                    onSelected: (_) {
                      setState(() => _ubicacion = u);
                      if (_origen == FechaOrigen.estimada) _estimar();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Material(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: _estimando
                    ? const SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.event_rounded),
                title: Text(_estimando ? 'Estimando la fecha...' : describirFecha(borrador)),
                subtitle: const Text('Toca para escanearla, elegirla o marcar que no vence'),
                onTap: _editarFecha,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _precio,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Precio total (opcional)',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _nombre.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_borrador()),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar y escanear otro'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Omitir este producto'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
