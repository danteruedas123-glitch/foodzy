import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';
import 'package:foodzy/features/premium/premium_provider.dart';

final recetasServiceProvider = Provider<RecetasService>((ref) {
  return RecetasService(GeminiClient(
    apiKey: ref.watch(apiKeyProvider),
    cuota: ref.watch(cuotaIAProvider),
  ));
});

/// Gustos y restricciones de la persona al cocinar.
class PreferenciasCulinarias {
  const PreferenciasCulinarias({
    this.dieta = 'Sin restricción',
    this.alergias = '',
    this.tiempoMax = 0,
  });

  factory PreferenciasCulinarias.fromJson(Map<String, dynamic> j) =>
      PreferenciasCulinarias(
        dieta: j['dieta']?.toString() ?? 'Sin restricción',
        alergias: j['alergias']?.toString() ?? '',
        tiempoMax: (j['tiempoMax'] as num?)?.toInt() ?? 0,
      );

  static const dietas = [
    'Sin restricción',
    'Vegetariana',
    'Vegana',
    'Sin lactosa',
    'Sin gluten',
  ];

  final String dieta;

  /// Texto libre: "maní, mariscos".
  final String alergias;

  /// Minutos máximos de preparación; 0 = sin límite.
  final int tiempoMax;

  Map<String, dynamic> toJson() =>
      {'dieta': dieta, 'alergias': alergias, 'tiempoMax': tiempoMax};

  PreferenciasCulinarias copyWith({String? dieta, String? alergias, int? tiempoMax}) =>
      PreferenciasCulinarias(
        dieta: dieta ?? this.dieta,
        alergias: alergias ?? this.alergias,
        tiempoMax: tiempoMax ?? this.tiempoMax,
      );

  bool get hayRestricciones =>
      dieta != 'Sin restricción' || alergias.trim().isNotEmpty || tiempoMax > 0;

  /// Texto para el prompt de la IA.
  String paraPrompt() {
    final partes = <String>[];
    if (dieta != 'Sin restricción') partes.add('Dieta: $dieta (respétala estrictamente).');
    if (alergias.trim().isNotEmpty) {
      partes.add('ALERGIAS o ingredientes que NO puede comer: ${alergias.trim()}. Nunca los uses.');
    }
    if (tiempoMax > 0) partes.add('Cada receta debe poder prepararse en $tiempoMax minutos o menos.');
    return partes.isEmpty ? '' : 'Preferencias de la persona:\n${partes.join('\n')}\n';
  }
}

class IngredienteReceta {
  const IngredienteReceta({
    required this.nombre,
    required this.cantidad,
    required this.enDespensa,
    this.alimentoId,
    this.cantidadUsada,
  });

  factory IngredienteReceta.fromJson(Map<String, dynamic> j) => IngredienteReceta(
        nombre: j['nombre']?.toString() ?? '',
        cantidad: j['cantidad']?.toString() ?? '',
        enDespensa: j['enDespensa'] == true,
        alimentoId: j['alimentoId']?.toString(),
        cantidadUsada: (j['cantidadUsada'] as num?)?.toDouble(),
      );

  final String nombre;

  /// Texto libre: "2 cucharadas", "200 g", "al gusto".
  final String cantidad;

  /// `true` si sale de la despensa; `false` si habría que conseguirlo.
  final bool enDespensa;

  /// Id del alimento de la despensa del que sale (si [enDespensa]).
  final String? alimentoId;

  /// Cuánto se gasta, en la misma unidad que el alimento de la despensa.
  /// `null` si no es medible (ej. "al gusto") y por tanto no se descuenta.
  final double? cantidadUsada;

  Map<String, dynamic> toJson() => {
        'nombre': nombre,
        'cantidad': cantidad,
        'enDespensa': enDespensa,
        if (alimentoId != null) 'alimentoId': alimentoId,
        if (cantidadUsada != null) 'cantidadUsada': cantidadUsada,
      };
}

class Receta {
  const Receta({
    required this.titulo,
    required this.descripcion,
    required this.minutos,
    required this.porciones,
    required this.ingredientes,
    required this.pasos,
    this.aprovecha,
  });

  factory Receta.fromJson(Map<String, dynamic> j) => Receta(
        titulo: j['titulo']?.toString() ?? 'Receta',
        descripcion: j['descripcion']?.toString() ?? '',
        minutos: (j['minutos'] as num?)?.toInt() ?? 30,
        porciones: (j['porciones'] as num?)?.toInt() ?? 2,
        aprovecha: j['aprovecha']?.toString(),
        ingredientes: [
          for (final i in (j['ingredientes'] as List? ?? const []))
            if (i is Map) IngredienteReceta.fromJson(Map<String, dynamic>.from(i)),
        ],
        pasos: [for (final p in (j['pasos'] as List? ?? const [])) p.toString()],
      );

  final String titulo;
  final String descripcion;
  final int minutos;
  final int porciones;
  final List<IngredienteReceta> ingredientes;
  final List<String> pasos;

  /// Nota de qué producto por vencer aprovecha y por qué.
  final String? aprovecha;

  List<IngredienteReceta> get faltantes =>
      ingredientes.where((i) => !i.enDespensa).toList();

  /// Identifica la receta aunque se regenere (para favoritas).
  String get clave => titulo.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'minutos': minutos,
        'porciones': porciones,
        if (aprovecha != null) 'aprovecha': aprovecha,
        'ingredientes': ingredientes.map((i) => i.toJson()).toList(),
        'pasos': pasos,
      };
}

/// Una comida del plan semanal: solo el título y una idea; la receta completa
/// se pide al tocarla.
class ComidaPlan {
  const ComidaPlan({
    required this.momento,
    required this.titulo,
    required this.descripcion,
  });

  factory ComidaPlan.fromJson(Map<String, dynamic> j) => ComidaPlan(
        momento: j['momento']?.toString() ?? '',
        titulo: j['titulo']?.toString() ?? '',
        descripcion: j['descripcion']?.toString() ?? '',
      );

  final String momento; // "Almuerzo" | "Cena"
  final String titulo;
  final String descripcion;

  Map<String, dynamic> toJson() =>
      {'momento': momento, 'titulo': titulo, 'descripcion': descripcion};
}

class DiaPlan {
  const DiaPlan({required this.dia, required this.comidas});

  factory DiaPlan.fromJson(Map<String, dynamic> j) => DiaPlan(
        dia: j['dia']?.toString() ?? '',
        comidas: [
          for (final c in (j['comidas'] as List? ?? const []))
            if (c is Map) ComidaPlan.fromJson(Map<String, dynamic>.from(c)),
        ],
      );

  final String dia;
  final List<ComidaPlan> comidas;

  Map<String, dynamic> toJson() =>
      {'dia': dia, 'comidas': comidas.map((c) => c.toJson()).toList()};
}

class RecetasService {
  RecetasService(this._cliente);

  final GeminiClient _cliente;

  /// Alimentos que se pueden cocinar: disponibles y no vencidos.
  List<Alimento> _vigentes(List<Alimento> despensa) => despensa
      .where((a) =>
          a.estado is Disponible &&
          (a.sinFechaVencimiento || a.noVence || diasParaVencer(a) >= 0))
      .toList();

  String _catalogo(List<Alimento> disponibles) => jsonEncode(disponibles
      .map((a) => {
            'id': a.id,
            'nombre': a.nombre,
            'categoria': a.categoria,
            'cantidad': a.cantidad.valor,
            'unidad': a.cantidad.unidad,
            'dias_para_vencer':
                (a.sinFechaVencimiento || a.noVence) ? null : diasParaVencer(a),
          })
      .toList());

  static const _formatoReceta = '''
{"titulo": "Arroz con huevo", "descripcion": "Una frase", "minutos": 20, "porciones": 2,
 "aprovecha": "Usa los tomates que vencen mañana",
 "ingredientes": [{"nombre": "Tomate", "cantidad": "2 unidades", "en_despensa": true, "alimento_id": "<id>", "cantidad_usada": 2}],
 "pasos": ["Paso 1", "Paso 2"]}''';

  static const _reglasIngredientes = '''
1. Usa principalmente ingredientes de la despensa; respeta las cantidades que hay (no pidas más de lo disponible).
2. Solo puedes sumar como "extra" básicos que casi todos tienen (sal, pimienta, aceite, agua, azúcar). Si necesitas algo más, márcalo con "en_despensa": false.
3. Marca "en_despensa": true solo para lo que realmente aparece en el JSON, y en ese caso pon "alimento_id" con el id EXACTO del inventario.
4. Para cada ingrediente de la despensa pon "cantidad_usada": un número en la MISMA unidad que tiene ese alimento en el inventario
   (ej. si el arroz está en "g", 200; si los huevos están en "u", 2; si la leche está en "L", 0.25). Nunca superes lo disponible.
   Si no se puede medir (al gusto, una pizca) pon null.
5. Pasos claros y cortos, en español.''';

  /// Genera recetas con lo que hay en la despensa. Si se da [prioritario],
  /// todas deben usar ese alimento (el que está por vencerse).
  Future<List<Receta>> generar(
    List<Alimento> despensa, {
    Alimento? prioritario,
    int cuantas = 3,
    String? momento,
    PreferenciasCulinarias preferencias = const PreferenciasCulinarias(),
  }) async {
    // Por seguridad, la comida ya vencida nunca entra en las recetas.
    final disponibles = _vigentes(despensa);
    if (prioritario != null && !disponibles.any((a) => a.id == prioritario.id)) {
      throw const ScannerException(
          'Ese alimento ya está vencido; por seguridad no sugerimos recetas con él.');
    }
    if (disponibles.isEmpty) {
      throw const ScannerException(
          'No tienes alimentos vigentes en tu despensa para armar recetas.');
    }

    final foco = prioritario == null
        ? 'Prioriza usar primero los alimentos con menos días para vencer (dias_para_vencer bajo = urgente).'
        : 'TODAS las recetas deben usar "${prioritario.nombre}" (id ${prioritario.id}) como ingrediente principal, '
            'porque está por vencerse y hay que aprovecharlo.';

    final json = await _cliente.pedir('''
Eres un chef que ayuda a no desperdiciar comida. Esta es la despensa de la persona (JSON):
${_catalogo(disponibles)}

${preferencias.paraPrompt()}
Crea $cuantas recetas distintas, realistas y fáciles de hacer en casa.
${momento == null ? '' : 'Todas las recetas deben ser apropiadas para el ${momento.toUpperCase()} (plato típico de esa comida del día).\n'}$foco

Reglas:
0. Todos los alimentos del inventario están vigentes (ninguno vencido).
$_reglasIngredientes
6. "aprovecha": una frase que diga qué producto por vencer se aprovecha (o null).

Devuelve SOLO un arreglo JSON con objetos de esta forma:
$_formatoReceta
''');

    final recetas = _parsear(json, {for (final a in disponibles) a.id: a});
    if (recetas.isEmpty) {
      throw const ScannerException(
          'No pude armar recetas con tu despensa. Intenta de nuevo.');
    }
    return recetas;
  }

  /// Arma un menú de [dias] días (almuerzo y cena) que aprovecha primero lo
  /// que vence antes.
  Future<List<DiaPlan>> planSemanal(
    List<Alimento> despensa, {
    int dias = 7,
    PreferenciasCulinarias preferencias = const PreferenciasCulinarias(),
  }) async {
    final disponibles = _vigentes(despensa);
    if (disponibles.isEmpty) {
      throw const ScannerException(
          'No tienes alimentos vigentes en tu despensa para armar un menú.');
    }
    final json = await _cliente.pedir('''
Eres un nutricionista y chef. Despensa de la persona (JSON):
${_catalogo(disponibles)}

${preferencias.paraPrompt()}
Arma un menú de $dias días con ALMUERZO y CENA cada día. Aprovecha primero lo que vence antes
(dias_para_vencer bajo) y reparte los ingredientes para que alcancen. Puedes sugerir comprar pocas cosas básicas.
Varía los platos y mantenlos fáciles.

Devuelve SOLO un arreglo JSON de $dias objetos con esta forma:
{"dia": "Lunes", "comidas": [
  {"momento": "Almuerzo", "titulo": "Arroz con huevo", "descripcion": "Una frase corta"},
  {"momento": "Cena", "titulo": "Sopa de tomate", "descripcion": "Una frase corta"}]}
''');
    final lista = json is List ? json : [json];
    final plan = [
      for (final d in lista)
        if (d is Map) DiaPlan.fromJson(Map<String, dynamic>.from(d)),
    ].where((d) => d.comidas.isNotEmpty).toList();
    if (plan.isEmpty) {
      throw const ScannerException('No pude armar el menú. Intenta de nuevo.');
    }
    return plan;
  }

  /// Receta completa de un plato del plan, con ingredientes de la despensa.
  Future<Receta> detallar(
    String titulo,
    List<Alimento> despensa, {
    PreferenciasCulinarias preferencias = const PreferenciasCulinarias(),
  }) async {
    final disponibles = _vigentes(despensa);
    final json = await _cliente.pedir('''
Despensa de la persona (JSON):
${_catalogo(disponibles)}

${preferencias.paraPrompt()}
Escribe la receta completa de "$titulo" usando lo que hay en la despensa.

Reglas:
$_reglasIngredientes

Devuelve SOLO un objeto JSON con esta forma:
$_formatoReceta
''');
    final recetas = _parsear(json, {for (final a in disponibles) a.id: a});
    if (recetas.isEmpty) {
      throw const ScannerException('No pude armar esa receta. Intenta de nuevo.');
    }
    return recetas.first;
  }

  List<Receta> _parsear(dynamic json, Map<String, Alimento> porId) {
    final lista = json is List ? json : [json];
    final recetas = <Receta>[];
    for (final r in lista) {
      if (r is! Map) continue;
      final ings = <IngredienteReceta>[];
      for (final i in (r['ingredientes'] as List? ?? const [])) {
        if (i is! Map) continue;
        // Solo cuenta como "de la despensa" si el id existe de verdad.
        final alimento = porId[i['alimento_id']?.toString()];
        final usada = (i['cantidad_usada'] as num?)?.toDouble();
        ings.add(IngredienteReceta(
          nombre: i['nombre']?.toString() ?? '',
          cantidad: i['cantidad']?.toString() ?? '',
          enDespensa: alimento != null,
          alimentoId: alimento?.id,
          cantidadUsada: (alimento != null && usada != null && usada > 0)
              ? usada.clamp(0.0, alimento.cantidad.valor).toDouble()
              : null,
        ));
      }
      final pasos = [
        for (final p in (r['pasos'] as List? ?? const [])) p.toString(),
      ];
      if (ings.isEmpty || pasos.isEmpty) continue;
      recetas.add(Receta(
        titulo: r['titulo']?.toString() ?? 'Receta',
        descripcion: r['descripcion']?.toString() ?? '',
        minutos: (r['minutos'] as num?)?.toInt() ?? 30,
        porciones: (r['porciones'] as num?)?.toInt() ?? 2,
        aprovecha: r['aprovecha']?.toString(),
        ingredientes: ings,
        pasos: pasos,
      ));
    }
    return recetas;
  }
}
