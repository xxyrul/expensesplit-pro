import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';
import '../services/expense_service.dart';
import '../services/auth_service.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expenseServiceProvider = Provider<ExpenseService>((ref) {
  final repository = ref.watch(expenseRepositoryProvider);
  return ExpenseService(repository);
});

final expensesSnapshotStreamProvider = StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final service = ref.watch(expenseServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return const Stream.empty();
      return service.getExpensesSnapshotStreamForUserWithBackfill(user.uid);
    },
    loading: () => const Stream.empty(),
    error: (_, __) => const Stream.empty(),
  );
});

final expensesStreamProvider = StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final service = ref.watch(expenseServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return service
          .getExpensesSnapshotStreamForUserWithBackfill(user.uid)
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => ExpenseModel.fromMap(doc.id, doc.data()))
                .toList(),
          );
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

final monthlyTrendProvider = Provider.autoDispose.family<Map<String, double>, DateTime>((ref, month) {
  final expensesAsync = ref.watch(expensesStreamProvider);
  final service = ref.watch(expenseServiceProvider);
  
  return expensesAsync.maybeWhen(
    data: (expenses) => service.getMonthlyTrend(expenses, month),
    orElse: () => {},
  );
});
