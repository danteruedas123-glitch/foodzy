import 'package:flutter/material.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';

/// Tarjeta desplegable con una receta: ingredientes (de la despensa o por
/// conseguir) y pasos numerados.
class RecetaCard extends StatelessWidget {
  const RecetaCard({
    super.key,
    required this.receta,
    this.abierta = false,
    this.onCocinar,
    this.favorita = false,
    this.onFavorita,
  });

  final Receta receta;
  final bool abierta;

  /// Si se da, muestra el botón "Cocinar esta receta" que descuenta ingredientes.
  final VoidCallback? onCocinar;

  /// Si se da [onFavorita], se muestra el botón de guardar en favoritas.
  final bool favorita;
  final VoidCallback? onFavorita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final faltan = receta.faltantes;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: abierta,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: const Text('🍳', style: TextStyle(fontSize: 22)),
          ),
          title: Text(receta.titulo,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 12,
              children: [
                _dato(context, Icons.timer_outlined, '${receta.minutos} min'),
                _dato(context, Icons.people_outline_rounded,
                    '${receta.porciones} porc.'),
                if (faltan.isEmpty)
                  _dato(context, Icons.check_circle_rounded, 'Todo en casa',
                      color: const Color(0xFF16A34A)),
              ],
            ),
          ),
          children: [
            if (onFavorita != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onFavorita,
                  icon: Icon(
                    favorita ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: favorita ? const Color(0xFFEF4444) : null,
                    size: 20,
                  ),
                  label: Text(favorita ? 'En favoritas' : 'Guardar en favoritas'),
                ),
              ),
            if (receta.descripcion.isNotEmpty) ...[
              Text(receta.descripcion, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
            ],
            if (receta.aprovecha != null && receta.aprovecha!.trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.eco_rounded,
                        size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(receta.aprovecha!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            Text('Ingredientes',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final i in receta.ingredientes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      i.enDespensa
                          ? Icons.check_circle_rounded
                          : Icons.add_shopping_cart_rounded,
                      size: 18,
                      color: i.enDespensa
                          ? const Color(0xFF16A34A)
                          : scheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: i.nombre,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        if (i.cantidad.isNotEmpty)
                          TextSpan(
                              text: '  ·  ${i.cantidad}',
                              style: TextStyle(color: scheme.onSurfaceVariant)),
                        if (!i.enDespensa)
                          TextSpan(
                              text: '  (por conseguir)',
                              style: TextStyle(
                                  color: scheme.outline, fontSize: 12)),
                      ])),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            Text('Preparación',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (var n = 0; n < receta.pasos.length; n++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: scheme.primary,
                      child: Text('${n + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(receta.pasos[n])),
                  ],
                ),
              ),
            if (onCocinar != null) ...[
              const SizedBox(height: 6),
              FilledButton.icon(
                onPressed: onCocinar,
                icon: const Icon(Icons.restaurant_rounded),
                label: const Text('Voy a cocinar esta receta'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dato(BuildContext context, IconData icono, String texto,
      {Color? color}) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: c),
        const SizedBox(width: 4),
        Text(texto,
            style: TextStyle(
                fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
