import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:foodzy/core/env.dart';
import 'package:foodzy/core/nube.dart';
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

/// Error al pedirle algo a un modelo, con un código al estilo HTTP para
/// decidir qué hacer: 404 (el modelo no existe), 503 (saturado), 429 (sin
/// cupo), 403 (la IA no está disponible), 400 (petición rechazada) o 0 (otro).
class ErrorIA implements Exception {
  const ErrorIA(this.codigo, this.mensaje);
  final int codigo;
  final String mensaje;
  @override
  String toString() => '$codigo: $mensaje';
}

/// Un trozo de lo que se le manda a la IA: texto o una imagen.
sealed class ParteIA {
  const ParteIA();
}

final class TextoIA extends ParteIA {
  const TextoIA(this.texto);
  final String texto;
}

final class ImagenIA extends ParteIA {
  const ImagenIA(this.mime, this.bytes);
  final String mime;
  final Uint8List bytes;
}

/// Hace una petición a un [modelo] con un nivel de razonamiento (`null` = el
/// que el modelo trae por defecto) y devuelve el texto de la respuesta, sin
/// las partes de razonamiento. Lanza [ErrorIA] si falla.
typedef TransporteIA = Future<String> Function(
  String modelo,
  List<ParteIA> partes, {
  required String? nivel,
});

/// Cliente común de Gemini: prueba una cadena de modelos con reintentos y
/// devuelve el JSON ya decodificado. Lo usan el escáner y las recetas.
///
/// Las peticiones van por **Firebase AI Logic**: la clave de Gemini vive en
/// el proyecto de Firebase y nunca está dentro de la app (antes había que
/// pegarla en Ajustes, y compilarla en el binario era el hallazgo de
/// seguridad H-01). Se pide el nivel de razonamiento más bajo que acepte cada
/// modelo: leer una foto o una factura no necesita que el modelo "piense" a
/// fondo, y hacerlo era lo que más demoraba cada respuesta.
class GeminiClient {
  GeminiClient({this.cuota, TransporteIA? transporte})
      : _transporte = transporte ?? _porFirebase;

  final CuotaIA? cuota;
  final TransporteIA _transporte;

  // Lo que se aprende de los modelos se recuerda entre peticiones (mientras
  // la app esté abierta), para no repetir en cada escaneo intentos que ya se
  // sabe que fallan.

  /// El último modelo que respondió, por modo (rápido o preciso).
  static final _ultimoQueRespondio = <bool, String>{};
  static final _noExisten = <String>{};

  /// Modelos que respondieron "sin cupo" y hasta cuándo no se prueban: la
  /// cuota gratuita se recupera sola, pero mientras tanto cada intento
  /// costaba segundos en cada escaneo.
  static final _sinCupoHasta = <String, DateTime>{};
  static const _pausaSinCupo = Duration(minutes: 5);

  /// Niveles de razonamiento, del más rápido al más lento. No todos los
  /// modelos admiten todos (gemini-3.8-flash no admite "minimal"); `null` es
  /// no pedir ninguno y dejar el que el modelo trae por defecto.
  static const _niveles = ['minimal', 'low', null];

  /// Por modelo, el primer nivel que aceptó (posición en [_niveles]).
  static final _nivelPorModelo = <String, int>{};

  /// Olvida lo aprendido de los modelos (para que las pruebas no se mezclen).
  @visibleForTesting
  static void olvidar() {
    _ultimoQueRespondio.clear();
    _noExisten.clear();
    _nivelPorModelo.clear();
    _sinCupoHasta.clear();
  }

  /// Modelos en el orden en que se prueban: primero el último que respondió.
  List<String> _modelosEnOrden(bool preciso) {
    final ultimo = _ultimoQueRespondio[preciso];
    final todos = [
      ?ultimo,
      for (final m in preciso ? Env.geminiModelosPrecisos : Env.geminiModelos)
        if (m != ultimo && !_noExisten.contains(m)) m,
    ];
    // Los que están sin cupo van al final (no se descartan: si todos lo
    // están, igual se intenta).
    final ahora = DateTime.now();
    bool sinCupo(String m) => _sinCupoHasta[m]?.isAfter(ahora) ?? false;
    return [...todos.where((m) => !sinCupo(m)), ...todos.where(sinCupo)];
  }

  /// Con [preciso] se prueban primero los modelos que leen mejor
  /// ([Env.geminiModelosPrecisos]); conviene para respuestas cortas. Sin él,
  /// primero los más rápidos, para respuestas largas como una factura.
  Future<dynamic> pedir(
    String prompt, {
    List<XFile> imagenes = const [],
    bool preciso = false,
  }) async {
    cuota?.verificar();

    final partes = <ParteIA>[
      TextoIA(prompt),
      for (final img in imagenes) ImagenIA(_mime(img), await img.readAsBytes()),
    ];

    // Se prueba cada modelo; si está saturado se reintenta una vez y, si
    // sigue igual (o no existe), se pasa al siguiente de la lista.
    // Dos vueltas por la lista: en la primera se salta de inmediato al
    // siguiente modelo si uno falla; si todos estaban saturados, se espera
    // un momento y se vuelve a intentar con los que no dieron "no existe".
    String? texto;
    ErrorIA? ultimoError;
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
        } on ErrorIA catch (e) {
          debugPrint('[IA] $nombre falló tras ${intento.elapsedMilliseconds}ms: $e');
          ultimoError = e;
          // Un 403 (AI Logic sin activar o sin permiso) no se reintenta con
          // el mismo modelo, pero sí se prueba el siguiente: justo después
          // de activarlo, Firebase tarda unos minutos en dejar pasar a todos.
          if (e.codigo == 503) {
            huboSaturacion = true;
          } else {
            descartados.add(nombre); // sin cupo, petición rechazada...
            if (e.codigo == 404) _noExisten.add(nombre);
            if (e.codigo == 429) {
              _sinCupoHasta[nombre] = DateTime.now().add(_pausaSinCupo);
            }
          }
        } catch (e) {
          debugPrint('[IA] $nombre falló tras ${intento.elapsedMilliseconds}ms: $e');
          ultimoError = ErrorIA(0, e.toString());
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
  Future<String> _generar(String modelo, List<ParteIA> partes) async {
    var i = _nivelPorModelo[modelo] ?? 0;
    while (true) {
      try {
        final texto = await _transporte(modelo, partes, nivel: _niveles[i]);
        _nivelPorModelo[modelo] = i;
        return texto;
      } on ErrorIA catch (e) {
        final rechazoElNivel = _niveles[i] != null &&
            e.codigo == 400 &&
            e.mensaje.toLowerCase().contains('think');
        if (!rechazoElNivel) rethrow;
        _nivelPorModelo[modelo] = ++i;
      }
    }
  }

  // ── Firebase AI Logic ───────────────────────────────────────────────────

  static const _nivelesFirebase = {
    'minimal': ThinkingLevel.minimal,
    'low': ThinkingLevel.low,
  };

  static Future<String> _porFirebase(
    String modelo,
    List<ParteIA> partes, {
    required String? nivel,
  }) async {
    if (!Nube.disponible) {
      throw const ErrorIA(403,
          'La IA necesita la conexión con la nube de Foodzy, y esta copia de la app no la tiene.');
    }
    final reloj = Stopwatch()..start();
    final GenerateContentResponse respuesta;
    try {
      respuesta = await FirebaseAI.googleAI()
          .generativeModel(
            model: modelo,
            generationConfig: GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.4,
              thinkingConfig: nivel == null
                  ? null
                  : ThinkingConfig.withThinkingLevel(_nivelesFirebase[nivel]),
            ),
          )
          .generateContent([
            Content.multi([
              for (final p in partes)
                switch (p) {
                  TextoIA(:final texto) => TextPart(texto),
                  ImagenIA(:final mime, :final bytes) => InlineDataPart(mime, bytes),
                },
            ]),
          ])
          .timeout(const Duration(seconds: 40));
    } on ServiceApiNotEnabled catch (e) {
      throw ErrorIA(403, e.message);
    } on QuotaExceeded catch (e) {
      throw ErrorIA(429, e.message);
    } on FirebaseAIException catch (e) {
      throw ErrorIA(codigoDe(e.message), e.message);
    }

    // Tiempos y tokens de cada respuesta, para saber qué demora el escaneo
    // (se ve con `adb logcat -s flutter`; en release no se escribe nada).
    final uso = respuesta.usageMetadata;
    final kb = partes.fold<int>(
            0,
            (n, p) => n +
                switch (p) {
                  TextoIA(:final texto) => texto.length,
                  ImagenIA(:final bytes) => bytes.length,
                }) ~/
        1024;
    debugPrint('[IA] $modelo nivel=${nivel ?? 'por defecto'} envío=${kb}KB '
        'tiempo=${reloj.elapsedMilliseconds}ms tokens: entrada=${uso?.promptTokenCount} '
        'razonamiento=${uso?.thoughtsTokenCount ?? 0} salida=${uso?.candidatesTokenCount}');

    try {
      return respuesta.text ?? '';
    } on FirebaseAIException catch (e) {
      throw ErrorIA(400, e.message); // respuesta bloqueada
    }
  }

  /// Firebase no entrega el código HTTP del error, solo el mensaje: se
  /// deduce de él.
  @visibleForTesting
  static int codigoDe(String mensaje) {
    final m = mensaje.toLowerCase();
    // AI Logic sin activar en el proyecto de Firebase.
    if (_sinActivar(m)) return 403;
    if (m.contains('not found') ||
        m.contains('not_found') ||
        m.contains('is not supported for generatecontent')) {
      return 404;
    }
    if (m.contains('overloaded') ||
        m.contains('unavailable') ||
        m.contains('high demand') ||
        m.contains('503')) {
      return 503;
    }
    if (m.contains('quota') || m.contains('resource_exhausted') || m.contains('429')) {
      return 429;
    }
    if (m.contains('permission_denied') || m.contains('api key') || m.contains('api_key')) {
      return 403;
    }
    if (m.contains('invalid_argument') || m.contains('think')) return 400;
    return 0;
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

  static bool _sinActivar(String m) =>
      m.contains('ailogic') ||
      m.contains('ai logic') ||
      m.contains('firebasevertexai') ||
      m.contains('has not been used in project') ||
      m.contains('does not have required permission to use project');

  String _traducir(ErrorIA e) {
    if (e.codigo == 403) {
      return _sinActivar(e.mensaje.toLowerCase())
          ? 'La IA de Foodzy no está activada todavía. Inténtalo más tarde.'
          : 'La IA no está disponible: ${e.mensaje}';
    }
    if (e.codigo == 429) {
      return 'Se alcanzó el límite de uso de la IA. Intenta de nuevo en un momento.';
    }
    if (e.codigo == 503) {
      return 'Los servidores de la IA están saturados en este momento. Espera un minuto y reintenta.';
    }
    return 'Error de la IA: ${e.mensaje}';
  }
}
