import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/captura.dart';
import 'package:foodzy/core/formato.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/consumo.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/scanner_service.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/providers/habitos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';
import 'package:image_picker/image_picker.dart';

/// "Sacar comida": la cámara reconoce lo que sacaste y tú indicas cuánto
/// usarás (porción, medida casera, cantidad exacta o medición por fotos).
class PantallaRetiro extends ConsumerStatefulWidget {
  const PantallaRetiro({super.key, required this.imageFile});

  final XFile imageFile;

  @override
  ConsumerState<PantallaRetiro> createState() => _PantallaRetiroState();
}

class _Seleccion {
  _Seleccion(this.alimento, this.cantidad, this.medidas, {this.habitual = false});

  final Alimento alimento;
  double cantidad;
  final List<MedidaCasera> medidas;
  final bool habitual;
  bool activo = true;

  String? medidaSel;
  int veces = 0;

  double get total => alimento.cantidad.valor;
  String get unidad => alimento.cantidad.unidad;
}

class _PantallaRetiroState extends ConsumerState<PantallaRetiro> {
  List<_Seleccion>? _items;
  bool _procesando = true;
  bool _guardando = false;
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
      final inventario = (ref.read(alimentosProvider).value ?? const <Alimento>[])
          .where((a) => a.estado is Disponible)
          .toList();
      final r = await ref
          .read(scannerServiceProvider)
          .detectarRetiro(widget.imageFile, inventario);
      if (!mounted) return;
      final habitos = ref.read(habitosProvider.notifier);
      setState(() {
        _items = r.map((d) {
          final habito =
              habitos.porcionHabitual(d.alimento.nombre, d.alimento.cantidad.unidad);
          final usaHabito = habito != null && habito > 0 && habito <= d.alimento.cantidad.valor;
          return _Seleccion(
            d.alimento,
            usaHabito ? habito : d.cantidad,
            d.medidas,
            habitual: usaHabito,
          );
        }).toList();
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

  void _poner(_Seleccion s, double valor) {
    final paso = pasoPara(s.unidad, s.total);
    var v = valor.clamp(paso <= s.total ? paso : s.total, s.total).toDouble();
    v = (v / paso).round() * paso;
    if (v > s.total) v = s.total;
    setState(() {
      s.cantidad = double.parse(v.toStringAsFixed(3));
    });
  }

  void _medida(_Seleccion s, MedidaCasera m) {
    if (s.medidaSel == m.nombre) {
      s.veces++;
    } else {
      s.medidaSel = m.nombre;
      s.veces = 1;
    }
    _poner(s, m.cantidad * s.veces);
  }

  Future<void> _editarExacto(_Seleccion s) async {
    final controlador = TextEditingController(text: fmtNum(s.cantidad));
    final valor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cantidad de ${s.alimento.nombre}'),
        content: TextField(
          controller: controlador,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: InputDecoration(
            suffixText: s.unidad,
            helperText: 'Tienes ${fmtCantidad(s.total, s.unidad)}',
          ),
          onSubmitted: (t) =>
              Navigator.pop(ctx, double.tryParse(t.replaceAll(',', '.'))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(controlador.text.replaceAll(',', '.'))),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (valor != null && valor > 0) {
      s.medidaSel = null;
      _poner(s, valor);
    }
  }

  /// Foto ANTES y DESPUÉS: la IA estima qué fracción del contenido se usó.
  Future<void> _medirPorFotos(_Seleccion s) async {
    Future<bool> confirmar(String titulo, String texto, String boton) async =>
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(titulo),
            content: Text(texto),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true), child: Text(boton)),
            ],
          ),
        ) ??
        false;

    if (!await confirmar(
      'Foto ANTES',
      'Toma una foto de ${s.alimento.nombre} tal como está ahora, mostrando bien el nivel o la cantidad.',
      'Tomar foto',
    )) { return; }
    if (!mounted) return;
    final antes = await capturarImagen(context);
    if (antes == null || !mounted) return;

    if (!await confirmar(
      'Ahora úsalo',
      'Saca la cantidad que necesites y toma la foto DESPUÉS, desde el mismo ángulo.',
      'Tomar foto',
    )) { return; }
    if (!mounted) return;
    final despues = await capturarImagen(context);
    if (despues == null || !mounted) return;

    final mensajero = ScaffoldMessenger.of(context);
    mensajero.showSnackBar(const SnackBar(
      content: Text('Comparando las fotos...'),
      duration: Duration(seconds: 20),
    ));
    try {
      final fraccion = await ref
          .read(scannerServiceProvider)
          .estimarConsumo(antes, despues, s.alimento);
      mensajero.hideCurrentSnackBar();
      if (!mounted) return;
      s.medidaSel = null;
      _poner(s, fraccion * s.total);
      mensajero.showSnackBar(SnackBar(
        content: Text(
            'Estimado: ${(fraccion * 100).round()} % (~${fmtCantidad(s.cantidad, s.unidad)}). Es aproximado, ajústalo si hace falta.'),
      ));
    } catch (e) {
      mensajero.hideCurrentSnackBar();
      mensajero.showSnackBar(SnackBar(
          content: Text(e is ScannerException ? e.mensaje : e.toString())));
    }
  }

  Future<void> _confirmar() async {
    final elegidos = _items!.where((s) => s.activo && s.cantidad > 0).toList();
    if (elegidos.isEmpty) return;
    setState(() => _guardando = true);
    final notifier = ref.read(alimentosProvider.notifier);
    final habitos = ref.read(habitosProvider.notifier);
    for (final s in elegidos) {
      final a = s.alimento;
      final nuevo = consumir(a, s.cantidad, DateTime.now());
      await notifier.actualizar(nuevo);
      // Solo se aprende de porciones parciales; sacar "todo" no es un hábito.
      if (nuevo.estado is Disponible) {
        await habitos.recordar(a.nombre, a.cantidad.unidad, s.cantidad);
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Descontaste de ${elegidos.length} alimento(s) de tu despensa.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hayActivos = _items?.any((s) => s.activo) ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Sacar comida')),
      body: Column(
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: kIsWeb
                    ? NetworkImage(widget.imageFile.path)
                    : FileImage(File(widget.imageFile.path)) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(child: _contenido(theme)),
        ],
      ),
      bottomNavigationBar: (_items != null && _items!.isNotEmpty)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: hayActivos && !_guardando ? _confirmar : null,
                  icon: const Icon(Icons.outbox_rounded),
                  label: const Text('Confirmar retiro'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                ),
              ),
            )
          : null,
    );
  }

  Widget _contenido(ThemeData theme) {
    if (_procesando) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 4)),
            SizedBox(height: 18),
            Text('Reconociendo lo que sacaste...'),
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
              Icon(Icons.error_outline_rounded, size: 52, color: theme.colorScheme.error),
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No reconocí nada de tu despensa en la foto.\nPrueba con mejor luz o más cerca.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _items!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _tarjeta(theme, _items![i]),
    );
  }

  Widget _tarjeta(ThemeData theme, _Seleccion s) {
    final a = s.alimento;
    final paso = pasoPara(s.unidad, s.total);
    final fracciones = const {'¼': 0.25, '½': 0.5, '¾': 0.75, 'Todo': 1.0};
    final minimo = paso <= s.total ? paso : s.total;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: s.activo
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: s.activo,
                  onChanged: (v) => setState(() => s.activo = v ?? false),
                ),
                FotoAlimento(alimento: a, tamano: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.nombre,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Tienes ${fmtCantidad(s.total, s.unidad)}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (s.activo) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _editarExacto(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Usaré ${fmtCantidad(s.cantidad, s.unidad)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.edit_rounded,
                                size: 16, color: theme.colorScheme.outline),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (s.habitual)
                      Tooltip(
                        message: 'Es la cantidad que sueles usar de este producto',
                        child: Chip(
                          avatar: const Icon(Icons.history_rounded, size: 16),
                          label: const Text('Tu porción'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                  ],
                ),
              ),
              if (s.total > minimo)
                Slider(
                  value: s.cantidad.clamp(minimo, s.total).toDouble(),
                  min: minimo,
                  max: s.total,
                  onChanged: (v) {
                    s.medidaSel = null;
                    _poner(s, v);
                  },
                ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final f in fracciones.entries)
                      ActionChip(
                        label: Text(f.key),
                        onPressed: () {
                          s.medidaSel = null;
                          _poner(s, f.value * s.total);
                        },
                      ),
                  ],
                ),
              ),
              if (s.medidas.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 0, 4),
                  child: Text('Medidas de cocina',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final m in s.medidas)
                        ChoiceChip(
                          selected: s.medidaSel == m.nombre,
                          label: Text(s.medidaSel == m.nombre && s.veces > 1
                              ? '${s.veces} × ${m.nombre}'
                              : '${m.nombre} (${fmtCantidad(m.cantidad, s.unidad)})'),
                          onSelected: (_) => _medida(s, m),
                        ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 4),
                child: TextButton.icon(
                  onPressed: () => _medirPorFotos(s),
                  icon: const Icon(Icons.compare_rounded, size: 18),
                  label: const Text('Medir con fotos antes / después'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
