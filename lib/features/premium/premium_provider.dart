import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/env.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Usos de IA (escaneos y recetas) que tiene el plan gratuito cada mes.
const int limiteIAGratis = 15;

enum PlanPremium {
  mensual('Mensual', r'$2.99', 'al mes'),
  anual('Anual', r'$24.99', 'al año · ahorras 30%');

  const PlanPremium(this.nombre, this.precio, this.periodo);
  final String nombre;
  final String precio;
  final String periodo;
}

class PremiumState {
  const PremiumState({required this.premium, required this.usados});

  final bool premium;
  final int usados;

  int get restantes => (limiteIAGratis - usados).clamp(0, limiteIAGratis);
  bool get agotado => !premium && usados >= limiteIAGratis;
}

/// Cobro de suscripciones. Aquí se conecta la tienda real (RevenueCat,
/// Google Play Billing o App Store); el resto de la app no cambia.
abstract class BillingService {
  Future<bool> comprar(PlanPremium plan);
  Future<bool> restaurar();

  /// Si la tienda dice que la suscripción sigue vigente; `null` si no se pudo
  /// consultar (sin red o sin tienda), para no quitar Premium por error.
  Future<bool?> premiumVigente();
}

/// Suscripciones reales con RevenueCat (Google Play / App Store).
class BillingRevenueCat implements BillingService {
  BillingRevenueCat(String apiKey) {
    _listo = _iniciar(apiKey);
  }

  late final Future<void> _listo;

  Future<void> _iniciar(String apiKey) =>
      Purchases.configure(PurchasesConfiguration(apiKey));

  bool _activo(CustomerInfo info) =>
      info.entitlements.active.containsKey(Env.revenueCatEntitlement);

  @override
  Future<bool> comprar(PlanPremium plan) async {
    await _listo;
    final ofertas = await Purchases.getOfferings();
    final actual = ofertas.current;
    final paquete = plan == PlanPremium.mensual ? actual?.monthly : actual?.annual;
    if (paquete == null) return false;
    try {
      final r = await Purchases.purchase(PurchaseParams.package(paquete));
      return _activo(r.customerInfo);
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError) {
        return false;
      }
      rethrow;
    }
  }

  @override
  Future<bool> restaurar() async {
    await _listo;
    return _activo(await Purchases.restorePurchases());
  }

  @override
  Future<bool?> premiumVigente() async {
    try {
      await _listo;
      return _activo(await Purchases.getCustomerInfo());
    } catch (_) {
      return null;
    }
  }
}

/// Mientras no haya tienda configurada: "compra" al instante, sin cobrar,
/// solo en debug o con COMPRAS_PRUEBA=true. Una versión publicada sin esa
/// bandera nunca activa Premium gratis.
class BillingSimulado implements BillingService {
  static bool get habilitado => kDebugMode || Env.comprasDePrueba;

  @override
  Future<bool> comprar(PlanPremium plan) async => habilitado;

  @override
  Future<bool> restaurar() async => false;

  @override
  Future<bool?> premiumVigente() async => null;
}

final billingProvider = Provider<BillingService>((ref) {
  final clave = switch (defaultTargetPlatform) {
    _ when kIsWeb => '',
    TargetPlatform.android => Env.revenueCatAndroidKey,
    TargetPlatform.iOS => Env.revenueCatIosKey,
    _ => '',
  };
  return clave.isEmpty ? BillingSimulado() : BillingRevenueCat(clave);
});

class PremiumNotifier extends Notifier<PremiumState> {
  static const _kPremium = 'premium_activo';
  static const _kUsosPrefijo = 'ia_usos_';

  String get _kUsos {
    final h = DateTime.now();
    return '$_kUsosPrefijo${h.year}-${h.month.toString().padLeft(2, '0')}';
  }

  @override
  PremiumState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    Future.microtask(sincronizar);
    return PremiumState(
      premium: prefs.getBool(_kPremium) ?? false,
      usados: prefs.getInt(_kUsos) ?? 0,
    );
  }

  /// Lanza si el plan gratuito ya gastó sus usos del mes.
  void verificarCupo() {
    // Se relee por si cambió el mes desde que se creó el estado.
    final usados = ref.read(sharedPreferencesProvider).getInt(_kUsos) ?? 0;
    if (!state.premium && usados >= limiteIAGratis) {
      throw const ScannerException(
        'Usaste tus $limiteIAGratis usos de IA gratis de este mes. '
        'Hazte Premium en Ajustes para seguir sin límite.',
      );
    }
  }

  Future<void> registrarUso() async {
    if (state.premium) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final usados = (prefs.getInt(_kUsos) ?? 0) + 1;
    await prefs.setInt(_kUsos, usados);
    state = PremiumState(premium: false, usados: usados);
  }

  /// Al abrir la app: confirma con la tienda que Premium sigue vigente
  /// (renovó, canceló o venció).
  Future<void> sincronizar() async {
    final vigente = await ref.read(billingProvider).premiumVigente();
    if (vigente != null && vigente != state.premium) await _fijarPremium(vigente);
  }

  Future<bool> comprar(PlanPremium plan) async {
    final ok = await ref.read(billingProvider).comprar(plan);
    if (ok) await _fijarPremium(true);
    return ok;
  }

  /// Solo modo de prueba: vuelve al plan gratis para repetir el flujo.
  Future<void> cancelarPrueba() => _fijarPremium(false);

  Future<bool> restaurar() async {
    final ok = await ref.read(billingProvider).restaurar();
    if (ok) await _fijarPremium(true);
    return ok;
  }

  Future<void> _fijarPremium(bool valor) async {
    await ref.read(sharedPreferencesProvider).setBool(_kPremium, valor);
    state = PremiumState(premium: valor, usados: state.usados);
  }
}

final premiumProvider =
    NotifierProvider<PremiumNotifier, PremiumState>(PremiumNotifier.new);

/// Cupo que se le pasa a [GeminiClient] para limitar el plan gratuito.
final cuotaIAProvider = Provider<CuotaIA>((ref) {
  final n = ref.read(premiumProvider.notifier);
  return CuotaIA(verificar: n.verificarCupo, registrar: n.registrarUso);
});
