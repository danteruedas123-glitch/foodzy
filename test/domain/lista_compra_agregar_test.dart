import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/compras/domain/item_compra.dart';
import 'package:foodzy/features/compras/presentation/lista_compra_provider.dart';

/// Lista en memoria para probar sin teléfono ni nube.
class RepoEnMemoria implements ListaCompraRepository {
  final items = <String, ItemCompra>{};

  @override
  Future<List<ItemCompra>> obtener() async => items.values.toList();

  @override
  Future<void> guardar(ItemCompra item) async => items[item.id] = item;

  @override
  Future<void> eliminar(String id) async => items.remove(id);
}

({String nombre, String? cantidad}) producto(String nombre, [String? cantidad]) =>
    (nombre: nombre, cantidad: cantidad);

void main() {
  late RepoEnMemoria repo;
  late ProviderContainer contenedor;

  Future<ListaCompraNotifier> preparar() async {
    contenedor = ProviderContainer(overrides: [
      listaCompraRepositoryProvider.overrideWith((ref) async => repo),
    ]);
    addTearDown(contenedor.dispose);
    await contenedor.read(listaCompraProvider.future);
    return contenedor.read(listaCompraProvider.notifier);
  }

  setUp(() => repo = RepoEnMemoria());

  group('ListaCompraNotifier.agregarVarios', () {
    test('añade los productos nuevos y dice cuántos fueron', () async {
      final lista = await preparar();

      final nuevos = await lista.agregarVarios([
        producto('Leche', '1 L'),
        producto('Tomate', '3 unidades'),
      ]);

      expect(nuevos, 2);
      expect(repo.items.values.map((i) => i.nombre), containsAll(['Leche', 'Tomate']));
      expect(repo.items.values.firstWhere((i) => i.nombre == 'Leche').cantidad, '1 L');
    });

    test('no repite lo que ya está en la lista sin comprar', () async {
      repo.items['1'] = ItemCompra(id: '1', nombre: 'Leche', creado: DateTime(2026, 10, 1));
      final lista = await preparar();

      final nuevos = await lista.agregarVarios([
        producto('Leche'),
        producto('Cebolla'),
      ]);

      expect(nuevos, 1);
      expect(repo.items, hasLength(2));
    });

    test('compara sin importar mayúsculas ni tildes', () async {
      repo.items['1'] = ItemCompra(id: '1', nombre: 'Limón', creado: DateTime(2026, 10, 1));
      final lista = await preparar();

      final nuevos = await lista.agregarVarios([producto('limon'), producto('LIMÓN')]);

      expect(nuevos, 0);
      expect(repo.items, hasLength(1));
    });

    test('un producto ya comprado sí se vuelve a añadir', () async {
      repo.items['1'] = ItemCompra(
        id: '1',
        nombre: 'Arroz',
        comprado: true,
        creado: DateTime(2026, 10, 1),
      );
      final lista = await preparar();

      final nuevos = await lista.agregarVarios([producto('Arroz')]);

      expect(nuevos, 1);
      expect(repo.items, hasLength(2));
    });

    test('no repite dentro del mismo lote', () async {
      final lista = await preparar();

      final nuevos = await lista.agregarVarios([
        producto('Sal'),
        producto('sal'),
        producto('Pimienta'),
      ]);

      expect(nuevos, 2);
      expect(repo.items, hasLength(2));
    });

    test('ignora nombres vacíos', () async {
      final lista = await preparar();

      final nuevos = await lista.agregarVarios([producto(''), producto('   ')]);

      expect(nuevos, 0);
      expect(repo.items, isEmpty);
    });

    test('cada producto recibe un id distinto aunque se añadan seguidos', () async {
      final lista = await preparar();

      await lista.agregarVarios([for (var i = 0; i < 20; i++) producto('Producto $i')]);

      expect(repo.items, hasLength(20));
    });
  });
}
