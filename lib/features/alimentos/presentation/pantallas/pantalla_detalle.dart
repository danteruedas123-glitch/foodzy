import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/formato.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/consumo.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_editar.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/opciones_fecha.dart';

class PantallaDetalle extends ConsumerWidget {
  const PantallaDetalle({super.key, required this.alimento});

  final Alimento alimento;

  Widget _buildImageHeader(BuildContext context) {
    if (alimento.fotos.isEmpty) return const SizedBox.shrink();

    final path = alimento.fotos.first;
    final isNetwork = path.startsWith('http') || path.startsWith('blob:');
    // Se decodifica al ancho de la pantalla, no al tamaño completo de la foto.
    final ancho = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round();

    return Container(
      width: double.infinity,
      height: 250,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: isNetwork
            ? Image.network(
                path,
                fit: BoxFit.cover,
                cacheWidth: ancho,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              )
            : (kIsWeb
                  ? const Center(
                      child: Icon(
                        Icons.broken_image,
                        size: 50,
                        color: Colors.grey,
                      ),
                    )
                  : Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      cacheWidth: ancho,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          ),
                    )),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Siempre se muestra la versión más reciente (la fecha puede cambiar aquí mismo).
    final alimento = ref
            .watch(alimentosProvider)
            .value
            ?.where((a) => a.id == this.alimento.id)
            .firstOrNull ??
        this.alimento;
    final bool vencido = alimento.estaVencido(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Alimento'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PantallaEditar(alimentoExistente: alimento),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirmar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar alimento'),
                  content: const Text(
                    '¿Estás seguro de que deseas eliminar este alimento?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );

              if (confirmar == true) {
                await ref
                    .read(alimentosProvider.notifier)
                    .eliminar(alimento.id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageHeader(context),
            // Tarjeta de información principal
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alimento.nombre,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(alimento.categoria),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Divider(height: 32),
                    _InfoRow(
                      icon: Icons.scale,
                      label: 'Cantidad',
                      value: fmtCantidad(
                        alimento.cantidad.valor,
                        alimento.cantidad.unidad,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      label: 'Fecha de Vencimiento',
                      value: describirFecha(alimento),
                      valueColor: vencido && alimento.estado is Disponible
                          ? Colors.red
                          : null,
                    ),
                    if (alimento.estado is Disponible)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final nuevo = await editarFechaAlimento(context, ref, alimento);
                            if (nuevo != null) {
                              await ref.read(alimentosProvider.notifier).actualizar(nuevo);
                            }
                          },
                          icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                          label: const Text('Escanear o cambiar la fecha'),
                        ),
                      ),
                    if (alimento.ubicacion != null) ...[
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.place_outlined,
                        label: 'Dónde lo guardas',
                        value: '${alimento.ubicacion!.emoji} ${alimento.ubicacion!.etiqueta}',
                      ),
                    ],
                    if (alimento.precio != null) ...[
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.sell_outlined,
                        label: 'Precio',
                        value: '\$${fmtNum(alimento.precio!)}',
                      ),
                    ],
                    const SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.info_outline,
                      label: 'Estado Actual',
                      value: alimento.estado.etiqueta,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (alimento.estado is Disponible) ...[
              Text(
                'Acciones Rápidas',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final double step = pasoPara(alimento.cantidad.unidad, alimento.cantidad.valor);
                        final double? consumido = await showDialog<double>(
                          context: context,
                          builder: (context) {
                            double cantidad = step;
                            return StatefulBuilder(
                              builder: (context, setState) {
                                return AlertDialog(
                                  title: const Text('Consumo Parcial'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Tienes ${fmtCantidad(alimento.cantidad.valor, alimento.cantidad.unidad)}. ¿Cuánto vas a consumir?',
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            onPressed: cantidad > step
                                                ? () => setState(
                                                    () => cantidad -= step,
                                                  )
                                                : null,
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 32,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            fmtNum(cantidad),
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          IconButton(
                                            onPressed:
                                                (cantidad + step) <=
                                                    alimento.cantidad.valor
                                                ? () => setState(
                                                    () => cantidad += step,
                                                  )
                                                : (cantidad <
                                                          alimento
                                                              .cantidad
                                                              .valor
                                                      ? () => setState(
                                                          () => cantidad =
                                                              alimento
                                                                  .cantidad
                                                                  .valor,
                                                        )
                                                      : null),
                                            icon: const Icon(
                                              Icons.add_circle_outline,
                                              size: 32,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(null),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(cantidad),
                                      child: const Text('Confirmar'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        );

                        if (consumido != null && consumido > 0 && context.mounted) {
                          final nuevo = consumir(alimento, consumido, DateTime.now());
                          await _guardarConDeshacer(
                            context,
                            ref,
                            antes: alimento,
                            nuevo: nuevo,
                            mensaje: nuevo.estado is Consumido
                                ? '${alimento.nombre} pasó al historial como consumido.'
                                : 'Usaste ${fmtCantidad(consumido, alimento.cantidad.unidad)} de ${alimento.nombre}. '
                                    'Quedan ${fmtCantidad(nuevo.cantidad.valor, nuevo.cantidad.unidad)}.',
                          );
                        }
                      },
                      icon: const Icon(Icons.restaurant),
                      label: const Text('Consumir'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _guardarConDeshacer(
                        context,
                        ref,
                        antes: alimento,
                        nuevo: alimento.copyWith(
                          estado: Desechado(
                            'Vencido o en mal estado',
                            fecha: DateTime.now(),
                          ),
                        ),
                        mensaje: '${alimento.nombre} pasó al historial como desechado.',
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Desechar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Guarda [nuevo], cierra el detalle y muestra un aviso con "Deshacer", que
/// devuelve el alimento a como estaba ([antes]). Así un toque por error en
/// "Consumir" o "Desechar" no se pierde.
Future<void> _guardarConDeshacer(
  BuildContext context,
  WidgetRef ref, {
  required Alimento antes,
  required Alimento nuevo,
  required String mensaje,
}) async {
  // Se toman antes de cerrar: después del pop esta pantalla ya no existe.
  final notifier = ref.read(alimentosProvider.notifier);
  final mensajero = ScaffoldMessenger.of(context);
  final navegador = Navigator.of(context);

  await notifier.actualizar(nuevo);
  navegador.pop();
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(mensaje),
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () => notifier.actualizar(antes),
      ),
    ));
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
