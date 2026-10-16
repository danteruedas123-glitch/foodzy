import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/features/nube/hogar.dart';

/// Hogares en memoria, con fallos que se pueden provocar a propósito.
class RepoFalso implements HogarRepository {
  final hogares = <String, Set<String>>{}; // id -> miembros
  final codigos = <String, String>{}; // código -> id del hogar
  final usuarios = <String, String>{}; // uid -> id de su hogar actual
  var _n = 0;

  /// `asignar` lanza error.
  bool fallaAsignar = false;

  /// `quitarMiembro` lanza error para este hogar.
  String? hogarQueNoSeDejaSalir;

  @override
  Future<Hogar?> hogarDe(String uid) async {
    final id = usuarios[uid];
    final miembros = id == null ? null : hogares[id];
    if (id == null || miembros == null || !miembros.contains(uid)) return null;
    return Hogar(id: id, codigo: _codigoDe(id), miembros: miembros.length);
  }

  String _codigoDe(String id) => codigos.entries.firstWhere((e) => e.value == id).key;

  @override
  Future<Hogar> crear({required String uid, String? nombre, String? email}) async {
    final id = 'hogar${++_n}';
    final codigo = 'COD${_n}XY';
    hogares[id] = {uid};
    codigos[codigo] = id;
    usuarios[uid] = id;
    return Hogar(id: id, codigo: codigo, miembros: 1);
  }

  @override
  Future<String?> hogarIdPorCodigo(String codigo) async => codigos[codigo];

  @override
  Future<void> agregarMiembro(String hogarId, String uid) async =>
      hogares[hogarId]!.add(uid);

  @override
  Future<void> quitarMiembro(String hogarId, String uid) async {
    if (hogarId == hogarQueNoSeDejaSalir) throw Exception('sin conexión');
    hogares[hogarId]!.remove(uid);
  }

  @override
  Future<void> asignar(String uid, String hogarId) async {
    if (fallaAsignar) throw Exception('sin conexión');
    usuarios[uid] = hogarId;
  }
}

void main() {
  late RepoFalso repo;
  late HogarService servicio;

  setUp(() {
    repo = RepoFalso();
    servicio = HogarService(repo);
  });

  group('asegurar', () {
    test('crea un hogar propio la primera vez y lo reutiliza después', () async {
      final primero = await servicio.asegurar(uid: 'ana');
      final segundo = await servicio.asegurar(uid: 'ana');

      expect(segundo.id, primero.id);
      expect(repo.hogares, hasLength(1));
      expect(primero.miembros, 1);
    });

    test('si ya no es miembro del hogar asignado, le crea uno nuevo', () async {
      final viejo = await servicio.asegurar(uid: 'ana');
      repo.hogares[viejo.id]!.remove('ana');

      final nuevo = await servicio.asegurar(uid: 'ana');

      expect(nuevo.id, isNot(viejo.id));
      expect(repo.hogares[nuevo.id], {'ana'});
    });
  });

  group('unirse', () {
    late Hogar ana;
    late Hogar luis;

    setUp(() async {
      ana = await servicio.asegurar(uid: 'ana');
      luis = await servicio.asegurar(uid: 'luis');
    });

    test('pasa a la persona al hogar nuevo y la saca del anterior', () async {
      await servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo);

      expect(repo.hogares[ana.id], {'ana', 'luis'});
      expect(repo.hogares[luis.id], isEmpty);
      expect(repo.usuarios['luis'], ana.id);
    });

    test('acepta el código en minúsculas y con espacios', () async {
      await servicio.unirse(uid: 'luis', actual: luis, codigo: '  ${ana.codigo.toLowerCase()} ');

      expect(repo.usuarios['luis'], ana.id);
    });

    test('un código incompleto, inexistente o del mismo hogar da un error claro', () async {
      for (final (codigo, mensaje) in [
        ('AB', 'Escribe el código completo.'),
        ('NOEXISTE', 'Ese código no existe. Revísalo con quien te invitó.'),
        (luis.codigo, 'Ya perteneces a ese hogar.'),
      ]) {
        await expectLater(
          servicio.unirse(uid: 'luis', actual: luis, codigo: codigo),
          throwsA(isA<HogarError>().having((e) => e.mensaje, 'mensaje', mensaje)),
        );
      }
      expect(repo.usuarios['luis'], luis.id);
      expect(repo.hogares[ana.id], {'ana'});
    });

    test('copia la despensa solo si se pide, del hogar viejo al nuevo', () async {
      final llamadas = <(String, String)>[];
      Future<void> copiar(String desde, String hacia) async => llamadas.add((desde, hacia));

      await servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo);
      expect(llamadas, isEmpty);

      // Vuelve a su hogar propio para repetir con copia.
      final otro = await servicio.asegurar(uid: 'sara');
      await servicio.unirse(uid: 'sara', actual: otro, codigo: ana.codigo, copiar: copiar);
      expect(llamadas, [(otro.id, ana.id)]);
    });

    test('si falla la copia, se deshace y queda en su hogar de antes', () async {
      Future<void> copiarRoto(String desde, String hacia) async => throw Exception('error');

      await expectLater(
        servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo, copiar: copiarRoto),
        throwsA(isA<HogarError>()),
      );

      expect(repo.hogares[ana.id], {'ana'}, reason: 'no debe quedar en el hogar nuevo');
      expect(repo.hogares[luis.id], {'luis'});
      expect(repo.usuarios['luis'], luis.id);
    });

    test('si falla guardar su hogar nuevo, se deshace y queda como estaba', () async {
      repo.fallaAsignar = true;

      await expectLater(
        servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo),
        throwsA(isA<HogarError>()),
      );

      expect(repo.hogares[ana.id], {'ana'});
      expect(repo.hogares[luis.id], {'luis'});
      expect(repo.usuarios['luis'], luis.id);
    });

    test('si no puede salir del hogar anterior, igual queda en el nuevo', () async {
      repo.hogarQueNoSeDejaSalir = luis.id;

      await servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo);

      expect(repo.usuarios['luis'], ana.id);
      expect(repo.hogares[ana.id], {'ana', 'luis'});
    });
  });

  group('salir', () {
    test('crea un hogar propio y deja al resto del grupo donde estaba', () async {
      final ana = await servicio.asegurar(uid: 'ana');
      final luis = await servicio.asegurar(uid: 'luis');
      await servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo);
      final compartido = (await repo.hogarDe('luis'))!;
      expect(compartido.miembros, 2);

      final propio = await servicio.salir(uid: 'luis', actual: compartido);

      expect(propio.id, isNot(compartido.id));
      expect(propio.miembros, 1);
      expect(repo.hogares[compartido.id], {'ana'});
      expect(repo.usuarios['luis'], propio.id);
    });

    test('si es la única persona del hogar no crea nada y devuelve el mismo', () async {
      final ana = await servicio.asegurar(uid: 'ana');

      final resultado = await servicio.salir(uid: 'ana', actual: ana);

      expect(resultado.id, ana.id);
      expect(repo.hogares, hasLength(1));
    });

    test('si no puede salir del anterior, igual queda con su hogar propio', () async {
      final ana = await servicio.asegurar(uid: 'ana');
      final luis = await servicio.asegurar(uid: 'luis');
      await servicio.unirse(uid: 'luis', actual: luis, codigo: ana.codigo);
      final compartido = (await repo.hogarDe('luis'))!;
      repo.hogarQueNoSeDejaSalir = compartido.id;

      final propio = await servicio.salir(uid: 'luis', actual: compartido);

      expect(repo.usuarios['luis'], propio.id);
    });
  });
}
