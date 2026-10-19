import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/configuracion/presentation/providers/theme_provider.dart';
import 'package:foodzy/features/nube/data/firestore_alimentos.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hace de Firestore sin conectarse a nada. Guarda en memoria o, si se le
/// pide, rechaza los cambios como lo harían las reglas de seguridad.
class NubeFalsa extends FirestoreAlimentosRepository {
  NubeFalsa(this.guardado) : super('hogar-de-prueba');

  /// Lo que de verdad quedó guardado "en el servidor".
  List<Alimento> guardado;
  bool rechazar = false;

  @override
  Future<List<Alimento>> obtenerTodos() async => [...guardado];

  @override
  Stream<List<Alimento>> flujo() => const Stream.empty();

  @override
  Future<void> guardar(Alimento alimento) async {
    if (rechazar) throw Exception('permission-denied');
    guardado = [for (final a in guardado) a.id == alimento.id ? alimento : a];
  }

  @override
  Future<void> eliminar(String id) async {
    if (rechazar) throw Exception('permission-denied');
    guardado = guardado.where((a) => a.id != id).toList();
  }
}

/// Una cuenta en la nube, sin Firebase.
class CuentaFalsa extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: true, uid: 'persona-1');
}

final leche = Alimento(
  id: 'leche',
  nombre: 'Leche',
  categoria: 'Lácteos',
  cantidad: const Cantidad(valor: 1, unidad: 'L'),
  fechaVencimiento: DateTime(2026, 12, 1),
  estado: Disponible(DateTime(2026, 10, 1)),
);

void main() {
  late NubeFalsa nube;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    nube = NubeFalsa([leche]);
    c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authProvider.overrideWith(CuentaFalsa.new),
      alimentosRepositoryProvider.overrideWith((ref) async => nube),
    ]);
    addTearDown(c.dispose);
    await c.read(alimentosProvider.future);
  });

  /// Deja que terminen los guardados que se lanzaron sin esperar.
  Future<void> esperarNube() => Future<void>.delayed(Duration.zero);

  final consumida = leche.copyWith(estado: Consumido(DateTime(2026, 10, 18)));

  test('si la nube acepta el cambio, se ve y no hay aviso', () async {
    await c.read(alimentosProvider.notifier).actualizar(consumida);
    await esperarNube();

    expect(c.read(alimentosProvider).value, [consumida]);
    expect(nube.guardado, [consumida]);
    expect(c.read(avisoGuardadoProvider), isNull);
  });

  test('si la nube rechaza un cambio, avisa y vuelve a lo guardado', () async {
    nube.rechazar = true;

    await c.read(alimentosProvider.notifier).actualizar(consumida);
    expect(c.read(alimentosProvider).value, [consumida],
        reason: 'el cambio se ve al instante');

    await esperarNube();

    expect(c.read(avisoGuardadoProvider)?.mensaje,
        contains('No se pudo guardar el último cambio'));
    expect(c.read(alimentosProvider).value, [leche],
        reason: 'no se queda mostrando algo que no se guardó');
  });

  test('si la nube rechaza un borrado, el alimento vuelve a aparecer', () async {
    nube.rechazar = true;

    await c.read(alimentosProvider.notifier).eliminar('leche');
    expect(c.read(alimentosProvider).value, isEmpty);

    await esperarNube();

    expect(c.read(alimentosProvider).value, [leche]);
    expect(c.read(avisoGuardadoProvider), isNotNull);
  });

  test('dos fallos seguidos generan dos avisos distintos', () async {
    nube.rechazar = true;
    final avisos = <AvisoGuardado?>[];
    c.listen(avisoGuardadoProvider, (_, a) => avisos.add(a));

    await c.read(alimentosProvider.notifier).actualizar(consumida);
    await esperarNube();
    await c.read(alimentosProvider.notifier).actualizar(consumida);
    await esperarNube();

    expect(avisos.length, 2);
  });
}
