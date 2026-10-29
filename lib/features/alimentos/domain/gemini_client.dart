import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:foodzy/core/env.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ScannerException implements Exception {
  const ScannerException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Cupo de usos de IA (plan gratuito): se verifica antes de pedir y se
/// registra solo si la IA respondió.
class CuotaIA {
  const CuotaIA({required this.verificar, required this.registrar});
  final void Function() verificar;
  final Future<void> Function() registrar;
}

/// Error de la API de Gemini, con su código HTTP y el mensaje que envió.
class _ErrorGemini implements Exception {
  const _ErrorGemini(this.codigo, this.mensaje);
  final int codigo;
  final String mensaje;
  @override
  String toString() => '$codigo: $mensaje';
}

/// Cliente común de Gemini: prueba una cadena de modelos con reintentos y
/// devuelve el JSON ya decodificado. Lo usan el escáner y las recetas.
///
/// Habla con la API REST directamente (con `http`) para poder pedir el nivel
/// de razonamiento más bajo que acepte cada modelo: leer una foto o una
/// factura no necesita que el modelo "piense" a fondo, y hacerlo era lo que
/// más demoraba cada respuesta.
class GeminiClient {
  GeminiClient({required this.apiKey, this.cuota, http.Client? cliente})
      : _http = cliente ?? _compartido;

  /// Una sola conexión para toda la app: las peticiones seguidas reutilizan
  /// la conexión segura ya abierta en vez de negociar una nueva cada vez.
  static final _compartido = http.Client();

  final String apiKey;
  final CuotaIA? cuota;
  final http.Client _http;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  // Lo que se aprende de los modelos se recuerda entre peticiones (mientras
  // la app esté abierta y no cambie la clave), para no repetir en cada
  // escaneo intentos que ya se sabe que fallan.
  static String? _claveRecordada;

  /// El último modelo que respondió, por modo (rápido o preciso).
  static final _ultimoQueRespondio = <bool, String>{};
  static final _noExisten = <String>{};

  /// Niveles de razonamiento, del más rápido al más lento. No todos los
  /// modelos admiten todos (gemini-3.8-flash no admite "minimal"); `null` es
  /// no pedir ninguno y dejar el que el modelo trae por defecto.
  static const _niveles = ['minimal', 'low', null];

  /// Por modelo, el primer nivel que aceptó (posición en [_niveles]).
  static final _nivelPorModelo = <String, int>{};

  /// Modelos en el orden en que se prueban: primero el último que respondió.
  List<String> _modelosEnOrden(bool preciso) {
    final clave = apiKey.trim();
    if (_claveRecordada != clave) {
      _claveRecordada = clave;
      _ultimoQueRespondio.clear();
      _noExisten.clear();
      _nivelPorModelo.clear();
    }
    final ultimo = _ultimoQueRespondio[preciso];
    return [
      ?ultimo,
      for (final m in preciso ? Env.geminiModelosPrecisos : Env.geminiModelos)
        if (m != ultimo && !_noExisten.contains(m)) m,
    ];
  }

  /// Con [preciso] se prueban primero los modelos que leen mejor
  /// ([Env.geminiModelosPrecisos]); conviene para respuestas cortas. Sin él,
  /// primero los más rápidos, para respuestas largas como una factura.
  Future<dynamic> pedir(
    String prompt, {
    List<XFile> imagenes = const [],
    bool preciso = false,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const ScannerException(
        'Falta la API Key de Gemini. Pégala en Ajustes → Inteligencia artificial.',
      );
    }

    cuota?.verificar();

    final partes = <Map<String, dynamic>>[
      {'text': prompt},
      for (final img in imagenes)
        {
          'inlineData': {
            'mimeType': _mime(img),
            'data': base64Encode(await img.readAsBytes()),
          },
        },
    ];

    // Se prueba cada modelo; si está saturado se reintenta una vez y, si
    // sigue igual (o no existe), se pasa al siguiente de la lista.
    // Dos vueltas por la lista: en la primera se salta de inmediato al
    // siguiente modelo si uno falla; si todos estaban saturados, se espera
    // un momento y se vuelve a intentar con los que no dieron "no existe".
    String? texto;
    String? ultimoError;
    final descartados = <String>{};
    for (var vuelta = 0; vuelta < 2 && texto == null; vuelta++) {
      var huboSaturacion = false;
      for (final nombre in _modelosEnOrden(preciso)) {
        if (descartados.contains(nombre)) continue;
        final intento = Stopwatch()..start();
        try {
          texto = await _generar(nombre, partes);
          _ultimoQueRespondio[preciso] = nombre;
          break;
        } on _ErrorGemini catch (e) {
          debugPrint('[IA] $nombre falló tras ${intento.elapsedMilliseconds}ms: $e');
          ultimoError = e.toString();
          final m = ultimoError.toLowerCase();
          if (m.contains('api key') || m.contains('api_key')) {
            throw ScannerException(_traducir(ultimoError));
          }
          final saturado = e.codigo == 503 ||
              m.contains('demand') ||
              m.contains('overloaded') ||
              m.contains('unavailable');
          if (saturado) {
            huboSaturacion = true;
          } else {
            descartados.add(nombre); // sin acceso, sin cupo...
            if (e.codigo == 404) _noExisten.add(nombre);
          }
        } catch (e) {
          debugPrint('[IA] $nombre falló tras ${intento.elapsedMilliseconds}ms: $e');
          ultimoError = e.toString();
          huboSaturacion = true; // tiempo agotado o red: se reintenta luego
        }
      }
      if (texto == null && huboSaturacion && vuelta == 0) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }

    if (texto == null && ultimoError != null) {
      throw ScannerException(_traducir(ultimoError));
    }
    if (texto == null || texto.trim().isEmpty) {
      throw const ScannerException('La IA no devolvió ninguna respuesta.');
    }

    try {
      final resultado = jsonDecode(_limpiar(texto));
      await cuota?.registrar();
      return resultado;
    } catch (_) {
      throw ScannerException('No pude entender la respuesta de la IA:\n$texto');
    }
  }

  /// Una petición a un modelo con el nivel de razonamiento más bajo que
  /// acepte. Si rechaza un nivel, prueba el siguiente y recuerda cuál sirvió
  /// para no repetir el rechazo en la próxima petición.
  Future<String> _generar(String modelo, List<Map<String, dynamic>> partes) async {
    var i = _nivelPorModelo[modelo] ?? 0;
    while (true) {
      try {
        final texto = await _llamar(modelo, partes, nivel: _niveles[i]);
        _nivelPorModelo[modelo] = i;
        return texto;
      } on _ErrorGemini catch (e) {
        final rechazoElNivel = _niveles[i] != null &&
            e.codigo == 400 &&
            e.mensaje.toLowerCase().contains('think');
        if (!rechazoElNivel) rethrow;
        _nivelPorModelo[modelo] = ++i;
      }
    }
  }

  Future<String> _llamar(
    String modelo,
    List<Map<String, dynamic>> partes, {
    required String? nivel,
  }) async {
    final reloj = Stopwatch()..start();
    final respuesta = await _http
        .post(
          Uri.parse('$_base/$modelo:generateContent'),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey.trim(),
          },
          body: jsonEncode({
            'contents': [
              {'role': 'user', 'parts': partes},
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'temperature': 0.4,
              if (nivel != null) 'thinkingConfig': {'thinkingLevel': nivel},
            },
          }),
        )
        .timeout(const Duration(seconds: 40));

    final cuerpo = utf8.decode(respuesta.bodyBytes);
    reloj.stop();
    Object? json;
    try {
      json = jsonDecode(cuerpo);
    } catch (_) {
      json = null;
    }

    if (respuesta.statusCode != 200) {
      final error = json is Map ? json['error'] : null;
      final mensaje = error is Map
          ? '${error['status'] ?? ''} ${error['message'] ?? ''}'.trim()
          : cuerpo;
      throw _ErrorGemini(respuesta.statusCode, mensaje);
    }

    // Tiempos y tokens de cada respuesta, para saber qué demora el escaneo
    // (se ve con `adb logcat -s flutter`).
    final uso = json is Map ? json['usageMetadata'] : null;
    if (uso is Map) {
      final kb = partes.fold<int>(0, (n, p) => n + jsonEncode(p).length) ~/ 1024;
      debugPrint('[IA] $modelo nivel=${nivel ?? 'por defecto'} envío=${kb}KB '
          'tiempo=${reloj.elapsedMilliseconds}ms tokens: entrada=${uso['promptTokenCount']} '
          'razonamiento=${uso['thoughtsTokenCount'] ?? 0} salida=${uso['candidatesTokenCount']}');
    }

    // Se juntan los textos de la respuesta, sin las partes de razonamiento.
    final candidatos = json is Map ? json['candidates'] : null;
    if (candidatos is! List || candidatos.isEmpty) return '';
    final contenido = candidatos.first is Map ? candidatos.first['content'] : null;
    final partesRespuesta = contenido is Map ? contenido['parts'] : null;
    if (partesRespuesta is! List) return '';
    return partesRespuesta
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
  }

  String _limpiar(String texto) {
    var t = texto.trim();
    if (t.startsWith('```')) {
      t = t.replaceFirst(RegExp(r'^```(?:json)?'), '');
      t = t.replaceFirst(RegExp(r'```\s*$'), '');
    }
    return t.trim();
  }

  String _mime(XFile f) {
    final tipo = f.mimeType;
    if (tipo != null && tipo.startsWith('image/')) return tipo;
    final nombre = f.name.toLowerCase();
    if (nombre.endsWith('.png')) return 'image/png';
    if (nombre.endsWith('.webp')) return 'image/webp';
    if (nombre.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }

  String _traducir(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('api key') || m.contains('api_key')) {
      return 'La API Key de Gemini no es válida. Revísala en Ajustes.';
    }
    if (m.contains('quota') || m.contains('429') || m.contains('resource_exhausted')) {
      return 'Se alcanzó el límite de uso de Gemini. Intenta de nuevo en un momento.';
    }
    if (m.contains('demand') || m.contains('overloaded') || m.contains('503')) {
      return 'Los servidores de la IA están saturados en este momento. Espera un minuto y reintenta.';
    }
    return 'Error de la IA: $mensaje';
  }
}
