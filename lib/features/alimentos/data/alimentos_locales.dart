import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:foodzy/core/json.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';

/// Cómo se lee un archivo de texto. Se inyecta para poder probar sin assets.
typedef LectorDeAssets = Future<String> Function(String ruta);

class AlimentosLocales implements AlimentosRepository {
  /// El lector entra por el constructor.
  AlimentosLocales({
    LectorDeAssets? lector,
    this.ruta = 'assets/data/alimentos.json',
  }) : _lector = lector ?? rootBundle.loadString;

  final LectorDeAssets _lector;
  final String ruta;

  List<Alimento>? _cache;

  @override
  Future<List<Alimento>> obtenerTodos() async {
    final guardado = _cache;
    if (guardado != null) return guardado;

    final crudo = await _lector(ruta);
    final decodificado = jsonDecode(crudo);

    if (decodificado is! List) {
      throw const CampoInvalido('(raíz)', 'el archivo debe contener una lista', null);
    }

    return _cache = decodificado
        .map((e) => Alimento.fromJson(e as Map<String, dynamic>))
        .toList(growable: true);
  }

  @override
  Future<Alimento?> obtenerPorId(String id) async {
    for (final alimento in await obtenerTodos()) {
      if (alimento.id == id) return alimento;
    }
    return null;
  }
  
  @override
  Future<List<Alimento>> obtenerDisponibles() async {
    final todos = await obtenerTodos();
    return todos.where((a) => a.estado is Disponible).toList();
  }

  @override
  Future<void> guardar(Alimento alimento) async {
    final todos = await obtenerTodos();
    final index = todos.indexWhere((a) => a.id == alimento.id);
    if (index >= 0) {
      todos[index] = alimento;
    } else {
      todos.add(alimento);
    }
  }

  @override
  Future<void> eliminar(String id) async {
    final todos = await obtenerTodos();
    todos.removeWhere((a) => a.id == id);
  }
}
