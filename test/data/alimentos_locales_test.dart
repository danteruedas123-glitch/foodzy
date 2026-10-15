import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:foodzy/core/json.dart';
import 'package:foodzy/features/alimentos/data/alimentos_locales.dart';

const _json = '''
[
  {
    "id": "ali-001",
    "nombre": "Leche deslactosada",
    "categoria": "Lácteos",
    "cantidad": { "valor": 1.0, "unidad": "litro" },
    "fechaVencimiento": "2026-08-25T00:00:00Z",
    "estado": { "tipo": "disponible", "fechaIngreso": "2026-08-10T14:30:00Z" }
  }
]
''';

void main() {
  test('lee la lista completa del archivo', () async {
    final repo = AlimentosLocales(lector: (_) async => _json);
    expect((await repo.obtenerTodos()).length, 1);
  });

  test('busca por id y devuelve null cuando no está', () async {
    final repo = AlimentosLocales(lector: (_) async => _json);

    expect((await repo.obtenerPorId('ali-001'))?.nombre, 'Leche deslactosada');
    expect(await repo.obtenerPorId('no-existe'), isNull);
  });
  
  test('obtenerDisponibles devuelve solo los disponibles', () async {
    final repo = AlimentosLocales(lector: (_) async => _json);
    final disponibles = await repo.obtenerDisponibles();
    
    expect(disponibles.length, 1);
    expect(disponibles.first.id, 'ali-001');
  });

  test('un archivo que no es una lista se rechaza', () async {
    final repo = AlimentosLocales(lector: (_) async => '{"a": 1}');
    expect(repo.obtenerTodos(), throwsA(isA<CampoInvalido>()));
  });

  test('el asset declarado en pubspec existe y el modelo lo entiende', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    final repo = AlimentosLocales(lector: rootBundle.loadString);
    expect((await repo.obtenerTodos()).length, greaterThanOrEqualTo(3));
  });
}
