import 'dart:io';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

class CsvExportService {
  /// يقوم بتصدير جميع العمليات إلى ملف CSV
  static Future<String> exportAll() async {
    final db = await DatabaseService().database;

    // تنفيذ الاستعلام لجلب كافة الصفوف بدون شرط الشهر
    final rows = await db.query('transactions', orderBy: 'created_at DESC');

    final buffer = StringBuffer();
    buffer.writeln('id,category,amount,is_income,hijri_month,created_at');
    for (final r in rows) {
      final id = r['id'];
      final cat = r['category_name'];
      final amount = r['amount'];
      final isIncome = r['is_income'];
      final hijri = r['hijri_month'];
      final created = r['created_at'];
      buffer.writeln('$id,"$cat",$amount,$isIncome,$hijri,$created');
    }

    final dbPath = await getDatabasesPath();
    final fileName = 'all_transactions_export.csv';
    final path = join(dbPath, fileName);
    final file = File(path);
    await file.writeAsString(buffer.toString());
    return path;
  }
}
