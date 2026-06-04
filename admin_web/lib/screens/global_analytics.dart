import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:web/web.dart' as web;

import '../widgets/modern_bottom_toast.dart';

class GlobalAnalyticsScreen extends ConsumerStatefulWidget {
  const GlobalAnalyticsScreen({super.key});

  @override
  ConsumerState<GlobalAnalyticsScreen> createState() =>
      _GlobalAnalyticsScreenState();
}

class _GlobalAnalyticsScreenState
    extends ConsumerState<GlobalAnalyticsScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _broadcastController = TextEditingController();
  bool _isExporting = false;
  bool _isBroadcasting = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  // ── CSV export ────────────────────────────────────────────────────────────
  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final snapshot =
          await _firestore.collectionGroup('expenses').get();

      // Build CSV manually — no external package needed
      final rows = <String>['Date,Category,Platform'];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['date'] ?? 'Unknown').toString().replaceAll(',', ' ');
        final cat  = (data['category'] ?? 'General').toString().replaceAll(',', ' ');
        rows.add('$date,$cat,ExpenseSplit Pro');
      }
      final csvString = rows.join('\n');
      final bytes = Uri.encodeComponent(csvString);

      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = 'data:text/csv;charset=utf-8,$bytes';
      anchor.download = 'fyp_anonymized_research_data.csv';
      anchor.click();

      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Research Data Exported Successfully!',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Export Failed: $e',
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ── Broadcast push ────────────────────────────────────────────────────────
  Future<void> _pushBroadcast() async {
    final msg = _broadcastController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isBroadcasting = true);
    try {
      await _firestore.collection('system_broadcasts').add({
        'message': msg,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      _broadcastController.clear();

      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Broadcast queued for delivery.',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        ModernBottomToast.show(
          context,
          message: 'Failed to queue broadcast: $errorMessage',
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 1100;
        final bool isMobile = constraints.maxWidth < 600;
        final double contentMaxWidth =
            constraints.maxWidth > 1600 ? 1600 : double.infinity;
        final EdgeInsets contentPadding = EdgeInsets.symmetric(
          horizontal: isMobile
              ? 16
              : (constraints.maxWidth > 1440 ? 40 : 32),
          vertical: isMobile ? 16 : 32,
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Padding(
              padding: contentPadding,
              child: ListView(
                children: [
                  // ── Page header (Banner) ─────────────────────────
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 192),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.outlineVariant),
                      image: const DecorationImage(
                        image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuB-g0GXcIXDK0Pe2VB2CHkb1aUMUriNNcsPCYJjPXFizXMHEoSg5xm5uhP54rjBI7hDsVxt_d_TSM2_pejL6f3Z8M_bqZ2yS1rHTec-KHZowBaQQyH7ZpqfOim_56H-Gd2f0vD0gNd2T7j0ijlBOGZRk2TXgLmepKQhzOCUw0u37tL5aLMfRAUi9B-JssAZFHEeaBD2NbaRkWzf-thml_vsTEQJz9cACGIAgXxvhIv809JN7ctbEWJe_2VKN1eyUYa0WOZMqiPf-z0'),
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [colorScheme.surface.withOpacity(0.8), Colors.transparent],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                      padding: const EdgeInsets.all(32.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Platform Command Center',
                                style: TextStyle(
                                  fontFamily: 'Hanken Grotesk',
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                  letterSpacing: -0.02,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Global Analytics, Spending Trends & governance controls.',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Live Broadcast card ──────────────────────────────
                  _buildBroadcastCard(colorScheme, isMobile),
                  const SizedBox(height: 24),

                  // ── Top KPI stat cards ───────────────────────────────
                  if (isNarrow)
                    Column(
                      children: [
                        _buildSimpleStatCard(
                          colorScheme: colorScheme,
                          title: 'Total Users',
                          icon: Icons.people,
                          stream:
                              _firestore.collection('users').snapshots(),
                          formatter: (snap) =>
                              snap.docs.length.toString(),
                        ),
                        const SizedBox(height: 16),
                        _buildSimpleStatCard(
                          colorScheme: colorScheme,
                          title: 'Expenses Tracked',
                          icon: Icons.receipt_long,
                          stream: _firestore
                              .collectionGroup('expenses')
                              .snapshots(),
                          formatter: (snap) =>
                              snap.docs.length.toString(),
                        ),
                        const SizedBox(height: 16),
                        _buildSimpleStatCard(
                          colorScheme: colorScheme,
                          title: 'OCR Scanner Accuracy',
                          icon: Icons.psychology,
                          stream: _firestore
                              .collectionGroup('ocr_logs')
                              .snapshots(),
                          formatter: _calcAccuracy,
                        ),
                      ],
                    )
                  else
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildSimpleStatCard(
                              colorScheme: colorScheme,
                              title: 'Total Users',
                              icon: Icons.people,
                              stream: _firestore
                                  .collection('users')
                                  .snapshots(),
                              formatter: (snap) =>
                                  snap.docs.length.toString(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildSimpleStatCard(
                              colorScheme: colorScheme,
                              title: 'Expenses Tracked',
                              icon: Icons.receipt_long,
                              stream: _firestore
                                  .collectionGroup('expenses')
                                  .snapshots(),
                              formatter: (snap) =>
                                  snap.docs.length.toString(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildSimpleStatCard(
                              colorScheme: colorScheme,
                              title: 'OCR Scanner Accuracy',
                              icon: Icons.psychology,
                              stream: _firestore
                                  .collectionGroup('ocr_logs')
                                  .snapshots(),
                              formatter: _calcAccuracy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 32),

                  // ── Charts row (single shared stream) ───────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collectionGroup('expenses').snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Failed to load charts: ${snap.error}',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        );
                      }
                      final docs = snap.data?.docs ?? [];
                      final loading = !snap.hasData;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildChartCard(
                              colorScheme: colorScheme,
                              title: 'Platform Activity Trend (Last 7 Days)',
                              height: 300,
                              child: loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : RepaintBoundary(child: _buildLineChart(docs)),
                            ),
                            const SizedBox(height: 16),
                            _buildChartCard(
                              colorScheme: colorScheme,
                              title: 'Most Popular Categories',
                              height: 300,
                              child: loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : RepaintBoundary(child: _buildPieChart(docs)),
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _buildChartCard(
                              colorScheme: colorScheme,
                              title: 'Platform Activity Trend (Last 7 Days)',
                              height: 380,
                              child: loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : RepaintBoundary(child: _buildLineChart(docs)),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 5,
                            child: _buildChartCard(
                              colorScheme: colorScheme,
                              title: 'Most Popular Categories',
                              height: 380,
                              child: loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : RepaintBoundary(child: _buildPieChart(docs)),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Recent governance + CSV export (responsive) ──────
                  if (isMobile) ..._buildBottomCardsMobile(colorScheme)
                  else _buildBottomCardsDesktop(colorScheme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Responsive bottom cards ───────────────────────────────────────────────
  List<Widget> _buildBottomCardsMobile(ColorScheme cs) {
    return [
      _buildGovernanceCard(cs),
      const SizedBox(height: 16),
      _buildCsvCard(cs),
    ];
  }

  Widget _buildBottomCardsDesktop(ColorScheme cs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: _buildGovernanceCard(cs)),
        const SizedBox(width: 24),
        Expanded(flex: 5, child: _buildCsvCard(cs)),
      ],
    );
  }

  Widget _buildGovernanceCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recent Governance Actions',
                  style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('system_config')
                .doc('audit_logs')
                .collection('entries')
                .orderBy('timestamp', descending: true)
                .limit(3)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Failed to load governance events: ${snapshot.error}',
                    style: TextStyle(color: cs.error),
                  ),
                );
              }
              final logs = snapshot.data?.docs ?? [];
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No governance events recorded yet.',
                      style: TextStyle(color: cs.onSurfaceVariant)),
                );
              }
              return Column(
                children: logs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final action = data['action'] ?? 'EVENT';
                  final detail = data['detail'] ?? '';
                  final email = data['adminEmail'] ?? 'Admin';
                  String timeStr = 'Just now';
                  if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
                    timeStr = DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate());
                  }
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(action,
                                  style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(detail, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCsvCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.download, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'FYP Research Data Export',
                  style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Download a privacy-aggregated CSV of platform activity for data analysis.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportData,
              icon: _isExporting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.table_chart, size: 18),
              label: const Text('Export Anonymized CSV', overflow: TextOverflow.ellipsis),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastCard(ColorScheme cs, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              const Text('Live System Broadcast', style: TextStyle(fontFamily: 'Hanken Grotesk', fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Push an instant real-time banner to all mobile app users globally.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (isMobile) ...[  
            TextField(
              controller: _broadcastController,
              decoration: InputDecoration(
                hintText: 'e.g., Welcome to ExpenseSplit Pro v1.0!',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: FilledButton.icon(
                  onPressed: _isBroadcasting ? null : _pushBroadcast,
                  icon: _isBroadcasting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.podcasts, size: 18),
                  label: const Text('📢 [Live Broadcast] Push Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ] else ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _broadcastController,
                    decoration: InputDecoration(
                      hintText: 'e.g., Welcome to ExpenseSplit Pro v1.0!',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: _isBroadcasting ? null : _pushBroadcast,
                      icon: _isBroadcasting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.podcasts, size: 18),
                      label: const Text('📢 [Live Broadcast] Push Live', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Accuracy formatter ────────────────────────────────────────────────────
  String _calcAccuracy(QuerySnapshot snap) {
    if (snap.docs.isEmpty) return 'N/A';
    final matches = snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final sys =
          (data['systemSuggestedAmount'] as num?)?.toDouble() ?? 0.0;
      final usr =
          (data['userCorrectedAmount'] as num?)?.toDouble() ?? 0.0;
      return sys == usr;
    }).length;
    return '${((matches / snap.docs.length) * 100).toStringAsFixed(1)}%';
  }

  // ── Simple stat card ──────────────────────────────────────────────────────
  Widget _buildSimpleStatCard({
    required ColorScheme colorScheme,
    required String title,
    required IconData icon,
    required Stream<QuerySnapshot> stream,
    required String Function(QuerySnapshot) formatter,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  'Error',
                  style: TextStyle(color: colorScheme.error),
                );
              }
              if (!snapshot.hasData) {
                return const Text('—');
              }
              return Text(
                formatter(snapshot.data!),
                style: TextStyle(
                  fontFamily: 'Hanken Grotesk',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Chart container card ──────────────────────────────────────────────────
  Widget _buildChartCard({
    required ColorScheme colorScheme,
    required String title,
    required double height,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
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
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Tooltip(
                message:
                    'Privacy First: We track activity counts, not user money.',
                child: Icon(
                  Icons.privacy_tip,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    );
  }

  // ── Line chart ────────────────────────────────────────────────────────────
  Widget _buildLineChart(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final Map<int, double> dailyTotals = {
      for (int i = 0; i < 7; i++) i: 0.0
    };
    double maxY = 0;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      final diff = now.difference(date).inDays;
      if (diff >= 0 && diff < 7) {
        final idx = 6 - diff;
        dailyTotals[idx] = dailyTotals[idx]! + 1.0;
        if (dailyTotals[idx]! > maxY) maxY = dailyTotals[idx]!;
      }
    }

    final spots = dailyTotals.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    final chartMaxY = maxY > 5 ? maxY : 5.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final daysAgo = 6 - value.toInt();
                final d = now.subtract(Duration(days: daysAgo));
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    DateFormat('E').format(d),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                if (value == 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: chartMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            preventCurveOverShooting: true,
            color: const Color(0xFF0F766E),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutQuart,
    );
  }

  // ── Pie chart ─────────────────────────────────────────────────────────────
  Widget _buildPieChart(List<QueryDocumentSnapshot> docs) {
    final Map<String, double> categoryTotals = {};
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cat = (data['category'] as String?) ?? 'General';
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + 1.0;
    }

    if (categoryTotals.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    const colors = [
      Color(0xFF0F766E),
      Color(0xFFF59E0B),
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF8B5CF6),
      Color(0xFF10B981),
    ];

    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];
    int colorIndex = 0;

    categoryTotals.forEach((cat, total) {
      final color = colors[colorIndex % colors.length];
      sections.add(
        PieChartSectionData(
          color: color,
          value: total,
          title: '',
          radius: 45,
        ),
      );
      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cat,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                '${total.toInt()} logs',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      colorIndex++;
    });

    return Row(
      children: [
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 35,
                sections: sections,
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOutQuart,
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: legendItems,
            ),
          ),
        ),
      ],
    );
  }
}
