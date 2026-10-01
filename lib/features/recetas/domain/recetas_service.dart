import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/domain/gemini_client.dart';
import 'package:foodzy/features/alimentos/presentation/widgets/estado_visual.dart';
import 'package:foodzy/features/configuracion/presentation/providers/api_key_provider.dart';

final recetasServiceProvider = Provider<RecetasService>((ref) {
  return RecetasService(GeminiClient(apiKey: ref.watch(apiKeyProvider)));
});

class IngredienteReceta {
  const IngredienteReceta({
    required this.nombre,
    required this.cantidad,
    required this.enDespensa,
    this.alimentoId,
    this.cantidadUsada,
  });

  final String nombre;

  /// Id del alimento de la despensa del que sale (si [enDespensa]).
  final String? alimentoId;

  /// Cuánto se gasta, en la misma unidad que el alimento de la despensa.
  /// `null` si no es medible (ej. "al gusto") y por tanto no se descuenta.
  final double? cantidadUsada;

  /// Texto libre: "2 cucharadas", "200 g", "al gusto".
  final String cantidad;

  /// `true` si sale de la despensa; `false` si habría que conseguirlo.
  final bool enDespensa;
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
}

class RecetasService {
  RecetasService(this._cliente);

  final GeminiClient _cliente;

  /// Genera recetas con lo que hay en la despensa. Si se da [prioritario],
  /// todas deben usar ese alimento (el que está por vencerse).
  Future<List<Receta>> generar(
    List<Alimento> despensa, {
    Alimento? prioritario,
    int cuantas = 3,
  }) async {
    // Por seguridad, la comida ya vencida nunca entra en las recetas.
    final disponibles = despensa
        .where((a) =>
            a.estado is Disponible &&
            (a.sinFechaVencimiento || diasParaVencer(a) >= 0))
        .toList();
    if (prioritario != null && !disponibles.any((a) => a.id == prioritario.id)) {
      throw const ScannerException(
          'Ese alimento ya está vencido; por seguridad no sugerimos recetas con él.');
    }
    if (disponibles.isEmpty) {
      throw const ScannerException(
          'No tienes alimentos vigentes en tu despensa para armar recetas.');
    }

    final catalogo = disponibles
        .map((a) => {
              'id': a.id,
              'nombre': a.nombre,
              'categoria': a.categoria,
              'cantidad': a.cantidad.valor,
              'unidad': a.cantidad.unidad,
              'dias_para_vencer':
                  a.sinFechaVencimiento ? null : diasParaVencer(a),
            })
        .toList();

    final foco = prioritario == null
        ? 'Prioriza usar primero los alimentos con menos días para vencer (dias_para_vencer bajo o negativo = urgente).'
        : 'TODAS las recetas deben usar "${prioritario.nombre}" (id ${prioritario.id}) como ingrediente principal, '
            'porque está por vencerse y hay que aprovecharlo.';

    final json = await _cliente.pedir('''
Eres un chef que ayuda a no desperdiciar comida. Esta es la despensa de la persona (JSON):
${jsonEncode(catalogo)}

Crea $cuantas recetas distintas, realistas y fáciles de hacer en casa.
$foco

Reglas:
0. Todos los alimentos del inventario están vigentes (ninguno vencido).
1. Usa principalmente ingredientes de la despensa; respeta las cantidades que hay (no pidas más de lo disponible).
2. Solo puedes sumar como "extra" básicos que casi todos tienen (sal, pimienta, aceite, agua, azúcar). Si necesitas algo más, márcalo con "en_despensa": false.
3. Marca "en_despensa": true solo para lo que realmente aparece en el JSON, y en ese caso pon "alimento_id" con el id EXACTO del inventario.
4. Para cada ingrediente de la despensa pon "cantidad_usada": un número en la MISMA unidad que tiene ese alimento en el inventario
   (ej. si el arroz está en "g", 200; si los huevos están en "u", 2; si la leche está en "L", 0.25). Nunca superes lo disponible.
   Si no se puede medir (al gusto, una pizca) pon null.
5. Pasos claros y cortos, en español.
6. "aprovecha": una frase que diga qué producto por vencer se aprovecha (o null).

Devuelve SOLO un arreglo JSON con objetos de esta forma:
{"titulo": "Arroz con huevo", "descripcion": "Una frase", "minutos": 20, "porciones": 2,
 "aprovecha": "Usa los tomates que vencen mañana",
 "ingredientes": [{"nombre": "Tomate", "cantidad": "2 unidades", "en_despensa": true, "alimento_id": "<id>", "cantidad_usada": 2}],
 "pasos": ["Paso 1", "Paso 2"]}
''');

    final porId = {for (final a in disponibles) a.id: a};

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
    if (recetas.isEmpty) {
      throw const ScannerException(
          'No pude armar recetas con tu despensa. Intenta de nuevo.');
    }
    return recetas;
  }
}
