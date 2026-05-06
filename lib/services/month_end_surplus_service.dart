import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/debt_model.dart';
import '../models/goal_model.dart';

enum MonthEndSurplusRedirectType { rollover, goal, debt }

class MonthEndSurplusService {
  MonthEndSurplusService._();
  static final MonthEndSurplusService instance = MonthEndSurplusService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _monthlyBudgetsCollection {
    final userId = _userId;
    if (userId == null) throw Exception('User is not logged in');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('monthly_budgets');
  }

  CollectionReference<Map<String, dynamic>> get _monthEndLedgerCollection {
    final userId = _userId;
    if (userId == null) throw Exception('User is not logged in');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('month_end_surpluses');
  }

  CollectionReference<Map<String, dynamic>> get _goalsCollection {
    final userId = _userId;
    if (userId == null) throw Exception('User is not logged in');
    return _firestore.collection('users').doc(userId).collection('goals');
  }

  CollectionReference<Map<String, dynamic>> get _debtsCollection {
    final userId = _userId;
    if (userId == null) throw Exception('User is not logged in');
    return _firestore.collection('users').doc(userId).collection('debts');
  }

  Future<void> rollOverSurplus({
    required double surplus,
    required DateTime month,
  }) async {
    if (surplus <= 0) return;

    final nextMonthKey = _monthKey(DateTime(month.year, month.month + 1, 1));
    final currentMonthKey = _monthKey(month);
    final nextMonthBudgetRef = _monthlyBudgetsCollection.doc(nextMonthKey);
    final ledgerRef = _monthEndLedgerCollection.doc(currentMonthKey);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(nextMonthBudgetRef);
      final data = snapshot.data();
      final existingBudget = (data?['budgetLimit'] as num?)?.toDouble() ?? 0.0;
      final existingRollover =
          (data?['rolledOverSurplus'] as num?)?.toDouble() ?? 0.0;

      transaction.set(nextMonthBudgetRef, {
        'monthKey': nextMonthKey,
        'budgetLimit': existingBudget + surplus,
        'rolledOverSurplus': existingRollover + surplus,
        'sourceMonthKey': currentMonthKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(ledgerRef, {
        'monthKey': currentMonthKey,
        'surplus': surplus,
        'redirectType': MonthEndSurplusRedirectType.rollover.name,
        'redirectedAt': FieldValue.serverTimestamp(),
        'targetType': 'next_month_budget',
        'targetId': nextMonthKey,
      }, SetOptions(merge: true));
    });
  }

  Future<void> redirectToGoal({
    required GoalModel goal,
    required double surplus,
    required DateTime month,
  }) async {
    if (surplus <= 0) return;
    if (goal.id == null) throw Exception('Goal has no document id');

    final currentMonthKey = _monthKey(month);
    final ledgerRef = _monthEndLedgerCollection.doc(currentMonthKey);
    final goalRef = _goalsCollection.doc(goal.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(goalRef);
      if (!snapshot.exists) {
        throw Exception('Selected goal no longer exists');
      }

      final data = snapshot.data();
      final currentAmount = (data?['currentAmount'] as num?)?.toDouble() ?? 0.0;

      transaction.update(goalRef, {'currentAmount': currentAmount + surplus});

      transaction.set(ledgerRef, {
        'monthKey': currentMonthKey,
        'surplus': surplus,
        'redirectType': MonthEndSurplusRedirectType.goal.name,
        'redirectedAt': FieldValue.serverTimestamp(),
        'targetType': 'goal',
        'targetId': goal.id,
        'targetName': goal.name,
      }, SetOptions(merge: true));
    });
  }

  Future<void> redirectToDebt({
    required DebtModel debt,
    required double surplus,
    required DateTime month,
  }) async {
    if (surplus <= 0) return;
    if (debt.id == null) throw Exception('Debt has no document id');

    final currentMonthKey = _monthKey(month);
    final ledgerRef = _monthEndLedgerCollection.doc(currentMonthKey);
    final debtRef = _debtsCollection.doc(debt.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(debtRef);
      if (!snapshot.exists) {
        throw Exception('Selected debt no longer exists');
      }

      final data = snapshot.data();
      final currentBalance =
          (data?['currentBalance'] as num?)?.toDouble() ?? 0.0;
      final updatedBalance = (currentBalance - surplus).clamp(
        0.0,
        double.infinity,
      );

      transaction.update(debtRef, {'currentBalance': updatedBalance});

      transaction.set(ledgerRef, {
        'monthKey': currentMonthKey,
        'surplus': surplus,
        'redirectType': MonthEndSurplusRedirectType.debt.name,
        'redirectedAt': FieldValue.serverTimestamp(),
        'targetType': 'debt',
        'targetId': debt.id,
        'targetName': debt.title,
      }, SetOptions(merge: true));
    });
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}
