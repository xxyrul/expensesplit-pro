class ExpenseModel {
  final String? id;
  final double amount;
  final String vendor;
  final String category;
  final DateTime date;
  final bool needsReview;
  final String? receiptImageUrl;
  final Map<String, double>? splitSummary;

  ExpenseModel({
    this.id,
    required this.amount,
    required this.vendor,
    required this.category,
    required this.date,
    this.needsReview = false,
    this.receiptImageUrl,
    this.splitSummary,
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
      if (splitSummary != null) 'splitSummary': splitSummary,
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
      splitSummary: map['splitSummary'] != null 
          ? Map<String, double>.from((map['splitSummary'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
          : null,
    );
  }

  ExpenseModel copyWith({
    String? id,
    double? amount,
    String? vendor,
    String? category,
    DateTime? date,
    bool? needsReview,
    String? receiptImageUrl,
    Map<String, double>? splitSummary,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      vendor: vendor ?? this.vendor,
      category: category ?? this.category,
      date: date ?? this.date,
      needsReview: needsReview ?? this.needsReview,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      splitSummary: splitSummary ?? this.splitSummary,
    );
  }
}
