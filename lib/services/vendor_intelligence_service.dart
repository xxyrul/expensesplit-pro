import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vendor_category_mapping.dart';
import '../models/ocr_log_model.dart';
import 'offline_vendor_ai_model.dart';

final vendorIntelligenceServiceProvider = Provider<VendorIntelligenceService>((ref) {
  return VendorIntelligenceService();
});

// ─────────────────────────────────────────────────────────────────────────────
// Seed knowledge: common Malaysian vendor keywords → category
// Used as a fallback when the user has no personal history yet.
// ─────────────────────────────────────────────────────────────────────────────
const _seedVendorKeywords = <String, String>{
  // Food & Beverage
  'mcdonald': 'Food', 'mcdonalds': 'Food', 'kfc': 'Food', 'pizza hut': 'Food',
  'domino': 'Food', 'burger king': 'Food', 'subway': 'Food', 'marrybrown': 'Food',
  'starbucks': 'Food', 'zus': 'Food', 'tealive': 'Food', 'chatime': 'Food',
  'gong cha': 'Food', 'old town': 'Food', 'kopitiam': 'Food', 'mamak': 'Food',
  'nando': 'Food', 'sushi king': 'Food', 'rakuzen': 'Food', 'secret recipe': 'Food',
  'the loaf': 'Food', 'bread story': 'Food',
  // Groceries
  'tesco': 'Groceries', 'mydin': 'Groceries', 'giant': 'Groceries',
  'aeon': 'Groceries', 'jaya grocer': 'Groceries', 'village grocer': 'Groceries',
  'cold storage': 'Groceries', 'lotus': 'Groceries', 'econsave': 'Groceries',
  'supermarket': 'Groceries', 'pasar': 'Groceries',
  // Transport
  'grab': 'Transport', 'myrapid': 'Transport', 'rapidkl': 'Transport',
  'petronas': 'Transport', 'shell': 'Transport', 'petron': 'Transport',
  'bhp': 'Transport', 'caltex': 'Transport', 'touch n go': 'Transport',
  'parking': 'Transport', 'lrt': 'Transport', 'mrt': 'Transport',
  // Shopping
  'uniqlo': 'Shopping', 'zara': 'Shopping', 'h&m': 'Shopping',
  'cotton on': 'Shopping', 'padini': 'Shopping', 'brands outlet': 'Shopping',
  'parkson': 'Shopping', 'isetan': 'Shopping', 'lazada': 'Shopping',
  'shopee': 'Shopping', 'zalora': 'Shopping',
  // Health
  'watson': 'Health', 'guardian': 'Health', 'caring': 'Health',
  'pharmacy': 'Health', 'klinik': 'Health', 'hospital': 'Health',
  'dentist': 'Health', 'gym': 'Health', 'fitness': 'Health',
  // Entertainment
  'gsc': 'Entertainment', 'tgv': 'Entertainment', 'mbo': 'Entertainment',
  'cinema': 'Entertainment', 'spotify': 'Entertainment', 'netflix': 'Entertainment',
  'steam': 'Entertainment', 'karaoke': 'Entertainment',
  // Utilities
  'tenaga': 'Utilities', 'tnb': 'Utilities', 'syabas': 'Utilities',
  'air selangor': 'Utilities', 'maxis': 'Utilities', 'celcom': 'Utilities',
  'digi': 'Utilities', 'umobile': 'Utilities', 'unifi': 'Utilities',
  'time fibre': 'Utilities', 'astro': 'Utilities',
  // Education
  'bookshop': 'Education', 'popular': 'Education', 'mph': 'Education',
  'kinokuniya': 'Education', 'tuition': 'Education', 'university': 'Education',
};

class VendorIntelligenceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final OfflineVendorAiModel _offlineAi = OfflineVendorAiModel();

  // ─────────────────────────────────────────────────────────────────────────
  // Normalise a vendor name for comparison
  // ─────────────────────────────────────────────────────────────────────────
  String _normalise(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int _calculateLevenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> v0 = List<int>.generate(b.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(b.length + 1, 0);

    for (int i = 0; i < a.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost
        ].reduce((min, val) => val < min ? val : min);
      }
      for (int j = 0; j <= b.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[b.length];
  }

  bool _isFuzzyMatch(String a, String b) {
    final na = _normalise(a);
    final nb = _normalise(b);
    if (na == nb || na.contains(nb) || nb.contains(na)) return true;
    return _calculateLevenshteinDistance(na, nb) <= 3;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Get category — personal catalog (fuzzy) → seed keywords
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> getCategoryForVendor(String vendorName) async {
    if (vendorName.trim().isEmpty) return null;

    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        final snap = await _db
            .collection('users')
            .doc(uid)
            .collection('vendor_catalog')
            .get();

        final catalogItems = snap.docs.map((doc) => doc.data()).toList();
        _offlineAi.trainWithCatalog(catalogItems);

        for (final doc in snap.docs) {
          final data = doc.data();
          final savedName = data['vendorName'] as String? ?? '';
          if (_isFuzzyMatch(savedName, vendorName)) {
            return data['defaultCategoryId'] as String?;
          }
          // Check aliases
          final aliases = List<String>.from(
              (data['aliases'] as List<dynamic>?)?.map((e) => e.toString()) ?? []);
          for (final alias in aliases) {
            if (_isFuzzyMatch(alias, vendorName)) {
              return data['defaultCategoryId'] as String?;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching vendor catalog: $e');
      }
    }

    // Seed keyword fallback
    final normalised = _normalise(vendorName);
    for (final entry in _seedVendorKeywords.entries) {
      if (normalised.contains(entry.key)) {
        return entry.value;
      }
    }

    // Offline AI Prediction fallback (Self-Learning)
    return _offlineAi.predictCategory(vendorName);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Save vendor → category (upsert with fuzzy dedup + usage tracking)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> saveVendorCategory(String vendorName, String category) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || vendorName.trim().isEmpty) return;

    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('vendor_catalog')
          .get();

      DocumentSnapshot? existingDoc;
      for (final doc in snap.docs) {
        final savedName = doc.data() is Map
            ? (doc.data() as Map<String, dynamic>)['vendorName'] as String? ?? ''
            : '';
        if (_isFuzzyMatch(savedName, vendorName)) {
          existingDoc = doc;
          break;
        }
      }

      if (existingDoc != null) {
        final data = existingDoc.data() as Map<String, dynamic>;
        final count = (data['usageCount'] as int? ?? 0) + 1;
        await existingDoc.reference.update({
          'defaultCategoryId': category,
          'usageCount': count,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      } else {
        final mapping = VendorCategoryMapping(
          vendorName: vendorName.trim(),
          defaultCategoryId: category,
          updatedAt: DateTime.now(),
        );
        await _db
            .collection('users')
            .doc(uid)
            .collection('vendor_catalog')
            .add({
          ...mapping.toMap(),
          'usageCount': 1,
          'aliases': <String>[],
        });
      }
    } catch (e) {
      debugPrint('Error saving vendor category: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Log OCR correction + learn vendor alias if vendor name was corrected
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> logOcrCorrection({
    required String rawText,
    required double systemSuggestedAmount,
    required double userCorrectedAmount,
    String? systemSuggestedVendor,
    String? userCorrectedVendor,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (systemSuggestedAmount <= 0) return;

    final diff = (systemSuggestedAmount - userCorrectedAmount).abs();
    final vendorChanged = systemSuggestedVendor != null &&
        userCorrectedVendor != null &&
        !_isFuzzyMatch(systemSuggestedVendor, userCorrectedVendor);

    if (diff == 0 && !vendorChanged) return;

    final pct = diff > 0 ? (diff / systemSuggestedAmount) * 100 : 0.0;
    final confidenceLabel = pct > 10.0 ? 'Low Confidence' : 'High Confidence';

    try {
      final log = OcrLogModel(
        rawText: rawText,
        systemSuggestedAmount: systemSuggestedAmount,
        userCorrectedAmount: userCorrectedAmount,
        confidenceLabel: confidenceLabel,
        createdAt: DateTime.now(),
        vendor: (userCorrectedVendor != null && userCorrectedVendor.isNotEmpty)
            ? userCorrectedVendor
            : systemSuggestedVendor,
      );
      await _db
          .collection('users')
          .doc(uid)
          .collection('ocr_logs')
          .add(log.toMap());

      // Learn vendor alias: "MCDNALD" → "McDonald's"
      if (vendorChanged &&
          systemSuggestedVendor!.isNotEmpty &&
          userCorrectedVendor!.isNotEmpty) {
        await _learnVendorAlias(
          ocrGuess: systemSuggestedVendor,
          correctedName: userCorrectedVendor,
          uid: uid,
        );
      }
    } catch (e) {
      debugPrint('Error logging OCR correction: $e');
    }
  }

  Future<void> _learnVendorAlias({
    required String ocrGuess,
    required String correctedName,
    required String uid,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('vendor_catalog')
          .get();

      DocumentReference? targetDoc;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final vendorName = data['vendorName'] as String? ?? '';
        if (_isFuzzyMatch(vendorName, correctedName)) {
          targetDoc = doc.reference;
          final aliases = List<String>.from(
              (data['aliases'] as List<dynamic>?)?.map((e) => e.toString()) ?? []);
          if (!aliases.contains(ocrGuess)) {
            aliases.add(ocrGuess);
            await doc.reference.update({'aliases': aliases});
          }
          break;
        }
      }

      if (targetDoc == null) {
        // If the mapping doesn't exist yet, create it immediately
        await _db.collection('users').doc(uid).collection('vendor_catalog').add({
          'vendorName': correctedName.trim(),
          'defaultCategoryId': 'Other', // Fallback, will be updated by saveVendorCategory
          'usageCount': 1,
          'aliases': [ocrGuess],
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error learning vendor alias: $e');
    }
  }
}
