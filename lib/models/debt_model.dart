import 'package:cloud_firestore/cloud_firestore.dart';

class DebtModel {
  final String? id;
  final String title;
  final String type; // Credit Card, Education, Car, Home, Personal
  final double originalBalance;
  final double currentBalance;
  final double monthlyPayment;
  final double interestRate; // Annual %
  final int dueDate; // 1-31

  DebtModel({
    this.id,
    required this.title,
    required this.type,
    required this.originalBalance,
    required this.currentBalance,
    required this.monthlyPayment,
    required this.interestRate,
    required this.dueDate,
  });

  double get paidAmount => originalBalance - currentBalance;
  double get progress => (paidAmount / originalBalance).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'originalBalance': originalBalance,
      'currentBalance': currentBalance,
      'monthlyPayment': monthlyPayment,
      'interestRate': interestRate,
      'dueDate': dueDate,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map, String id) {
    return DebtModel(
      id: id,
      title: map['title'] ?? '',
      type: map['type'] ?? 'Personal',
      originalBalance: (map['originalBalance'] ?? 0.0).toDouble(),
      currentBalance: (map['currentBalance'] ?? 0.0).toDouble(),
      monthlyPayment: (map['monthlyPayment'] ?? 0.0).toDouble(),
      interestRate: (map['interestRate'] ?? 0.0).toDouble(),
      dueDate: map['dueDate'] ?? 1,
    );
  }

  DebtModel copyWith({
    String? id,
    String? title,
    String? type,
    double? originalBalance,
    double? currentBalance,
    double? monthlyPayment,
    double? interestRate,
    int? dueDate,
  }) {
    return DebtModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      originalBalance: originalBalance ?? this.originalBalance,
      currentBalance: currentBalance ?? this.currentBalance,
      monthlyPayment: monthlyPayment ?? this.monthlyPayment,
      interestRate: interestRate ?? this.interestRate,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
