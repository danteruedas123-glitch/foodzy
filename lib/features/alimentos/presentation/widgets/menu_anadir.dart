import 'package:flutter/material.dart';
import 'package:foodzy/core/captura.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_editar.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_escaneo.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_retiro.dart';

/// Hoja inferior con las formas de meter o sacar comida.
Future<void> mostrarMenuAnadir(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => _MenuAnadir(raiz: context),
  );
}

class _MenuAnadir extends StatelessWidget {
  const _MenuAnadir({required this.raiz});

  /// Contexto de la pantalla que abrió la hoja (sigue vivo al cerrarla).
  final BuildContext raiz;

  Future<void> _escanear(
    BuildContext sheet,
    Future<dynamic> Function(dynamic imagen) abrir, {
    bool galeria = false,
  }) async {
    Navigator.of(sheet).pop();
    final imagen = galeria ? await elegirDeGaleria() : await capturarImagen(raiz);
    if (imagen != null && raiz.mounted) await abrir(imagen);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nav = Navigator.of(raiz);

    Widget opcion({
      required IconData icono,
      required String titulo,
      required String detalle,
      required Color color,
      required VoidCallback onTap,
      VoidCallback? onGaleria,
    }) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        color: color.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: color,
            child: Icon(icono, color: Colors.white),
          ),
          title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(detalle),
          trailing: onGaleria != null
              ? IconButton(
                  tooltip: 'Elegir de la galería',
                  onPressed: onGaleria,
                  icon: const Icon(Icons.photo_library_outlined),
                )
              : null,
          onTap: onTap,
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text('¿Qué quieres hacer?',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          ),
          opcion(
            icono: Icons.shopping_basket_rounded,
            titulo: 'Foto de mi compra',
            detalle: hayCamara
                ? 'Apunta la cámara a tus alimentos'
                : 'Sube una foto de tus alimentos',
            color: const Color(0xFF16A34A),
            onTap: () => _escanear(context, (img) => nav.push(MaterialPageRoute(
                builder: (_) => PantallaEscaneo(imageFile: img)))),
            onGaleria: hayCamara
                ? () => _escanear(context, galeria: true, (img) => nav.push(
                    MaterialPageRoute(builder: (_) => PantallaEscaneo(imageFile: img))))
                : null,
          ),
          opcion(
            icono: Icons.receipt_long_rounded,
            titulo: 'Escanear factura',
            detalle: 'Lee el ticket y carga todos los productos',
            color: const Color(0xFF2563EB),
            onTap: () => _escanear(context, (img) => nav.push(MaterialPageRoute(
                builder: (_) => PantallaEscaneo(imageFile: img, modo: ModoEscaneo.factura)))),
            onGaleria: hayCamara
                ? () => _escanear(context, galeria: true, (img) => nav.push(
                    MaterialPageRoute(
                        builder: (_) =>
                            PantallaEscaneo(imageFile: img, modo: ModoEscaneo.factura))))
                : null,
          ),
          opcion(
            icono: Icons.outbox_rounded,
            titulo: 'Sacar comida',
            detalle: 'Muestra lo que sacaste y se descuenta solo',
            color: const Color(0xFFEA580C),
            onTap: () => _escanear(context, (img) => nav.push(MaterialPageRoute(
                builder: (_) => PantallaRetiro(imageFile: img)))),
            onGaleria: hayCamara
                ? () => _escanear(context, galeria: true, (img) => nav.push(
                    MaterialPageRoute(builder: (_) => PantallaRetiro(imageFile: img))))
                : null,
          ),
          opcion(
            icono: Icons.edit_rounded,
            titulo: 'Ingreso manual',
            detalle: 'Escribe el alimento tú mismo',
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.of(context).pop();
              nav.push(MaterialPageRoute(builder: (_) => const PantallaEditar()));
            },
          ),
        ],
      ),
    );
  }
}
