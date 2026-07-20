import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants.dart';
import '../models/category.dart';
import '../models/item.dart';

/// Manages all SQLite persistence for inventory items.
class DatabaseService {
  static DatabaseService? _instance;
  Database? _db;

  DatabaseService._();
  factory DatabaseService() => _instance ??= DatabaseService._();

  Future<Database> get database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, AppConstants.dbName);
    return openDatabase(path,
        version: AppConstants.dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.itemsTable} (
        id                    TEXT PRIMARY KEY,
        name                  TEXT NOT NULL,
        category              TEXT NOT NULL,
        sub_category          TEXT,
        room_location         TEXT,
        photo_paths           TEXT,
        voice_description     TEXT,
        notes                 TEXT,
        identified_as         TEXT,
        barcode_value         TEXT,
        barcode_product_name  TEXT,
        estimated_value       REAL,
        dimensions            TEXT,
        packing_status        TEXT DEFAULT 'notStarted',
        is_duplicate_flagged  INTEGER DEFAULT 0,
        enhanced_photo_path   TEXT,
        created_at            TEXT NOT NULL,
        updated_at            TEXT NOT NULL,
        sell_details          TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Add migration stubs here for future schema changes.
  }

  // ---- CRUD ----

  Future<void> insertItem(Item item) async {
    final db = await database;
    await db.insert(AppConstants.itemsTable, item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.update(AppConstants.itemsTable, item.toMap(),
        where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> deleteItem(String id) async {
    final db = await database;
    await db.delete(AppConstants.itemsTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteItems(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(AppConstants.itemsTable,
        where: 'id IN ($placeholders)', whereArgs: ids);
  }

  Future<Item?> getItem(String id) async {
    final db = await database;
    final rows = await db.query(AppConstants.itemsTable,
        where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Item.fromMap(rows.first);
  }

  Future<List<Item>> getAllItems({
    Category? filterCategory,
    PackingStatus? filterPackingStatus,
    String? filterRoom,
    String? searchQuery,
    String? orderBy,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];

    if (filterCategory != null) {
      conditions.add('category = ?');
      args.add(filterCategory.name);
    }
    if (filterPackingStatus != null) {
      conditions.add('packing_status = ?');
      args.add(filterPackingStatus.name);
    }
    if (filterRoom != null) {
      conditions.add('room_location = ?');
      args.add(filterRoom);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = '%$searchQuery%';
      conditions.add('(name LIKE ? OR identified_as LIKE ? OR voice_description LIKE ? OR barcode_product_name LIKE ?)');
      args.addAll([q, q, q, q]);
    }

    final where = conditions.isEmpty ? null : conditions.join(' AND ');
    final rows = await db.query(AppConstants.itemsTable,
        where: where, whereArgs: args.isEmpty ? null : args,
        orderBy: orderBy ?? 'updated_at DESC');
    return rows.map(Item.fromMap).toList();
  }

  Future<Map<Category, int>> getCategoryCounts() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT category, COUNT(*) as cnt FROM ${AppConstants.itemsTable} GROUP BY category');
    return {
      for (final row in rows)
        Category.values.firstWhere((c) => c.name == row['category'],
            orElse: () => Category.trash): row['cnt'] as int
    };
  }

  Future<double> getTotalEstimatedValue({Category? category}) async {
    final db = await database;
    final where = category != null ? 'WHERE category = ?' : '';
    final args = category != null ? [category.name] : [];
    final result = await db.rawQuery(
        'SELECT SUM(estimated_value) as total FROM ${AppConstants.itemsTable} $where',
        args);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<Item>> getDuplicateFlagged() async {
    final db = await database;
    final rows = await db.query(AppConstants.itemsTable,
        where: 'is_duplicate_flagged = 1');
    return rows.map(Item.fromMap).toList();
  }

  /// Returns all rows as raw maps for the export service.
  Future<List<Map<String, dynamic>>> exportAllRaw() async {
    final db = await database;
    return db.query(AppConstants.itemsTable, orderBy: 'category, name');
  }

  /// Copies the live database file to [destPath] (SQLite export).
  Future<void> copyDatabaseTo(String destPath) async {
    final db = await database;
    final src = db.path;
    await db.close();
    _db = null;
    await File(src).copy(destPath);
    _db = await _openDb();
  }
}
