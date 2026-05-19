/// Severity bands for governance triage (thesis-friendly, not ML scores).
enum AnomalySeverity { high, medium, low }

/// Stable rule identifiers — cite these in thesis methodology / demo scripts.
class AnomalyRuleCodes {
  AnomalyRuleCodes._();

  static const duplicateReceipt = 'DUPLICATE_RECEIPT';
  static const highAmountOutlier = 'HIGH_AMOUNT_OUTLIER';
  static const repeatedSameDayVendor = 'REPEATED_SAME_DAY_VENDOR';
  static const incompleteMetadata = 'INCOMPLETE_METADATA';
  static const lowConfidenceOcr = 'LOW_CONFIDENCE_OCR';
  static const ocrAmountMismatch = 'OCR_AMOUNT_MISMATCH';
  static const categoryVendorMismatch = 'CATEGORY_VENDOR_MISMATCH';

  static const all = [
    duplicateReceipt,
    highAmountOutlier,
    repeatedSameDayVendor,
    incompleteMetadata,
    lowConfidenceOcr,
    ocrAmountMismatch,
    categoryVendorMismatch,
  ];

  static String label(String code) => switch (code) {
        duplicateReceipt => 'Duplicate receipt',
        highAmountOutlier => 'Unusually high amount',
        repeatedSameDayVendor => 'Repeated same-day vendor',
        incompleteMetadata => 'Incomplete metadata',
        lowConfidenceOcr => 'Low-confidence OCR',
        ocrAmountMismatch => 'OCR amount mismatch',
        categoryVendorMismatch => 'Category / vendor mismatch',
        _ => code,
      };
}

/// One explainable integrity finding produced by [AnomalyDetectionService].
class AnomalyAlert {
  final String id;
  final String ruleCode;
  final AnomalySeverity severity;
  final String title;
  final String summary;
  final List<String> reasons;
  final Map<String, String> evidence;
  final String userId;
  final String userLabel;
  final String displayDate;
  final String? expenseId;
  final String? ocrLogId;

  const AnomalyAlert({
    required this.id,
    required this.ruleCode,
    required this.severity,
    required this.title,
    required this.summary,
    required this.reasons,
    required this.evidence,
    required this.userId,
    required this.userLabel,
    required this.displayDate,
    this.expenseId,
    this.ocrLogId,
  });

  String get severityLabel => switch (severity) {
        AnomalySeverity.high => 'High',
        AnomalySeverity.medium => 'Medium',
        AnomalySeverity.low => 'Low',
      };

  String get ruleLabel => AnomalyRuleCodes.label(ruleCode);

  bool get isOcrRelated =>
      ruleCode == AnomalyRuleCodes.lowConfidenceOcr ||
      ruleCode == AnomalyRuleCodes.ocrAmountMismatch;

  bool get isExpenseRelated => expenseId != null;
}
