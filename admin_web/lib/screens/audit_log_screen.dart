import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedActionFilter = 'All';

  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> docs) {
    if (_selectedActionFilter == 'All') return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final action = data['action'] ?? '';
      return action == _selectedActionFilter;
    }).toList();
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'DELETE_EXPENSE':
      case 'DEACTIVATE_USER':
        return Colors.red; // Destructive / Critical Governance Actions
      case 'EDIT_EXPENSE':
      case 'CHANGE_USER_ROLE':
        return Colors.orange; // High Impact Configuration Updates
      case 'EXPORT_EXPENSES':
      case 'LEARN_OCR_MAPPING':
        return Colors.blue; // System Optimization & Privacy Operations
      case 'OCR_REVIEW':
      case 'ACTIVATE_USER':
      case 'OCR_RESOLVE_ANOMALY':
        return Colors.green; // Approvals & Standard Maintenance
      case 'UPDATE_PRIVACY_POLICY':
        return Colors.purple;
      case 'SUSPEND_USER_ANOMALY':
      case 'DELETE_VENDOR_MAPPING':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1440),
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
                            'System Security Audit Trail',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Immutably logged actions for system accountability, access controls, and policy compliance verification.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Append-only governance trail',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _buildFilterBar(colorScheme),
                const SizedBox(height: 24),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('system_config')
                        .doc('audit_logs')
                        .collection('entries')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading audit log: ${snapshot.error}'));
                      }

                      final allLogs = snapshot.data?.docs ?? [];
                      final filteredLogs = _applyFilters(allLogs);

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Administrative Entries: ${filteredLogs.length}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Showing newest first',
                                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: filteredLogs.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No security events logged under current filter.',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    )
                                  : Scrollbar(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: SizedBox(
                                          width: 1280,
                                          child: DataTable(
                                            columnSpacing: 24,
                                            horizontalMargin: 20,
                                            headingRowColor: WidgetStateProperty.all(
                                              colorScheme.surfaceContainerHighest,
                                            ),
                                            columns: const [
                                              DataColumn(label: Text('Timestamp')),
                                              DataColumn(label: Text('Operator')),
                                              DataColumn(label: Text('Event Action')),
                                              DataColumn(label: Text('Target Info')),
                                              DataColumn(label: Text('Event Details')),
                                            ],
                                            rows: filteredLogs.map((doc) {
                                              final data = doc.data() as Map<String, dynamic>;
                                              final adminEmail = data['adminEmail'] ?? 'Unknown Admin';
                                              final action = data['action'] ?? 'Unknown Action';
                                              final targetType = data['targetType'] ?? 'System';
                                              final targetId = data['targetId'] ?? '';
                                              final detail = data['detail'] ?? '';

                                              String timestampStr = 'N/A';
                                              if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
                                                final date = (data['timestamp'] as Timestamp).toDate();
                                                timestampStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
                                              }

                                              final actionColor = _getActionColor(action);

                                              return DataRow(cells: [
                                                DataCell(Text(timestampStr, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
                                                DataCell(SizedBox(
                                                  width: 180,
                                                  child: Text(adminEmail, maxLines: 1, overflow: TextOverflow.ellipsis),
                                                )),
                                                DataCell(Chip(
                                                  label: Text(
                                                    action,
                                                    style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                                                  ),
                                                  backgroundColor: actionColor.withOpacity(0.1),
                                                  side: BorderSide(color: actionColor.withOpacity(0.2)),
                                                )),
                                                DataCell(SizedBox(
                                                  width: 220,
                                                  child: Text('$targetType ($targetId)', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                                )),
                                                DataCell(SizedBox(
                                                  width: 420,
                                                  child: Tooltip(
                                                    message: detail,
                                                    child: Text(
                                                      detail,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 13),
                                                    ),
                                                  ),
                                                )),
                                              ]);
                                            }).toList(),
                                          ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list),
          const SizedBox(width: 12),
          const Text('Filter by Event Type:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 24),
          DropdownButton<String>(
            value: _selectedActionFilter,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'All', child: Text('All Events')),
              DropdownMenuItem(value: 'DELETE_EXPENSE', child: Text('DELETE_EXPENSE')),
              DropdownMenuItem(value: 'EDIT_EXPENSE', child: Text('EDIT_EXPENSE')),
              DropdownMenuItem(value: 'OCR_REVIEW', child: Text('OCR_REVIEW')),
              DropdownMenuItem(value: 'ACTIVATE_USER', child: Text('ACTIVATE_USER')),
              DropdownMenuItem(value: 'DEACTIVATE_USER', child: Text('DEACTIVATE_USER')),
              DropdownMenuItem(value: 'CHANGE_USER_ROLE', child: Text('CHANGE_USER_ROLE')),
              DropdownMenuItem(value: 'EXPORT_EXPENSES', child: Text('EXPORT_EXPENSES')),
              DropdownMenuItem(value: 'LEARN_OCR_MAPPING', child: Text('LEARN_OCR_MAPPING')),
              DropdownMenuItem(value: 'UPDATE_PRIVACY_POLICY', child: Text('UPDATE_PRIVACY_POLICY')),
              DropdownMenuItem(value: 'OCR_RESOLVE_ANOMALY', child: Text('OCR_RESOLVE_ANOMALY')),
              DropdownMenuItem(value: 'SUSPEND_USER_ANOMALY', child: Text('SUSPEND_USER_ANOMALY')),
              DropdownMenuItem(value: 'DELETE_VENDOR_MAPPING', child: Text('DELETE_VENDOR_MAPPING')),
            ],
            onChanged: (val) {
              setState(() {
                _selectedActionFilter = val ?? 'All';
              });
            },
          ),
        ],
      ),
    );
  }
}
