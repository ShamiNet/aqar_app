import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class LocalDbService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aqar_offline.db');
    return _database!;
  }

  static Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  static Future<void> _createDB(Database db, int version) async {
    // 1. جدول للعقارات المحفوظة (للقراءة بدون إنترنت)
    await db.execute('''
      CREATE TABLE cached_properties (
        id TEXT PRIMARY KEY,
        data TEXT
      )
    ''');

    // 2. جدول للعمليات المعلقة (Sync Queue - للطبات التي تمت بدون إنترنت)
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        method TEXT,
        endpoint TEXT,
        body TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // ==========================================
  // 💾 حفظ وجلب العقارات (Offline Read)
  // ==========================================
  static Future<void> cachePropertiesList(
    List<Map<String, dynamic>> properties,
  ) async {
    final db = await database;
    Batch batch = db.batch();

    // مسح الكاش القديم
    batch.delete('cached_properties');

    // إضافة البيانات الجديدة للعمل بدون إنترنت
    for (var prop in properties) {
      batch.insert('cached_properties', {
        'id': prop['id'] ?? prop['_id'],
        'data': jsonEncode(prop),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getCachedProperties() async {
    final db = await database;
    final result = await db.query('cached_properties');
    return result
        .map((e) => jsonDecode(e['data'] as String) as Map<String, dynamic>)
        .toList();
  }

  // ==========================================
  // 🔄 نظام المزامنة (Offline Write & Sync)
  // ==========================================
  static Future<void> addPendingRequest(
    String method,
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final db = await database;
    await db.insert('sync_queue', {
      'method': method,
      'endpoint': endpoint,
      'body': jsonEncode(body),
    });
    debugPrint(
      '📦 [Offline] لا يوجد إنترنت: تم حفظ الطلب محلياً للمزامنة لاحقاً ($endpoint)',
    );
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'created_at ASC');
  }

  static Future<void> removePendingRequest(int id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }
}
