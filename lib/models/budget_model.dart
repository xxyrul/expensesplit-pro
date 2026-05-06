class BudgetModel {
  final String category;
  final double limit;

  BudgetModel({required this.category, required this.limit});

  Map<String, dynamic> toMap() {
    return {'category': category, 'limit': limit};
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      category: map['category'] ?? '',
      limit: (map['limit'] as num).toDouble(),
    );
  }
}
