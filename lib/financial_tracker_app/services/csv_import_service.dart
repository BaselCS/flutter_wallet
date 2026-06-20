import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'database_service.dart';

class CsvImportService {
  static Future<int> importCsv(String filePath) async {
    final file = File(filePath);
    final input = await file.readAsString();

    // محاولة التحليل باستخدام نهاية السطر القياسية
    List<List<dynamic>> rows = const CsvToListConverter(
      eol: '\n',
    ).convert(input);

    // إذا لم يتم التقسيم بشكل صحيح، نحاول باستخدام نهاية السطر الخاصة بويندوز
    if (rows.isEmpty || rows.length == 1) {
      rows = const CsvToListConverter(eol: '\r\n').convert(input);
    }

    if (rows.isEmpty || rows.length <= 1) return 0;

    int count = 0;
    final dbService = DatabaseService();

    final existingCategories = await dbService.getCategories();
    final categoryMap = {for (var c in existingCategories) c.name: c.id};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) continue;

      try {
        final catName = row[1].toString().replaceAll('"', '').trim();
        final amount = double.tryParse(row[2].toString())?.toInt() ?? 0;
        final isIncome =
            row[3].toString() == '1' ||
            row[3].toString().toLowerCase() == 'true';
        final hijriMonth = row[4].toString().trim();
        final createdAt =
            int.tryParse(row[5].toString()) ??
            DateTime.now().millisecondsSinceEpoch;

        int catId = categoryMap[catName] ?? 0;
        if (catId == 0) {
          catId = await dbService.insertCategory(
            CategoryModel(name: catName, icon: '؟', isIncome: isIncome),
          );
          categoryMap[catName] = catId;
        }

        final txn = TransactionModel(
          categoryId: catId,
          categoryName: catName,
          amount: amount,
          isIncome: isIncome,
          hijriMonth: hijriMonth,
          createdAt: createdAt,
        );

        await dbService.insertTransaction(txn);
        count++;
      } catch (e) {
        // طباعة تفاصيل الخطأ للتمكن من تصحيح الأخطاء لاحقاً
        debugPrint('خطأ في تحليل الصف $i: $e');
        continue;
      }
    }
    return count;
  }
}
