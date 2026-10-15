import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/captura.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/scanner_service.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';

enum _Accion { elegir, escanear, noVence }

/// Texto que describe la fecha de un alimento y de dónde salió.
String describirFecha(Alimento a) {
  if (a.noVence) return 'No vence';
  if (a.sinFechaVencimiento) return 'Sin fecha';
  final f = fechaCorta(a.fechaVencimiento);
  return switch (a.origenFecha) {
    FechaOrigen.leida => '$f · leída del empaque',
    FechaOrigen.estimada => '≈ $f · estimada',
    FechaOrigen.manual => f,
  };
}

/// Hoja con las formas de fijar la fecha de vencimiento de [alimento].
/// Devuelve el alimento actualizado, o `null` si no se cambió nada.
Future<Alimento?> editarFechaAlimento(
  BuildContext context,
  WidgetRef ref,
  Alimento alimento,
) async {
  final accion = await showModalBottomSheet<_Accion>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget tile(IconData icono, String titulo, String detalle, _Accion a) =>
          ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(icono, color: theme.colorScheme.onPrimaryContainer),
            ),
            title: Text(titulo,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(detalle),
            onTap: () => Navigator.pop(ctx, a),
          );

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Vencimiento de ${alimento.nombre}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text('Ahora: ${describirFecha(alimento)}',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              tile(
                Icons.document_scanner_rounded,
                'Escanear la fecha',
                hayCamara
                    ? 'Foto de cerca de la fecha impresa en el empaque'
                    : 'Sube una foto de cerca de la fecha impresa',
                _Accion.escanear,
              ),
              tile(
                Icons.edit_calendar_rounded,
                'Elegir la fecha',
                'Ponla tú mismo en el calendario',
                _Accion.elegir,
              ),
              if (!alimento.noVence)
                tile(
                  Icons.all_inclusive_rounded,
                  'Este producto no vence',
                  'Sal, azúcar, miel... no recibirá avisos de vencimiento',
                  _Accion.noVence,
                ),
            ],
          ),
        ),
      );
    },
  );
  if (accion == null || !context.mounted) return null;

  switch (accion) {
    case _Accion.noVence:
      return alimento.sinVencimiento();

    case _Accion.elegir:
      final base = (alimento.sinFechaVencimiento || alimento.noVence)
          ? DateTime.now().add(const Duration(days: 7))
          : alimento.fechaVencimiento;
      final f = await showDatePicker(
        context: context,
        initialDate: base,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
        helpText: 'Vencimiento de ${alimento.nombre}',
      );
      return f == null ? null : alimento.conFecha(f);

    case _Accion.escanear:
      final imagen = await capturarImagen(context);
      if (imagen == null || !context.mounted) return null;
      final mensajero = ScaffoldMessenger.of(context);
      mensajero.showSnackBar(const SnackBar(
        content: Text('Leyendo la fecha...'),
        duration: Duration(seconds: 30),
      ));
      try {
        final fecha =
            await ref.read(scannerServiceProvider).leerFechaVencimiento(imagen);
        mensajero.hideCurrentSnackBar();
        mensajero.showSnackBar(SnackBar(
          content: Text('Fecha leída: ${fechaCorta(fecha)}'),
        ));
        return alimento.conFecha(fecha, origen: FechaOrigen.leida);
      } catch (e) {
        mensajero.hideCurrentSnackBar();
        mensajero.showSnackBar(SnackBar(
          content: Text(e is ScannerException ? e.mensaje : e.toString()),
        ));
        return null;
      }
  }
}
