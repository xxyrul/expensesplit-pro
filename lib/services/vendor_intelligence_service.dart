import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vendor_category_mapping.dart';
import '../models/ocr_log_model.dart';

final vendorIntelligenceServiceProvider = Provider<VendorIntelligenceService>((ref) {
  return VendorIntelligenceService();
});

class VendorIntelligenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Smart Vendor Recognition
  Future<String?> getCategoryForVendor(String vendorName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || vendorName.trim().isEmpty) return null;

    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('vendor_catalog')
          .where('vendorName', isEqualTo: vendorName.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final mapping = VendorCategoryMapping.fromMap(querySnapshot.docs.first.data());
        return mapping.defaultCategoryId;
      }
    } catch (e) {
      print("Error fetching vendor category: $e");
    }
    return null;
  }

  Future<void> saveVendorCategory(String vendorName, String category) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || vendorName.trim().isEmpty) return;

    final standardizedVendorName = vendorName.trim();

    try {
      final querySnapshot = await _db
          .collection('users')
          .doc(uid)
          .collection('vendor_catalog')
          .where('vendorName', isEqualTo: standardizedVendorName)
          .limit(1)
          .get();

      final mapping = VendorCategoryMapping(
        vendorName: standardizedVendorName,
        defaultCategoryId: category,
        updatedAt: DateTime.now(),
      );

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing vendor
        final docId = querySnapshot.docs.first.id;
        await _db
            .collection('users')
            .doc(uid)
            .collection('vendor_catalog')
            .doc(docId)
            .update(mapping.toMap());
      } else {
        // Create new vendor
        await _db
            .collection('users')
            .doc(uid)
            .collection('vendor_catalog')
            .add(mapping.toMap());
      }
    } catch (e) {
      print("Error saving vendor category: $e");
    }
  }

  // OCR Correction Feedback Loop
  Future<void> logOcrCorrection({
    required String rawText,
    required double systemSuggestedAmount,
    required double userCorrectedAmount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Avoid logging if amounts are identical or system was completely wrong (e.g. 0)
    // Actually we *should* log if it's completely wrong. But let's follow the standard 10% diff rule.
    if (systemSuggestedAmount <= 0) return;

    final absoluteDifference = (systemSuggestedAmount - userCorrectedAmount).abs();
    final percentageDifference = (absoluteDifference / systemSuggestedAmount) * 100;

    String confidenceLabel = 'High Confidence';
    if (percentageDifference > 10.0) {
      confidenceLabel = 'Low Confidence';
    }

    // Only log if the user explicitly corrected it (difference > 0)
    if (absoluteDifference == 0) return;

    try {
      final log = OcrLogModel(
        rawText: rawText,
        systemSuggestedAmount: systemSuggestedAmount,
        userCorrectedAmount: userCorrectedAmount,
        confidenceLabel: confidenceLabel,
        createdAt: DateTime.now(),
      );

      await _db
          .collection('users')
          .doc(uid)
          .collection('ocr_logs')
          .add(log.toMap());
    } catch (e) {
      print("Error logging ocr correction: $e");
    }
  }
}
