import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addExpense(ExpenseModel expense) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .add({
          ...expense.toMap(),
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<void> deleteExpense(String expenseId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  Future<void> updateExpense(String expenseId, ExpenseModel expense) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(expenseId)
        .update(expense.toMap());
  }

  Stream<List<ExpenseModel>> getExpenses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return getExpensesSnapshotStream().map(
      (snapshot) => snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

final expenseServiceProvider = Provider((ref) => ExpenseService());

// Updated with autoDispose to handle account switching correctly
final expensesStreamProvider = StreamProvider.autoDispose<List<ExpenseModel>>((
  ref,
) {
  final service = ref.watch(expenseServiceProvider);
  return service.getExpenses();
});
