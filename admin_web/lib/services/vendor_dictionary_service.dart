import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories aligned with mobile app + OCR learning.
const kVendorDictionaryCategories = [
  'Food',
  'Groceries',
  'Transport',
  'Shopping',
  'Health',
  'Entertainment',
  'Utilities',
  'Education',
  'Bills',
  'Others',
  'General',
];

class VendorDictionaryService {
  VendorDictionaryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('ocr_learning');

  /// Creates or merges a vendor → category mapping with optional OCR aliases.
  Future<String> upsertMapping({
    required String vendorName,
    required String category,
    List<String> aliases = const [],
  }) async {
    final master = vendorName.trim();
    if (master.isEmpty) {
      throw ArgumentError('Vendor name is required');
    }

    final normalizedAliases = aliases
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();

    final query = await _collection.where('vendorName', isEqualTo: master).limit(1).get();

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final existing = List<String>.from(doc.data()['aliases'] ?? []);
      final merged = {...existing, ...normalizedAliases}.toList();
      await doc.reference.update({
        'category': category,
        'aliases': merged,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return doc.id;
    }

    final ref = await _collection.add({
      'vendorName': master,
      'category': category,
      'aliases': normalizedAliases,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> deleteMapping(String docId) async {
    await _collection.doc(docId).delete();
  }

  Future<void> removeAlias(String docId, String alias) async {
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) return;
    final aliases = List<String>.from(doc.data()?['aliases'] ?? []);
    aliases.remove(alias);
    await doc.reference.update({'aliases': aliases});
  }
}
