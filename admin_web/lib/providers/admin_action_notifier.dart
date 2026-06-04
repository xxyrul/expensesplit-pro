import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/modern_bottom_toast.dart';

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
        ModernBottomToast.show(
          context,
          message: 'Expense Approved and Audited successfully!',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ModernBottomToast.show(
          context,
          message: 'Approval failed: $e',
          type: ModernToastType.error,
        );
      }
    } finally {
      // 5. Remove docId from loading state
      state = state.where((id) => id != docId).toSet();
    }
  }

  Future<void> revertToPending({
    required BuildContext context,
    required String userId,
    required String docId,
  }) async {
    state = {...state, docId};
    try {
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('users').doc(userId).collection('ocr_logs').doc(docId).update({
        'adminStatus': 'Pending',
      });

      await firestore.collection('audit_log').add({
        'action': 're-evaluation',
        'adminId': 'admin_id',
        'timestamp': FieldValue.serverTimestamp(),
        'docId': docId,
        'details': 'Reverted OCR log to Pending for re-evaluation.',
      });

      if (context.mounted) {
        ModernBottomToast.show(
          context,
          message: 'Record reverted to Pending for Re-evaluation.',
          type: ModernToastType.info,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ModernBottomToast.show(
          context,
          message: 'Revert failed: $e',
          type: ModernToastType.error,
        );
      }
    } finally {
      state = state.where((id) => id != docId).toSet();
    }
  }
}

final adminActionProvider = NotifierProvider<AdminActionNotifier, Set<String>>(() {
  return AdminActionNotifier();
});
