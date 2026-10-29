import 'dart:convert';


import 'package:flutter_riverpod/flutter_riverpod.dart';
export 'package:foodzy/features/alimentos/domain/gemini_client.dart' show ScannerException;
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';
import 'package:foodzy/features/premium/premium_provider.dart';
import 'package:image_picker/image_picker.dart';

final scannerServiceProvider = Provider<ScannerService>((ref) {
  return GeminiScannerService(
    apiKey: ref.watch(apiKeyProvider),
    cuota: ref.watch(cuotaIAProvider),
  );
});

/// Un alimento que la IA propone, antes de que el usuario lo confirme.
class AlimentoDetectado {
  const AlimentoDetectado({required this.alimento, this.caja});

  final Alimento alimento;

  /// Dónde está el producto en la foto: `[ymin, xmin, ymax, xmax]` en
  /// milésimas (0 a 1000). Sirve para recortar su miniatura. `null` en las
  /// facturas, o si la IA no lo indicó.
  final List<num>? caja;

  /// `true` si la fecha de vencimiento no se leyó sino que se estimó.
  bool get fechaEstimada => alimento.origenFecha == FechaOrigen.estimada;
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


/// Resultado de estimar cuánto dura un producto.
class FechaEstimada {
  const FechaEstimada({this.fecha, this.noVence = false});

  final DateTime? fecha;
  final bool noVence;
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

  /// Lee la fecha de vencimiento impresa en una foto de cerca del empaque.
  Future<DateTime> leerFechaVencimiento(XFile imagen);

  /// Estima cuánto dura un producto (sin foto), según su tipo y dónde se guarda.
  Future<FechaEstimada> estimarFecha({
    required String nombre,
    required String categoria,
    Ubicacion? ubicacion,
  });
}

class GeminiScannerService implements ScannerService {
  GeminiScannerService({required this.apiKey, CuotaIA? cuota})
      : _cliente = GeminiClient(apiKey: apiKey, cuota: cuota);

  final String apiKey;
  final GeminiClient _cliente;

  /// Cómo leer una fecha impresa sin confundirla con otras del empaque.
  static const _comoLeerFecha =
      'Cómo leer la fecha impresa: puede decir VENCE, VENC, V., F.V., FV, EXP, CAD, CONSUMIR ANTES DE, '
      'CONSUMIR PREFERENTEMENTE ANTES DE o BEST BEFORE, y suele estar en la tapa, el cuello de la botella, '
      'el fondo, la pestaña o un borde del empaque. El formato es día/mes/año (25/12/26 = 25 de diciembre de 2026; '
      '05-03-2027 = 5 de marzo de 2027); un año de 2 cifras es 20XX. Si solo hay mes y año (12/2026, DIC 2026), '
      'usa el último día de ese mes. NO la confundas con la fecha de elaboración o fabricación (F.E., ELAB, FAB, '
      'PROD, EMP), el lote (L., LOTE) ni el registro sanitario (INVIMA, RSA): si aparecen dos fechas, la de '
      'vencimiento es la más lejana. Si no se lee con claridad, no la inventes.';

  /// Cuánto dura cada tipo de producto sin abrir, para estimar la fecha.
  static const _vidaUtil =
      'Días que dura cada tipo de producto SIN ABRIR (nevera / congelador / alacena): '
      'leche pasteurizada en bolsa 5 / 60 / -; leche UHT o larga vida 90 en alacena; yogur, kumis y bebidas lácteas 21 / - / -; '
      'queso fresco, campesino o cuajada 7 / 60 / -; queso madurado o tajado 30 / 90 / -; mantequilla 60 / 180 / -; crema de leche 10; '
      'huevos 30 / - / 21; carne de res o cerdo cruda 3 / 180 / -; carne molida 2 / 90 / -; pollo crudo 2 / 270 / -; '
      'pescado y mariscos crudos 2 / 120 / -; jamón, salchichas y embutidos sellados 30 / 60 / -; '
      'pan tajado o de molde 10 / 90 / 7; pan fresco de panadería 4 / 60 / 2; arepas empacadas 10 / 60 / -; tortillas 20; '
      'banano y plátano - / - / 5; aguacate 6 / - / 4; fresas y moras 4; uvas 7; manzana y pera 30 / - / 10; '
      'naranja, limón y mandarina 21 / - / 10; papaya, piña y mango 5 / - / 4; lechuga, espinaca y hierbas 5; '
      'tomate 10 / - / 6; zanahoria 21; pimentón, pepino y brócoli 7; papa - / - / 30; cebolla cabezona - / - / 45; ajo 90; '
      'arroz, pasta seca, granos secos, harina y azúcar 365 en alacena; enlatados 730; galletas, cereales y snacks 180; '
      'café molido 180; aceite 365; salsas (tomate, mayonesa) 270; jugos en caja 180; gaseosas 180; '
      'congelados industriales (verduras, helado, nuggets) 240 en congelador. '
      'Para lo que no esté en la tabla, usa el producto más parecido.';

  static const _reglasFecha =
      'Fecha de vencimiento, en este orden: '
      '(a) Si el producto NO se echa a perder (sal, azúcar, miel, vinagre, especias secas, bicarbonato, agua embotellada...), '
      'pon "no_vence": true y "fecha_vencimiento_iso": null. '
      '(b) Si la fecha impresa en el empaque se ve con claridad, léela y pon "fecha_origen": "leida". '
      '$_comoLeerFecha '
      '(c) En cualquier otro caso ESTÍMALA sumando a hoy los días de esta tabla para la ubicación que sugieras, '
      'y pon "fecha_origen": "estimada". $_vidaUtil '
      'Si en la foto se ve maduro, abierto o en mal estado, acorta la fecha. '
      'Sé conservador: ante la duda, estima una fecha más corta. '
      'Nunca dejes la fecha en null salvo que "no_vence" sea true. '
      'Ubicación: sugiere dónde se guarda cada producto en "ubicacion" ("nevera", "congelador" o "alacena") y estima la fecha ASUMIENDO esa ubicación '
      '(un producto congelado dura meses; el mismo en nevera, días).';

  static const _reglasUnidad =
      'cantidad_unidad debe ser exactamente una de: "u", "kg", "g", "L", "ml". '
      'Para frutas, verduras y piezas sueltas usa "u" contando las piezas. '
      'Para productos empaquetados con contenido neto visible (ej. "300 g", "1 L", "500 ml"), '
      'NO uses "u": cantidad_valor es el contenido neto TOTAL (contenido de un empaque × número de empaques) '
      'y cantidad_unidad es g, ml, kg o L según el empaque (ej. un Milo de 300 g → 300 "g"; 2 leches de 1 L → 2 "L"). '
      'Usa "u" para un empaque solo si no se alcanza a ver su contenido.';

  static const _reglaEmoji =
      '"emoji" es UN solo emoji que muestre ese producto concreto, no su categoría '
      '(🥛 leche, 🧀 queso, 🥚 huevos, 🍌 banano, 🍅 tomate, 🍗 pollo, 🥩 carne, 🍚 arroz, 🍝 pasta, 🍞 pan, 🥫 enlatados).';

  @override
  Future<List<AlimentoDetectado>> analizarCompra(XFile imagen) async {
    final hoy = _hoy();
    final lista = await _pedirLista('''
Analiza esta foto de comida o mercado. Identifica cada alimento por separado.
Hoy es $hoy.

Devuelve SOLO un arreglo JSON con objetos de esta forma:
{"nombre": "Tomate", "categoria": "Verduras", "emoji": "🍅", "cantidad_valor": 3, "cantidad_unidad": "u", "fecha_vencimiento_iso": "YYYY-MM-DD" o null, "fecha_origen": "leida" o "estimada", "no_vence": false, "ubicacion": "nevera", "box_2d": [ymin, xmin, ymax, xmax]}

Reglas:
1. $_reglasUnidad
2. $_reglasFecha
3. $_reglaEmoji
4. "box_2d" es el recuadro del producto en la foto, en milésimas de la imagen (0 a 1000). Si hay varias unidades juntas del mismo producto (3 tomates), un solo recuadro que las abarque.
5. Si no hay comida en la imagen, devuelve [].
''', imagen);
    return _sinRepetidos(lista).map(_aDetectado).toList();
  }

  @override
  Future<List<AlimentoDetectado>> analizarFactura(XFile imagen) async {
    final hoy = _hoy();
    final lista = await _pedirLista('''
Esta imagen es una factura o ticket de supermercado. Extrae SOLO los productos comestibles o bebibles; ignora bolsas, impuestos, descuentos, totales y artículos no alimenticios.
Hoy es $hoy.

Devuelve SOLO un arreglo JSON con objetos de esta forma:
{"nombre": "Leche entera", "categoria": "Lácteos", "emoji": "🥛", "cantidad_valor": 2, "cantidad_unidad": "u", "fecha_vencimiento_iso": "YYYY-MM-DD", "fecha_origen": "estimada", "no_vence": false, "ubicacion": "nevera", "precio_total": 8500}

Reglas:
1. Expande abreviaturas del ticket a un nombre legible (ej. "LCHE ENT 1L" → "Leche entera 1 L").
2. Pon en "precio_total" lo que costó ese renglón (el total de la línea, número sin símbolo ni separador de miles; null si no se lee). Toma la cantidad comprada de la factura y el tamaño del empaque que suele venir en el nombre (ej. "MILO 300G" → 300 "g"). $_reglasUnidad
3. Las facturas no traen fecha de vencimiento. $_reglasFecha
4. $_reglaEmoji
5. Lista cada renglón de la factura UNA sola vez. Si un producto aparece en varios renglones o con cantidad mayor a 1, devuélvelo en un solo objeto con la cantidad sumada. Nunca repitas objetos idénticos.
6. Si no hay productos legibles, devuelve [].
''', imagen);
    return _sinRepetidos(lista).map(_aDetectado).toList();
  }

  /// La IA a veces repite el mismo renglón varias veces; se descartan las
  /// copias idénticas (mismo nombre, cantidad, unidad y precio).
  List<Map<String, dynamic>> _sinRepetidos(List<Map<String, dynamic>> lista) {
    final vistos = <String>{};
    return [
      for (final m in lista)
        if (vistos.add([
          m['nombre']?.toString().trim().toLowerCase(),
          m['cantidad_valor'],
          m['cantidad_unidad'],
          m['precio_total'],
        ].join('|')))
          m,
    ];
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

  @override
  Future<DateTime> leerFechaVencimiento(XFile imagen) async {
    final decodificado = await _cliente.pedir('''
Esta es una foto de cerca de un empaque de alimento. Busca la fecha de vencimiento y devuelve SOLO esa.
$_comoLeerFecha
También puede venir como 25 DIC 26, 2026-12-25 o con puntos (25.12.26).
Hoy es ${_hoy()}.

Devuelve SOLO un objeto JSON: {"fecha_vencimiento_iso": "YYYY-MM-DD"}
Si no se ve ninguna fecha de vencimiento con claridad, devuelve {"fecha_vencimiento_iso": null}.
''', imagenes: [imagen], preciso: true);

    final mapa = decodificado is List && decodificado.isNotEmpty
        ? decodificado.first
        : decodificado;
    final fecha = mapa is Map
        ? DateTime.tryParse(mapa['fecha_vencimiento_iso']?.toString() ?? '')
        : null;
    if (fecha == null) {
      throw const ScannerException(
          'No pude leer la fecha. Acércate más al texto, con buena luz, e inténtalo de nuevo.');
    }
    return fecha;
  }

  @override
  Future<FechaEstimada> estimarFecha({
    required String nombre,
    required String categoria,
    Ubicacion? ubicacion,
  }) async {
    final donde = ubicacion == null ? 'no se sabe' : ubicacion.etiqueta;
    final json = await _cliente.pedir('''
Producto: $nombre (categoría: $categoria). Se guarda en: $donde. Hoy es ${_hoy()}.

Estima hasta cuándo se puede consumir de forma segura un producto SIN ABRIR de ese tipo guardado así,
sumando a hoy los días de esta tabla. $_vidaUtil
Si no se echa a perder (sal, azúcar, miel, vinagre, especias secas...), responde no_vence true.
Sé conservador: ante la duda, una fecha más corta.

Devuelve SOLO un objeto JSON: {"fecha_vencimiento_iso": "YYYY-MM-DD" o null, "no_vence": false}
''', preciso: true);
    final mapa = json is List && json.isNotEmpty ? json.first : json;
    if (mapa is! Map) throw const ScannerException('No pude estimar la fecha.');
    if (mapa['no_vence'] == true) return const FechaEstimada(noVence: true);
    final fecha = DateTime.tryParse(mapa['fecha_vencimiento_iso']?.toString() ?? '');
    if (fecha == null) throw const ScannerException('No pude estimar la fecha.');
    return FechaEstimada(fecha: _noAntesDeHoy(fecha));
  }

  AlimentoDetectado _aDetectado(Map<String, dynamic> m) {
    final ahora = DateTime.now();
    final valor = (m['cantidad_valor'] as num?)?.toDouble() ?? 1.0;

    final noVence = m['no_vence'] == true;
    final fechaIa = DateTime.tryParse(m['fecha_vencimiento_iso']?.toString() ?? '');
    final origen = (m['fecha_origen']?.toString() == 'leida')
        ? FechaOrigen.leida
        : FechaOrigen.estimada;
    // Una fecha leída se respeta aunque ya pasó (el producto está vencido);
    // una estimada en el pasado es un error de cálculo de la IA.
    final DateTime fecha = noVence
        ? Alimento.nuncaVence
        : fechaIa == null
            ? Alimento.sinFecha
            : origen == FechaOrigen.estimada
                ? _noAntesDeHoy(fechaIa)
                : fechaIa;

    return AlimentoDetectado(
      caja: _caja(m['box_2d']),
      alimento: Alimento(
        id: '${ahora.microsecondsSinceEpoch}-${m.hashCode}',
        nombre: m['nombre']?.toString() ?? 'Desconocido',
        categoria: m['categoria']?.toString() ?? 'Otros',
        cantidad: Cantidad(
          valor: valor > 0 ? valor : 1.0,
          unidad: m['cantidad_unidad']?.toString() ?? 'u',
        ),
        fechaVencimiento: fecha,
        estado: Disponible(ahora),
        origenFecha: origen,
        ubicacion: Ubicacion.desde(m['ubicacion']?.toString()),
        precio: (m['precio_total'] as num?)?.toDouble(),
        fechaCompra: ahora,
        cantidadInicial: valor > 0 ? valor : 1.0,
        emoji: _emoji(m['emoji']),
      ),
    );
  }

  /// Hoy si [fecha] ya pasó; si no, la misma fecha.
  static DateTime _noAntesDeHoy(DateTime fecha) {
    final a = DateTime.now();
    final hoy = DateTime(a.year, a.month, a.day);
    return fecha.isBefore(hoy) ? hoy : fecha;
  }

  /// El emoji solo si de verdad es un emoji corto (sin letras ni números).
  static String? _emoji(Object? valor) {
    final t = valor?.toString().trim() ?? '';
    if (t.isEmpty || t.length > 12 || RegExp(r'[A-Za-z0-9]').hasMatch(t)) return null;
    return t;
  }

  /// La caja `[ymin, xmin, ymax, xmax]` si tiene la forma esperada.
  static List<num>? _caja(Object? valor) {
    if (valor is! List || valor.length != 4 || valor.any((v) => v is! num)) return null;
    return valor.cast<num>();
  }
}
