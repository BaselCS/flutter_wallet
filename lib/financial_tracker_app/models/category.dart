class CategoryModel {
  final int? id;
  final String name;
  final String icon;
  final bool isIncome;

  CategoryModel({
    this.id,
    required this.name,
    required this.icon,
    required this.isIncome,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'is_income': isIncome ? 1 : 0,
  };

  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
    id: m['id'] as int?,
    name: m['name'] as String,
    icon: m['icon'] as String,
    isIncome: (m['is_income'] as int) == 1,
  );
}
