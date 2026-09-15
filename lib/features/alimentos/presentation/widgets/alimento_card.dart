import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:intl/intl.dart';

class AlimentoCard extends StatelessWidget {
  const AlimentoCard({super.key, required this.alimento, this.onTap});

  final Alimento alimento;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final estadoInfo = _getEstadoInfo(alimento);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: estadoInfo.color.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: _buildThumbnail(),
        title: Text(
          alimento.nombre,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${alimento.categoria} • ${alimento.cantidad.valor} ${alimento.cantidad.unidad}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(estadoInfo.icon, size: 16, color: estadoInfo.color),
                const SizedBox(width: 4),
                Text(
                  estadoInfo.text,
                  style: TextStyle(
                    color: estadoInfo.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildThumbnail() {
    if (alimento.fotos.isEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        radius: 24,
        child: const Icon(Icons.fastfood, color: Colors.grey),
      );
    }

    final path = alimento.fotos.first;
    final isNetwork = path.startsWith('http') || path.startsWith('blob:');

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: isNetwork
          ? Image.network(
              path,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const _FallbackIcon(),
            )
          : (kIsWeb
                ? const _FallbackIcon()
                : Image.file(
                    File(path),
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _FallbackIcon(),
                  )),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}

class _EstadoInfo {
  _EstadoInfo(this.text, this.color, this.icon);
  final String text;
  final Color color;
  final IconData icon;
}

_EstadoInfo _getEstadoInfo(Alimento a) {
  final estado = a.estado;
  if (estado is Consumido) {
    return _EstadoInfo(
      'Consumido el ${DateFormat.yMd().format(estado.fechaConsumo)}',
      Colors.blue,
      Icons.check_circle,
    );
  } else if (estado is Desechado) {
    return _EstadoInfo(
      'Desechado\nMotivo: ${estado.motivo}',
      Colors.grey,
      Icons.delete,
    );
  } else {
    // Disponible
    final hoy = DateTime.now();
    final diasRestantes = a.fechaVencimiento.difference(hoy).inDays;

    if (diasRestantes < 0) {
      return _EstadoInfo(
        'Vencido hace ${diasRestantes.abs()} días',
        Colors.red,
        Icons.warning,
      );
    } else if (diasRestantes <= 3) {
      return _EstadoInfo(
        'Vence en $diasRestantes días',
        Colors.orange,
        Icons.access_time,
      );
    } else {
      return _EstadoInfo(
        'Vence en $diasRestantes días',
        Colors.green,
        Icons.eco,
      );
    }
  }
}
