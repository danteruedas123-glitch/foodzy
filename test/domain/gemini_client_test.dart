import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodzy/core/env.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Respuesta correcta de Gemini con una parte de razonamiento y el JSON.
http.Response respuestaOk(Object json) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'pensando...', 'thought': true},
                {'text': jsonEncode(json)},
              ],
            },
          },
        ],
      })),
      200,
    );

http.Response error(int codigo, String estado, String mensaje) => http.Response(
      jsonEncode({
        'error': {'code': codigo, 'status': estado, 'message': mensaje},
      }),
      codigo,
    );

String modeloDe(http.Request r) =>
    r.url.pathSegments.last.split(':').first;

void main() {
  // Cada prueba usa una clave distinta: así no hereda lo que el cliente
  // recordó de los modelos en la prueba anterior.
  var n = 0;
  String clave() => 'clave-${n++}';

  final primero = Env.geminiModelos[0];
  final segundo = Env.geminiModelos[1];

  test('pide el razonamiento mínimo y devuelve el JSON sin las partes de razonamiento',
      () async {
    late Map<String, dynamic> cuerpo;
    final cliente = GeminiClient(
      apiKey: clave(),
      cliente: MockClient((r) async {
        cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
        return respuestaOk({'ok': true});
      }),
    );

    expect(await cliente.pedir('hola'), {'ok': true});
    expect(cuerpo['generationConfig']['thinkingConfig'], {'thinkingLevel': 'minimal'});
  });

  /// El nivel pedido en una petición, o null si no pidió ninguno.
  String? nivelDe(http.Request r) {
    final config = (jsonDecode(r.body) as Map)['generationConfig'] as Map;
    return (config['thinkingConfig'] as Map?)?['thinkingLevel'] as String?;
  }

  test('si el modelo no admite "minimal", usa "low" y lo recuerda', () async {
    final pedidos = <String?>[];
    final cliente = GeminiClient(
      apiKey: clave(),
      cliente: MockClient((r) async {
        final nivel = nivelDe(r);
        pedidos.add(nivel);
        if (nivel == 'minimal') {
          return error(400, 'INVALID_ARGUMENT', 'Thinking level MINIMAL is not supported for this model.');
        }
        return respuestaOk({'ok': true});
      }),
    );

    await cliente.pedir('hola');
    expect(pedidos, ['minimal', 'low']);

    pedidos.clear();
    await cliente.pedir('otra vez');
    expect(pedidos, ['low'], reason: 'no repite el rechazo');
  });

  test('si el modelo no admite elegir el nivel, repite sin pedirlo', () async {
    final pedidos = <String?>[];
    final cliente = GeminiClient(
      apiKey: clave(),
      cliente: MockClient((r) async {
        final nivel = nivelDe(r);
        pedidos.add(nivel);
        if (nivel != null) {
          return error(400, 'INVALID_ARGUMENT', 'Thinking level is not supported for this model.');
        }
        return respuestaOk([1, 2]);
      }),
    );

    expect(await cliente.pedir('hola'), [1, 2]);
    expect(pedidos, ['minimal', 'low', null]);

    // La segunda vez ya no lo intenta con nivel.
    pedidos.clear();
    await cliente.pedir('otra vez');
    expect(pedidos, [null]);
  });

  test('un modelo que no existe no se vuelve a probar en la siguiente petición',
      () async {
    final modelos = <String>[];
    final cliente = GeminiClient(
      apiKey: clave(),
      cliente: MockClient((r) async {
        final m = modeloDe(r);
        modelos.add(m);
        if (m == primero) return error(404, 'NOT_FOUND', 'models/$m is not found');
        return respuestaOk({'ok': true});
      }),
    );

    await cliente.pedir('uno');
    expect(modelos, [primero, segundo]);

    modelos.clear();
    await cliente.pedir('dos');
    expect(modelos, [segundo], reason: 'empieza por el que respondió');
  });

  test('una clave inválida da un mensaje claro', () async {
    final cliente = GeminiClient(
      apiKey: clave(),
      cliente: MockClient((_) async =>
          error(400, 'INVALID_ARGUMENT', 'API key not valid. Please pass a valid API key.')),
    );

    expect(
      () => cliente.pedir('hola'),
      throwsA(isA<ScannerException>().having(
          (e) => e.mensaje, 'mensaje', contains('API Key de Gemini no es válida'))),
    );
  });
}
