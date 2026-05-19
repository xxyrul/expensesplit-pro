import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logAction({
    required String action,
    required String targetId,
    required String targetType,
    required String detail,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection('system_config')
          .doc('audit_logs')
          .collection('entries')
          .add({
        'adminUid': user.uid,
        'adminEmail': user.email ?? 'Unknown Admin',
        'action': action,
        'targetId': targetId,
        'targetType': targetType,
        'detail': detail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to write audit log: $e');
    }
  }

  Stream<QuerySnapshot> getAuditLogs() {
    return _firestore
        .collection('system_config')
        .doc('audit_logs')
        .collection('entries')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

final auditLogServiceProvider = Provider((ref) => AuditLogService());
