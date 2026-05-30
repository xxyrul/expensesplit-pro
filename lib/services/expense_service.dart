import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';
import 'auth_service.dart';

class ExpenseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> addExpense(ExpenseModel expense) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('users').doc(uid).collection('expenses').add({
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
        .update({
          ...expense.toMap(),
          'timestamp': Timestamp.fromDate(expense.date),
        });
  }

  Future<void> backfillMissingExpenseTimestamps() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await backfillMissingExpenseTimestampsForUser(uid);
  }

  Future<void> backfillMissingExpenseTimestampsForUser(String uid) async {
    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .get();

    WriteBatch batch = _db.batch();
    var pendingWrites = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (pendingWrites == 0 || (!force && pendingWrites < 450)) return;
      await batch.commit();
      batch = _db.batch();
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

  Stream<List<ExpenseModel>> getExpenses() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return getExpensesSnapshotStreamForUser(uid).map(
      (snapshot) => snapshot.docs
          .map((doc) => ExpenseModel.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return getExpensesSnapshotStreamForUser(uid);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotStreamForUser(
    String uid,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
  getExpensesSnapshotStreamForUserWithBackfill(String uid) async* {
    await backfillMissingExpenseTimestampsForUser(uid);
    yield* getExpensesSnapshotStreamForUser(uid);
  }
}

final expenseServiceProvider = Provider((ref) => ExpenseService());

final expensesSnapshotStreamProvider =
    StreamProvider.autoDispose<QuerySnapshot<Map<String, dynamic>>>((ref) {
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

final expensesStreamProvider = StreamProvider.autoDispose<List<ExpenseModel>>((
  ref,
) {
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
