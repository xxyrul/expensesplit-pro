import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/anomaly_alert.dart';
import '../services/anomaly_detection_service.dart';
import '../services/audit_log_service.dart';
import '../widgets/modern_bottom_toast.dart';

final _anomalyServiceProvider = Provider((ref) => AnomalyDetectionService());

class AnomalyAlertsScreen extends ConsumerStatefulWidget {
  const AnomalyAlertsScreen({super.key});

  @override
  ConsumerState<AnomalyAlertsScreen> createState() => _AnomalyAlertsScreenState();
}

class _AnomalyAlertsScreenState extends ConsumerState<AnomalyAlertsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, Map<String, String>> _userCache = {};
  Map<String, String> _vendorCategoryHints = {};
  bool _isLoading = true;
  String? _loadError;
  AnomalySeverity? _severityFilter;
  String? _ruleFilter;

  @override
  void initState() {
    super.initState();
    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final usersSnap = await _firestore.collection('users').get();
      final hintsSnap = await _firestore.collection('ocr_learning').get();

      final cache = <String, Map<String, String>>{};
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        cache[doc.id] = {
          'email': data['email']?.toString() ?? 'Unknown Email',
          'displayName': data['displayName']?.toString() ?? data['name']?.toString() ?? 'Unknown User',
        };
      }

      final hints = <String, String>{};
      for (final doc in hintsSnap.docs) {
        final data = doc.data();
        final vendor = (data['vendorName'] ?? '').toString().trim().toLowerCase();
        final category = (data['category'] ?? '').toString().trim();
        if (vendor.isNotEmpty && category.isNotEmpty) {
          hints[vendor] = category;
        }
      }

      if (mounted) {
        setState(() {
          _userCache = cache;
          _vendorCategoryHints = hints;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _isMaskingActive() async {
    try {
      final doc = await _firestore.collection('system_config').doc('privacy_settings').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['maskSensitiveData'] == true;
      }
    } catch (_) {}
    return false;
  }

  List<Map<String, dynamic>> _mapExpenseDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      return {
        'id': doc.id,
        'userId': doc.reference.parent.parent?.id ?? '',
        'data': doc.data() as Map<String, dynamic>,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _mapOcrDocs(List<QueryDocumentSnapshot> docs) {
    return docs.map((doc) {
      return {
        'id': doc.id,
        'userId': doc.reference.parent.parent?.id ?? '',
        'data': doc.data() as Map<String, dynamic>,
      };
    }).toList();
  }

  List<AnomalyAlert> _filterAlerts(List<AnomalyAlert> alerts) {
    return alerts.where((a) {
      if (_severityFilter != null && a.severity != _severityFilter) return false;
      if (_ruleFilter != null && a.ruleCode != _ruleFilter) return false;
      return true;
    }).toList();
  }

  void _showRulesReference() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explainable integrity rules'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final code in AnomalyRuleCodes.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        code,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      ),
                      Text(AnomalyRuleCodes.label(code)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final detector = ref.watch(_anomalyServiceProvider);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load reference data', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadReferenceData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<bool>(
      future: _isMaskingActive(),
      builder: (context, maskingSnap) {
        final isMasked = maskingSnap.data ?? false;

        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Anomalies & Integrity Monitor',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rule-based scanner with explainable reasons for each flag — suitable for governance review and thesis demonstration.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showRulesReference,
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('Rule reference'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loadReferenceData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh data'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primaryContainer,
                        foregroundColor: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Filter:', style: TextStyle(fontWeight: FontWeight.w600)),
                    DropdownButton<AnomalySeverity?>(
                      value: _severityFilter,
                      hint: const Text('All severities'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All severities')),
                        ...AnomalySeverity.values.map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _severityFilter = v),
                    ),
                    DropdownButton<String?>(
                      value: _ruleFilter,
                      hint: const Text('All rules'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All rules')),
                        ...AnomalyRuleCodes.all.map(
                          (c) => DropdownMenuItem(value: c, child: Text(AnomalyRuleCodes.label(c))),
                        ),
                      ],
                      onChanged: (v) => setState(() => _ruleFilter = v),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collectionGroup('expenses').snapshots(),
                    builder: (context, expSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collectionGroup('ocr_logs').snapshots(),
                        builder: (context, ocrSnapshot) {
                          if (expSnapshot.hasError || ocrSnapshot.hasError) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cloud_off, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    expSnapshot.error?.toString() ??
                                        ocrSnapshot.error?.toString() ??
                                        'Stream error',
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: () => setState(() {}),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (expSnapshot.connectionState == ConnectionState.waiting ||
                              ocrSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final allAlerts = detector.analyze(
                            expenses: _mapExpenseDocs(expSnapshot.data?.docs ?? []),
                            ocrLogs: _mapOcrDocs(ocrSnapshot.data?.docs ?? []),
                            userCache: _userCache,
                            maskEmails: isMasked,
                            vendorCategoryHints: _vendorCategoryHints,
                          );
                          final alerts = _filterAlerts(allAlerts);

                          final highCount = alerts.where((a) => a.severity == AnomalySeverity.high).length;
                          final medCount = alerts.where((a) => a.severity == AnomalySeverity.medium).length;
                          final lowCount = alerts.where((a) => a.severity == AnomalySeverity.low).length;
                          final severityColors = _SeverityColors.from(colorScheme);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _buildKpiCard(colorScheme, 'Filtered alerts', '${alerts.length}', colorScheme.onSurface),
                                  const SizedBox(width: 16),
                                  _buildKpiCard(colorScheme, 'High', '$highCount', severityColors.high),
                                  const SizedBox(width: 16),
                                  _buildKpiCard(colorScheme, 'Medium', '$medCount', severityColors.medium),
                                  const SizedBox(width: 16),
                                  _buildKpiCard(colorScheme, 'Low', '$lowCount', severityColors.low),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Expanded(
                                child: alerts.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified_user, size: 56, color: colorScheme.outline),
                                            const SizedBox(height: 12),
                                            Text(
                                              allAlerts.isEmpty
                                                  ? 'No integrity warnings detected by current rules.'
                                                  : 'No alerts match the selected filters.',
                                              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: alerts.length,
                                        itemBuilder: (context, index) => _AnomalyAlertCard(
                                          alert: alerts[index],
                                          colorScheme: colorScheme,
                                          severityColors: severityColors,
                                          onInspect: alerts[index].isExpenseRelated
                                              ? () => _inspectExpense(
                                                    alerts[index].userId,
                                                    alerts[index].expenseId!,
                                                  )
                                              : null,
                                          onResolveOcr: alerts[index].isOcrRelated
                                              ? () => _approveOcr(
                                                    alerts[index].userId,
                                                    alerts[index].ocrLogId!,
                                                  )
                                              : null,
                                          onSuspend: () => _flagAccount(
                                                alerts[index].userId,
                                                alerts[index].userLabel,
                                              ),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKpiCard(ColorScheme colorScheme, String label, String value, Color activeColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: activeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _inspectExpense(String userId, String expenseId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).collection('expenses').doc(expenseId).get();

      if (!doc.exists || doc.data() == null || !mounted) return;
      final data = doc.data()!;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Flagged expense inspection'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Document ID: $expenseId', style: const TextStyle(fontSize: 12)),
              const Divider(),
              Text('Vendor: ${data['vendor'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Category: ${data['category'] ?? 'General'}'),
              Text('Amount: RM ${((data['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
              Text('Date: ${data['date'] ?? '—'}'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(context, message: 'Could not load expense: $e', type: ModernToastType.error);
      }
    }
  }

  Future<void> _approveOcr(String userId, String logId) async {
    try {
      await _firestore.collection('users').doc(userId).collection('ocr_logs').doc(logId).update({
        'adminStatus': 'Approved',
      });

      ref.read(auditLogServiceProvider).logAction(
            action: 'OCR_RESOLVE_ANOMALY',
            targetId: logId,
            targetType: 'ocr_log',
            detail: 'Resolved OCR-related anomaly from integrity monitor.',
          );

      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'OCR item marked approved.',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(context, message: 'Update failed: $e', type: ModernToastType.error);
      }
    }
  }

  void _flagAccount(String userId, String userEmail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspend user account?'),
        content: Text(
          'Deactivate "$userEmail" after governance review? This blocks mobile sign-in until reactivated.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(userId).update({'isActive': false});
                ref.read(auditLogServiceProvider).logAction(
                      action: 'SUSPEND_USER_ANOMALY',
                      targetId: userId,
                      targetType: 'user',
                      detail: 'Suspended user "$userEmail" from anomaly monitor.',
                    );
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ModernBottomToast.show(context, message: 'Suspend failed: $e', type: ModernToastType.error);
                }
              }
            },
            child: const Text('Confirm suspension'),
          ),
        ],
      ),
    );
  }
}

class _SeverityColors {
  const _SeverityColors({
    required this.high,
    required this.medium,
    required this.low,
  });

  final Color high;
  final Color medium;
  final Color low;

  factory _SeverityColors.from(ColorScheme scheme) => _SeverityColors(
        high: scheme.error,
        medium: scheme.tertiary,
        low: scheme.primary,
      );

  Color forSeverity(AnomalySeverity severity) => switch (severity) {
        AnomalySeverity.high => high,
        AnomalySeverity.medium => medium,
        AnomalySeverity.low => low,
      };
}

class _AnomalyAlertCard extends StatelessWidget {
  const _AnomalyAlertCard({
    required this.alert,
    required this.colorScheme,
    required this.severityColors,
    this.onInspect,
    this.onResolveOcr,
    required this.onSuspend,
  });

  final AnomalyAlert alert;
  final ColorScheme colorScheme;
  final _SeverityColors severityColors;
  final VoidCallback? onInspect;
  final VoidCallback? onResolveOcr;
  final VoidCallback onSuspend;

  Color get _severityColor => severityColors.forSeverity(alert.severity);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _severityColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.rule_folder_outlined, color: _severityColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Chip(
                        label: Text(alert.severityLabel, style: TextStyle(color: _severityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                        backgroundColor: _severityColor.withValues(alpha: 0.1),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                      ),
                      Chip(
                        label: Text(
                          alert.ruleCode,
                          style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                        ),
                        backgroundColor: colorScheme.surface,
                        side: BorderSide(color: colorScheme.outlineVariant),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(alert.summary, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Why this was flagged (${alert.reasons.length} reasons)',
                        style: TextStyle(fontSize: 13, color: colorScheme.primary, fontWeight: FontWeight.w600),
                      ),
                      children: [
                        ...alert.reasons.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Expanded(child: Text(r, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                        if (alert.evidence.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.analytics_outlined, size: 14, color: colorScheme.primary),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Evidence Data',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  ...alert.evidence.entries.map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 3.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 140,
                                            child: Text(
                                              e.key,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${e.value}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('User: ${alert.userLabel}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                      const SizedBox(width: 24),
                      Icon(Icons.calendar_today, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text('Date: ${alert.displayDate}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (onInspect != null)
                  FilledButton(onPressed: onInspect, child: const Text('Inspect record')),
                if (onResolveOcr != null) ...[
                  if (onInspect != null) const SizedBox(height: 8),
                  FilledButton(onPressed: onResolveOcr, child: const Text('Approve OCR')),
                ],
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                  onPressed: onSuspend,
                  child: const Text('Suspend account'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
