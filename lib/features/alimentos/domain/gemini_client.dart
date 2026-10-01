import 'dart:convert';

import 'package:foodzy/core/env.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

class ScannerException implements Exception {
  const ScannerException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Cliente común de Gemini: prueba una cadena de modelos con reintentos y
/// devuelve el JSON ya decodificado. Lo usan el escáner y las recetas.
class GeminiClient {
  GeminiClient({required this.apiKey});

  final String apiKey;

  Future<dynamic> pedir(String prompt, {List<XFile> imagenes = const []}) async {
    if (apiKey.trim().isEmpty) {
      throw const ScannerException(
        'Falta la API Key de Gemini. Pégala en Ajustes → Inteligencia artificial.',
      );
    }

    final partes = <Part>[TextPart(prompt)];
    for (final img in imagenes) {
      partes.add(DataPart(_mime(img), await img.readAsBytes()));
    }
    final contenido = [Content.multi(partes)];

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
      for (final nombre in Env.geminiModelos) {
        if (descartados.contains(nombre)) continue;
        final model = GenerativeModel(
          model: nombre,
          apiKey: apiKey.trim(),
          generationConfig: GenerationConfig(
            responseMimeType: 'application/json',
            temperature: 0.4,
          ),
        );
        try {
          final respuesta = await model
              .generateContent(contenido)
              .timeout(const Duration(seconds: 40));
          texto = respuesta.text;
          break;
        } on GenerativeAIException catch (e) {
          ultimoError = e.message;
          final m = e.message.toLowerCase();
          if (m.contains('api key') || m.contains('api_key')) {
            throw ScannerException(_traducir(e.message));
          }
          final saturado = m.contains('demand') ||
              m.contains('overloaded') ||
              m.contains('unavailable') ||
              m.contains('503');
          if (saturado) {
            huboSaturacion = true;
          } else {
            descartados.add(nombre); // no existe / sin acceso
          }
        } catch (e) {
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
      return jsonDecode(_limpiar(texto));
    } catch (_) {
      throw ScannerException('No pude entender la respuesta de la IA:\n$texto');
    }
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
    if (m.contains('quota') || m.contains('429')) {
      return 'Se alcanzó el límite de uso de Gemini. Intenta de nuevo en un momento.';
    }
    if (m.contains('demand') || m.contains('overloaded') || m.contains('503')) {
      return 'Los servidores de la IA están saturados en este momento. Espera un minuto y reintenta.';
    }
    return 'Error de la IA: $mensaje';
  }
}
