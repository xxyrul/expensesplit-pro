import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/debt_model.dart';

final debtServiceProvider = Provider<DebtService>((ref) {
  return DebtService();
});

final debtsStreamProvider = StreamProvider.autoDispose<List<DebtModel>>((ref) {
  final debtService = ref.watch(debtServiceProvider);
  return debtService.streamDebts();
});

class DebtService {
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

  /// Calculates estimated months to payoff using the amortization formula.
  /// balance: A, monthlyPayment: P, annualRate: r (as decimal, e.g. 0.05 for 5%)
  /// n = -log(1 - (r/12 * A) / P) / log(1 + r/12)
  int calculatePayoffTime(double balance, double monthlyPayment, double annualRatePercent) {
    if (balance <= 0) return 0;
    
    final monthlyRate = (annualRatePercent / 100) / 12;
    
    if (monthlyRate == 0) {
      return (balance / monthlyPayment).ceil();
    }

    // If monthly interest is greater than or equal to payment, it never gets paid off.
    if (monthlyPayment <= balance * monthlyRate) {
      return -1; // Special value for "Infinity"
    }

    final n = -log(1 - (monthlyRate * balance) / monthlyPayment) / log(1 + monthlyRate);
    return n.ceil();
  }
}
