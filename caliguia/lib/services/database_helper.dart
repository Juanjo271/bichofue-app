import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Helper de SQLite local para cache de fotos, chat histórico y datos offline.
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'caliguia_local.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        // Cache de fotos de marcadores
        await db.execute('''
          CREATE TABLE cached_photos (
            marker_id INTEGER PRIMARY KEY,
            image BLOB NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');
        // Histórico de chat
        await db.execute('''
          CREATE TABLE chat_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            is_bot INTEGER NOT NULL,
            text TEXT NOT NULL,
            audio_url TEXT,
            route_meta TEXT,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        // Placeholder para futuras migraciones
      },
    );
  }

  /// Guardar foto en cache local
  Future<void> saveCachedPhoto(int markerId, Uint8List image) async {
    final db = await database;
    await db.insert(
      'cached_photos',
      {
        'marker_id': markerId,
        'image': image,
        'cached_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtener foto de cache local
  Future<Uint8List?> getCachedPhoto(int markerId) async {
    final db = await database;
    final results = await db.query(
      'cached_photos',
      where: 'marker_id = ?',
      whereArgs: [markerId],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first['image'] as Uint8List;
    }
    return null;
  }

  /// Guardar mensaje de chat
  Future<void> saveChatMessage({
    required bool isBot,
    required String text,
    String? audioUrl,
    String? routeMeta,
  }) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      {
        'is_bot': isBot ? 1 : 0,
        'text': text,
        'audio_url': audioUrl,
        'route_meta': routeMeta,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Obtener historial de chat
  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 100}) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      orderBy: 'id ASC',
      limit: limit,
    );
  }

  /// Limpiar historial de chat
  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete('chat_messages');
  }

  /// Cerrar conexión (para testing)
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
