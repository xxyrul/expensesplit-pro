import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense_model.dart';

class AllExpensesNotifier extends AsyncNotifier<List<ExpenseModel>> {
  @override
  Future<List<ExpenseModel>> build() async {
    final stream = FirebaseFirestore.instance
        .collectionGroup('expenses')
        .orderBy('timestamp', descending: true)
        .snapshots();

    final snapshot = await stream.first;
    return snapshot.docs.map((doc) {
      final data = doc.data();
      // Safely map timestamp to ISO string since ExpenseModel expects 'date' as a string in fromMap
      if (data['timestamp'] != null) {
        if (data['timestamp'] is Timestamp) {
          data['date'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
        } else {
          data['date'] = data['timestamp'].toString();
        }
      } else {
        data['date'] = DateTime.now().toIso8601String();
      }
      return ExpenseModel.fromMap(doc.id, data);
    }).toList();
  }
}

final allExpensesProvider = AsyncNotifierProvider<AllExpensesNotifier, List<ExpenseModel>>(() {
  return AllExpensesNotifier();
});
