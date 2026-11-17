import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/core/env.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';

/// Una petición que el cliente le hizo al transporte (Firebase en la app).
typedef Pedido = ({String modelo, String? nivel});

/// Transporte de mentira: anota cada pedido y responde lo que diga [responder]
/// (un texto, o lanza un [ErrorIA]).
TransporteIA falso(List<Pedido> pedidos, String Function(Pedido p) responder) =>
    (modelo, partes, {required nivel}) async {
      final p = (modelo: modelo, nivel: nivel);
      pedidos.add(p);
      return responder(p);
    };

void main() {
  // Lo aprendido de los modelos es compartido: cada prueba empieza de cero.
  setUp(GeminiClient.olvidar);

  final primero = Env.geminiModelos[0];
  final segundo = Env.geminiModelos[1];

  test('pide el razonamiento mínimo y devuelve el JSON', () async {
    final pedidos = <Pedido>[];
    final cliente = GeminiClient(
      transporte: falso(pedidos, (_) => jsonEncode({'ok': true})),
    );

    expect(await cliente.pedir('hola'), {'ok': true});
    expect(pedidos, [(modelo: primero, nivel: 'minimal')]);
  });

  test('quita los ``` que a veces rodean el JSON', () async {
    final cliente = GeminiClient(
      transporte: falso([], (_) => '```json\n{"ok": 1}\n```'),
    );
    expect(await cliente.pedir('hola'), {'ok': 1});
  });

  test('si el modelo no admite "minimal", usa "low" y lo recuerda', () async {
    final pedidos = <Pedido>[];
    final cliente = GeminiClient(
      transporte: falso(pedidos, (p) {
        if (p.nivel == 'minimal') {
          throw const ErrorIA(400, 'Thinking level MINIMAL is not supported for this model.');
        }
        return jsonEncode({'ok': true});
      }),
    );

    await cliente.pedir('hola');
    expect(pedidos.map((p) => p.nivel), ['minimal', 'low']);

    pedidos.clear();
    await cliente.pedir('otra vez');
    expect(pedidos.map((p) => p.nivel), ['low'], reason: 'no repite el rechazo');
  });

  test('si el modelo no admite elegir el nivel, repite sin pedirlo', () async {
    final pedidos = <Pedido>[];
    final cliente = GeminiClient(
      transporte: falso(pedidos, (p) {
        if (p.nivel != null) {
          throw const ErrorIA(400, 'Thinking level is not supported for this model.');
        }
        return jsonEncode([1, 2]);
      }),
    );

    expect(await cliente.pedir('hola'), [1, 2]);
    expect(pedidos.map((p) => p.nivel), ['minimal', 'low', null]);

    // La segunda vez ya no lo intenta con nivel.
    pedidos.clear();
    await cliente.pedir('otra vez');
    expect(pedidos.map((p) => p.nivel), [null]);
  });

  test('un modelo que no existe no se vuelve a probar en la siguiente petición',
      () async {
    final pedidos = <Pedido>[];
    final cliente = GeminiClient(
      transporte: falso(pedidos, (p) {
        if (p.modelo == primero) throw ErrorIA(404, 'models/$primero is not found');
        return jsonEncode({'ok': true});
      }),
    );

    await cliente.pedir('uno');
    expect(pedidos.map((p) => p.modelo), [primero, segundo]);

    pedidos.clear();
    await cliente.pedir('dos');
    expect(pedidos.map((p) => p.modelo), [segundo], reason: 'empieza por el que respondió');
  });

  test('si la IA no está activada en Firebase, prueba cada modelo una vez y avisa',
      () async {
    final pedidos = <Pedido>[];
    final cliente = GeminiClient(
      transporte: falso(pedidos, (_) => throw const ErrorIA(403,
          'Enable Firebase AI Logic in your Firebase project by visiting https://console.firebase.google.com/project/x/ailogic')),
    );

    await expectLater(
      () => cliente.pedir('hola'),
      throwsA(isA<ScannerException>()
          .having((e) => e.mensaje, 'mensaje', contains('no está activada'))),
    );
    expect(pedidos.map((p) => p.modelo), Env.geminiModelos);
  });

  test('si un modelo da 403 mientras Firebase propaga la activación, usa el siguiente',
      () async {
    final cliente = GeminiClient(
      transporte: falso([], (p) {
        if (p.modelo == primero) throw const ErrorIA(403, 'has not been used in project 1');
        return '{"ok": true}';
      }),
    );
    expect(await cliente.pedir('hola'), {'ok': true});
  });

  test('sin cupo en todos los modelos da un mensaje claro', () async {
    final cliente = GeminiClient(
      transporte: falso([], (_) => throw const ErrorIA(429, 'Quota exceeded')),
    );

    await expectLater(
      () => cliente.pedir('hola'),
      throwsA(isA<ScannerException>()
          .having((e) => e.mensaje, 'mensaje', contains('límite de uso'))),
    );
  });

  test('un modelo sin cupo pasa al final de la lista por un rato', () async {
    final pedidos = <Pedido>[];
    final cliente = GeminiClient(
      transporte: falso(pedidos, (p) {
        if (p.modelo == primero) throw const ErrorIA(429, 'Quota exceeded');
        return '{"ok": true}';
      }),
    );

    await cliente.pedir('uno', preciso: true); // aprende que [primero] no tiene cupo
    pedidos.clear();
    await cliente.pedir('dos');
    expect(pedidos.first.modelo, isNot(primero), reason: 'no pierde tiempo en el que no tiene cupo');
  });

  test('el cupo del plan gratuito se cuenta solo si la IA respondió', () async {
    var registrados = 0;
    final cuota = CuotaIA(verificar: () {}, registrar: () async => registrados++);

    await GeminiClient(cuota: cuota, transporte: falso([], (_) => '{"ok": true}'))
        .pedir('bien');
    expect(registrados, 1);

    await expectLater(
      () => GeminiClient(
        cuota: cuota,
        transporte: falso([], (_) => throw const ErrorIA(429, 'Quota exceeded')),
      ).pedir('mal'),
      throwsA(isA<ScannerException>()),
    );
    expect(registrados, 1, reason: 'un fallo no gasta un uso');
  });

  group('código de los errores de Firebase', () {
    test('se deduce del mensaje', () {
      expect(GeminiClient.codigoDe('models/gemini-x is not found for API version v1beta'), 404);
      expect(GeminiClient.codigoDe('The model is overloaded. Please try again later.'), 503);
      expect(GeminiClient.codigoDe('This model is currently experiencing high demand.'), 503);
      expect(GeminiClient.codigoDe('RESOURCE_EXHAUSTED: quota'), 429);
      expect(GeminiClient.codigoDe('Thinking level is not supported'), 400);
      expect(
          GeminiClient.codigoDe('Firebase AI Logic API has not been used in project 1 before '
              'or it is disabled. Enable it by visiting https://console.developers.google.com/'
              'apis/api/firebasevertexai.googleapis.com/overview?project=1 then retry.'),
          403);
      expect(GeminiClient.codigoDe('algo raro'), 0);
    });
  });
}
