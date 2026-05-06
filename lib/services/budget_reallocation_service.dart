import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetReallocationService {
  BudgetReallocationService._();
  static final BudgetReallocationService instance =
      BudgetReallocationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _budgetsCollection {
    final userId = _userId;
    if (userId == null) throw Exception('User is not logged in');
    return _firestore.collection('users').doc(userId).collection('budgets');
  }

  /// Reallocate budget from source category to burst category using atomic WriteBatch
  ///
  /// Validates that the source category has sufficient available balance before proceeding.
  /// Throws [Exception] if:
  /// - amount <= 0
  /// - source category not found
  /// - amount exceeds source category's available balance (limit - current month's spending)
  Future<void> reallocateBudget({
    required String sourceCategoryId,
    required String burstCategoryId,
    required double amount,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than 0');
    }

    // Get source category limit
    final sourceDoc = await _budgetsCollection.doc(sourceCategoryId).get();
    if (!sourceDoc.exists) {
      throw Exception('Source category "$sourceCategoryId" not found');
    }

    final sourceLimit = (sourceDoc.data()?['limit'] as num?)?.toDouble() ?? 0.0;
    if (sourceLimit <= 0) {
      throw Exception('Source category has invalid limit');
    }

    // Calculate spending for source category in current month
    final userId = _userId;
    if (userId == null) throw Exception('User is not logged in');

    final now = DateTime.now();
    final currentMonthExpenses = await _firestore
        .collection('users')
        .doc(userId)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: DateTime(now.year, now.month, 1))
        .where('date', isLessThan: DateTime(now.year, now.month + 1, 1))
        .get();

    final spent = currentMonthExpenses.docs.fold<double>(0.0, (sum, doc) {
      final expenseCategory = doc.data()['category'] as String?;
      if (expenseCategory == sourceCategoryId) {
        final expenseAmount = (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        return sum + expenseAmount;
      }
      return sum;
    });

    // Validate amount does not exceed available balance
    final available = sourceLimit - spent;
    if (amount > available) {
      throw Exception(
        'Cannot borrow RM ${amount.toStringAsFixed(2)} from $sourceCategoryId. '
        'Available balance: RM ${available.toStringAsFixed(2)}',
      );
    }

    final sourceRef = _budgetsCollection.doc(sourceCategoryId);
    final burstRef = _budgetsCollection.doc(burstCategoryId);

    final batch = _firestore.batch();

    // Subtract from source
    batch.update(sourceRef, {
      'limit': FieldValue.increment(-amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Add to burst category
    batch.update(burstRef, {
      'limit': FieldValue.increment(amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to reallocate budget: $e');
    }
  }
}
