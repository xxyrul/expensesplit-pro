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
      builder: (ctx) => StatefulBuilder(
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                if (ctx.mounted) Navigator.pop(ctx);
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
      builder: (ctx) => AlertDialog(
        title: const Text('Remove dictionary entry?'),
        content: Text('Delete "$vendor" from the global seed list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
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
        final isMobile = constraints.maxWidth < 600;
        final isNarrow = constraints.maxWidth < 900;

        return Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vendor Intelligence Hub',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Curate the global vendor dictionary from real OCR corrections — improves categorization for every user.',
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildKpiRow(colorScheme, isMobile),
              const SizedBox(height: 24),
              Expanded(
                child: isNarrow
                    ? Column(
                        children: [
                          Expanded(child: _buildOcrPanel(colorScheme)),
                          const SizedBox(height: 16),
                          Expanded(child: _buildDictionaryPanel(colorScheme)),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildOcrPanel(colorScheme)),
                          const SizedBox(width: 24),
                          Expanded(child: _buildDictionaryPanel(colorScheme)),
                        ],
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
      Expanded(child: _KpiCard(
        label: 'Dictionary entries',
        stream: _firestore.collection('ocr_learning').snapshots(),
        value: (snap) => '${snap.docs.length}',
        colorScheme: colorScheme,
      )),
      SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 16 : 0),
      Expanded(child: _KpiCard(
        label: 'OCR corrections logged',
        stream: _firestore.collectionGroup('ocr_logs').snapshots(),
        value: (snap) => '${snap.docs.length}',
        colorScheme: colorScheme,
      )),
      SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 16 : 0),
      Expanded(child: _KpiCard(
        label: 'Low-confidence (pending)',
        stream: _firestore.collectionGroup('ocr_logs').snapshots(),
        value: (snap) {
          final n = snap.docs.where((d) {
            final data = d.data();
            return data['confidenceLabel'] == 'Low Confidence' &&
                (data['adminStatus'] ?? 'Pending') == 'Pending';
          }).length;
          return '$n';
        },
        colorScheme: colorScheme,
        accent: colorScheme.tertiary,
      )),
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
    return _Panel(
      colorScheme: colorScheme,
      title: 'Recent OCR corrections',
      icon: Icons.document_scanner_outlined,
      headerAction: TextField(
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search receipt text…',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onChanged: (v) => setState(() => _ocrSearch = v.toLowerCase()),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collectionGroup('ocr_logs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Could not load OCR logs. Ensure Firestore indexes exist.',
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
            return const Center(child: Text('No OCR corrections match your search.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => Divider(color: colorScheme.outlineVariant, height: 1),
            itemBuilder: (context, index) {
              final doc = filtered[index];
              final data = doc.data();
              final raw = (data['rawText'] ?? '').toString();
              final confidence = data['confidenceLabel'] ?? '—';
              final sys = (data['systemSuggestedAmount'] as num?)?.toDouble() ?? 0;
              final user = (data['userCorrectedAmount'] as num?)?.toDouble() ?? 0;
              final status = data['adminStatus'] ?? 'Pending';
              final date = _parseLogDate(data);

              return ListTile(
                title: Text(_snippet(raw), maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${confidence} · RM ${sys.toStringAsFixed(2)} → ${user.toStringAsFixed(2)} · $status'
                  '${date != null ? '\n${DateFormat('yyyy-MM-dd HH:mm').format(date)}' : ''}',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
                trailing: IconButton.filledTonal(
                  onPressed: () => _promoteOcrLog(doc),
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  tooltip: 'Add to dictionary',
                ),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('OCR raw text'),
                      content: SingleChildScrollView(child: Text(raw)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _promoteOcrLog(doc);
                          },
                          child: const Text('Add to dictionary'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDictionaryPanel(ColorScheme colorScheme) {
    return _Panel(
      colorScheme: colorScheme,
      title: 'Global seed dictionary',
      icon: Icons.menu_book_outlined,
      headerAction: FilledButton.icon(
        onPressed: _openAddWordDialog,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add vendor'),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search vendor or alias…',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _dictSearch = v.toLowerCase()),
            ),
          ),
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.library_add_outlined, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 12),
                        const Text('No dictionary entries yet.'),
                        const SizedBox(height: 8),
                        FilledButton(onPressed: _openAddWordDialog, child: const Text('Add first vendor')),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data();
                    final vendor = data['vendorName'] ?? '';
                    final category = data['category'] ?? 'General';
                    final aliases = List<String>.from(data['aliases'] ?? []);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    vendor,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                Chip(
                                  label: Text(category, style: const TextStyle(fontSize: 11)),
                                  visualDensity: VisualDensity.compact,
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (action) {
                                    if (action == 'edit') _editMapping(doc.id, data);
                                    if (action == 'delete') _confirmDelete(doc.id, vendor);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit / add alias')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete entry')),
                                  ],
                                ),
                              ],
                            ),
                            if (aliases.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: aliases.map((alias) {
                                  return InputChip(
                                    label: Text(alias, style: const TextStyle(fontSize: 11)),
                                    onDeleted: () => ref
                                        .read(_dictionaryServiceProvider)
                                        .removeAlias(doc.id, alias),
                                  );
                                }).toList(),
                              ),
                            ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                if (headerAction != null) SizedBox(width: 200, child: headerAction),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.stream,
    required this.value,
    required this.colorScheme,
    this.accent,
  });

  final String label;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final String Function(QuerySnapshot<Map<String, dynamic>>) value;
  final ColorScheme colorScheme;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final display = snapshot.hasData
              ? value(snapshot.data!)
              : snapshot.hasError
                  ? '—'
                  : '…';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                display,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: accent ?? colorScheme.onSurface,
                ),
              ),
            ],
          );
        },
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
