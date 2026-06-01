class MonthlySummary {
  final int? id;
  final String monthKey; // e.g. 1447-10
  final int openingBalance;
  final int closingBalance;
  final int createdAt;

  MonthlySummary({
    this.id,
    required this.monthKey,
    required this.openingBalance,
    required this.closingBalance,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'month_key': monthKey,
    'opening_balance': openingBalance,
    'closing_balance': closingBalance,
    'created_at': createdAt,
  };

  factory MonthlySummary.fromMap(Map<String, dynamic> m) => MonthlySummary(
    id: m['id'] as int?,
    monthKey: m['month_key'] as String,
    openingBalance: (m['opening_balance'] as num).toInt(),
    closingBalance: (m['closing_balance'] as num).toInt(),
    createdAt: m['created_at'] as int,
  );
}
