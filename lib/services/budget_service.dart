import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_service.dart';

class BudgetService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Saves multiple budget limits at once using a WriteBatch.
  /// This corresponds to the 'updateBudgets' call in your UI.
  Future<void> updateBudgets(Map<String, double> budgetData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final batch = _db.batch();

    budgetData.forEach((category, limit) {
      final docRef = _db
          .collection('users')
          .doc(uid)
          .collection('budgets')
          .doc(category);

      batch.set(docRef, {
        'limit': limit,
        'category': category,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    });

    try {
      await batch.commit();
    } catch (e) {
      throw Exception("Failed to update budgets: $e");
    }
  }

  /// Save a limit for a single specific category
  Future<void> setBudget(String category, double limit) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('budgets')
        .doc(category)
        .set({
          'limit': limit,
          'category': category,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
  }

  /// Get all budget limits as a Map (e.g., {'Total': 5000, 'Food': 500})
  Stream<Map<String, double>> getBudgets() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value({});

    final budgetsCollection = _db
        .collection('users')
        .doc(uid)
        .collection('budgets');
    final rolloverDoc = _db
        .collection('users')
        .doc(uid)
        .collection('monthly_budgets')
        .doc(_monthKey(DateTime.now()));

    late final StreamController<Map<String, double>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
    budgetsSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    rolloverSubscription;

    Map<String, double> baseBudgets = {};
    double rolloverAmount = 0.0;

    void emitMergedBudgets() {
      final mergedBudgets = Map<String, double>.from(baseBudgets);
      if (rolloverAmount > 0) {
        mergedBudgets['Total'] =
            (mergedBudgets['Total'] ?? 0.0) + rolloverAmount;
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
          rolloverAmount =
              ((data?['rolledOverSurplus'] ?? data?['budgetLimit'] ?? 0.0)
                      as num)
                  .toDouble();
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

final budgetServiceProvider = Provider((ref) => BudgetService());

/// Provider for the UI to listen to budget changes in real-time
final budgetsStreamProvider = StreamProvider.autoDispose<Map<String, double>>((
  ref,
) {
  final authState = ref.watch(authStateChangesProvider);
  final service = ref.watch(budgetServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value({});
      return service.getBudgets();
    },
    loading: () => Stream.value({}),
    error: (_, __) => Stream.value({}),
  );
});
