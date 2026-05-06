class VendorCategoryMapping {
  final String vendorName;
  final String defaultCategoryId;
  final DateTime updatedAt;

  VendorCategoryMapping({
    required this.vendorName,
    required this.defaultCategoryId,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorName': vendorName,
      'defaultCategoryId': defaultCategoryId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory VendorCategoryMapping.fromMap(Map<String, dynamic> map) {
    return VendorCategoryMapping(
      vendorName: map['vendorName'] ?? '',
      defaultCategoryId: map['defaultCategoryId'] ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt']).toLocal()
          : DateTime.now(),
    );
  }
}
