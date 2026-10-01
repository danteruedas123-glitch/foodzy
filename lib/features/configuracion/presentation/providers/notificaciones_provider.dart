import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';

class AjustesNotificaciones {
  const AjustesNotificaciones({
    this.activas = true,
    this.diasAviso = 2,
    this.hora = 9,
    this.minuto = 0,
  });

  final bool activas;

  /// Cuántos días antes del vencimiento se avisa.
  final int diasAviso;
  final int hora;
  final int minuto;

  AjustesNotificaciones copyWith({
    bool? activas,
    int? diasAviso,
    int? hora,
    int? minuto,
  }) =>
      AjustesNotificaciones(
        activas: activas ?? this.activas,
        diasAviso: diasAviso ?? this.diasAviso,
        hora: hora ?? this.hora,
        minuto: minuto ?? this.minuto,
      );
}

class NotificacionesNotifier extends Notifier<AjustesNotificaciones> {
  static const _kActivas = 'notif_activas';
  static const _kDias = 'notif_dias';
  static const _kHora = 'notif_hora';
  static const _kMinuto = 'notif_minuto';

  @override
  AjustesNotificaciones build() {
    final p = ref.watch(sharedPreferencesProvider);
    return AjustesNotificaciones(
      activas: p.getBool(_kActivas) ?? true,
      diasAviso: p.getInt(_kDias) ?? 2,
      hora: p.getInt(_kHora) ?? 9,
      minuto: p.getInt(_kMinuto) ?? 0,
    );
  }

  Future<void> cambiar(AjustesNotificaciones nuevo) async {
    final p = ref.read(sharedPreferencesProvider);
    await p.setBool(_kActivas, nuevo.activas);
    await p.setInt(_kDias, nuevo.diasAviso);
    await p.setInt(_kHora, nuevo.hora);
    await p.setInt(_kMinuto, nuevo.minuto);
    state = nuevo;
  }
}

final notificacionesProvider =
    NotifierProvider<NotificacionesNotifier, AjustesNotificaciones>(
  NotificacionesNotifier.new,
);
