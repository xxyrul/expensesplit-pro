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

  Future<void> addExpenseWithSplits(ExpenseModel expense, Map<String, double> splits) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User is not authenticated');

    try {
      // Create a new document reference
      final expenseRef = _db.collection('users').doc(uid).collection('expenses').doc();
      
      WriteBatch batch = _db.batch();
      
      // Save the main expense
      batch.set(expenseRef, {
        ...expense.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Save the splits in a subcollection
      splits.forEach((userId, amountOwed) {
        DocumentReference splitDocRef = expenseRef.collection('splits').doc(userId);
        batch.set(splitDocRef, {
          'userId': userId,
          'amountOwed': amountOwed,
          'isPaid': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      await batch.commit();
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

  Future<void> updateExpenseWithSplits(String expenseId, ExpenseModel expense, Map<String, double> splits) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User is not authenticated');

    try {
      final expenseRef = _db.collection('users').doc(uid).collection('expenses').doc(expenseId);
      
      WriteBatch batch = _db.batch();
      
      batch.update(expenseRef, {
        ...expense.toMap(),
        'timestamp': Timestamp.fromDate(expense.date),
      });
      
      splits.forEach((userId, amountOwed) {
        DocumentReference splitDocRef = expenseRef.collection('splits').doc(userId);
        batch.set(splitDocRef, {
          'userId': userId,
          'amountOwed': amountOwed,
          'isPaid': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      
      await batch.commit();
    } catch (e) {
      debugPrint('Unknown Error: $e');
      throw Exception('Failed to save: $e');
    }
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

  Future<List<ExpenseModel>> getExpensesByDateRange(DateTime start, DateTime end) async {
    final uid = currentUserId;
    if (uid == null) return [];

    final startTimestamp = Timestamp.fromDate(start);
    // Include the entire end day
    final endTimestamp = Timestamp.fromDate(DateTime(end.year, end.month, end.day, 23, 59, 59));

    final snapshot = await _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
        .where('timestamp', isLessThanOrEqualTo: endTimestamp)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => ExpenseModel.fromMap(doc.id, doc.data())).toList();
  }

  WriteBatch batch() => _db.batch();
}
