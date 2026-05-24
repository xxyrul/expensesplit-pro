import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/audit_log_service.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    if (!mask) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<bool>(
      future: _isMaskingActive(),
      builder: (context, maskingSnap) {
        final isMasked = maskingSnap.data ?? false;

        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;

                return Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (with revalidate button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Account Governance',
                            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Control access policies, toggle account statuses, and configure system administrator privileges.',
                            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Revalidate admin session',
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No signed-in user to revalidate.')));
                          return;
                        }
                        try {
                          final doc = await _firestore.collection('admins').doc(user.uid).get();
                          if (doc.exists) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current session is a verified admin.')));
                          } else {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current account is NOT listed in admins. Signing out.')));
                            await FirebaseAuth.instance.signOut();
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Revalidation failed: $e')));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Table Container
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collection('users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }

                      final docs = snapshot.data?.docs ?? [];

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
                                'Total Managed Accounts: ${docs.length}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: docs.isEmpty
                                  ? const Center(child: Text('No registered users found.'))
                                  : isMobile
                                      ? ListView.separated(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: docs.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final doc = docs[index];
                                            final data = doc.data() as Map<String, dynamic>;
                                            final userId = doc.id;
                                            final name = data['displayName'] ?? data['name'] ?? 'User';
                                            final email = data['email'] ?? 'No Email';
                                            final role = data['role'] ?? 'User';
                                            final isActive = data['isActive'] ?? true;

                                            return Card(
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                                side: BorderSide(color: colorScheme.outlineVariant),
                                              ),
                                              elevation: 0,
                                              color: colorScheme.surfaceContainerLow,
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            name,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Row(
                                                          children: [
                                                            Chip(
                                                              label: Text(role, style: const TextStyle(fontSize: 10)),
                                                              backgroundColor: role == 'Admin'
                                                                  ? Colors.blue.withOpacity(0.1)
                                                                  : Colors.grey.withOpacity(0.1),
                                                              labelStyle: TextStyle(
                                                                color: role == 'Admin' ? Colors.blue : Colors.grey[700],
                                                              ),
                                                              side: BorderSide.none,
                                                              visualDensity: VisualDensity.compact,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Chip(
                                                              label: Text(isActive ? 'Active' : 'Deactivated', style: const TextStyle(fontSize: 10)),
                                                              backgroundColor: isActive
                                                                  ? Colors.green.withOpacity(0.1)
                                                                  : Colors.red.withOpacity(0.1),
                                                              labelStyle: TextStyle(
                                                                color: isActive ? Colors.green : Colors.red,
                                                              ),
                                                              side: BorderSide.none,
                                                              visualDensity: VisualDensity.compact,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      _maskEmail(email, isMasked),
                                                      style: TextStyle(
                                                        color: colorScheme.onSurfaceVariant,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    const Divider(height: 1),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        IconButton.filledTonal(
                                                          icon: Icon(
                                                            isActive ? Icons.block : Icons.check_circle_outline,
                                                            color: isActive ? Colors.red : Colors.green,
                                                            size: 20,
                                                          ),
                                                          tooltip: isActive ? 'Deactivate Account' : 'Activate Account',
                                                          onPressed: () => _toggleAccountStatus(
                                                            userId,
                                                            name,
                                                            isActive,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        IconButton.filledTonal(
                                                          icon: const Icon(Icons.shield, size: 20),
                                                          tooltip: 'Change User Role',
                                                          onPressed: () => _changeRoleDialog(
                                                            context,
                                                            userId,
                                                            name,
                                                            role,
                                                            email,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        IconButton.filledTonal(
                                                          icon: const Icon(Icons.analytics, size: 20),
                                                          tooltip: 'View User Stats',
                                                          onPressed: () => _showStatsDialog(
                                                            context,
                                                            userId,
                                                            name,
                                                          ),
                                                        ),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        )
                                      : LayoutBuilder(
                                          builder: (context, constraints) {
                                            final tableWidth = constraints.maxWidth > 1000 ? constraints.maxWidth : 1000.0;
                                            final emailColumnWidth = tableWidth - 620.0;

                                            return Scrollbar(
                                              child: SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: SizedBox(
                                                  width: tableWidth,
                                                  child: SingleChildScrollView(
                                                    scrollDirection: Axis.vertical,
                                                    child: DataTable(
                                                      headingRowColor: WidgetStateProperty.all(
                                                        colorScheme.surfaceContainerHighest,
                                                      ),
                                                      columns: const [
                                                        DataColumn(label: Text('Display Name')),
                                                        DataColumn(label: Text('Email')),
                                                        DataColumn(label: Text('Role')),
                                                        DataColumn(label: Text('Status')),
                                                        DataColumn(label: Text('Actions')),
                                                      ],
                                                      rows: docs.map((doc) {
                                                        final data = doc.data() as Map<String, dynamic>;
                                                        final userId = doc.id;
                                                        final name = data['displayName'] ?? data['name'] ?? 'User';
                                                        final email = data['email'] ?? 'No Email';
                                                        final role = data['role'] ?? 'User';
                                                        final isActive = data['isActive'] ?? true;

                                                        return DataRow(cells: [
                                                          DataCell(SizedBox(
                                                            width: 160,
                                                            child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                          )),
                                                          DataCell(SizedBox(
                                                            width: emailColumnWidth,
                                                            child: Text(_maskEmail(email, isMasked), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                          )),
                                                          DataCell(Chip(
                                                            label: Text(
                                                              role,
                                                              style: TextStyle(
                                                                color: role == 'Admin' ? Colors.blue : Colors.grey,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                            backgroundColor: role == 'Admin'
                                                                ? Colors.blue.withOpacity(0.1)
                                                                : Colors.grey.withOpacity(0.1),
                                                            side: BorderSide.none,
                                                          )),
                                                          DataCell(Chip(
                                                            label: Text(
                                                              isActive ? 'Active' : 'Deactivated',
                                                              style: TextStyle(
                                                                color: isActive ? Colors.green : Colors.red,
                                                                fontSize: 11,
                                                              ),
                                                            ),
                                                            backgroundColor: isActive
                                                                ? Colors.green.withOpacity(0.1)
                                                                : Colors.red.withOpacity(0.1),
                                                            side: BorderSide.none,
                                                          )),
                                                          DataCell(Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              IconButton(
                                                                icon: Icon(
                                                                  isActive ? Icons.block : Icons.check_circle_outline,
                                                                  color: isActive ? Colors.red : Colors.green,
                                                                ),
                                                                tooltip: isActive ? 'Deactivate Account' : 'Activate Account',
                                                                onPressed: () => _toggleAccountStatus(
                                                                  userId,
                                                                  name,
                                                                  isActive,
                                                                ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(Icons.shield),
                                                                tooltip: 'Change User Role',
                                                                onPressed: () => _changeRoleDialog(
                                                                  context,
                                                                  userId,
                                                                  name,
                                                                  role,
                                                                  email,
                                                                ),
                                                              ),
                                                              IconButton(
                                                                icon: const Icon(Icons.analytics),
                                                                tooltip: 'View User Stats',
                                                                onPressed: () => _showStatsDialog(
                                                                  context,
                                                                  userId,
                                                                  name,
                                                                ),
                                                              ),
                                                            ],
                                                          )),
                                                        ]);
                                                      }).toList(),
                                                    ),
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
          );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleAccountStatus(String userId, String name, bool currentStatus) async {
    final newStatus = !currentStatus;
    await _firestore.collection('users').doc(userId).update({'isActive': newStatus});

    // Log governance action
    ref.read(auditLogServiceProvider).logAction(
      action: newStatus ? 'ACTIVATE_USER' : 'DEACTIVATE_USER',
      targetId: userId,
      targetType: 'user',
      detail: newStatus
          ? 'Activated user account for "$name".'
          : 'Deactivated user account for "$name" (denied platform operations).',
    );
  }

  void _changeRoleDialog(
    BuildContext context,
    String userId,
    String name,
    String currentRole,
    String email,
  ) {
    String selectedRole = currentRole;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Modify Access Privileges for $name'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Promoting a user to Admin grants them access credentials to log into this administrative command dashboard.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: const InputDecoration(labelText: 'System Security Role'),
                    items: const [
                      DropdownMenuItem(value: 'User', child: Text('User (Mobile client access)')),
                      DropdownMenuItem(value: 'Admin', child: Text('Admin (Full system credentials)')),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        selectedRole = val ?? 'User';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 1. Update user role field in user doc
                    await _firestore.collection('users').doc(userId).update({'role': selectedRole});

                    // 2. Add or remove from admin access collection to sync login permission
                    if (selectedRole == 'Admin') {
                      await _firestore.collection('admins').doc(userId).set({
                        'email': email,
                        'promotedAt': FieldValue.serverTimestamp(),
                      });
                    } else {
                      await _firestore.collection('admins').doc(userId).delete();
                    }

                    // 3. Log Audit
                    ref.read(auditLogServiceProvider).logAction(
                      action: 'CHANGE_USER_ROLE',
                      targetId: userId,
                      targetType: 'user',
                      detail: 'Changed security role of "$name" from "$currentRole" to "$selectedRole".',
                    );

                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Confirm Privileges'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showStatsDialog(BuildContext context, String userId, String name) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Activity Dashboard: $name'),
          content: SizedBox(
            width: 400,
            child: FutureBuilder<QuerySnapshot>(
              future: _firestore.collection('users').doc(userId).collection('expenses').get(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                final double totalSpent = docs.fold(
                  0.0,
                  (sum, doc) => sum + ((doc.data() as Map)['amount'] as num? ?? 0).toDouble(),
                );

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statsRow('Total Expenses Logged', '${docs.length} items'),
                    _statsRow('Total Consolidated Spend', 'RM ${totalSpent.toStringAsFixed(2)}'),
                    if (docs.isNotEmpty) ...[
                      const Divider(),
                      const Text(
                        'Recent Transactions:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ...docs.take(3).map((d) {
                        final amt = ((d.data() as Map)['amount'] as num? ?? 0).toDouble();
                        final vend = (d.data() as Map)['vendor'] ?? 'N/A';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(vend, style: const TextStyle(fontSize: 12)),
                              Text('RM ${amt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      })
                    ]
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            )
          ],
        );
      },
    );
  }

  Widget _statsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
