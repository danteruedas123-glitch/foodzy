import 'dart:convert';


import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:foodzy/features/alimentos/domain/gemini_client.dart' show ScannerException;
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';
import 'package:image_picker/image_picker.dart';

final scannerServiceProvider = Provider<ScannerService>((ref) {
  return GeminiScannerService(apiKey: ref.watch(apiKeyProvider));
});

/// Un alimento que la IA propone, antes de que el usuario lo confirme.
class AlimentoDetectado {
  const AlimentoDetectado({required this.alimento, this.fechaEstimada = false});

  final Alimento alimento;

  /// `true` si la fecha de vencimiento no se leyó sino que se estimó.
  final bool fechaEstimada;

  AlimentoDetectado copyWith({Alimento? alimento, bool? fechaEstimada}) =>
      AlimentoDetectado(
        alimento: alimento ?? this.alimento,
        fechaEstimada: fechaEstimada ?? this.fechaEstimada,
      );
}

/// Un alimento del inventario que la cámara vio salir de la despensa.
class RetiroDetectado {
  const RetiroDetectado({
    required this.alimento,
    required this.cantidad,
    this.medidas = const [],
  });

  final Alimento alimento;

  /// Cuánto se retiró, en la misma unidad que el alimento.
  final double cantidad;

  /// Medidas caseras de este producto (1 cucharada ≈ 15 g), en su unidad.
  final List<MedidaCasera> medidas;
}

/// Una medida de cocina y su equivalencia en la unidad del alimento.
class MedidaCasera {
  const MedidaCasera(this.nombre, this.cantidad);

  final String nombre;
  final double cantidad;
}


abstract interface class ScannerService {
  /// Foto de la compra, de productos sueltos.
  Future<List<AlimentoDetectado>> analizarCompra(XFile imagen);

  /// Foto de una factura o ticket de supermercado.
  Future<List<AlimentoDetectado>> analizarFactura(XFile imagen);

  /// Foto de lo que se sacó; se cruza con el inventario disponible.
  Future<List<RetiroDetectado>> detectarRetiro(
    XFile imagen,
    List<Alimento> inventario,
  );

  /// Compara una foto del producto antes y después de usarlo y devuelve la
  /// fracción consumida (0 a 1) del contenido que tenía.
  Future<double> estimarConsumo(XFile antes, XFile despues, Alimento alimento);
}

class GeminiScannerService implements ScannerService {
  GeminiScannerService({required this.apiKey}) : _cliente = GeminiClient(apiKey: apiKey);

  final String apiKey;
  final GeminiClient _cliente;

  static const _reglasUnidad =
      'cantidad_unidad debe ser exactamente una de: "u", "kg", "g", "L", "ml". '
      'Para frutas, verduras y piezas sueltas usa "u" contando las piezas. '
      'Para productos empaquetados con contenido neto visible (ej. "300 g", "1 L", "500 ml"), '
      'NO uses "u": cantidad_valor es el contenido neto TOTAL (contenido de un empaque × número de empaques) '
      'y cantidad_unidad es g, ml, kg o L según el empaque (ej. un Milo de 300 g → 300 "g"; 2 leches de 1 L → 2 "L"). '
      'Usa "u" para un empaque solo si no se alcanza a ver su contenido.';

  @override
  Future<List<AlimentoDetectado>> analizarCompra(XFile imagen) async {
    final hoy = _hoy();
    final lista = await _pedirLista('''
Analiza esta foto de comida o mercado. Identifica cada alimento por separado.
Hoy es $hoy.

Devuelve SOLO un arreglo JSON con objetos de esta forma:
{"nombre": "Tomate", "categoria": "Verduras", "cantidad_valor": 3, "cantidad_unidad": "u", "fecha_vencimiento_iso": "YYYY-MM-DD" o null, "fecha_estimada": true/false}

Reglas:
1. $_reglasUnidad
2. Productos frescos (frutas, verduras, carnes, pan): estima la fecha desde hoy según su vida útil típica y pon "fecha_estimada": true.
3. Productos empaquetados: si ves la fecha impresa, léela ("fecha_estimada": false). Si no se ve, pon null; no inventes fechas.
4. Si no hay comida en la imagen, devuelve [].
''', imagen);
    return lista.map(_aDetectado).toList();
  }

  @override
  Future<List<AlimentoDetectado>> analizarFactura(XFile imagen) async {
    final hoy = _hoy();
    final lista = await _pedirLista('''
Esta imagen es una factura o ticket de supermercado. Extrae SOLO los productos comestibles o bebibles; ignora bolsas, impuestos, descuentos, totales y artículos no alimenticios.
Hoy es $hoy.

Devuelve SOLO un arreglo JSON con objetos de esta forma:
{"nombre": "Leche entera", "categoria": "Lácteos", "cantidad_valor": 2, "cantidad_unidad": "u", "fecha_vencimiento_iso": "YYYY-MM-DD", "fecha_estimada": true}

Reglas:
1. Expande abreviaturas del ticket a un nombre legible (ej. "LCHE ENT 1L" → "Leche entera 1 L").
2. Toma la cantidad comprada de la factura y el tamaño del empaque que suele venir en el nombre (ej. "MILO 300G" → 300 "g"). $_reglasUnidad
3. Las facturas no traen fecha de vencimiento: estímala desde hoy según el tipo de producto (fresco pocos días, lácteos semanas, enlatados meses) y pon "fecha_estimada": true.
4. Si no hay productos legibles, devuelve [].
''', imagen);
    return lista.map(_aDetectado).toList();
  }

  @override
  Future<List<RetiroDetectado>> detectarRetiro(
    XFile imagen,
    List<Alimento> inventario,
  ) async {
    if (inventario.isEmpty) {
      throw const ScannerException('No tienes alimentos disponibles para retirar.');
    }
    final catalogo = inventario
        .map((a) => {
              'id': a.id,
              'nombre': a.nombre,
              'cantidad': a.cantidad.valor,
              'unidad': a.cantidad.unidad,
            })
        .toList();

    final lista = await _pedirLista('''
Esta foto muestra comida que una persona acaba de sacar de su despensa o nevera para consumirla.
Este es el inventario disponible (JSON):
${jsonEncode(catalogo)}

Identifica qué alimentos de ese inventario aparecen en la foto y cuánto de cada uno se usará.
Devuelve SOLO un arreglo JSON con objetos de esta forma:
{"id": "<id exacto del inventario>", "cantidad_retirada": 30, "medidas": [{"nombre": "1 cucharada", "cantidad": 15}, {"nombre": "1 taza", "cantidad": 240}]}

Reglas:
1. Usa únicamente ids que existan en el inventario; ignora lo que no esté en él.
2. cantidad_retirada usa la misma unidad del inventario y nunca supera la cantidad disponible.
   Estima una porción razonable de una sola vez (ej. de un tarro de Milo, unas 2 cucharadas ≈ 30 g; de un litro de leche, un vaso ≈ 250 ml). No saques el producto completo salvo que sea una pieza o un empaque pequeño de un solo uso.
3. medidas: 3 o 4 medidas caseras útiles para ESE producto (cucharadita, cucharada, taza, vaso, puñado, rebanada, pieza...), con su equivalencia numérica en la unidad del inventario.
4. Si no reconoces nada del inventario, devuelve [].
''', imagen);

    final porId = {for (final a in inventario) a.id: a};
    final salida = <RetiroDetectado>[];
    for (final item in lista) {
      final alimento = porId[item['id']?.toString()];
      if (alimento == null) continue;
      final pedida = (item['cantidad_retirada'] as num?)?.toDouble() ?? 1.0;
      final cantidad = pedida.clamp(0.0, alimento.cantidad.valor).toDouble();
      if (cantidad <= 0) continue;

      final medidas = <MedidaCasera>[];
      final crudas = item['medidas'];
      if (crudas is List) {
        for (final m in crudas) {
          if (m is! Map) continue;
          final nombre = m['nombre']?.toString();
          final valor = (m['cantidad'] as num?)?.toDouble();
          if (nombre == null || valor == null || valor <= 0) continue;
          medidas.add(MedidaCasera(nombre, valor));
        }
      }
      salida.add(RetiroDetectado(
        alimento: alimento,
        cantidad: cantidad,
        medidas: medidas,
      ));
    }
    return salida;
  }

  @override
  Future<double> estimarConsumo(
    XFile antes,
    XFile despues,
    Alimento alimento,
  ) async {
    final decodificado = await _cliente.pedir('''
Tienes dos fotos del mismo producto: la primera ANTES de usarlo y la segunda DESPUÉS.
Producto: ${alimento.nombre}, contenido antes de usarlo: ${alimento.cantidad.valor} ${alimento.cantidad.unidad}.

Estima qué fracción de ese contenido se consumió comparando el nivel o la cantidad visible en ambas fotos.
Devuelve SOLO un objeto JSON: {"fraccion_consumida": 0.25}
(un número entre 0 y 1; si no puedes comparar con certeza, da tu mejor estimación prudente).
''', imagenes: [antes, despues]);

    final mapa = decodificado is List && decodificado.isNotEmpty
        ? decodificado.first
        : decodificado;
    final f = mapa is Map ? (mapa['fraccion_consumida'] as num?)?.toDouble() : null;
    if (f == null) {
      throw const ScannerException('No pude comparar las fotos. Intenta con mejor luz.');
    }
    return f.clamp(0.0, 1.0).toDouble();
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  String _hoy() => DateTime.now().toIso8601String().split('T').first;

  Future<List<Map<String, dynamic>>> _pedirLista(
    String prompt,
    XFile imagen,
  ) async {
    final decodificado = await _cliente.pedir(prompt, imagenes: [imagen]);
    final lista = decodificado is List ? decodificado : [decodificado];
    return lista.whereType<Map<String, dynamic>>().toList();
  }

  AlimentoDetectado _aDetectado(Map<String, dynamic> m) {
    final ahora = DateTime.now();
    final fecha = DateTime.tryParse(m['fecha_vencimiento_iso']?.toString() ?? '');
    final valor = (m['cantidad_valor'] as num?)?.toDouble() ?? 1.0;

    return AlimentoDetectado(
      fechaEstimada: fecha != null && m['fecha_estimada'] == true,
      alimento: Alimento(
        id: '${ahora.microsecondsSinceEpoch}-${m.hashCode}',
        nombre: m['nombre']?.toString() ?? 'Desconocido',
        categoria: m['categoria']?.toString() ?? 'Otros',
        cantidad: Cantidad(
          valor: valor > 0 ? valor : 1.0,
          unidad: m['cantidad_unidad']?.toString() ?? 'u',
        ),
        fechaVencimiento: fecha ?? Alimento.sinFecha,
        estado: Disponible(ahora),
      ),
    );
  }
}
