import 'package:flutter/material.dart';
import 'dart:math';

import '../services/database_service.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/monthly_summary.dart';
import '../utils/hijri_helper.dart';

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  Future<void>? _initFuture;
  bool _isInitialized = false;
  String viewedMonthKey = HijriHelper.currentMonthKey();

  int currentAmount = 0;
  bool isAddition = true; // true: إضافة (+), false: طرح (-)

  // قيم مبدئية للعرض (will be computed from DB later)
  int actualBalance = 0;
  int totalIncome = 0;
  int totalExpenses = 0;
  int previousBalance = 0;

  final List<int> quickAmounts = [10, 5, 1, 500, 100, 50];

  List<CategoryModel> categories = [];

  TransactionProvider();

  bool get isInitialized => _isInitialized;

  Future<void> init() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    await _seedCategoriesIfNeeded();
    await _loadCategories();
    viewedMonthKey = HijriHelper.currentMonthKey();
    await _loadBalanceSnapshotFor(viewedMonthKey);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _seedCategoriesIfNeeded() async {
    final existing = await _db.getCategories();
    if (existing.isNotEmpty) {
      return;
    }

    final defaults = [
      CategoryModel(name: 'راتب', icon: '💰', isIncome: true),
      CategoryModel(name: 'طعام', icon: '🍔', isIncome: false),
      CategoryModel(name: 'مواصلات', icon: '🚗', isIncome: false),
      CategoryModel(name: 'فواتير', icon: '📄', isIncome: false),
    ];

    for (final c in defaults) {
      await _db.insertCategory(c);
    }
  }

  Future<void> _loadCategories() async {
    categories = await _db.getCategories();
  }

  Future<void> _loadBalanceSnapshotFor(String monthKey) async {
    final latestSummary = await _db.getLatestMonthlySummaryBeforeOrFor(
      monthKey,
    );
    final priorTransactions = await _db.getTransactionsBeforeMonth(monthKey);

    if (latestSummary == null) {
      previousBalance = 0;
      for (final t in priorTransactions) {
        previousBalance += t.isIncome ? t.amount : -t.amount;
      }
    } else if (latestSummary.monthKey == monthKey) {
      previousBalance = latestSummary.openingBalance;
    } else {
      previousBalance = latestSummary.closingBalance;
      final transactionsAfterSummary = priorTransactions.where((t) {
        return t.hijriMonth.compareTo(latestSummary.monthKey) > 0;
      });

      for (final t in transactionsAfterSummary) {
        previousBalance += t.isIncome ? t.amount : -t.amount;
      }
    }

    final txns = await _db.getTransactionsByMonth(monthKey);
    totalIncome = 0;
    totalExpenses = 0;

    for (final t in txns) {
      if (t.isIncome) {
        totalIncome += t.amount;
      } else {
        totalExpenses += t.amount;
      }
    }

    actualBalance = previousBalance + totalIncome - totalExpenses;
  }

  String get viewedMonthTitle => HijriHelper.monthTitleFromKey(viewedMonthKey);

  Future<void> loadCategories() async {
    await init();
    await _loadCategories();
    notifyListeners();
  }

  Future<void> addCategory(String name, String icon, bool isIncome) async {
    final c = CategoryModel(name: name, icon: icon, isIncome: isIncome);
    await _db.insertCategory(c);
    categories = [...categories, c];
    notifyListeners();
    await _loadCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(CategoryModel category) async {
    final id = category.id;
    if (id == null) return;

    await _db.deleteCategory(id);
    categories = categories.where((c) => c.id != id).toList();
    notifyListeners();
  }

  Future<List<TransactionModel>> getTransactionsForMonth(
    String monthKey,
  ) async {
    await init();
    return await _db.getTransactionsByMonth(monthKey);
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    await init();
    return await _db.getAllTransactions();
  }

  Future<void> _reloadState() async {
    await _loadCategories();
    await _loadBalanceSnapshotFor(viewedMonthKey);
    notifyListeners();
  }

  void _resetInitialization() {
    _initFuture = null;
    _isInitialized = false;
  }

  Future<void> generateFakeDataForLastSixMonths() async {
    await init();

    final now = DateTime.now();
    final random = Random();
    var monthKey = HijriHelper.currentMonthKey();
    final availableCategories = categories.isNotEmpty
        ? List<CategoryModel>.from(categories)
        : [
            CategoryModel(name: 'راتب', icon: '💰', isIncome: true),
            CategoryModel(name: 'طعام', icon: '🍔', isIncome: false),
            CategoryModel(name: 'مواصلات', icon: '🚗', isIncome: false),
            CategoryModel(name: 'فواتير', icon: '📄', isIncome: false),
          ];

    final entries = <TransactionModel>[];

    for (var monthIndex = 0; monthIndex < 6; monthIndex++) {
      final monthCategories = availableCategories..shuffle(random);
      final entriesCount = 3 + random.nextInt(4);

      for (var i = 0; i < entriesCount; i++) {
        final category = monthCategories[i % monthCategories.length];
        final isIncome = category.isIncome;
        final amount = isIncome
            ? 1500 + random.nextInt(3500)
            : 25 + random.nextInt(975);

        final day = 1 + random.nextInt(27);
        final hour = random.nextInt(23);
        final minute = random.nextInt(59);
        final createdAt = DateTime(
          now.year,
          now.month - monthIndex,
          day,
          hour,
          minute,
        ).millisecondsSinceEpoch;

        entries.add(
          TransactionModel(
            categoryId: category.id ?? 0,
            categoryName: category.name,
            amount: amount.toInt(),
            isIncome: isIncome,
            hijriMonth: monthKey,
            createdAt: createdAt,
          ),
        );
      }

      monthKey = HijriHelper.previousMonthKeyFrom(monthKey);
    }

    for (final entry in entries) {
      await _db.insertTransaction(entry);
    }

    await _reloadState();
  }

  Future<void> deleteAllData() async {
    await init();
    await _db.clearAllData();
    _resetInitialization();
    viewedMonthKey = HijriHelper.currentMonthKey();
    currentAmount = 0;
    isAddition = true;
    await init();
  }

  Future<void> goToPreviousMonth() async {
    await init();
    viewedMonthKey = HijriHelper.previousMonthKeyFrom(viewedMonthKey);
    await _loadBalanceSnapshotFor(viewedMonthKey);
    notifyListeners();
  }

  bool get canGoToNextMonth {
    return viewedMonthKey.compareTo(HijriHelper.currentMonthKey()) < 0;
  }

  Future<void> goToNextMonth() async {
    await init();
    if (!canGoToNextMonth) return;

    viewedMonthKey = HijriHelper.nextMonthKeyFrom(viewedMonthKey);
    await _loadBalanceSnapshotFor(viewedMonthKey);
    notifyListeners();
  }

  Future<void> goToCurrentMonth() async {
    await init();
    viewedMonthKey = HijriHelper.currentMonthKey();
    await _loadBalanceSnapshotFor(viewedMonthKey);
    notifyListeners();
  }

  Future<void> endMonth() async {
    await init();
    final current = viewedMonthKey;
    final txns = await _db.getTransactionsByMonth(current);

    int income = 0;
    int expenses = 0;
    for (final t in txns) {
      if (t.isIncome) {
        income += t.amount;
      } else {
        expenses += t.amount;
      }
    }

    final closing = previousBalance + income - expenses;

    final summary = MonthlySummary(
      monthKey: current,
      openingBalance: previousBalance,
      closingBalance: closing,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.insertMonthlySummary(summary);

    // carry over
    previousBalance = closing;
    viewedMonthKey = HijriHelper.nextMonthKeyFrom(current);
    await _loadBalanceSnapshotFor(viewedMonthKey);
    notifyListeners();
  }

  void toggleInputType(bool value) {
    isAddition = value;
    notifyListeners();
  }

  void addAmount(int value) {
    // إذا كان الوضع طرح، نجمع القيمة بالسالب، وإلا بالموجب
    int finalValue = isAddition ? value : -value;
    currentAmount += finalValue;
    notifyListeners();
  }

  void clearAmount() {
    currentAmount = 0;
    notifyListeners();
  }

  Future<void> saveTransaction(String categoryName) async {
    await init();
    if (currentAmount == 0) return;

    final cat = categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () =>
          CategoryModel(id: 0, name: categoryName, icon: '❓', isIncome: false),
    );

    final now = DateTime.now();
    final hijriMonthPlaceholder = viewedMonthKey;

    final txn = TransactionModel(
      categoryId: cat.id ?? 0,
      categoryName: cat.name,
      amount: currentAmount,
      isIncome: cat.isIncome,
      hijriMonth: hijriMonthPlaceholder,
      createdAt: now.millisecondsSinceEpoch,
    );

    await _db.insertTransaction(txn);

    // Update quick aggregates in memory
    if (cat.isIncome) {
      totalIncome += currentAmount;
      actualBalance += currentAmount;
    } else {
      totalExpenses += currentAmount;
      actualBalance -= currentAmount;
    }

    // تصفير العداد بعد الحفظ
    clearAmount();
  }
}
