import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/audit_log_service.dart';
import '../services/vendor_dictionary_service.dart';
import '../widgets/modern_bottom_toast.dart';
import '../widgets/vendor_learn_dialog.dart';

final _dictionaryServiceProvider = Provider((ref) => VendorDictionaryService());

class VendorIntelligenceHub extends ConsumerStatefulWidget {
  const VendorIntelligenceHub({super.key});

  @override
  ConsumerState<VendorIntelligenceHub> createState() => _VendorIntelligenceHubState();
}

class _VendorIntelligenceHubState extends ConsumerState<VendorIntelligenceHub> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _ocrSearch = '';
  String _dictSearch = '';
  final ScrollController _vController = ScrollController();
  final ScrollController _hController = ScrollController();
  final ScrollController _dialogVController = ScrollController();
  final ScrollController _dialogHController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    _dialogVController.dispose();
    _dialogHController.dispose();
    super.dispose();
  }

  DateTime? _parseLogDate(Map<String, dynamic> data) {
    final raw = data['createdAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  String _snippet(String raw, {int maxLen = 80}) {
    final line = raw.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (line.length <= maxLen) return line.isEmpty ? 'Unknown receipt text' : line;
    return '${line.substring(0, maxLen)}…';
  }

  Future<void> _promoteOcrLog(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    final raw = (data['rawText'] ?? '').toString();
    final userId = doc.reference.parent.parent?.id ?? '';

    await VendorLearnDialog.show(
      context,
      ref,
      initialAlias: _snippet(raw, maxLen: 48),
      ocrLogUserId: userId,
      ocrLogDocId: doc.id,
      onOcrApproved: () async {
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('ocr_logs')
            .doc(doc.id)
            .update({'adminStatus': 'Approved'});
      },
    );
  }

  Future<void> _openAddWordDialog() async {
    final ok = await VendorLearnDialog.show(context, ref);
    if (ok == true && mounted) {
      ModernBottomToast.show(
        context,
        message: 'Dictionary entry saved.',
        type: ModernToastType.success,
      );
    }
  }

  Future<void> _editMapping(String docId, Map<String, dynamic> data) async {
    final vendor = (data['vendorName'] ?? '').toString();
    var category = (data['category'] ?? 'General').toString();
    final aliasController = TextEditingController();
    final dictionary = ref.read(_dictionaryServiceProvider);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit "$vendor"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: kVendorDictionaryCategories.contains(category) ? category : 'General',
                decoration: const InputDecoration(labelText: 'Category'),
                items: kVendorDictionaryCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: aliasController,
                decoration: const InputDecoration(
                  labelText: 'Add alias keyword',
                  hintText: 'Optional OCR match text',
                ),
              ),
            ],
          ),
            actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await dictionary.upsertMapping(
                  vendorName: vendor,
                  category: category,
                  aliases: aliasController.text.trim().isEmpty
                      ? []
                      : [aliasController.text.trim()],
                );
                ref.read(auditLogServiceProvider).logAction(
                      action: 'LEARN_OCR_MAPPING',
                      targetId: docId,
                      targetType: 'ocr_learning',
                      detail: 'Updated mapping for "$vendor" → $category.',
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String docId, String vendor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove dictionary entry?'),
        content: Text('Delete "$vendor" from the global seed list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(_dictionaryServiceProvider).deleteMapping(docId);
    ref.read(auditLogServiceProvider).logAction(
          action: 'DELETE_VENDOR_MAPPING',
          targetId: docId,
          targetType: 'ocr_learning',
          detail: 'Removed vendor dictionary entry "$vendor".',
        );
    if (mounted) {
      ModernBottomToast.show(context, message: 'Entry removed.', type: ModernToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title & Actions
              Flex(
                direction: isMobile ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vendor Intelligence',
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.02,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage global seed dictionary and review automated OCR corrections.',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  if (isMobile) const SizedBox(height: 16),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Export Data'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onSurface,
                          side: BorderSide(color: colorScheme.outlineVariant),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.05),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _openAddWordDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Vendor Alias'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimaryContainer,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 8,
                          shadowColor: colorScheme.primary.withOpacity(0.3),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.05),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Bento Grid
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildKpiRow(colorScheme, isMobile),
                      const SizedBox(height: 24),
                      if (isMobile) ...[
                        SizedBox(height: 500, child: _buildOcrPanel(colorScheme)),
                        const SizedBox(height: 24),
                        SizedBox(height: 500, child: _buildDictionaryPanel(colorScheme)),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 8, child: SizedBox(height: 500, child: _buildOcrPanel(colorScheme))),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: SizedBox(height: 500, child: _buildDictionaryPanel(colorScheme))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiRow(ColorScheme colorScheme, bool isMobile) {
    final kpis = [
      Expanded(
        child: _KpiCard(
          label: 'GLOBAL DICTIONARY ENTRIES',
          icon: Icons.menu_book,
          stream: _firestore.collection('ocr_learning').snapshots(),
          value: (snap) => '${snap.docs.length}',
          trend: '+2.4%',
          trendUp: true,
          desc: 'Verified standard names across all organizations.',
          colorScheme: colorScheme,
          accent: colorScheme.primary,
        ),
      ),
      SizedBox(width: isMobile ? 0 : 24, height: isMobile ? 24 : 0),
      Expanded(
        child: _KpiCard(
          label: 'AUTO-CORRECTIONS (30D)',
          icon: Icons.spellcheck,
          stream: _firestore.collectionGroup('ocr_logs').snapshots(),
          value: (snap) => '${snap.docs.length}',
          trend: '+12%',
          trendUp: true,
          desc: 'Receipt variations mapped to standard names.',
          colorScheme: colorScheme,
          accent: colorScheme.secondary,
        ),
      ),
      SizedBox(width: isMobile ? 0 : 24, height: isMobile ? 24 : 0),
      Expanded(
        child: _KpiCard(
          label: 'LOW CONFIDENCE FLAGS',
          icon: Icons.warning,
          stream: _firestore.collectionGroup('ocr_logs').snapshots(),
          value: (snap) {
            final n = snap.docs.where((d) {
              final data = d.data();
              return data['confidenceLabel'] == 'Low Confidence' &&
                  (data['adminStatus'] ?? 'Pending') == 'Pending';
            }).length;
            return '$n';
          },
          trend: '-5%',
          trendUp: false,
          desc: 'Requires manual review for dictionary addition.',
          colorScheme: colorScheme,
          accent: colorScheme.tertiary,
        ),
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: kpis.map((w) => w is Expanded ? w.child : w).toList(),
      );
    }
    return Row(children: kpis);
  }

  Widget _buildOcrPanel(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent OCR Corrections',
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live feed of receipt text mapped to standardized vendors.',
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_list),
                  color: colorScheme.primary,
                  style: IconButton.styleFrom(
                    hoverColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collectionGroup('ocr_logs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: 'Could not load OCR logs.',
                    detail: snapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = [...?snapshot.data?.docs];
                docs.sort((a, b) {
                  final ad = _parseLogDate(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bd = _parseLogDate(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bd.compareTo(ad);
                });

                final filtered = docs.where((doc) {
                  if (_ocrSearch.isEmpty) return true;
                  final raw = (doc.data()['rawText'] ?? '').toString().toLowerCase();
                  return raw.contains(_ocrSearch);
                }).take(40).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No OCR corrections found.'));
                }

                return Scrollbar(
                  controller: _vController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _vController,
                    scrollDirection: Axis.vertical,
                    child: Scrollbar(
                      controller: _hController,
                      thumbVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 1,
                      child: SingleChildScrollView(
                        controller: _hController,
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: 600),
                          child: DataTable(
                        headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerLow),
                        dataRowMaxHeight: 64,
                        dataRowMinHeight: 64,
                        columnSpacing: 24,
                        horizontalMargin: 24,
                        dividerThickness: 1,
                        columns: [
                          DataColumn(label: Text('RAW OCR TEXT', style: _headerStyle(colorScheme))),
                          DataColumn(label: Text('STANDARD VENDOR', style: _headerStyle(colorScheme))),
                          DataColumn(label: Text('CONFIDENCE', style: _headerStyle(colorScheme))),
                          DataColumn(label: Text('ACTION', style: _headerStyle(colorScheme))),
                        ],
                        rows: filtered.map((doc) {
                          final data = doc.data();
                          final raw = _snippet((data['rawText'] ?? '').toString(), maxLen: 30);
                          final confidenceLabel = data['confidenceLabel'] ?? '—';
                          
                          double confPercent = 0.95; // Default high
                          if (confidenceLabel == 'Low Confidence') confPercent = 0.42;
                          else if (confidenceLabel == 'Medium Confidence') confPercent = 0.75;
                          
                          Color confColor = colorScheme.primary;
                          if (confPercent < 0.5) confColor = colorScheme.error;
                          else if (confPercent < 0.8) confColor = colorScheme.secondary;

                          // Extract a potential mapped vendor or fallback
                          final vendorName = 'Standard Vendor'; 
                          final firstLetter = vendorName.substring(0, 1).toUpperCase();

                          return DataRow(
                            cells: [
                              DataCell(Text(raw, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: colorScheme.error))),
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: colorScheme.outline),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(firstLetter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(vendorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: confPercent,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: confColor,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${(confPercent * 100).toInt()}%', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              ),
                              DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: const Icon(Icons.edit, size: 16),
                                    color: colorScheme.onSurfaceVariant,
                                    onPressed: () => _promoteOcrLog(doc),
                                    tooltip: 'Edit / Map',
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: TextButton(
                onPressed: () => _showAllCorrectionsDialog(context, colorScheme),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, letterSpacing: 0.05),
                ),
                child: const Text('View All Corrections'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAllCorrectionsDialog(BuildContext context, ColorScheme cs) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: cs.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 800,
            height: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('All Recent OCR Corrections', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 24, fontWeight: FontWeight.bold, color: cs.onSurface)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collectionGroup('ocr_logs').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading corrections.', style: TextStyle(color: cs.error)));
                      }
                      var docs = [...?snapshot.data?.docs];
                      docs.sort((a, b) {
                        final ad = _parseLogDate(a.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bd = _parseLogDate(b.data()) ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return bd.compareTo(ad);
                      });
                      if (docs.isEmpty) {
                        return const Center(child: Text('No OCR corrections found.'));
                      }
                      
                      return Scrollbar(
                        controller: _dialogVController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _dialogVController,
                          scrollDirection: Axis.vertical,
                          child: Scrollbar(
                            controller: _dialogHController,
                            thumbVisibility: true,
                            notificationPredicate: (notif) => notif.depth == 1,
                            child: SingleChildScrollView(
                              controller: _dialogHController,
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 700),
                                child: DataTable(
                              headingRowColor: WidgetStateProperty.all(cs.surfaceContainerLow),
                              dataRowMaxHeight: 64,
                              dataRowMinHeight: 64,
                              columnSpacing: 24,
                              horizontalMargin: 24,
                              dividerThickness: 1,
                              columns: [
                                DataColumn(label: Text('RAW OCR TEXT', style: _headerStyle(cs))),
                                DataColumn(label: Text('STANDARD VENDOR', style: _headerStyle(cs))),
                                DataColumn(label: Text('CONFIDENCE', style: _headerStyle(cs))),
                                DataColumn(label: Text('ACTION', style: _headerStyle(cs))),
                              ],
                              rows: docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final raw = _snippet((data['rawText'] ?? '').toString(), maxLen: 30);
                                final confidenceLabel = data['confidenceLabel'] ?? '—';
                                
                                double confPercent = 0.95; 
                                if (confidenceLabel == 'Low Confidence') confPercent = 0.42;
                                else if (confidenceLabel == 'Medium Confidence') confPercent = 0.75;
                                
                                Color confColor = cs.primary;
                                if (confPercent < 0.5) confColor = cs.error;
                                else if (confPercent < 0.8) confColor = cs.secondary;

                                final vendorName = 'Standard Vendor'; 
                                final firstLetter = vendorName.substring(0, 1).toUpperCase();

                                return DataRow(
                                  cells: [
                                    DataCell(Text(raw, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: cs.error))),
                                    DataCell(
                                      Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: cs.outline),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(firstLetter, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(vendorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          Container(
                                            width: 64,
                                            height: 6,
                                            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: confPercent,
                                              child: Container(decoration: BoxDecoration(color: confColor, borderRadius: BorderRadius.circular(4))),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('${(confPercent * 100).toInt()}%', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          icon: const Icon(Icons.edit, size: 16),
                                          color: cs.onSurfaceVariant,
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _promoteOcrLog(doc);
                                          },
                                          tooltip: 'Edit / Map',
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                    }
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  TextStyle _headerStyle(ColorScheme cs) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.05,
      color: cs.onSurfaceVariant,
    );
  }

  Widget _buildDictionaryPanel(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Seed Dictionary',
                  style: TextStyle(
                    fontFamily: 'Hanken Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search dictionary...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainer,
                  ),
                  onChanged: (v) => setState(() => _dictSearch = v.toLowerCase()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('ocr_learning').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: 'Could not load dictionary.',
                    detail: snapshot.error.toString(),
                    onRetry: () => setState(() {}),
                  );
                }

                final docs = [...?snapshot.data?.docs];
                docs.sort((a, b) {
                  final av = (a.data()['vendorName'] ?? '').toString();
                  final bv = (b.data()['vendorName'] ?? '').toString();
                  return av.compareTo(bv);
                });
                
                final filtered = docs.where((doc) {
                  if (_dictSearch.isEmpty) return true;
                  final data = doc.data();
                  final vendor = (data['vendorName'] ?? '').toString().toLowerCase();
                  final aliases = List<String>.from(data['aliases'] ?? []);
                  if (vendor.contains(_dictSearch)) return true;
                  return aliases.any((a) => a.toLowerCase().contains(_dictSearch));
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No entries found.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final vendor = data['vendorName'] ?? '';
                    final category = data['category'] ?? 'General';
                    final aliases = List<String>.from(data['aliases'] ?? []);
                    final aliasesStr = aliases.take(3).join(', ') + (aliases.length > 3 ? '...' : '');

                    return InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    vendor,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${aliases.length} Aliases',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              aliasesStr.isEmpty ? 'No aliases mapped yet.' : aliasesStr,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Category: $category', style: TextStyle(fontSize: 12, color: colorScheme.primary)),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_square, size: 16),
                                      color: colorScheme.onSurfaceVariant,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _editMapping(doc.id, data),
                                    ),
                                    const SizedBox(width: 12),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 16, color: colorScheme.error),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                      onPressed: () => _confirmDelete(doc.id, vendor),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.colorScheme,
    required this.title,
    required this.icon,
    required this.child,
    this.headerAction,
  });

  final ColorScheme colorScheme;
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobilePanel = constraints.maxWidth < 500;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: isMobilePanel
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          if (headerAction != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: headerAction,
                            ),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          Icon(icon, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          ),
                          if (headerAction != null) ...[
                            const SizedBox(width: 12),
                            SizedBox(width: 200, child: headerAction),
                          ],
                        ],
                      ),
              ),
              Divider(height: 1, color: colorScheme.outlineVariant),
              Expanded(child: child),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.icon,
    required this.stream,
    required this.value,
    required this.trend,
    required this.trendUp,
    required this.desc,
    required this.colorScheme,
    this.accent,
  });

  final String label;
  final IconData icon;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String Function(QuerySnapshot<Map<String, dynamic>>) value;
  final String trend;
  final bool trendUp;
  final String desc;
  final ColorScheme colorScheme;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -10,
            right: -10,
            child: Opacity(
              opacity: 0.1,
              child: Icon(icon, size: 80, color: accent ?? colorScheme.primary),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.05,
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (context, snapshot) {
                  final display = snapshot.hasData
                      ? value(snapshot.data!)
                      : snapshot.hasError
                          ? '—'
                          : '…';
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        display,
                        style: TextStyle(
                          fontFamily: 'Hanken Grotesk',
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Icon(
                            trendUp ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: accent ?? colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            trend,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent ?? colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.detail,
    required this.onRetry,
  });

  final String message;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
