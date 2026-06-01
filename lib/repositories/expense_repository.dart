import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> addExpense(ExpenseModel expense) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User is not authenticated');

    try {
      await _db.collection('users').doc(uid).collection('expenses').add({
        ...expense.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      debugPrint('Firestore Write Error: ${e.code} - ${e.message}');
      throw Exception('Failed to save: ${e.message}');
    } catch (e) {
      debugPrint('Unknown Error: $e');
      throw Exception('Failed to save: $e');
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    final uid = currentUserId;
    if (uid == null) return;
    await _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }

  Future<void> updateExpense(String expenseId, ExpenseModel expense) async {
    final uid = currentUserId;
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

  Future<QuerySnapshot<Map<String, dynamic>>> getExpensesSnapshotForUser(
    String uid,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .get();
  }

  WriteBatch batch() => _db.batch();
}
