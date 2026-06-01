import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/budget_repository.dart';

class BudgetService {
  final BudgetRepository _repository;

  BudgetService(this._repository);

  Future<void> updateBudgets(Map<String, double> budgetData) async {
    await _repository.updateBudgets(budgetData);
  }

  Future<void> setBudget(String category, double limit) async {
    await _repository.setBudget(category, limit);
  }

  Stream<Map<String, double>> getBudgets() {
    final uid = _repository.currentUserId;
    if (uid == null) return Stream.value({});

    final budgetsCollection = _repository.getBudgetsCollection(uid);
    final rolloverDoc = _repository.getMonthlyRolloverDoc(uid, _monthKey(DateTime.now()));

    late final StreamController<Map<String, double>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? budgetsSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? rolloverSubscription;

    Map<String, double> baseBudgets = {};
    double rolloverAmount = 0.0;

    void emitMergedBudgets() {
      final mergedBudgets = Map<String, double>.from(baseBudgets);
      if (rolloverAmount > 0) {
        mergedBudgets['Total'] = (mergedBudgets['Total'] ?? 0.0) + rolloverAmount;
      }
      controller.add(mergedBudgets);
    }

    controller = StreamController<Map<String, double>>(
      onListen: () {
        budgetsSubscription = budgetsCollection.snapshots().listen((snap) {
          baseBudgets = {
            for (final doc in snap.docs)
              doc.id: (doc.data()['limit'] as num).toDouble(),
          };
          emitMergedBudgets();
        }, onError: controller.addError);

        rolloverSubscription = rolloverDoc.snapshots().listen((snapshot) {
          final data = snapshot.data();
          rolloverAmount = ((data?['rolledOverSurplus'] ?? data?['budgetLimit'] ?? 0.0) as num).toDouble();
          emitMergedBudgets();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await budgetsSubscription?.cancel();
        await rolloverSubscription?.cancel();
      },
    );

    return controller.stream;
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}
