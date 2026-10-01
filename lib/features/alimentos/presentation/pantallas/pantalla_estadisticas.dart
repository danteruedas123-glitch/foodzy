import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estadisticas.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:intl/intl.dart';

String _dinero(double v) => '\$${NumberFormat.decimalPattern().format(v.round())}';

const _meses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Cuánto gastas, cuánto desperdicias y en qué, mes a mes.
class PantallaEstadisticas extends ConsumerStatefulWidget {
  const PantallaEstadisticas({super.key});

  @override
  ConsumerState<PantallaEstadisticas> createState() =>
      _PantallaEstadisticasState();
}

class _PantallaEstadisticasState extends ConsumerState<PantallaEstadisticas> {
  late DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);

  void _mover(int delta) =>
      setState(() => _mes = DateTime(_mes.year, _mes.month + delta));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lista = ref.watch(alimentosProvider).value ?? const <Alimento>[];
    final r = estadisticasDelMes(lista, _mes);
    final serie = ultimosMeses(lista, _mes);
    final maxGasto = serie.map((m) => m.gastado).fold<double>(0, (a, b) => a > b ? a : b);
    final esActual = _mes.year == DateTime.now().year && _mes.month == DateTime.now().month;

    return Scaffold(
      appBar: AppBar(title: const Text('Tus números')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _mover(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text(
                  '${_meses[_mes.month - 1][0].toUpperCase()}${_meses[_mes.month - 1].substring(1)} ${_mes.year}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: esActual ? null : () => _mover(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Tarjeta('Gastado', _dinero(r.gastado), const Color(0xFF2563EB), Icons.shopping_cart_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _Tarjeta('Desperdiciado', _dinero(r.desperdiciado), const Color(0xFFEF4444), Icons.delete_outline_rounded)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Tarjeta('Consumidos', '${r.consumidos}', const Color(0xFF16A34A), Icons.check_circle_outline_rounded)),
              const SizedBox(width: 10),
              Expanded(child: _Tarjeta('Desechados', '${r.desechados}', const Color(0xFF78716C), Icons.remove_circle_outline_rounded)),
            ],
          ),
          if (r.gastado > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.porcentajeDesperdicio < 0.05
                        ? '¡Excelente! Casi nada se desperdició 🎉'
                        : 'Se perdió el ${(r.porcentajeDesperdicio * 100).round()} % de lo que gastaste',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 12,
                      value: r.porcentajeDesperdicio,
                      backgroundColor: const Color(0xFF16A34A).withValues(alpha: 0.25),
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text('Gasto de los últimos 6 meses',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in serie)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (m.gastado > 0)
                            Text(
                              NumberFormat.compact().format(m.gastado),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: maxGasto <= 0 ? 4 : (m.gastado / maxGasto * 100).clamp(4.0, 100.0),
                            decoration: BoxDecoration(
                              color: (m.mes.year == _mes.year && m.mes.month == _mes.month)
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(_meses[m.mes.month - 1].substring(0, 3),
                              style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (r.gastoPorCategoria.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text('En qué gastas',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final e in (r.gastoPorCategoria.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value))))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text(_dinero(e.value)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: r.gastado <= 0 ? 0 : e.value / r.gastado,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (r.topDesperdicio.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Lo que más se perdió',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final t in r.topDesperdicio)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0x22EF4444),
                  child: Icon(Icons.trending_down_rounded, color: Color(0xFFEF4444)),
                ),
                title: Text(t.$1),
                trailing: Text(_dinero(t.$2),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
              ),
          ],
          if (r.vacio) ...[
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  const Text('📊', style: TextStyle(fontSize: 52)),
                  const SizedBox(height: 8),
                  Text('Sin datos este mes',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                    'Escanea tus facturas: traen el precio de cada producto y así podemos calcular tus gastos.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta(this.titulo, this.valor, this.color, this.icono);
  final String titulo;
  final String valor;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
          ),
          Text(titulo, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
