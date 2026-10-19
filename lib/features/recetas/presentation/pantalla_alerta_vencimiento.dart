import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/cargando_alimentos.dart';
import 'package:foodzy/core/formato.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/alimento_card.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';
import 'package:foodzy/features/recetas/domain/recetas_service.dart';
import 'package:foodzy/features/recetas/presentation/recetas_estado_provider.dart';
import 'package:foodzy/features/recetas/presentation/widgets/hoja_cocinar.dart';
import 'package:foodzy/features/recetas/presentation/widgets/receta_card.dart';

/// Se abre al tocar el aviso de "está por vencerse": pregunta si ya se
/// consumió y, si no, propone recetas que lo aprovechen con la despensa.
class PantallaAlertaVencimiento extends ConsumerStatefulWidget {
  const PantallaAlertaVencimiento({super.key, required this.alimentoId});

  final String alimentoId;

  @override
  ConsumerState<PantallaAlertaVencimiento> createState() =>
      _PantallaAlertaVencimientoState();
}

class _PantallaAlertaVencimientoState
    extends ConsumerState<PantallaAlertaVencimiento> {
  bool _pidioRecetas = false;
  bool _cargando = false;
  String? _error;
  List<Receta>? _recetas;

  Alimento? _buscar() {
    final lista = ref.watch(alimentosProvider).value ?? const <Alimento>[];
    for (final a in lista) {
      if (a.id == widget.alimentoId) return a;
    }
    return null;
  }

  Future<void> _consumido(Alimento a) async {
    await ref
        .read(alimentosProvider.notifier)
        .actualizar(a.copyWith(estado: Consumido(DateTime.now())));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('¡Genial! ${a.nombre} quedó como consumido.')),
    );
  }

  Future<void> _danado(Alimento a) async {
    await ref.read(alimentosProvider.notifier).actualizar(
        a.copyWith(
            estado: Desechado('Se echó a perder antes de usarlo',
                fecha: DateTime.now())));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${a.nombre} se marcó como desechado.')),
    );
  }

  Future<void> _pedirRecetas(Alimento a) async {
    setState(() {
      _pidioRecetas = true;
      _cargando = true;
      _error = null;
    });
    try {
      final despensa = ref.read(alimentosProvider).value ?? const <Alimento>[];
      final r = await ref
          .read(recetasServiceProvider)
          .generar(despensa,
              prioritario: a,
              cuantas: 3,
              preferencias: ref.read(preferenciasProvider));
      if (!mounted) return;
      setState(() {
        _recetas = r;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ScannerException ? e.mensaje : e.toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alimento = _buscar();
    final cargandoLista = ref.watch(alimentosProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de vencimiento')),
      body: Builder(builder: (_) {
        if (alimento == null) {
          return Center(
            child: cargandoLista
                ? const CargandoAlimentos()
                : const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('Ese alimento ya no está en tu despensa.',
                        textAlign: TextAlign.center),
                  ),
          );
        }
        if (alimento.estado is! Disponible) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Ya registraste este alimento como usado. ¡Todo en orden!',
                  textAlign: TextAlign.center),
            ),
          );
        }

        final visual = estadoVisual(alimento);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: visual.color.withValues(alpha: 0.12),
                border: Border.all(color: visual.color.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  FotoAlimento(alimento: alimento, tamano: 76),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alimento.nombre,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 2),
                        Text(
                          'Tienes ${fmtCantidad(alimento.cantidad.valor, alimento.cantidad.unidad)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        EstadoChip(visual: visual),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text('¿Ya lo consumiste?',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _consumido(alimento),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Sí, ya lo consumí'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _cargando ? null : () => _pedirRecetas(alimento),
                    icon: const Icon(Icons.restaurant_menu_rounded),
                    label: const Text('Todavía no'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _danado(alimento),
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: theme.colorScheme.error),
                label: Text('Se echó a perder',
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            ),
            if (_pidioRecetas) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('💡', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recetas para aprovechar ${alimento.nombre}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Hechas con lo que ya tienes en tu despensa.',
                  style: theme.textTheme.bodySmall),
              const SizedBox(height: 12),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        CargandoAlimentos(),
                        SizedBox(height: 14),
                        Text('Pensando recetas...'),
                      ],
                    ),
                  ),
                )
              else if (_error != null)
                Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: () => _pedirRecetas(alimento),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                )
              else
                for (var i = 0; i < (_recetas?.length ?? 0); i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RecetaCard(
                      receta: _recetas![i],
                      abierta: i == 0,
                      onCocinar: () => cocinarReceta(context, _recetas![i]),
                    ),
                  ),
            ],
          ],
        );
      }),
    );
  }
}
