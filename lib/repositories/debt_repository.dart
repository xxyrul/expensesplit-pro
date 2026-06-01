import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/debt_model.dart';

class DebtRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  CollectionReference get _debtsCollection {
    if (userId == null) throw Exception("User is not logged in");
    return _firestore.collection('users').doc(userId).collection('debts');
  }

  Stream<List<DebtModel>> streamDebts() {
    final uid = userId;
    if (uid == null) return Stream.value([]);
    
    return _firestore.collection('users').doc(uid).collection('debts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return DebtModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> addDebt(DebtModel debt) async {
    await _debtsCollection.add(debt.toMap());
  }

  Future<void> updateDebt(DebtModel debt) async {
    if (debt.id == null) return;
    await _debtsCollection.doc(debt.id).update(debt.toMap());
  }

  Future<void> deleteDebt(String debtId) async {
    await _debtsCollection.doc(debtId).delete();
  }

  Future<void> addPayment(String debtId, double amount) async {
    final docRef = _debtsCollection.doc(debtId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final currentBalance = (snapshot.data() as Map<String, dynamic>)['currentBalance'] as num? ?? 0.0;
      final newBalance = currentBalance - amount;
      
      transaction.update(docRef, {
        'currentBalance': newBalance < 0 ? 0.0 : newBalance,
      });
    });
  }
}
