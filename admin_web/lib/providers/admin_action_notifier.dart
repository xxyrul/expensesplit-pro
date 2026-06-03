import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminActionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return {};
  }

  Future<void> approveExpense({
    required BuildContext context,
    required String userId,
    required String docId,
    required double systemVal,
    required double userVal,
  }) async {
    // 1. Optimistic UI: Add docId to loading state
    state = {...state, docId};

    try {
      final firestore = FirebaseFirestore.instance;

      // 2. Atomic Update on Firestore
      await firestore.collection('users').doc(userId).collection('ocr_logs').doc(docId).update({
        'adminStatus': 'Approved',
      });

      // 3. Governance Audit
      await firestore.collection('audit_log').add({
        'action': 'approved',
        'adminId': 'admin_id', // Note: In a real app, pull from Auth
        'timestamp': FieldValue.serverTimestamp(),
        'docId': docId,
        'details': 'Marked OCR log as Approved (SysSuggested: RM $systemVal | UserCorrected: RM $userVal).',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Expense Approved and Audited successfully!'),
              ],
            ),
            backgroundColor: Colors.green[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Approval failed: $e')),
              ],
            ),
            backgroundColor: Colors.red[800],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // 5. Remove docId from loading state
      state = state.where((id) => id != docId).toSet();
    }
  }
}

final adminActionProvider = NotifierProvider<AdminActionNotifier, Set<String>>(() {
  return AdminActionNotifier();
});
