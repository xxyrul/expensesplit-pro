import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live privacy flag — rebuilds admin lists when masking is toggled.
final privacyMaskingActiveProvider = StreamProvider<bool>((ref) {
  return FirebaseFirestore.instance
      .collection('system_config')
      .doc('privacy_settings')
      .snapshots()
      .map((doc) => doc.data()?['maskSensitiveData'] == true);
});
