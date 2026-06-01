import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/transaction.dart';
import '../models/category.dart';
import '../models/monthly_summary.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'quick_financial_tracker.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  FutureOr<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        is_income INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        amount REAL NOT NULL,
        is_income INTEGER NOT NULL,
        hijri_month TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE monthly_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL UNIQUE,
        opening_balance REAL NOT NULL,
        closing_balance REAL NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  // Categories
  Future<int> insertCategory(CategoryModel c) async {
    final db = await database;
    return await db.insert('categories', c.toMap());
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CategoryModel>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'id');
    return rows.map((r) => CategoryModel.fromMap(r)).toList();
  }

  // Transactions
  Future<int> insertTransaction(TransactionModel t) async {
    final db = await database;
    return await db.insert('transactions', t.toMap());
  }

  Future<List<TransactionModel>> getTransactionsByMonth(String monthKey) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'hijri_month = ?',
      whereArgs: [monthKey],
      orderBy: 'created_at DESC',
    );
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  Future<List<TransactionModel>> getTransactionsBeforeMonth(
    String monthKey,
  ) async {
    final db = await database;
    final rows = await db.query(
      'transactions',
      where: 'hijri_month < ?',
      whereArgs: [monthKey],
      orderBy: 'hijri_month ASC, created_at ASC',
    );
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'created_at DESC');
    return rows.map((r) => TransactionModel.fromMap(r)).toList();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('monthly_summaries');
      await txn.delete('categories');
    });
  }

  // Monthly summaries
  Future<int> insertMonthlySummary(MonthlySummary s) async {
    final db = await database;
    return await db.insert(
      'monthly_summaries',
      s.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<MonthlySummary?> getMonthlySummary(String monthKey) async {
    final db = await database;
    final rows = await db.query(
      'monthly_summaries',
      where: 'month_key = ?',
      whereArgs: [monthKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlySummary.fromMap(rows.first);
  }

  Future<MonthlySummary?> getLatestMonthlySummary() async {
    final db = await database;
    final rows = await db.query(
      'monthly_summaries',
      orderBy: 'created_at DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlySummary.fromMap(rows.first);
  }

  Future<MonthlySummary?> getLatestMonthlySummaryBeforeOrFor(
    String monthKey,
  ) async {
    final db = await database;
    final rows = await db.query(
      'monthly_summaries',
      where: 'month_key <= ?',
      whereArgs: [monthKey],
      orderBy: 'month_key DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MonthlySummary.fromMap(rows.first);
  }

  // Close DB
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
