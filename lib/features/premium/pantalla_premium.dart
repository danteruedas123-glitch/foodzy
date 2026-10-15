import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/premium/premium_provider.dart';

/// Pantalla de planes: muestra el uso del mes y las suscripciones.
class PantallaPremium extends ConsumerStatefulWidget {
  const PantallaPremium({super.key});

  @override
  ConsumerState<PantallaPremium> createState() => _PantallaPremiumState();
}

class _PantallaPremiumState extends ConsumerState<PantallaPremium> {
  PlanPremium _plan = PlanPremium.anual;
  bool _procesando = false;

  static const _beneficios = [
    (Icons.auto_awesome, 'IA sin límite', 'Escaneos de fotos y facturas ilimitados'),
    (Icons.restaurant_menu, 'Recetas y menú semanal', 'Con lo que tienes en tu despensa'),
    (Icons.group, 'Hogar compartido', 'Sincroniza con tu familia'),
    (Icons.insights, 'Estadísticas de ahorro', 'Cuánto dinero evitas desperdiciar'),
  ];

  bool get _pruebaActiva =>
      ref.read(billingProvider) is BillingSimulado && BillingSimulado.habilitado;

  void _aviso(String texto) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _comprar() async {
    setState(() => _procesando = true);
    var ok = false;
    try {
      ok = await ref.read(premiumProvider.notifier).comprar(_plan);
    } catch (_) {
      if (mounted) _aviso('No se pudo completar la compra. Intenta de nuevo.');
    }
    if (!mounted) return;
    setState(() => _procesando = false);
    if (ok) {
      _aviso('¡Ya eres Premium! Gracias por apoyar Foodzy.');
      Navigator.of(context).pop();
    } else if (!_pruebaActiva) {
      _aviso('Las compras aún no están disponibles en esta versión.');
    }
  }

  Future<void> _restaurar() async {
    setState(() => _procesando = true);
    final ok = await ref.read(premiumProvider.notifier).restaurar();
    if (!mounted) return;
    setState(() => _procesando = false);
    _aviso(ok
        ? 'Compra restaurada. ¡Bienvenido de nuevo!'
        : 'No encontramos compras para restaurar.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final estado = ref.watch(premiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Foodzy Premium')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(Icons.workspace_premium,
                    size: 44, color: cs.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(
                  estado.premium
                      ? 'Ya eres Premium'
                      : 'Cocina y ahorra sin límites',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                if (!estado.premium) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (estado.usados / limiteIAGratis).clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Usos de IA gratis este mes: '
                    '${estado.usados.clamp(0, limiteIAGratis)}/$limiteIAGratis',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: cs.onPrimaryContainer),
                  ),
                ],
              ],
            ),
          ),
          if (_pruebaActiva) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.science, color: cs.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Modo de prueba: la compra es simulada y no se cobra nada.',
                      style: TextStyle(color: cs.onTertiaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          for (final (icono, titulo, detalle) in _beneficios)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: cs.secondaryContainer,
                child: Icon(icono, color: cs.onSecondaryContainer),
              ),
              title: Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(detalle),
            ),
          if (estado.premium && _pruebaActiva)
            TextButton(
              onPressed: () =>
                  ref.read(premiumProvider.notifier).cancelarPrueba(),
              child: const Text('Cancelar Premium (solo prueba)'),
            ),
          if (!estado.premium) ...[
            const SizedBox(height: 12),
            for (final p in PlanPremium.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _plan = p),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _plan == p ? cs.primary : cs.outlineVariant,
                        width: _plan == p ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(_plan == p
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.nombre,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              Text(p.periodo, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Text(p.precio,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: _procesando ? null : _comprar,
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: _procesando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Text('Continuar'),
            ),
            TextButton(
              onPressed: _procesando ? null : _restaurar,
              child: const Text('Restaurar compras'),
            ),
            Text(
              'La suscripción se renueva sola y puedes cancelarla cuando quieras desde tu tienda de aplicaciones.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
