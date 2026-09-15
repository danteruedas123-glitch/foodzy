import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/env.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

final scannerServiceProvider = Provider<ScannerService>((ref) {
  return GeminiScannerService(apiKey: Env.geminiApiKey);
});

abstract interface class ScannerService {
  Future<List<Alimento>> analizarImagen(XFile imageFile);
}

class GeminiScannerService implements ScannerService {
  GeminiScannerService({required this.apiKey});

  final String apiKey;

  @override
  Future<List<Alimento>> analizarImagen(XFile imageFile) async {
    if (apiKey == 'TU_API_KEY_AQUI' || apiKey.isEmpty) {
      throw Exception('Por favor configura la API Key de Gemini en lib/core/env.dart');
    }

    // gemini-1.5-flash es excelente y muy rápido para tareas multimodales
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );

    final imageBytes = await imageFile.readAsBytes();
    final imagePart = DataPart('image/jpeg', imageBytes);

    final hoy = DateTime.now();
    final fechaHoyStr = hoy.toIso8601String().split('T').first;

    final prompt = TextPart('''
Analiza la siguiente imagen de comestibles. Identifica cada alimento presente de forma individual.
Hoy es $fechaHoyStr.

Para cada alimento detectado, devuelve la siguiente estructura JSON estrictamente, sin markdown u otro texto:
[
  {
    "nombre": "Nombre del alimento (ej. Tomate, Lata de Atún)",
    "categoria": "Categoría general (ej. Verduras, Enlatados, Lácteos)",
    "cantidad_valor": 1.0,
    "cantidad_unidad": "u", 
    "fecha_vencimiento_iso": "YYYY-MM-DD" // (Puede ser null)
  }
]

Reglas críticas para la fecha de vencimiento:
1. Si el alimento es fresco (frutas, verduras, carnes sin empaque), ESTIMA su tiempo de vida desde la fecha de hoy ($fechaHoyStr) y coloca esa fecha en "fecha_vencimiento_iso". Por ejemplo, un tomate dura unos 7 a 10 días, así que pon la fecha correspondiente.
2. Si el alimento está empaquetado (latas, cajas, botellas), intenta buscar y leer la fecha de vencimiento impresa en el empaque. Si la logras leer, colócala en "fecha_vencimiento_iso".
3. Si el alimento está empaquetado pero NO puedes ver ninguna fecha de vencimiento en la foto, DEBES poner "fecha_vencimiento_iso" como null. (No inventes fechas para enlatados o empaquetados).
4. La cantidad_unidad debe ser "u" (unidades), "kg", "g", "L" o "ml".
5. Para frutas y verduras frescas, estima SIEMPRE la cantidad en unidades (ej. "cantidad_unidad": "u", "cantidad_valor": 3) y NUNCA en kilos o gramos, así el usuario podrá restar por unidad al consumirlas.
''');

    final response = await model.generateContent([
      Content.multi([prompt, imagePart])
    ]);

    final text = response.text;
    if (text == null) {
      throw Exception('La IA no devolvió ninguna respuesta.');
    }

    // Limpiar posibles backticks del JSON (ej. ```json ... ```)
    String cleanJson = text;
    if (cleanJson.contains('```json')) {
      cleanJson = cleanJson.split('```json')[1];
    }
    if (cleanJson.contains('```')) {
      cleanJson = cleanJson.split('```')[0];
    }
    
    cleanJson = cleanJson.trim();

    try {
      final List<dynamic> decoded = jsonDecode(cleanJson);
      final List<Alimento> alimentos = [];

      for (final item in decoded) {
        final mapa = item as Map<String, dynamic>;
        
        DateTime fechaVencimiento;
        final fechaStr = mapa['fecha_vencimiento_iso'];
        
        if (fechaStr != null) {
          fechaVencimiento = DateTime.tryParse(fechaStr) ?? hoy;
        } else {
          // Si es null, pondremos una fecha muy lejana (o la de hoy) 
          // pero esto se utilizará en la UI para pedirle al usuario que la ponga.
          // Por convención interna, usaremos un "flag" o manejaremos esto en la UI.
          // Para que el modelo Alimento no sufra, pondremos una fecha especial (ej. año 1970)
          // que la UI identificará como "Falta fecha".
          fechaVencimiento = DateTime(1970, 1, 1);
        }

        final nuevo = Alimento(
          id: DateTime.now().microsecondsSinceEpoch.toString(), // ID temporal
          nombre: mapa['nombre']?.toString() ?? 'Desconocido',
          categoria: mapa['categoria']?.toString() ?? 'Otros',
          cantidad: Cantidad(
            valor: (mapa['cantidad_valor'] as num?)?.toDouble() ?? 1.0,
            unidad: mapa['cantidad_unidad']?.toString() ?? 'u',
          ),
          fechaVencimiento: fechaVencimiento,
          estado: Disponible(hoy),
        );
        alimentos.add(nuevo);
      }
      return alimentos;
    } catch (e) {
      throw Exception('Error al decodificar la respuesta de la IA: $e\nRespuesta:\n$cleanJson');
    }
  }
}
