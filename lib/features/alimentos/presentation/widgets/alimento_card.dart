import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foodzy/core/formato.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';

/// Miniatura de un alimento: su foto o, si no hay, un emoji de su categoría.
class FotoAlimento extends StatelessWidget {
  const FotoAlimento({super.key, required this.alimento, this.tamano = 64});

  final Alimento alimento;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final emoji = Center(
      child: Text(
        emojiCategoria(alimento.categoria, alimento.nombre),
        style: TextStyle(fontSize: tamano * 0.5),
      ),
    );
    final fondo = Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tamano * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primaryContainer, scheme.tertiaryContainer],
        ),
      ),
      child: emoji,
    );

    if (alimento.fotos.isEmpty) return fondo;

    final path = alimento.fotos.first;
    final esRed = path.startsWith('http') || path.startsWith('blob:');
    // La foto se decodifica al tamaño en que se ve, no a su tamaño completo
    // (una foto de 1800 px ocupa ~15 MB en memoria para una miniatura de
    // 64). El doble del tamaño visible mantiene nítidas las fotos
    // horizontales, que se recortan en cuadrado.
    final ancho = (tamano * MediaQuery.devicePixelRatioOf(context) * 2).round();
    Widget imagen;
    if (esRed) {
      imagen = Image.network(path, fit: BoxFit.cover, cacheWidth: ancho,
          errorBuilder: (_, _, _) => fondo);
    } else if (kIsWeb) {
      return fondo;
    } else {
      imagen = Image.file(File(path), fit: BoxFit.cover, cacheWidth: ancho,
          errorBuilder: (_, _, _) => fondo);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(tamano * 0.3),
      child: SizedBox(width: tamano, height: tamano, child: imagen),
    );
  }
}

/// Etiqueta redondeada con el estado (vence en 3 días, vencido, etc.).
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.visual});

  final EstadoVisual visual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icono, size: 14, color: visual.color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              visual.texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: visual.color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AlimentoCard extends StatelessWidget {
  const AlimentoCard({super.key, required this.alimento, this.onTap});

  final Alimento alimento;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = estadoVisual(alimento);
    final cantidad = alimento.cantidad;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: visual.color.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: 'foto_${alimento.id}',
                child: FotoAlimento(alimento: alimento),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alimento.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${alimento.categoria} · ${fmtCantidad(cantidad.valor, cantidad.unidad)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EstadoChip(visual: visual),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
