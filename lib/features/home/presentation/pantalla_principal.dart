import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/notificaciones.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_alimentos.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/menu_anadir.dart';
import 'package:foodzy/features/configuracion/presentation/pantallas/pantalla_configuracion.dart';
import 'package:foodzy/features/configuracion/presentation/providers/historial_ajustes_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/notificaciones_provider.dart';
import 'package:foodzy/features/home/presentation/pantalla_inicio.dart';
import 'package:foodzy/features/recetas/presentation/pantalla_alerta_vencimiento.dart';
import 'package:foodzy/features/recetas/presentation/pantalla_recetas.dart';

/// Estructura adaptable: barra inferior en móvil, riel lateral en tablet y PC.
class PantallaPrincipal extends ConsumerStatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  ConsumerState<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends ConsumerState<PantallaPrincipal> {
  int _indice = 0;
  final _avisos = NotificacionesService.instancia;

  static const _destinos = [
    (Icons.home_outlined, Icons.home_rounded, 'Inicio'),
    (Icons.kitchen_outlined, Icons.kitchen_rounded, 'Despensa'),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded, 'Recetas'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Ajustes'),
  ];

  @override
  void initState() {
    super.initState();
    _avisos.alimentoTocado.addListener(_abrirAviso);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _abrirAviso(); // por si la app se abrió desde una notificación
      // Limpia del historial lo que ya pasó el plazo elegido.
      ref
          .read(alimentosProvider.notifier)
          .limpiarHistorial(ref.read(historialDiasProvider));
      if (ref.read(notificacionesProvider).activas) {
        await _avisos.pedirPermiso();
      }
      _sincronizar();
    });
  }

  @override
  void dispose() {
    _avisos.alimentoTocado.removeListener(_abrirAviso);
    super.dispose();
  }

  void _abrirAviso() {
    final id = _avisos.alimentoTocado.value;
    if (id == null || !mounted) return;
    _avisos.alimentoTocado.value = null;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PantallaAlertaVencimiento(alimentoId: id),
    ));
  }

  void _sincronizar() {
    final lista = ref.read(alimentosProvider).value;
    if (lista == null) return;
    _avisos.reprogramar(lista, ref.read(notificacionesProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(alimentosProvider, (_, _) => _sincronizar());
    ref.listen(notificacionesProvider, (_, _) => _sincronizar());

    final ancho = MediaQuery.sizeOf(context).width;
    final ancha = ancho >= 800;
    final theme = Theme.of(context);

    final paginas = <Widget>[
      PantallaInicio(
        irADespensa: () => setState(() => _indice = 1),
        irARecetas: () => setState(() => _indice = 2),
      ),
      const PantallaAlimentos(),
      const PantallaRecetas(),
      const PantallaConfiguracion(),
    ];

    final cuerpo = AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(_indice),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: paginas[_indice],
          ),
        ),
      ),
    );

    final Widget? fab = _indice == 0
        ? FloatingActionButton.extended(
            onPressed: () => mostrarMenuAnadir(context),
            icon: const Icon(Icons.add_a_photo_rounded),
            label: const Text('Escanear'),
          )
        : _indice == 1
            ? FloatingActionButton(
                tooltip: 'Escanear',
                onPressed: () => mostrarMenuAnadir(context),
                child: const Icon(Icons.add_a_photo_rounded),
              )
            : null;

    if (ancha) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _indice,
              onDestinationSelected: (i) => setState(() => _indice = i),
              extended: ancho >= 1100,
              labelType: ancho >= 1100
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.eco_rounded,
                        color: theme.colorScheme.primary, size: 30),
                    if (ancho >= 1100) ...[
                      const SizedBox(width: 8),
                      Text('Foodzy',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinos)
                  NavigationRailDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: Text(d.$3),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: cuerpo),
          ],
        ),
      );
    }

    return Scaffold(
      body: cuerpo,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: [
          for (final d in _destinos)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
            ),
        ],
      ),
    );
  }
}
