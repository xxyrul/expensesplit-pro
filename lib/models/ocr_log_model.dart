class OcrLogModel {
  final String? id;
  final String rawText;
  final double systemSuggestedAmount;
  final double userCorrectedAmount;
  final String confidenceLabel;
  final DateTime createdAt;
  final String? vendor;

  OcrLogModel({
    this.id,
    required this.rawText,
    required this.systemSuggestedAmount,
    required this.userCorrectedAmount,
    required this.confidenceLabel,
    required this.createdAt,
    this.vendor,
  });

  Map<String, dynamic> toMap() {
    return {
      'rawText': rawText,
      'systemSuggestedAmount': systemSuggestedAmount,
      'userCorrectedAmount': userCorrectedAmount,
      'confidenceLabel': confidenceLabel,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (vendor != null && vendor!.isNotEmpty) 'vendor': vendor,
    };
  }

  factory OcrLogModel.fromMap(String id, Map<String, dynamic> map) {
    return OcrLogModel(
      id: id,
      rawText: map['rawText'] ?? '',
      systemSuggestedAmount: (map['systemSuggestedAmount'] as num?)?.toDouble() ?? 0.0,
      userCorrectedAmount: (map['userCorrectedAmount'] as num?)?.toDouble() ?? 0.0,
      confidenceLabel: map['confidenceLabel'] ?? '',
      vendor: map['vendor']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt']).toLocal()
          : DateTime.now(),
    );
  }
}
