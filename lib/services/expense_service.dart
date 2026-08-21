import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

class ExpenseService {
  final ExpenseRepository _repository;

  ExpenseService(this._repository);

  Future<void> addExpense(ExpenseModel expense) => _repository.addExpense(expense);
  Future<void> addExpenseWithSplits(ExpenseModel expense, Map<String, double> splits) => _repository.addExpenseWithSplits(expense, splits);
  Future<void> deleteExpense(String expenseId) => _repository.deleteExpense(expenseId);
  Future<void> updateExpense(String expenseId, ExpenseModel expense) => _repository.updateExpense(expenseId, expense);
  Future<void> updateExpenseWithSplits(String expenseId, ExpenseModel expense, Map<String, double> splits) => _repository.updateExpenseWithSplits(expenseId, expense, splits);

  Future<void> backfillMissingExpenseTimestamps() async {
    final uid = _repository.currentUserId;
    if (uid == null) return;
    await backfillMissingExpenseTimestampsForUser(uid);
  }

  Future<void> backfillMissingExpenseTimestampsForUser(String uid) async {
    final snapshot = await _repository.getExpensesSnapshotForUser(uid);
    var batch = _repository.batch();
    var pendingWrites = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (pendingWrites == 0 || (!force && pendingWrites < 450)) return;
      await batch.commit();
      batch = _repository.batch();
      pendingWrites = 0;
    }

    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['timestamp'] != null) continue;

      final rawDate = data['date'];
      DateTime? parsedDate;
      if (rawDate is Timestamp) {
        parsedDate = rawDate.toDate();
      } else if (rawDate is String) {
        parsedDate = DateTime.tryParse(rawDate);
      }

      batch.update(doc.reference, {
        'timestamp': parsedDate != null
            ? Timestamp.fromDate(parsedDate)
            : FieldValue.serverTimestamp(),
      });
      pendingWrites += 1;
      await commitBatchIfNeeded();
    }

    await commitBatchIfNeeded(force: true);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotStream() {
    final uid = _repository.currentUserId;
    if (uid == null) return const Stream.empty();
    return _repository.getExpensesSnapshotStreamForUser(uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotStreamForUser(String uid) {
    return _repository.getExpensesSnapshotStreamForUser(uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotStreamForUserWithBackfill(String uid) async* {
    await backfillMissingExpenseTimestampsForUser(uid);
    yield* _repository.getExpensesSnapshotStreamForUser(uid);
  }
  
  Map<String, double> getMonthlyTrend(List<ExpenseModel> expenses, DateTime month) {
    final Map<String, double> trend = {};
    for (var expense in expenses) {
      if (expense.date.year == month.year && expense.date.month == month.month) {
        trend[expense.category] = (trend[expense.category] ?? 0.0) + expense.amount;
      }
    }
    return trend;
  }
}
