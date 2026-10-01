import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/notificaciones.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_historial.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/historial_ajustes_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/notificaciones_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

/// Ajustes: apariencia, clave de la IA y sesión. Sirve como pestaña o como
/// pantalla independiente.
class PantallaConfiguracion extends ConsumerStatefulWidget {
  const PantallaConfiguracion({super.key});

  @override
  ConsumerState<PantallaConfiguracion> createState() =>
      _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends ConsumerState<PantallaConfiguracion> {
  late final TextEditingController _clave;
  bool _oculta = true;

  @override
  void initState() {
    super.initState();
    _clave = TextEditingController(text: ref.read(apiKeyProvider));
  }

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  static const _colores = [
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.redAccent,
    Colors.pink,
    Colors.indigo,
  ];

  static const _fuentes = ['Poppins', 'Roboto', 'Lato', 'Montserrat'];

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Text(t,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
      );

  Widget _tarjetaHistorial(ThemeData theme) {
    final dias = ref.watch(historialDiasProvider);

    String etiqueta(int d) => switch (d) {
          0 => 'Siempre',
          30 => '30 días',
          60 => '60 días',
          90 => '90 días',
          _ => '$d días',
        };

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lo que consumes o desechas sale de tu despensa y pasa al historial.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Conservar el historial durante:', style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                for (final d in const [30, 60, 90, 180, 0])
                  ChoiceChip(
                    label: Text(d == 180 ? '6 meses' : etiqueta(d)),
                    selected: dias == d,
                    onSelected: (_) async {
                      await ref.read(historialDiasProvider.notifier).cambiar(d);
                      await ref.read(alimentosProvider.notifier).limpiarHistorial(d);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              dias == 0
                  ? 'No se borrará nada automáticamente.'
                  : 'Lo más antiguo se borra solo, junto con sus fotos.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PantallaHistorial())),
              icon: const Icon(Icons.history_rounded),
              label: const Text('Ver historial'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaNotificaciones(ThemeData theme) {
    final servicio = NotificacionesService.instancia;
    final n = ref.watch(notificacionesProvider);
    final notifier = ref.read(notificacionesProvider.notifier);
    final hora = TimeOfDay(hour: n.hora, minute: n.minuto);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Avisarme antes de que venza',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(servicio.soportado
                  ? 'Una notificación por cada alimento que está por vencerse.'
                  : 'Disponible en el celular (Android o iOS).'),
              value: n.activas,
              onChanged: (v) async {
                if (v) await servicio.pedirPermiso();
                await notifier.cambiar(n.copyWith(activas: v));
              },
            ),
            if (n.activas) ...[
              const SizedBox(height: 8),
              Text('Avisar con anticipación',
                  style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [1, 2, 3, 5])
                    ChoiceChip(
                      label: Text(d == 1 ? '1 día' : '$d días'),
                      selected: n.diasAviso == d,
                      onSelected: (_) =>
                          notifier.cambiar(n.copyWith(diasAviso: d)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                      context: context,
                      initialTime: hora,
                      helpText: 'Hora del aviso');
                  if (t != null) {
                    await notifier.cambiar(
                        n.copyWith(hora: t.hour, minuto: t.minute));
                  }
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Hora del aviso: ${hora.format(context)}'),
              ),
            ],
            if (servicio.soportado) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () async {
                  final ok = await servicio.pedirPermiso();
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Activa los permisos de notificación de Foodzy en los ajustes del teléfono.'),
                    ));
                    return;
                  }
                  // La prueba abre el aviso del alimento que vence antes.
                  final lista = (ref.read(alimentosProvider).value ?? const [])
                      .where((a) =>
                          a.estado is Disponible && !a.sinFechaVencimiento)
                      .toList()
                    ..sort((a, b) =>
                        a.fechaVencimiento.compareTo(b.fechaVencimiento));
                  await servicio.mostrarPrueba(
                    alimentoId: lista.isEmpty ? null : lista.first.id,
                    nombre: lista.isEmpty ? null : lista.first.nombre,
                  );
                },
                icon: const Icon(Icons.notifications_active_rounded),
                label: const Text('Probar una notificación ahora'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ajustes = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final claveGuardada = ref.watch(apiKeyProvider);
    final usuario = ref.watch(authProvider).userName ?? 'Usuario';

    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 16, 16, 120),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                usuario.isEmpty ? 'U' : usuario[0].toUpperCase(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usuario,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900)),
                  Text('Tu despensa inteligente', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        _titulo('Inteligencia artificial'),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      claveGuardada.isEmpty
                          ? Icons.key_off_rounded
                          : Icons.verified_rounded,
                      color: claveGuardada.isEmpty
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        claveGuardada.isEmpty
                            ? 'Falta la API Key de Gemini'
                            : 'API Key de Gemini configurada',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Es lo que lee tus fotos y facturas. Obtén una gratis en aistudio.google.com.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clave,
                  obscureText: _oculta,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    hintText: 'Pega tu API Key',
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_oculta
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded),
                      onPressed: () => setState(() => _oculta = !_oculta),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await ref.read(apiKeyProvider.notifier).guardar(_clave.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clave guardada en este dispositivo.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Guardar clave'),
                ),
              ],
            ),
          ),
        ),
        _titulo('Notificaciones'),
        _tarjetaNotificaciones(theme),
        _titulo('Historial'),
        _tarjetaHistorial(theme),
        _titulo('Apariencia'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_rounded),
                label: Text('Auto')),
            ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_rounded),
                label: Text('Claro')),
            ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_rounded),
                label: Text('Oscuro')),
          ],
          selected: {ajustes.themeMode},
          onSelectionChanged: (s) => notifier.changeMode(s.first),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in _colores)
              GestureDetector(
                onTap: () => notifier.changeColor(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: ajustes.primaryColor.toARGB32() == c.toARGB32()
                        ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                        : null,
                  ),
                  child: ajustes.primaryColor.toARGB32() == c.toARGB32()
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          children: [
            for (final f in _fuentes)
              ChoiceChip(
                label: Text(f),
                selected: ajustes.fontFamily == f,
                onSelected: (_) => notifier.changeFont(f),
              ),
          ],
        ),
        _titulo('Cuenta'),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
          icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
          label: Text('Cerrar sesión', style: TextStyle(color: theme.colorScheme.error)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }
}
