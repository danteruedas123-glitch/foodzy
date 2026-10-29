import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/configuracion/presentation/providers/notificaciones_provider.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Avisos locales de "este alimento está por vencerse". Funciona en Android
/// e iOS; en web y escritorio no hace nada.
class NotificacionesService {
  NotificacionesService._();
  static final NotificacionesService instancia = NotificacionesService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _listo = false;

  /// Id del alimento de la notificación que el usuario acaba de tocar.
  final ValueNotifier<String?> alimentoTocado = ValueNotifier<String?>(null);

  bool get soportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'vencimientos',
      'Avisos de vencimiento',
      channelDescription: 'Te avisa cuando un alimento está por vencerse',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void>? _iniciando;

  /// Prepara el plugin una sola vez. Si se llama varias veces a la vez (el
  /// arranque, el permiso y la primera reprogramación), todas esperan la misma
  /// preparación en vez de repetirla.
  Future<void> iniciar() {
    if (!soportado || _listo) return Future.value();
    return _iniciando ??= _iniciar().whenComplete(() => _iniciando = null);
  }

  Future<void> _iniciar() async {
    try {
      tz.initializeTimeZones();
      try {
        final zona = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zona.identifier));
      } catch (_) {
        // Si no se conoce la zona, se queda en UTC.
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (r) {
          if (r.payload != null && r.payload!.isNotEmpty) {
            alimentoTocado.value = r.payload;
          }
        },
      );

      // App abierta desde cero al tocar una notificación.
      final lanzamiento = await _plugin.getNotificationAppLaunchDetails();
      if (lanzamiento?.didNotificationLaunchApp ?? false) {
        final payload = lanzamiento!.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) alimentoTocado.value = payload;
      }
      _listo = true;
    } catch (e) {
      debugPrint('No se pudo iniciar las notificaciones: $e');
    }
  }

  /// Pide permiso al sistema (Android 13+ e iOS). Devuelve si quedó concedido.
  Future<bool> pedirPermiso() async {
    if (!soportado) return false;
    await iniciar();
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        return await android?.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cola = Future.value();
  int? _ultimaFirma;

  /// Reprograma todos los avisos según la despensa y los ajustes actuales.
  /// Las llamadas se hacen una tras otra: dos a la vez se pisaban (una podía
  /// cancelar lo que la otra acababa de programar).
  Future<void> reprogramar(
    List<Alimento> alimentos,
    AjustesNotificaciones ajustes,
  ) =>
      _cola = _cola.then((_) => _reprogramar(alimentos, ajustes));

  Future<void> _reprogramar(
    List<Alimento> alimentos,
    AjustesNotificaciones ajustes,
  ) async {
    if (!soportado) return;
    await iniciar();
    if (!_listo) return;

    // Si no cambió nada que afecte a los avisos (por ejemplo, solo cambió la
    // cantidad de un alimento), no se cancelan y reprograman todos otra vez.
    final hoy = DateTime.now();
    final firma = Object.hashAll([
      ajustes.activas,
      ajustes.diasAviso,
      ajustes.hora,
      ajustes.minuto,
      hoy.year,
      hoy.month,
      hoy.day,
      for (final a in alimentos)
        if (a.estado is Disponible && !a.sinFechaVencimiento && !a.noVence)
          Object.hash(a.id, a.nombre, a.fechaVencimiento, a.origenFecha),
    ]);
    if (firma == _ultimaFirma) return;

    try {
      await _plugin.cancelAllPendingNotifications();
      _ultimaFirma = null;
      if (!ajustes.activas) {
        _ultimaFirma = firma;
        return;
      }

      final ahora = tz.TZDateTime.now(tz.local);
      for (final a in alimentos) {
        if (a.estado is! Disponible || a.sinFechaVencimiento || a.noVence) continue;

        final f = a.fechaVencimiento;
        final finDelDia = tz.TZDateTime(tz.local, f.year, f.month, f.day, 23, 59);
        if (finDelDia.isBefore(ahora)) continue; // ya venció

        var cuando = tz.TZDateTime(tz.local, f.year, f.month, f.day,
                ajustes.hora, ajustes.minuto)
            .subtract(Duration(days: ajustes.diasAviso));

        if (cuando.isBefore(ahora)) {
          // Ya estamos dentro del plazo de aviso: próximo momento a la hora elegida.
          cuando = tz.TZDateTime(tz.local, ahora.year, ahora.month, ahora.day,
              ajustes.hora, ajustes.minuto);
          if (cuando.isBefore(ahora)) cuando = cuando.add(const Duration(days: 1));
          if (cuando.isAfter(finDelDia)) continue;
        }

        final dias = DateTime(f.year, f.month, f.day)
            .difference(DateTime(cuando.year, cuando.month, cuando.day))
            .inDays;
        final cuandoVence = dias <= 0
            ? 'vence hoy'
            : dias == 1
                ? 'vence mañana'
                : 'vence en $dias días';

        await _plugin.zonedSchedule(
          id: a.id.hashCode & 0x3fffffff,
          title: a.origenFecha == FechaOrigen.estimada
              ? '⏰ ${a.nombre} podría estar por vencerse'
              : '⏰ ${a.nombre} está por vencerse',
          body: a.origenFecha == FechaOrigen.estimada
              ? 'Según lo estimado, $cuandoVence. Toca para confirmarlo.'
              : '${_mayus(cuandoVence)}. Toca para decidir qué hacer con él.',
          scheduledDate: cuando,
          notificationDetails: _detalles,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: a.id,
        );
      }
      _ultimaFirma = firma;
    } catch (e) {
      debugPrint('No se pudieron programar los avisos: $e');
    }
  }

  /// Muestra un aviso ahora mismo, para comprobar que todo funciona.
  Future<void> mostrarPrueba({String? alimentoId, String? nombre}) async {
    if (!soportado) return;
    await iniciar();
    await _plugin.show(
      id: 1,
      title: nombre != null
          ? '⏰ $nombre está por vencerse'
          : '✅ Las notificaciones funcionan',
      body: nombre != null
          ? 'Toca para decidir qué hacer con él.'
          : 'Foodzy te avisará antes de que se venza tu comida.',
      notificationDetails: _detalles,
      payload: alimentoId,
    );
  }

  String _mayus(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
