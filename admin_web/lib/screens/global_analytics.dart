import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../widgets/modern_bottom_toast.dart';

class GlobalAnalyticsScreen extends ConsumerStatefulWidget {
  const GlobalAnalyticsScreen({super.key});

  @override
  ConsumerState<GlobalAnalyticsScreen> createState() => _GlobalAnalyticsScreenState();
}

class _GlobalAnalyticsScreenState extends ConsumerState<GlobalAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _broadcastController = TextEditingController();
  bool _isExporting = false;
  bool _isBroadcasting = false;

  @override
  void dispose() {
    _broadcastController.dispose();
    super.dispose();
  }

  Future<void> _exportData() async {
    setState(() => _isExporting = true);
    try {
      final snapshot = await _firestore.collectionGroup('expenses').get();
      
      List<List<dynamic>> csvData = [
        ['Date', 'Category', 'Platform'], 
      ];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        csvData.add([
          data['date'] ?? 'Unknown',
          data['category'] ?? 'General',
          'ExpenseSplit Pro',
        ]);
      }

      String csvString = csv.encode(csvData);
      final bytes = Uri.encodeComponent(csvString);
      
      html.AnchorElement(href: "data:text/csv;charset=utf-8,$bytes")
        ..setAttribute("download", "fyp_anonymized_research_data.csv")
        ..click();

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

  Future<void> _pushBroadcast() async {
    final msg = _broadcastController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isBroadcasting = true);
    try {
      await _firestore.collection('system_config').doc('broadcast').set({
        'message': msg,
        'timestamp': FieldValue.serverTimestamp(),
        'active': true,
      });
      _broadcastController.clear();
      
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Broadcast Pushed Live to App!',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Broadcast Failed: $e',
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isBroadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isNarrow = constraints.maxWidth < 1100;
        final double contentMaxWidth = constraints.maxWidth > 1600 ? 1600 : double.infinity;
        final bool isMobile = constraints.maxWidth < 600;
        final EdgeInsets contentPadding = EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : (constraints.maxWidth > 1440 ? 40 : 32),
          vertical: isMobile ? 16 : 32,
        );

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Padding(
              padding: contentPadding,
              child: ListView(
                children: [
              Text(
                'Platform Command Center',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Global Analytics, Spending Trends & governance controls.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // TOP STATS
              if (isNarrow)
                Column(
                  children: [
                    _buildSimpleStatCard(
                      title: 'Total Users',
                      icon: Icons.people,
                      stream: _firestore.collection('users').snapshots(),
                      formatter: (snap) => snap.docs.length.toString(),
                    ),
                    const SizedBox(height: 16),
                    _buildSimpleStatCard(
                      title: 'Expenses Tracked',
                      icon: Icons.receipt_long,
                      stream: _firestore.collectionGroup('expenses').snapshots(),
                      formatter: (snap) => snap.docs.length.toString(),
                    ),
                    const SizedBox(height: 16),
                    _buildSimpleStatCard(
                      title: 'OCR Scanner Accuracy',
                      icon: Icons.psychology,
                      stream: _firestore.collectionGroup('ocr_logs').snapshots(),
                      formatter: (snap) {
                        if (snap.docs.isEmpty) return 'N/A';
                        final matches = snap.docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final sys = (data['systemSuggestedAmount'] as num?)?.toDouble() ?? 0.0;
                          final user = (data['userCorrectedAmount'] as num?)?.toDouble() ?? 0.0;
                          return sys == user;
                        }).length;
                        final percentage = (matches / snap.docs.length) * 100;
                        return '${percentage.toStringAsFixed(1)}%';
                      },
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
                          title: 'Total Users',
                          icon: Icons.people,
                          stream: _firestore.collection('users').snapshots(),
                          formatter: (snap) => snap.docs.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildSimpleStatCard(
                          title: 'Expenses Tracked',
                          icon: Icons.receipt_long,
                          stream: _firestore.collectionGroup('expenses').snapshots(),
                          formatter: (snap) => snap.docs.length.toString(),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildSimpleStatCard(
                          title: 'OCR Scanner Accuracy',
                          icon: Icons.psychology,
                          stream: _firestore.collectionGroup('ocr_logs').snapshots(),
                          formatter: (snap) {
                            if (snap.docs.isEmpty) return 'N/A';
                            final matches = snap.docs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final sys = (data['systemSuggestedAmount'] as num?)?.toDouble() ?? 0.0;
                              final user = (data['userCorrectedAmount'] as num?)?.toDouble() ?? 0.0;
                              return sys == user;
                            }).length;
                            final percentage = (matches / snap.docs.length) * 100;
                            return '${percentage.toStringAsFixed(1)}%';
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // CHARTS ROW / COLUMN
              if (isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 360,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Platform Activity Trend (Last 7 Days)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                              ),
                              const Tooltip(
                                message: 'Privacy First: We track activity counts, not user money.',
                                child: Icon(Icons.privacy_tip, color: Color(0xFF10B981), size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _firestore.collectionGroup('expenses').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                return _buildLineChart(snapshot.data!.docs);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      height: 360,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Most Popular Categories',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                              ),
                              const Tooltip(
                                message: 'Based on receipt counts, not spending volume.',
                                child: Icon(Icons.privacy_tip, color: Color(0xFF10B981), size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _firestore.collectionGroup('expenses').snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                return _buildPieChart(snapshot.data!.docs);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Container(
                        width: double.infinity,
                        height: 380,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Platform Activity Trend (Last 7 Days)',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const Tooltip(
                                  message: 'Privacy First: We track activity counts, not user money.',
                                  child: Icon(Icons.privacy_tip, color: Color(0xFF10B981), size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _firestore.collectionGroup('expenses').snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  return _buildLineChart(snapshot.data!.docs);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Container(
                        width: double.infinity,
                        height: 380,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Most Popular Categories',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                ),
                                const Tooltip(
                                  message: 'Based on receipt counts, not spending volume.',
                                  child: Icon(Icons.privacy_tip, color: Color(0xFF10B981), size: 20),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Expanded(
                              child: StreamBuilder<QuerySnapshot>(
                                stream: _firestore.collectionGroup('expenses').snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  return _buildPieChart(snapshot.data!.docs);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 32),

          // RECENT ACTIVITY & CONTROLS ROW
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Recent Activity Feed
                Expanded(
                  flex: 7,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, color: colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              "Recent Governance Actions",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        StreamBuilder<QuerySnapshot>(
                          stream: _firestore
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
                            final logs = snapshot.data?.docs ?? [];
                            if (logs.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20.0),
                                child: Text('No governance events recorded yet.', style: TextStyle(color: Colors.grey)),
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
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(action, style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          detail,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            email,
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            timeStr,
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                // CSV Export Feature
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.download, color: Color(0xFF3B82F6)),
                            const SizedBox(width: 8),
                            Text(
                              "FYP Research Data",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Download a strict-privacy aggregated CSV file of platform activity for data analysis.",
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            onPressed: _isExporting ? null : _exportData,
                            icon: _isExporting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.table_chart),
                            label: const Text("Export Anonymized CSV"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // Broadcast Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.campaign, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Text(
                      "Live System Broadcast",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Push an instant real-time banner notification to all mobile app users globally.",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _broadcastController,
                            decoration: InputDecoration(
                              hintText: "e.g., Welcome to ExpenseSplit Pro v1.0!",
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isBroadcasting ? null : _pushBroadcast,
                            icon: _isBroadcasting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                            label: const Text("Push Live"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
      },
    );
  }

  Widget _buildSimpleStatCard({
    required String title,
    required IconData icon,
    required Stream<QuerySnapshot> stream,
    required String Function(QuerySnapshot) formatter,
  }) {
    return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  return Text('Error', style: TextStyle(color: Theme.of(context).colorScheme.error));
                }
                if (!snapshot.hasData) {
                  return const Text('—');
                }
                return Text(
                  formatter(snapshot.data!),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              },
            ),
          ],
        ),
      );
  }

  Widget _buildLineChart(List<QueryDocumentSnapshot> docs) {
    // 1. Group data by day for the last 7 days
    final now = DateTime.now();
    final Map<int, double> dailyTotals = {};
    for (int i = 0; i < 7; i++) {
      dailyTotals[i] = 0.0;
    }

    double maxY = 0;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['date'] as String?;
      if (dateStr == null) continue;
      
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      final diff = now.difference(date).inDays;
      if (diff >= 0 && diff < 7) {
        // Reverse index so 0 is oldest, 6 is today
        final chartIndex = 6 - diff;
        // Privacy Pivot: Count +1 for activity, ignore amount!
        dailyTotals[chartIndex] = dailyTotals[chartIndex]! + 1.0;
        if (dailyTotals[chartIndex]! > maxY) {
          maxY = dailyTotals[chartIndex]!;
        }
      }
    }

    final spots = dailyTotals.entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();
    
    // Sort spots by X
    spots.sort((a, b) => a.x.compareTo(b.x));

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? (maxY / 4) : 1,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // value is 0 to 6
                final daysAgo = 6 - value.toInt();
                final d = now.subtract(Duration(days: daysAgo));
                return SideTitleWidget(
                  meta: meta,
                  child: Text(DateFormat('E').format(d), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY * 1.2, // add some headroom
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF0F766E),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0F766E).withOpacity(0.1),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutQuart,
    );
  }

  Widget _buildPieChart(List<QueryDocumentSnapshot> docs) {
    // Group by category
    final Map<String, double> categoryTotals = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cat = data['category'] as String? ?? 'General';
      // Privacy Pivot: Track COUNT of category usage, not financial volume
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + 1.0;
    }

    if (categoryTotals.isEmpty) {
      return const Center(child: Text("No data yet"));
    }

    final colors = [
      const Color(0xFF0F766E), // Teal
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF3B82F6), // Blue
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF10B981), // Emerald
    ];

    int colorIndex = 0;
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];

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
              Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(child: Text(cat, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface))),
              Text('${total.toInt()} logs', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
        ),
      );
      
      colorIndex++;
    });

    return Row(
      children: [
        Expanded(
          flex: 1,
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
          flex: 1,
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
