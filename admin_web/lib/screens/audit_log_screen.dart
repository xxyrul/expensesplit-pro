import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  // ── State variables ──────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedActionFilter = 'All';

  // ── Filter logic ─────────────────────────────────────────────────────────
  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> docs) {
    if (_selectedActionFilter == 'All') return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final action = data['action'] ?? '';
      return action == _selectedActionFilter;
    }).toList();
  }

  // ── Action colour mapping ─────────────────────────────────────────────────
  Color _getActionColor(String action) {
    switch (action) {
      case 'DELETE_EXPENSE':
      case 'DEACTIVATE_USER':
        return Colors.red;
      case 'EDIT_EXPENSE':
      case 'CHANGE_USER_ROLE':
        return Colors.orange;
      case 'EXPORT_EXPENSES':
      case 'LEARN_OCR_MAPPING':
        return Colors.blue;
      case 'OCR_REVIEW':
      case 'ACTIVATE_USER':
      case 'OCR_RESOLVE_ANOMALY':
        return Colors.green;
      case 'UPDATE_PRIVACY_POLICY':
        return Colors.purple;
      case 'SUSPEND_USER_ANOMALY':
      case 'DELETE_VENDOR_MAPPING':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            return Padding(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Page header (Banner) ─────────────────────────
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 192),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                          image: const DecorationImage(
                            image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuB-g0GXcIXDK0Pe2VB2CHkb1aUMUriNNcsPCYJjPXFizXMHEoSg5xm5uhP54rjBI7hDsVxt_d_TSM2_pejL6f3Z8M_bqZ2yS1rHTec-KHZowBaQQyH7ZpqfOim_56H-Gd2f0vD0gNd2T7j0ijlBOGZRk2TXgLmepKQhzOCUw0u37tL5aLMfRAUi9B-JssAZFHEeaBD2NbaRkWzf-thml_vsTEQJz9cACGIAgXxvhIv809JN7ctbEWJe_2VKN1eyUYa0WOZMqiPf-z0'),
                            fit: BoxFit.cover,
                            opacity: 0.3,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [colorScheme.surface.withOpacity(0.8), Colors.transparent],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                          padding: const EdgeInsets.all(24.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'System Activity Monitoring',
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
                                    'Immutably logged actions for system accountability, access controls, and policy compliance verification.',
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
                      const SizedBox(height: 40),

                      // ── Filter bar ──────────────────────────────────
                      _buildFilterBar(colorScheme),
                      const SizedBox(height: 24),

                      // ── Data table ──────────────────────────────────
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: _firestore
                              .collection('system_config')
                              .doc('audit_logs')
                              .collection('entries')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  'Error loading audit log: ${snapshot.error}',
                                ),
                              );
                            }

                            final allLogs = snapshot.data?.docs ?? [];
                            final filteredLogs = _applyFilters(allLogs);

                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Table header bar
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHigh,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Activity Log',
                                          style: TextStyle(
                                            fontFamily: 'Hanken Grotesk',
                                            fontSize: 20,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Showing ${filteredLogs.length} entries',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 14,
                                                color: colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.chevron_left, size: 20),
                                                  onPressed: () {},
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.chevron_right, size: 20),
                                                  onPressed: () {},
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Table body
                                  Expanded(
                                    child: filteredLogs.isEmpty
                                        ? const Center(
                                            child: Text(
                                              'No security events logged '
                                              'under current filter.',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          )
                                        : isMobile
                                        ? ListView.separated(
                                            padding: const EdgeInsets.all(14),
                                            itemCount: filteredLogs.length,
                                            separatorBuilder: (_, _) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (ctx, i) {
                                              final data =
                                                  filteredLogs[i].data()
                                                      as Map<String, dynamic>;
                                              final adminEmail =
                                                  data['adminEmail'] ??
                                                  'Unknown Admin';
                                              final action =
                                                  data['action'] ??
                                                  'Unknown Action';
                                              final targetType =
                                                  data['targetType'] ??
                                                  'System';
                                              final targetId =
                                                  data['targetId'] ?? '';
                                              final detail =
                                                  data['detail'] ?? '';
                                              final actionColor =
                                                  _getActionColor(action);

                                              String timestampStr = 'N/A';
                                              if (data['timestamp'] != null &&
                                                  data['timestamp']
                                                      is Timestamp) {
                                                final date =
                                                    (data['timestamp']
                                                            as Timestamp)
                                                        .toDate();
                                                timestampStr = DateFormat(
                                                  'yyyy-MM-dd HH:mm:ss',
                                                ).format(date);
                                              }

                                              return Container(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .surfaceContainerHighest
                                                      .withOpacity(0.35),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: colorScheme
                                                        .outlineVariant,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      timestampStr,
                                                      style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: 12,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Chip(
                                                          label: Text(
                                                            action,
                                                            style: TextStyle(
                                                              color:
                                                                  actionColor,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                          backgroundColor:
                                                              actionColor
                                                                  .withOpacity(
                                                                    0.12,
                                                                  ),
                                                          side: BorderSide(
                                                            color: actionColor
                                                                .withOpacity(
                                                                  0.28,
                                                                ),
                                                          ),
                                                        ),
                                                        Text(
                                                          adminEmail,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      '$targetType ($targetId)',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      detail,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          )
                                        : LayoutBuilder(
                                            builder: (ctx, tableConstraints) {
                                              final tableWidth =
                                                  tableConstraints.maxWidth >
                                                      1280
                                                  ? tableConstraints.maxWidth
                                                  : 1280.0;
                                              final detailsColWidth =
                                                  tableWidth - 750.0;

                                              return Scrollbar(
                                                child: SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: SizedBox(
                                                    width: tableWidth,
                                                    child: DataTable(
                                                      columnSpacing: 24,
                                                      horizontalMargin: 20,
                                                      headingRowColor: WidgetStateProperty.all(
                                                        colorScheme.surfaceContainerLowest,
                                                      ),
                                                      dividerThickness: 1,
                                                      dataRowMinHeight: 72,
                                                      dataRowMaxHeight: 72,
                                                      columns: [
                                                        DataColumn(label: Text('TIMESTAMP', style: _headerStyle(colorScheme))),
                                                        DataColumn(label: Text('OPERATOR', style: _headerStyle(colorScheme))),
                                                        DataColumn(label: Text('EVENT ACTION', style: _headerStyle(colorScheme))),
                                                        DataColumn(label: Text('TARGET INFO', style: _headerStyle(colorScheme))),
                                                        DataColumn(label: Text('EVENT DETAILS', style: _headerStyle(colorScheme))),
                                                      ],
                                                      rows: filteredLogs.map((doc) {
                                                        final data = doc.data() as Map<String, dynamic>;
                                                        final adminEmail = data['adminEmail'] ?? 'Unknown Admin';
                                                        final action = data['action'] ?? 'Unknown Action';
                                                        final targetType = data['targetType'] ?? 'System';
                                                        final targetId = data['targetId'] ?? '';
                                                        final detail = data['detail'] ?? '';

                                                        DateTime? date;
                                                        if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
                                                          date = (data['timestamp'] as Timestamp).toDate();
                                                        }
                                                        
                                                        final dateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : 'N/A';
                                                        final timeStr = date != null ? '${DateFormat('HH:mm:ss').format(date)} UTC' : '';

                                                        final actionColor = _getActionColor(action);

                                                        return DataRow(
                                                          color: WidgetStateProperty.resolveWith<Color?>((states) {
                                                            if (states.contains(WidgetState.hovered)) {
                                                              return colorScheme.surfaceContainerHighest.withOpacity(0.5);
                                                            }
                                                            if (actionColor == Colors.red || actionColor == Colors.redAccent) {
                                                              return colorScheme.error.withOpacity(0.05);
                                                            }
                                                            if (actionColor == Colors.orange) {
                                                              return colorScheme.secondary.withOpacity(0.05);
                                                            }
                                                            return null;
                                                          }),
                                                          cells: [
                                                            DataCell(
                                                              Column(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(dateStr, style: const TextStyle(fontFamily: 'Inter', fontSize: 14)),
                                                                  if (timeStr.isNotEmpty)
                                                                    Text(timeStr, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: colorScheme.onSurfaceVariant)),
                                                                ],
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width: 180,
                                                                child: Text(
                                                                  adminEmail,
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: colorScheme.onSurfaceVariant),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                                decoration: BoxDecoration(
                                                                  color: actionColor.withOpacity(0.2),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  action,
                                                                  style: TextStyle(
                                                                    color: actionColor,
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600,
                                                                    letterSpacing: 0.05,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width: 220,
                                                                child: Text(
                                                                  '$targetType ($targetId)',
                                                                  maxLines: 1,
                                                                  overflow: TextOverflow.ellipsis,
                                                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width: detailsColWidth,
                                                                child: Tooltip(
                                                                  message: detail,
                                                                  child: Text(
                                                                    detail,
                                                                    maxLines: 2,
                                                                    overflow: TextOverflow.ellipsis,
                                                                    style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
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
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────
  Widget _buildFilterBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_list, color: colorScheme.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Global Filters',
                    style: TextStyle(
                      fontFamily: 'Hanken Grotesk',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      setState(() => _selectedActionFilter = 'All');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onSurface,
                      side: BorderSide(color: colorScheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final colWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 48) / 4;
              
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildFilterDropdown(
                    label: 'Event Action',
                    width: colWidth,
                    value: _selectedActionFilter,
                    items: const [
                      'All',
                      'DELETE_EXPENSE',
                      'EDIT_EXPENSE',
                      'OCR_REVIEW',
                      'ACTIVATE_USER',
                      'DEACTIVATE_USER',
                      'CHANGE_USER_ROLE',
                      'EXPORT_EXPENSES',
                      'LEARN_OCR_MAPPING',
                      'UPDATE_PRIVACY_POLICY',
                      'OCR_RESOLVE_ANOMALY',
                      'SUSPEND_USER_ANOMALY',
                      'DELETE_VENDOR_MAPPING',
                    ],
                    onChanged: (val) => setState(() => _selectedActionFilter = val ?? 'All'),
                    colorScheme: colorScheme,
                  ),
                  _buildFilterDropdown(
                    label: 'Date Range',
                    width: colWidth,
                    value: 'Last 7 Days',
                    items: const ['Last 7 Days', 'Last 30 Days', 'This Month', 'Custom Range...'],
                    onChanged: (val) {},
                    colorScheme: colorScheme,
                  ),
                  _buildFilterDropdown(
                    label: 'Status',
                    width: colWidth,
                    value: 'All Statuses',
                    items: const ['All Statuses', 'Success', 'Failed', 'Warning'],
                    onChanged: (val) {},
                    colorScheme: colorScheme,
                  ),
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Search', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'User, ID...',
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withOpacity(0.5)),
                            prefixIcon: Icon(Icons.search, size: 20, color: colorScheme.onSurfaceVariant),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: colorScheme.outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: colorScheme.primary),
                            ),
                            filled: true,
                            fillColor: colorScheme.surface,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required double width,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: colorScheme.surfaceContainerHigh,
                icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurfaceVariant),
                style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: colorScheme.onSurface),
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(item == 'All' ? 'All Events' : item),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
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
}
