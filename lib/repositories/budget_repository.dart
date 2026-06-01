import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetRepository {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> getBudgetsCollection(String uid) {
    return _db.collection('users').doc(uid).collection('budgets');
  }

  DocumentReference<Map<String, dynamic>> getMonthlyRolloverDoc(String uid, String monthKey) {
    return _db.collection('users').doc(uid).collection('monthly_budgets').doc(monthKey);
  }

  Future<void> updateBudgets(Map<String, double> budgetData) async {
    final uid = currentUserId;
    if (uid == null) return;

    final batch = _db.batch();
    final collection = getBudgetsCollection(uid);

    budgetData.forEach((category, limit) {
      final docRef = collection.doc(category);
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

  Future<void> setBudget(String category, double limit) async {
    final uid = currentUserId;
    if (uid == null) return;

    await getBudgetsCollection(uid).doc(category).set({
      'limit': limit,
      'category': category,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }
}
