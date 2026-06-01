class TransactionModel {
  final int? id;
  final int categoryId;
  final String categoryName;
  final int amount;
  final bool isIncome;
  final String hijriMonth; // e.g. "1447-10"
  final int createdAt; // epoch millis

  TransactionModel({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.isIncome,
    required this.hijriMonth,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'category_id': categoryId,
    'category_name': categoryName,
    'amount': amount,
    'is_income': isIncome ? 1 : 0,
    'hijri_month': hijriMonth,
    'created_at': createdAt,
  };

  factory TransactionModel.fromMap(Map<String, dynamic> m) => TransactionModel(
    id: m['id'] as int?,
    categoryId: m['category_id'] as int,
    categoryName: m['category_name'] as String,
    amount: (m['amount'] as num).toInt(),
    isIncome: (m['is_income'] as int) == 1,
    hijriMonth: m['hijri_month'] as String,
    createdAt: m['created_at'] as int,
  );
}
