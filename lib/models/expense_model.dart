class ExpenseModel {
  final String? id;
  final double amount;
  final String vendor;
  final String category;
  final DateTime date;
  final bool needsReview;
  final String? receiptImageUrl;

  ExpenseModel({
    this.id,
    required this.amount,
    required this.vendor,
    required this.category,
    required this.date,
    this.needsReview = false,
    this.receiptImageUrl,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'vendor': vendor,
      'category': category,
      'date': date.toIso8601String(),
      'needsReview': needsReview,
      if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
    };
  }

  // Create from Firestore Snapshot
  factory ExpenseModel.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseModel(
      id: id,
      amount: (map['amount'] as num).toDouble(),
      vendor: map['vendor'] ?? map['merchant'] ?? map['store'] ?? map['name'] ?? 'Not Specified',
      category: map['category'] ?? 'General',
      date: DateTime.parse(map['date']),
      needsReview: map['needsReview'] ?? false,
      receiptImageUrl: map['receiptImageUrl'] as String?,
    );
  }
}
