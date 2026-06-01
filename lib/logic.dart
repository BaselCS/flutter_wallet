import 'package:flutter/material.dart';

class QuickTransactionViewModel extends ChangeNotifier {
  double currentAmount = 0.0;
  bool isExpense = true;

  final List<double> quickAmounts = [1, 5, 10, 50, 100, 500];

  final List<Map<String, dynamic>> categories = [
    {'name': 'طعام', 'icon': Icons.restaurant},
    {'name': 'وقود', 'icon': Icons.local_gas_station},
    {'name': 'تسوق', 'icon': Icons.shopping_bag},
    {'name': 'فواتير', 'icon': Icons.receipt},
  ];

  void addAmount(double value) {
    currentAmount += value;
    notifyListeners();
  }

  void clearAmount() {
    currentAmount = 0.0;
    notifyListeners();
  }

  void toggleTransactionType(bool expense) {
    isExpense = expense;
    notifyListeners();
  }

  Map<String, dynamic>? submitTransaction(String categoryName) {
    if (currentAmount == 0) return null;

    final transaction = {
      'categoryName': categoryName,
      'amount': currentAmount,
      'isExpense': isExpense,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    debugPrint(
      "تم الحفظ: ${isExpense ? 'مصروف' : 'مدخول'} | الفئة: $categoryName | المبلغ: $currentAmount",
    );

    // تصفير العداد بعد الحفظ للعملية التالية
    clearAmount();
    return transaction;
  }
}
