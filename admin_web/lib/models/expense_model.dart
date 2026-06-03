class ExpenseModel {
  final String? id;
  final double amount;
  final String vendor;
  final String category;
  final DateTime date;

  ExpenseModel({
    this.id,
    required this.amount,
    required this.vendor,
    required this.category,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'vendor': vendor,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  factory ExpenseModel.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseModel(
      id: id,
      amount: (map['amount'] as num).toDouble(),
      vendor: map['vendor']?.toString() ?? map['merchant']?.toString() ?? map['store']?.toString() ?? 'Not Specified',
      category: map['category']?.toString() ?? 'General',
      date: DateTime.parse(map['date']),
    );
  }
}
