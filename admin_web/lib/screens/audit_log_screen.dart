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
                      // ── Page header ─────────────────────────────────
                      Flex(
                        direction: isMobile ? Axis.vertical : Axis.horizontal,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isMobile)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'System Security Audit Trail',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Immutably logged actions for system '
                                  'accountability, access controls, and '
                                  'policy compliance verification.',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            )
                          else
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'System Security Audit Trail',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Immutably logged actions for system '
                                    'accountability, access controls, and '
                                    'policy compliance verification.',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 16,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          SizedBox(
                            width: isMobile ? 0 : 16,
                            height: isMobile ? 12 : 0,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withOpacity(0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Append-only governance trail',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

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
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      14,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Administrative Entries: '
                                          '${filteredLogs.length}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'Showing newest first',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),

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
                                                      headingRowColor:
                                                          WidgetStateProperty.all(
                                                            colorScheme
                                                                .surfaceContainerHighest,
                                                          ),
                                                      columns: const [
                                                        DataColumn(
                                                          label: Text(
                                                            'Timestamp',
                                                          ),
                                                        ),
                                                        DataColumn(
                                                          label: Text(
                                                            'Operator',
                                                          ),
                                                        ),
                                                        DataColumn(
                                                          label: Text(
                                                            'Event Action',
                                                          ),
                                                        ),
                                                        DataColumn(
                                                          label: Text(
                                                            'Target Info',
                                                          ),
                                                        ),
                                                        DataColumn(
                                                          label: Text(
                                                            'Event Details',
                                                          ),
                                                        ),
                                                      ],
                                                      rows: filteredLogs.map((
                                                        doc,
                                                      ) {
                                                        final data =
                                                            doc.data()
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >;
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
                                                            data['targetId'] ??
                                                            '';
                                                        final detail =
                                                            data['detail'] ??
                                                            '';

                                                        String timestampStr =
                                                            'N/A';
                                                        if (data['timestamp'] !=
                                                                null &&
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

                                                        final actionColor =
                                                            _getActionColor(
                                                              action,
                                                            );

                                                        return DataRow(
                                                          cells: [
                                                            DataCell(
                                                              Text(
                                                                timestampStr,
                                                                style: const TextStyle(
                                                                  fontFamily:
                                                                      'monospace',
                                                                  fontSize: 13,
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width: 180,
                                                                child: Text(
                                                                  adminEmail,
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              Chip(
                                                                label: Text(
                                                                  action,
                                                                  style: TextStyle(
                                                                    color:
                                                                        actionColor,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                                backgroundColor:
                                                                    actionColor
                                                                        .withOpacity(
                                                                          0.1,
                                                                        ),
                                                                side: BorderSide(
                                                                  color: actionColor
                                                                      .withOpacity(
                                                                        0.2,
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
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      const TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                ),
                                                              ),
                                                            ),
                                                            DataCell(
                                                              SizedBox(
                                                                width:
                                                                    detailsColWidth,
                                                                child: Tooltip(
                                                                  message:
                                                                      detail,
                                                                  child: Text(
                                                                    detail,
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Icon(Icons.filter_list, color: colorScheme.primary),
          const Text(
            'Filter by Event Type:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorScheme.outlineVariant, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedActionFilter,
                dropdownColor: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: colorScheme.primary,
                ),
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Events')),
                  DropdownMenuItem(
                    value: 'DELETE_EXPENSE',
                    child: Text('DELETE_EXPENSE'),
                  ),
                  DropdownMenuItem(
                    value: 'EDIT_EXPENSE',
                    child: Text('EDIT_EXPENSE'),
                  ),
                  DropdownMenuItem(
                    value: 'OCR_REVIEW',
                    child: Text('OCR_REVIEW'),
                  ),
                  DropdownMenuItem(
                    value: 'ACTIVATE_USER',
                    child: Text('ACTIVATE_USER'),
                  ),
                  DropdownMenuItem(
                    value: 'DEACTIVATE_USER',
                    child: Text('DEACTIVATE_USER'),
                  ),
                  DropdownMenuItem(
                    value: 'CHANGE_USER_ROLE',
                    child: Text('CHANGE_USER_ROLE'),
                  ),
                  DropdownMenuItem(
                    value: 'EXPORT_EXPENSES',
                    child: Text('EXPORT_EXPENSES'),
                  ),
                  DropdownMenuItem(
                    value: 'LEARN_OCR_MAPPING',
                    child: Text('LEARN_OCR_MAPPING'),
                  ),
                  DropdownMenuItem(
                    value: 'UPDATE_PRIVACY_POLICY',
                    child: Text('UPDATE_PRIVACY_POLICY'),
                  ),
                  DropdownMenuItem(
                    value: 'OCR_RESOLVE_ANOMALY',
                    child: Text('OCR_RESOLVE_ANOMALY'),
                  ),
                  DropdownMenuItem(
                    value: 'SUSPEND_USER_ANOMALY',
                    child: Text('SUSPEND_USER_ANOMALY'),
                  ),
                  DropdownMenuItem(
                    value: 'DELETE_VENDOR_MAPPING',
                    child: Text('DELETE_VENDOR_MAPPING'),
                  ),
                ],
                onChanged: (val) =>
                    setState(() => _selectedActionFilter = val ?? 'All'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
