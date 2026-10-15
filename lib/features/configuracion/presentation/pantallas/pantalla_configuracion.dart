import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/notificaciones.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/nube/hogar_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/alimentos/presentation/pantallas/pantalla_historial.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/historial_ajustes_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/notificaciones_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/premium/insignias_premium.dart';
import 'package:foodzy/features/premium/pantalla_premium.dart';
import 'package:foodzy/features/premium/premium_provider.dart';

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
    Colors.lime,
  ];

  static const _fuentes = ['Poppins', 'Roboto', 'Lato', 'Montserrat'];

  Widget _titulo(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(
      t,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
  );

  Widget _tarjetaCuenta(ThemeData theme) {
    final auth = ref.watch(authProvider);
    final hogar = ref.watch(hogarProvider);

    Widget caja(List<Widget> hijos) => Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: hijos,
        ),
      ),
    );

    // Sin Firebase: todo vive en el teléfono.
    if (!Nube.disponible || !auth.esNube) {
      return caja([
        Row(
          children: [
            Icon(Icons.phone_android_rounded, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Modo local',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tus datos están solo en este teléfono. Conecta Firebase para tener copia de seguridad en la nube y compartir tu despensa con tu familia (mira el README del proyecto).',
          style: theme.textTheme.bodySmall,
        ),
      ]);
    }

    return caja([
      Row(
        children: [
          Icon(Icons.cloud_done_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              auth.email ?? 'Cuenta',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        'Tus datos se guardan en la nube y se sincronizan.',
        style: theme.textTheme.bodySmall,
      ),
      const Divider(height: 28),
      hogar.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(8),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No se pudo cargar el hogar: $e'),
            TextButton.icon(
              onPressed: () => ref.invalidate(hogarProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
            ),
          ],
        ),
        data: (h) {
          if (h == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu hogar compartido', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                h.miembros <= 1
                    ? 'Invita a tu familia con este código y compartirán la despensa y la lista de compras.'
                    : 'Compartes la despensa con ${h.miembros - 1} persona(s) más.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  h.codigo,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: h.codigo));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Código copiado')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Copiar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Únete a mi despensa en Foodzy con este código: ${h.codigo}',
                      ),
                    ),
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('Invitar'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: _unirseAHogar,
                    icon: const Icon(Icons.group_add_rounded, size: 18),
                    label: const Text('Unirme con un código'),
                  ),
                  if (h.miembros > 1)
                    TextButton.icon(
                      onPressed: _salirDelHogar,
                      icon: Icon(
                        Icons.exit_to_app_rounded,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Salir del hogar',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ]);
  }

  Future<void> _unirseAHogar() async {
    final codigo = TextEditingController();
    var copiar = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Unirme a un hogar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codigo,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Código de 6 letras',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: copiar,
                onChanged: (v) => setD(() => copiar = v ?? true),
                title: const Text('Llevar mi despensa actual al hogar'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Unirme'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(hogarProvider.notifier)
          .unirse(codigo.text, copiarMisDatos: copiar);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Listo! Ahora compartes la despensa.')),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _salirDelHogar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir del hogar?'),
        content: const Text(
          'Dejarás de ver la despensa compartida y empezarás con una despensa vacía propia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(hogarProvider.notifier).salir();
  }

  Widget _tarjetaPremium(ThemeData theme) {
    final p = ref.watch(premiumProvider);
    final cs = theme.colorScheme;
    void abrir() => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PantallaPremium()));

    if (p.premium) {
      const tinta = TextStyle(color: OroPremium.tinta);
      return Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: OroPremium.degradado),
          child: ListTile(
            leading: const CoronaPremium(tamano: 30),
            title: Text(
              'Foodzy Premium',
              style: tinta.copyWith(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('IA sin límite activada', style: tinta),
            trailing: const Icon(Icons.chevron_right, color: OroPremium.tinta),
            onTap: abrir,
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.workspace_premium, color: cs.onPrimaryContainer),
        title: Text(
          'Hazte Premium',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: cs.onPrimaryContainer,
          ),
        ),
        subtitle: Text(
          'Te quedan ${p.restantes} de $limiteIAGratis usos de IA este mes',
          style: TextStyle(color: cs.onPrimaryContainer),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
        onTap: abrir,
      ),
    );
  }

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
            const Text(
              'Lo que consumes o desechas sale de tu despensa y pasa al historial.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Conservar el historial durante:',
              style: theme.textTheme.bodySmall,
            ),
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
                      await ref
                          .read(alimentosProvider.notifier)
                          .limpiarHistorial(d);
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
                MaterialPageRoute(builder: (_) => const PantallaHistorial()),
              ),
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
              title: const Text(
                'Avisarme antes de que venza',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                servicio.soportado
                    ? 'Una notificación por cada alimento que está por vencerse.'
                    : 'Disponible en el celular (Android o iOS).',
              ),
              value: n.activas,
              onChanged: (v) async {
                if (v) await servicio.pedirPermiso();
                await notifier.cambiar(n.copyWith(activas: v));
              },
            ),
            if (n.activas) ...[
              const SizedBox(height: 8),
              Text(
                'Avisar con anticipación',
                style: theme.textTheme.labelLarge,
              ),
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
                    helpText: 'Hora del aviso',
                  );
                  if (t != null) {
                    await notifier.cambiar(
                      n.copyWith(hora: t.hour, minuto: t.minute),
                    );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Activa los permisos de notificación de Foodzy en los ajustes del teléfono.',
                        ),
                      ),
                    );
                    return;
                  }
                  // La prueba abre el aviso del alimento que vence antes.
                  final lista =
                      (ref.read(alimentosProvider).value ?? const [])
                          .where(
                            (a) =>
                                a.estado is Disponible &&
                                !a.sinFechaVencimiento,
                          )
                          .toList()
                        ..sort(
                          (a, b) =>
                              a.fechaVencimiento.compareTo(b.fechaVencimiento),
                        );
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
        16,
        MediaQuery.of(context).padding.top + 16,
        16,
        120,
      ),
      children: [
        Row(
          children: [
            const AvatarUsuario(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NombreConInsignia(
                    usuario,
                    estilo: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Tu despensa inteligente',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _tarjetaPremium(theme),
        _titulo('Inteligencia artificial'),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
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
                      icon: Icon(
                        _oculta
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () => setState(() => _oculta = !_oculta),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    await ref
                        .read(apiKeyProvider.notifier)
                        .guardar(_clave.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Clave guardada en este dispositivo.'),
                        ),
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
        _titulo('Cuenta y hogar'),
        _tarjetaCuenta(theme),
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
              label: Text('Auto'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode_rounded),
              label: Text('Claro'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode_rounded),
              label: Text('Oscuro'),
            ),
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
                        ? Border.all(
                            color: theme.colorScheme.onSurface,
                            width: 3,
                          )
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
          label: Text(
            'Cerrar sesión',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
