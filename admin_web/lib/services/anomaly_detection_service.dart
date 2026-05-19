import '../models/anomaly_alert.dart';
import '../utils/privacy_mask.dart';

/// Rule-based integrity scanner for admin oversight (no ML black box).
///
/// Each rule returns human-readable [AnomalyAlert.reasons] so findings are
/// defensible in a thesis demo or audit review.
class AnomalyDetectionService {
  static const double _outlierMultiplier = 3.0;
  static const double _outlierMinAmountRm = 200.0;
  static const double _ocrMismatchMinDeltaRm = 5.0;
  static const double _ocrMismatchMinDeltaPct = 0.10;

  static final Set<String> _genericVendors = {
    '',
    'n/a',
    'na',
    'general',
    'receipt',
    'unknown',
    'misc',
  };

  String _normVendor(String? v) =>
      (v ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    return DateTime.tryParse(raw.toString());
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// [expenses] — map keys: `id`, `userId`, `data` (Firestore expense fields).
  /// [ocrLogs] — map keys: `id`, `userId`, `data`.
  /// [vendorCategoryHints] — normalized vendor → expected category (`ocr_learning`).
  List<AnomalyAlert> analyze({
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> ocrLogs,
    required Map<String, Map<String, String>> userCache,
    required bool maskEmails,
    Map<String, String> vendorCategoryHints = const {},
  }) {
    final alerts = <AnomalyAlert>[];
    final seenIds = <String>{};

    void add(AnomalyAlert alert) {
      if (seenIds.add(alert.id)) alerts.add(alert);
    }

    String userLabel(String userId) {
      final user = userCache[userId];
      final email = user?['email'] ?? 'Unknown Email';
      return maskEmailIfEnabled(email, maskEmails);
    }

    final byUser = <String, List<Map<String, dynamic>>>{};
    for (final row in expenses) {
      final uid = row['userId'] as String? ?? '';
      if (uid.isEmpty) continue;
      byUser.putIfAbsent(uid, () => []).add(row);
    }

    for (final entry in byUser.entries) {
      final userId = entry.key;
      final rows = entry.value;
      final label = userLabel(userId);

      rows.sort((a, b) {
        final ad = _parseDate((a['data'] as Map)['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd = _parseDate((b['data'] as Map)['date']) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ad.compareTo(bd);
      });

      _detectDuplicates(rows, userId, label, add);
      _detectHighOutliers(rows, userId, label, add);
      _detectRepeatedSameDayVendor(rows, userId, label, add);
      _detectIncompleteMetadata(rows, userId, label, add);
      _detectCategoryMismatch(rows, userId, label, vendorCategoryHints, add);
    }

    for (final row in ocrLogs) {
      _detectOcrIssues(row, userLabel(row['userId'] as String? ?? ''), add);
    }

    alerts.sort((a, b) {
      final s = b.severity.index.compareTo(a.severity.index);
      if (s != 0) return s;
      return a.displayDate.compareTo(b.displayDate);
    });

    return alerts;
  }

  void _detectDuplicates(
    List<Map<String, dynamic>> rows,
    String userId,
    String label,
    void Function(AnomalyAlert) add,
  ) {
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final data = row['data'] as Map<String, dynamic>;
      final vendor = _normVendor(data['vendor']?.toString());
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final date = _parseDate(data['date']);
      if (vendor.isEmpty || date == null) continue;
      final key = '$userId|$vendor|${amount.toStringAsFixed(2)}|${_dayKey(date)}';
      buckets.putIfAbsent(key, () => []).add(row);
    }

    for (final group in buckets.values) {
      if (group.length < 2) continue;
      final first = group.first['data'] as Map<String, dynamic>;
      final vendor = first['vendor']?.toString() ?? '';
      final amount = (first['amount'] as num?)?.toDouble() ?? 0.0;
      final date = _parseDate(first['date'])!;

      add(AnomalyAlert(
        id: '${group.first['id']}_${AnomalyRuleCodes.duplicateReceipt}',
        ruleCode: AnomalyRuleCodes.duplicateReceipt,
        severity: AnomalySeverity.high,
        title: 'Duplicate receipt pattern',
        summary:
            'Vendor "$vendor" for RM ${amount.toStringAsFixed(2)} appears ${group.length} times on ${_dayKey(date)}.',
        reasons: [
          'Rule: same user, vendor, amount, and calendar day.',
          '${group.length} matching expense records were found.',
          'Duplicates may indicate double submission or receipt reuse.',
        ],
        evidence: {
          'vendor': vendor,
          'amount': amount.toStringAsFixed(2),
          'date': _dayKey(date),
          'matchCount': '${group.length}',
        },
        userId: userId,
        userLabel: label,
        displayDate: _dayKey(date),
        expenseId: group.last['id'] as String?,
      ));
    }
  }

  void _detectHighOutliers(
    List<Map<String, dynamic>> rows,
    String userId,
    String label,
    void Function(AnomalyAlert) add,
  ) {
    if (rows.length < 3) return;

    final amounts = rows
        .map((r) => ((r['data'] as Map)['amount'] as num?)?.toDouble() ?? 0.0)
        .toList();
    final avg = amounts.reduce((a, b) => a + b) / amounts.length;

    for (final row in rows) {
      final data = row['data'] as Map<String, dynamic>;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      if (amount <= _outlierMultiplier * avg || amount <= _outlierMinAmountRm) continue;

      final vendor = data['vendor']?.toString() ?? 'N/A';
      final date = _parseDate(data['date']);

      add(AnomalyAlert(
        id: '${row['id']}_${AnomalyRuleCodes.highAmountOutlier}',
        ruleCode: AnomalyRuleCodes.highAmountOutlier,
        severity: AnomalySeverity.medium,
        title: 'Unusually high amount',
        summary:
            'RM ${amount.toStringAsFixed(2)} at "$vendor" exceeds ${_outlierMultiplier}x the user average (RM ${avg.toStringAsFixed(2)}).',
        reasons: [
          'Rule: amount > ${_outlierMultiplier}x recent user average AND > RM $_outlierMinAmountRm.',
          'Based on ${rows.length} expenses for this user in the dataset.',
          'Large one-off spends are flagged for manual review, not auto-blocked.',
        ],
        evidence: {
          'amount': amount.toStringAsFixed(2),
          'userAverage': avg.toStringAsFixed(2),
          'thresholdMultiplier': '$_outlierMultiplier',
          'vendor': vendor,
        },
        userId: userId,
        userLabel: label,
        displayDate: date != null ? _dayKey(date) : '—',
        expenseId: row['id'] as String?,
      ));
    }
  }

  void _detectRepeatedSameDayVendor(
    List<Map<String, dynamic>> rows,
    String userId,
    String label,
    void Function(AnomalyAlert) add,
  ) {
    final buckets = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final data = row['data'] as Map<String, dynamic>;
      final vendor = _normVendor(data['vendor']?.toString());
      final date = _parseDate(data['date']);
      if (vendor.isEmpty || _genericVendors.contains(vendor) || date == null) continue;
      final key = '$userId|$vendor|${_dayKey(date)}';
      buckets.putIfAbsent(key, () => []).add(row);
    }

    for (final group in buckets.values) {
      if (group.length < 3) continue;
      final data = group.first['data'] as Map<String, dynamic>;
      final vendor = data['vendor']?.toString() ?? '';
      final date = _parseDate(data['date'])!;

      add(AnomalyAlert(
        id: '${group.first['id']}_${AnomalyRuleCodes.repeatedSameDayVendor}',
        ruleCode: AnomalyRuleCodes.repeatedSameDayVendor,
        severity: AnomalySeverity.medium,
        title: 'Repeated same-day vendor activity',
        summary: '"$vendor" logged ${group.length} times on ${_dayKey(date)}.',
        reasons: [
          'Rule: ≥3 expenses with the same vendor on the same calendar day.',
          'May indicate split receipts, testing, or unusual submission behaviour.',
        ],
        evidence: {
          'vendor': vendor,
          'date': _dayKey(date),
          'submissionCount': '${group.length}',
        },
        userId: userId,
        userLabel: label,
        displayDate: _dayKey(date),
        expenseId: group.last['id'] as String?,
      ));
    }
  }

  void _detectIncompleteMetadata(
    List<Map<String, dynamic>> rows,
    String userId,
    String label,
    void Function(AnomalyAlert) add,
  ) {
    for (final row in rows) {
      final data = row['data'] as Map<String, dynamic>;
      final vendor = _normVendor(data['vendor']?.toString());
      if (!_genericVendors.contains(vendor)) continue;

      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      final date = _parseDate(data['date']);

      add(AnomalyAlert(
        id: '${row['id']}_${AnomalyRuleCodes.incompleteMetadata}',
        ruleCode: AnomalyRuleCodes.incompleteMetadata,
        severity: AnomalySeverity.low,
        title: 'Incomplete vendor metadata',
        summary:
            'RM ${amount.toStringAsFixed(2)} logged with generic or missing vendor "${data['vendor'] ?? ''}".',
        reasons: [
          'Rule: vendor is empty or a placeholder (e.g. receipt, general, n/a).',
          'Weak metadata reduces audit quality and OCR learning value.',
        ],
        evidence: {
          'vendor': data['vendor']?.toString() ?? '',
          'amount': amount.toStringAsFixed(2),
        },
        userId: userId,
        userLabel: label,
        displayDate: date != null ? _dayKey(date) : '—',
        expenseId: row['id'] as String?,
      ));
    }
  }

  void _detectCategoryMismatch(
    List<Map<String, dynamic>> rows,
    String userId,
    String label,
    Map<String, String> hints,
    void Function(AnomalyAlert) add,
  ) {
    if (hints.isEmpty) return;

    for (final row in rows) {
      final data = row['data'] as Map<String, dynamic>;
      final vendor = _normVendor(data['vendor']?.toString());
      final category = (data['category'] ?? '').toString().trim();
      if (vendor.isEmpty || category.isEmpty) continue;

      String? expected;
      hints.forEach((key, value) {
        if (expected != null) return;
        if (vendor == key || vendor.contains(key) || key.contains(vendor)) {
          expected = value;
        }
      });
      if (expected == null) continue;
      if (category.toLowerCase() == expected!.toLowerCase()) continue;

      final date = _parseDate(data['date']);
      add(AnomalyAlert(
        id: '${row['id']}_${AnomalyRuleCodes.categoryVendorMismatch}',
        ruleCode: AnomalyRuleCodes.categoryVendorMismatch,
        severity: AnomalySeverity.low,
        title: 'Category does not match vendor dictionary',
        summary:
            '"${data['vendor']}" is usually "$expected" but was filed under "$category".',
        reasons: [
          'Rule: expense category differs from admin OCR learning dictionary.',
          'Dictionary entry comes from approved `ocr_learning` mappings.',
        ],
        evidence: {
          'vendor': data['vendor']?.toString() ?? '',
          'loggedCategory': category,
          'expectedCategory': expected!,
        },
        userId: userId,
        userLabel: label,
        displayDate: date != null ? _dayKey(date) : '—',
        expenseId: row['id'] as String?,
      ));
    }
  }

  void _detectOcrIssues(
    Map<String, dynamic> row,
    String label,
    void Function(AnomalyAlert) add,
  ) {
    final data = row['data'] as Map<String, dynamic>;
    final userId = row['userId'] as String? ?? '';
    final logId = row['id'] as String? ?? '';
    final adminStatus = (data['adminStatus'] ?? 'Pending').toString();
    if (adminStatus != 'Pending') return;

    final sys = (data['systemSuggestedAmount'] as num?)?.toDouble() ?? 0.0;
    final user = (data['userCorrectedAmount'] as num?)?.toDouble() ?? 0.0;
    final confidence = (data['confidenceLabel'] ?? '').toString();
    final delta = (user - sys).abs();
    final pct = sys > 0 ? delta / sys : (delta > 0 ? 1.0 : 0.0);

    if (confidence == 'Low Confidence') {
      add(AnomalyAlert(
        id: '${logId}_${AnomalyRuleCodes.lowConfidenceOcr}',
        ruleCode: AnomalyRuleCodes.lowConfidenceOcr,
        severity: AnomalySeverity.medium,
        title: 'Low-confidence OCR extraction',
        summary:
            'Scanner confidence was low (suggested RM ${sys.toStringAsFixed(2)}, user entered RM ${user.toStringAsFixed(2)}).',
        reasons: [
          'Rule: OCR log marked "Low Confidence" and still Pending admin review.',
          'Receipt text may be blurry, cropped, or missing a clear total line.',
        ],
        evidence: {
          'systemAmount': sys.toStringAsFixed(2),
          'userAmount': user.toStringAsFixed(2),
          'confidence': confidence,
          'adminStatus': adminStatus,
        },
        userId: userId,
        userLabel: label,
        displayDate: 'Pending review',
        ocrLogId: logId,
      ));
    }

    if (sys != user &&
        (delta >= _ocrMismatchMinDeltaRm || pct >= _ocrMismatchMinDeltaPct)) {
      add(AnomalyAlert(
        id: '${logId}_${AnomalyRuleCodes.ocrAmountMismatch}',
        ruleCode: AnomalyRuleCodes.ocrAmountMismatch,
        severity: AnomalySeverity.medium,
        title: 'OCR amount correction gap',
        summary:
            'User corrected RM ${sys.toStringAsFixed(2)} → RM ${user.toStringAsFixed(2)} (Δ RM ${delta.toStringAsFixed(2)}).',
        reasons: [
          'Rule: |system − user amount| ≥ RM $_ocrMismatchMinDeltaRm or ≥ ${(_ocrMismatchMinDeltaPct * 100).toStringAsFixed(0)}% of suggested amount.',
          'Corrections are logged for OCR quality review and model improvement.',
        ],
        evidence: {
          'systemAmount': sys.toStringAsFixed(2),
          'userAmount': user.toStringAsFixed(2),
          'delta': delta.toStringAsFixed(2),
        },
        userId: userId,
        userLabel: label,
        displayDate: 'Pending review',
        ocrLogId: logId,
      ));
    }
  }
}
