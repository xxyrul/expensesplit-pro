import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/audit_log_service.dart';
import '../widgets/vendor_learn_dialog.dart';

class OcrReviewQueueScreen extends ConsumerStatefulWidget {
  const OcrReviewQueueScreen({super.key});

  @override
  ConsumerState<OcrReviewQueueScreen> createState() => _OcrReviewQueueScreenState();
}

class _OcrReviewQueueScreenState extends ConsumerState<OcrReviewQueueScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedConfidenceFilter = 'All';
  String _selectedStatusFilter = 'All';
  Map<String, Map<String, String>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserCache();
  }

  Future<void> _loadUserCache() async {
    try {
      final snap = await _firestore.collection('users').get();
      final Map<String, Map<String, String>> tempCache = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        tempCache[doc.id] = {
          'email': data['email']?.toString() ?? 'Unknown Email',
          'displayName': data['displayName']?.toString() ?? data['name']?.toString() ?? 'Unknown User',
        };
      }
      if (mounted) {
        setState(() {
          _userCache = tempCache;
        });
      }
    } catch (e) {
      debugPrint('Error loading user cache: $e');
    }
  }

  Future<bool> _isMaskingActive() async {
    try {
      final doc = await _firestore.collection('system_config').doc('privacy_settings').get();
      if (doc.exists && doc.data() != null) {
        return doc.data()!['maskSensitiveData'] ?? false;
      }
    } catch (_) {}
    return false;
  }

  String _maskEmail(String email, bool mask) {
    if (!mask || email == 'Unknown Email') return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }

  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final confidence = data['confidenceLabel'] ?? '';
      final adminStatus = data['adminStatus'] ?? 'Pending';

      if (_selectedConfidenceFilter != 'All' && confidence != _selectedConfidenceFilter) {
        return false;
      }
      if (_selectedStatusFilter != 'All' && adminStatus != _selectedStatusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<bool>(
      future: _isMaskingActive(),
      builder: (context, maskingSnap) {
        final isMasked = maskingSnap.data ?? false;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 900;
                final isMobile = constraints.maxWidth < 600;

                return Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isNarrow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OCR Review Queue',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Review and correct low-confidence OCR transcriptions. Feed adjustments back to the global learning dictionary.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadUserCache,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OCR Review Queue',
                                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Review and correct low-confidence OCR transcriptions. Feed adjustments back to the global learning dictionary.',
                                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _loadUserCache,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                    _buildFilterBar(colorScheme),
                    const SizedBox(height: 24),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore.collectionGroup('ocr_logs').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          final allDocs = snapshot.data?.docs ?? [];
                          final filteredDocs = _applyFilters(allDocs);

                          return Container(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: colorScheme.outlineVariant),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    'Pending Actions: ${filteredDocs.where((d) => (d.data() as Map)['adminStatus'] == null || (d.data() as Map)['adminStatus'] == 'Pending').length}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: filteredDocs.isEmpty
                                      ? const Center(
                                          child: Text(
                                            'No OCR logs matching selected filters.',
                                            style: TextStyle(fontSize: 16, color: Colors.grey),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.vertical,
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: DataTable(
                                              headingRowColor: WidgetStateProperty.all(
                                                colorScheme.surfaceContainerHighest,
                                              ),
                                              columns: const [
                                                DataColumn(label: Text('Timestamp')),
                                                DataColumn(label: Text('User')),
                                                DataColumn(label: Text('System Suggested Amount')),
                                                DataColumn(label: Text('User Corrected Amount')),
                                                DataColumn(label: Text('Confidence')),
                                                DataColumn(label: Text('Admin Status')),
                                                DataColumn(label: Text('Actions')),
                                              ],
                                              rows: filteredDocs.map((doc) {
                                                final data = doc.data() as Map<String, dynamic>;
                                                final docId = doc.id;
                                                final userId = doc.reference.parent.parent?.id ?? '';

                                                final user = _userCache[userId];
                                                final userEmail = _maskEmail(user?['email'] ?? 'Unknown', isMasked);

                                                final systemSuggestedAmount =
                                                    (data['systemSuggestedAmount'] as num?)?.toDouble() ?? 0.0;
                                                final userCorrectedAmount =
                                                    (data['userCorrectedAmount'] as num?)?.toDouble() ?? 0.0;
                                                final confidence = data['confidenceLabel'] ?? 'Unknown';
                                                final adminStatus = data['adminStatus'] ?? 'Pending';
                                                final rawText = data['rawText'] ?? '';

                                                String dateStr = '';
                                                if (data['createdAt'] != null) {
                                                  DateTime? createdDate;
                                                  if (data['createdAt'] is Timestamp) {
                                                    createdDate = (data['createdAt'] as Timestamp).toDate();
                                                  } else {
                                                    createdDate = DateTime.tryParse(data['createdAt']);
                                                  }
                                                  if (createdDate != null) {
                                                    dateStr = DateFormat('yyyy-MM-dd HH:mm').format(createdDate);
                                                  }
                                                }

                                                final bool isLowConfidence = confidence == 'Low Confidence';
                                                final isApproved = adminStatus == 'Approved';
                                                final isRejected = adminStatus == 'Rejected';

                                                return DataRow(
                                                  cells: [
                                                    DataCell(Text(dateStr)),
                                                    DataCell(Text(userEmail)),
                                                    DataCell(Text('RM ${systemSuggestedAmount.toStringAsFixed(2)}')),
                                                    DataCell(
                                                      Text(
                                                        'RM ${userCorrectedAmount.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          color: systemSuggestedAmount != userCorrectedAmount
                                                              ? Colors.amber
                                                              : Colors.green,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Chip(
                                                        label: Text(
                                                          confidence,
                                                          style: TextStyle(
                                                            color: isLowConfidence ? Colors.red : Colors.green,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                        backgroundColor: isLowConfidence
                                                            ? Colors.red.withOpacity(0.1)
                                                            : Colors.green.withOpacity(0.1),
                                                        side: BorderSide.none,
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        adminStatus,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: isApproved
                                                              ? Colors.green
                                                              : isRejected
                                                                  ? Colors.red
                                                                  : Colors.amber,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Row(
                                                        children: [
                                                          IconButton(
                                                            icon: const Icon(Icons.text_snippet),
                                                            tooltip: 'Show Raw OCR text',
                                                            onPressed: () => _showRawTextDialog(context, rawText),
                                                          ),
                                                          if (adminStatus == 'Pending') ...[
                                                            IconButton(
                                                              icon: const Icon(Icons.check, color: Colors.green),
                                                              tooltip: 'Approve System Value',
                                                              onPressed: () => _updateStatus(
                                                                userId,
                                                                docId,
                                                                'Approved',
                                                                systemSuggestedAmount,
                                                                userCorrectedAmount,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.close, color: Colors.red),
                                                              tooltip: 'Reject Scan',
                                                              onPressed: () => _updateStatus(
                                                                userId,
                                                                docId,
                                                                'Rejected',
                                                                systemSuggestedAmount,
                                                                userCorrectedAmount,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.psychology, color: Colors.blue),
                                                              tooltip: 'Correct & Add to Seed Dictionary',
                                                              onPressed: () => _showLearnDialog(
                                                                context,
                                                                userId,
                                                                docId,
                                                                rawText,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

  Widget _buildFilterBar(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        final controls = [
          const Icon(Icons.tune),
          const Text('Filters:', style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _selectedConfidenceFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Confidences')),
              DropdownMenuItem(value: 'High Confidence', child: Text('High Confidence')),
              DropdownMenuItem(value: 'Low Confidence', child: Text('Low Confidence')),
            ],
            onChanged: (val) {
              setState(() {
                _selectedConfidenceFilter = val ?? 'All';
              });
            },
          ),
          DropdownButton<String>(
            value: _selectedStatusFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Statuses')),
              DropdownMenuItem(value: 'Pending', child: Text('Pending Review')),
              DropdownMenuItem(value: 'Approved', child: Text('Approved')),
              DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
            ],
            onChanged: (val) {
              setState(() {
                _selectedStatusFilter = val ?? 'All';
              });
            },
          ),
        ];

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: isNarrow
              ? Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: controls,
                )
              : Row(
                  children: [
                    controls[0],
                    const SizedBox(width: 12),
                    controls[1],
                    const SizedBox(width: 24),
                    controls[2],
                    const SizedBox(width: 32),
                    controls[3],
                  ],
                ),
        );
      },
    );
  }

  void _showRawTextDialog(BuildContext context, String rawText) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Raw OCR Transcription Output'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rawText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Colors.greenAccent,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(
    String userId,
    String docId,
    String status,
    double systemVal,
    double userVal,
  ) async {
    await _firestore.collection('users').doc(userId).collection('ocr_logs').doc(docId).update({
      'adminStatus': status,
    });

    ref.read(auditLogServiceProvider).logAction(
          action: 'OCR_REVIEW',
          targetId: docId,
          targetType: 'ocr_log',
          detail:
              'Marked OCR log as $status (SysSuggested: RM ${systemVal.toStringAsFixed(2)} | UserCorrected: RM ${userVal.toStringAsFixed(2)}).',
        );
  }

  void _showLearnDialog(
    BuildContext context,
    String userId,
    String docId,
    String rawText,
  ) {
    final alias = rawText.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
    VendorLearnDialog.show(
      context,
      ref,
      initialAlias: alias.length > 48 ? '${alias.substring(0, 48)}…' : alias,
      ocrLogUserId: userId,
      ocrLogDocId: docId,
      onOcrApproved: () => _updateStatus(userId, docId, 'Approved', 0.0, 0.0),
    );
  }
}
