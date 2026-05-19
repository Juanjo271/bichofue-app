import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Servicio de base de datos SQLite local para modo OFFLINE.
/// Copia la DB embebida desde assets al almacenamiento del dispositivo
/// la primera vez que se abre.
class DatabaseService {
  static Database? _db;
  static const String _dbName = 'caliguia_offline.db';

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    // Si no existe, copiar desde assets
    if (!await databaseExists(path)) {
      try {
        await Directory(dirname(path)).create(recursive: true);
        final data = await rootBundle.load('assets/data/caliguia.db');
        final bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception('Error copiando base de datos offline: $e');
      }
    }

    return await openDatabase(path, readOnly: true);
  }

  /// Lista todos los atractivos (modo offline)
  static Future<List<Map<String, dynamic>>> getAtractivos() async {
    final db = await database;
    return await db.query('atractivos', orderBy: 'es_emblematico DESC, nombre ASC');
  }

  /// Buscar atractivo por ID
  static Future<Map<String, dynamic>?> getAtractivoById(int id) async {
    final db = await database;
    final rows = await db.query('atractivos', where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Lista perfiles disponibles
  static Future<List<Map<String, dynamic>>> getPerfiles() async {
    final db = await database;
    return await db.query('perfiles', orderBy: 'id');
  }

  /// Lista eventos
  static Future<List<Map<String, dynamic>>> getEventos() async {
    final db = await database;
    return await db.query('eventos', orderBy: 'fecha_inicio');
  }

  /// Cierra la conexion
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
