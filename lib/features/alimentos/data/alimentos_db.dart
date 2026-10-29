import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/alimentos_repository.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class AlimentosDB implements AlimentosRepository {
  AlimentosDB._();
  
  static final AlimentosDB instance = AlimentosDB._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('alimentos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE alimentos (
        id TEXT PRIMARY KEY,
        datos TEXT NOT NULL
      )
    ''');
  }

  @override
  Future<List<Alimento>> obtenerTodos() async {
    final db = await instance.database;
    final maps = await db.query('alimentos');

    if (maps.isEmpty) {
      return [];
    }

    return maps.map((map) {
      final decoded = jsonDecode(map['datos'] as String);
      return Alimento.fromJson(decoded as Map<String, dynamic>);
    }).toList();
  }

  @override
  Future<Alimento?> obtenerPorId(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'alimentos',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final decoded = jsonDecode(maps.first['datos'] as String);
      return Alimento.fromJson(decoded as Map<String, dynamic>);
    } else {
      return null;
    }
  }

  @override
  Future<List<Alimento>> obtenerDisponibles() async {
    final todos = await obtenerTodos();
    return todos.where((a) => a.estado is Disponible).toList();
  }

  @override
  Future<void> guardar(Alimento alimento) async {
    final db = await instance.database;
    final datosStr = jsonEncode(alimento.toJson());

    await db.insert(
      'alimentos',
      {
        'id': alimento.id,
        'datos': datosStr,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Guarda varios alimentos en una sola transacción.
  Future<void> guardarVarios(Iterable<Alimento> alimentos) async {
    final db = await instance.database;
    final lote = db.batch();
    for (final a in alimentos) {
      lote.insert(
        'alimentos',
        {'id': a.id, 'datos': jsonEncode(a.toJson())},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await lote.commit(noResult: true);
  }

  /// Borra varios alimentos con una sola consulta por cada 500 ids.
  Future<void> eliminarVarios(Iterable<String> ids) async {
    final db = await instance.database;
    final lista = ids.toList();
    for (var i = 0; i < lista.length; i += 500) {
      final parte = lista.skip(i).take(500).toList();
      await db.delete(
        'alimentos',
        where: 'id IN (${List.filled(parte.length, '?').join(',')})',
        whereArgs: parte,
      );
    }
  }

  @override
  Future<void> eliminar(String id) async {
    final db = await instance.database;
    await db.delete(
      'alimentos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
