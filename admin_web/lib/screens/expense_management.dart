import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:csv/csv.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../utils/admin_picker_helper.dart';
import '../services/audit_log_service.dart';

class ExpenseManagementScreen extends ConsumerStatefulWidget {
  const ExpenseManagementScreen({super.key});

  @override
  ConsumerState<ExpenseManagementScreen> createState() => _ExpenseManagementScreenState();
}

class _ExpenseManagementScreenState extends ConsumerState<ExpenseManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Search & Filter state
  String _searchQuery = '';
  String _selectedCategory = 'All';
  double? _minAmount;
  double? _maxAmount;
  DateTimeRange? _selectedDateRange;

  // Cache of user profiles to map userId -> email/displayName
  Map<String, Map<String, String>> _userCache = {};
  StreamSubscription<QuerySnapshot>? _userCacheSubscription;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _subscribeToUserCache();
  }

  @override
  void dispose() {
    _userCacheSubscription?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _subscribeToUserCache() {
    _userCacheSubscription?.cancel();
    _userCacheSubscription = _firestore.collection('users').snapshots().listen(
      (snap) {
        final Map<String, Map<String, String>> tempCache = {};
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          tempCache[doc.id] = {
            'email': data['email'] ?? 'Unknown Email',
            'displayName': data['displayName'] ?? data['name'] ?? 'Unknown User',
          };
        }
        if (mounted) {
          setState(() {
            _userCache = tempCache;
          });
        }
      },
      onError: (e) {
        print('Error listening to user cache: $e');
      },
    );
  }

  Future<void> _loadUserCache() async {
    _subscribeToUserCache();
  }

  // Check if masking is active
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

  // Filter logic applied in memory
  List<DocumentSnapshot> _applyFilters(List<DocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final vendor = (data['vendor'] as String? ?? '').toLowerCase();
      final category = data['category'] as String? ?? 'General';
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

      // Date parsing
      DateTime? date;
      final dateStr = data['date'];
      if (dateStr != null) {
        date = DateTime.tryParse(dateStr);
      }

      // 1. Search Query (Vendor)
      if (_searchQuery.isNotEmpty && !vendor.contains(_searchQuery.toLowerCase())) {
        return false;
      }

      // 2. Category
      if (_selectedCategory != 'All' && category != _selectedCategory) {
        return false;
      }

      // 3. Min Amount
      if (_minAmount != null && amount < _minAmount!) {
        return false;
      }

      // 4. Max Amount
      if (_maxAmount != null && amount > _maxAmount!) {
        return false;
      }

      // 5. Date Range
      if (_selectedDateRange != null && date != null) {
        final start = _selectedDateRange!.start;
        final end = _selectedDateRange!.end.add(const Duration(days: 1));
        if (date.isBefore(start) || date.isAfter(end)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _exportFilteredToCsv(List<DocumentSnapshot> filteredDocs, bool isMasked) async {
    List<List<dynamic>> csvData = [
      ['Date', 'Vendor', 'Category', 'Amount (RM)', 'User Email', 'User Name'],
    ];

    for (var doc in filteredDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = doc.reference.parent.parent?.id ?? '';
      final user = _userCache[userId];
      final email = user?['email'] ?? 'Unknown Email';
      final displayName = user?['displayName'] ?? 'Unknown User';

      csvData.add([
        data['date'] ?? '',
        data['vendor'] ?? '',
        data['category'] ?? '',
        data['amount'] ?? 0.0,
        _maskEmail(email, isMasked),
        displayName,
      ]);
    }

    String csvString = csv.encode(csvData);
    final bytes = Uri.encodeComponent(csvString);
    html.AnchorElement(href: "data:text/csv;charset=utf-8,$bytes")
      ..setAttribute("download", "filtered_expenses_export.csv")
      ..click();

    // Log Export Audit Action
    ref.read(auditLogServiceProvider).logAction(
      action: 'EXPORT_EXPENSES',
      targetId: 'ALL',
      targetType: 'expense',
      detail: 'Exported ${filteredDocs.length} expense records to CSV.',
    );
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
                final isNarrow = constraints.maxWidth < 900;
                final isMobile = constraints.maxWidth < 600;

                return Padding(
                  padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  'Global Expense Ledger',
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
                                  'Inspect, filter, edit, and moderate expense records across all system users.',
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

                    // Filters panel card
                    _buildFiltersCard(colorScheme),

                    const SizedBox(height: 24),

                    // Table and Data view
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore.collectionGroup('expenses').orderBy('date', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading expenses: ${snapshot.error}'));
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      final filteredDocs = _applyFilters(allDocs);

                      return Container(
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header / Actions bar
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Records Found: ${filteredDocs.length}',
                                    style: TextStyle(
                                      fontFamily: 'Hanken Grotesk',
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (filteredDocs.isNotEmpty)
                                    ElevatedButton.icon(
                                      onPressed: () => _exportFilteredToCsv(filteredDocs, isMasked),
                                      icon: const Icon(Icons.download),
                                      label: const Text('Export Filtered CSV'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        foregroundColor: colorScheme.onPrimary,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Table body
                            Expanded(
                              child: filteredDocs.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No matching expense records found.',
                                        style: TextStyle(fontSize: 16, color: Colors.grey),
                                      ),
                                    )
                                  : isMobile
                                      ? ListView.separated(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: filteredDocs.length,
                                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                                          itemBuilder: (context, index) {
                                            final doc = filteredDocs[index];
                                            final data = doc.data() as Map<String, dynamic>;
                                            final userId = doc.reference.parent.parent?.id ?? '';
                                            final expenseId = doc.id;

                                            final user = _userCache[userId];
                                            final userEmail = _maskEmail(user?['email'] ?? 'Unknown', isMasked);
                                            final userName = user?['displayName'] ?? 'User';

                                            final vendor = data['vendor'] ?? 'N/A';
                                            final category = data['category'] ?? 'General';
                                            final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

                                            String dateStr = '';
                                            if (data['date'] != null) {
                                              final parsedDate = DateTime.tryParse(data['date']);
                                              if (parsedDate != null) {
                                                dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
                                              }
                                            }

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
                                                            vendor,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 16,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          dateStr,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Text(
                                                                userName,
                                                                style: const TextStyle(
                                                                  fontWeight: FontWeight.w500,
                                                                  fontSize: 13,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                              const SizedBox(height: 2),
                                                              Text(
                                                                userEmail,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: colorScheme.onSurfaceVariant,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          'RM ${amount.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: colorScheme.primary,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Chip(
                                                          label: Text(category, style: const TextStyle(fontSize: 10)),
                                                          backgroundColor: colorScheme.surfaceContainerHighest,
                                                          side: BorderSide.none,
                                                          visualDensity: VisualDensity.compact,
                                                        ),
                                                        Row(
                                                          children: [
                                                            IconButton.filledTonal(
                                                              icon: const Icon(Icons.visibility, size: 18),
                                                              tooltip: 'View Details',
                                                              onPressed: () => _viewDetailsDialog(
                                                                context,
                                                                data,
                                                                userName,
                                                                userEmail,
                                                                dateStr,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            IconButton.filledTonal(
                                                              icon: const Icon(Icons.edit, size: 18),
                                                              tooltip: 'Edit Record',
                                                              onPressed: () => _editExpenseDialog(
                                                                context,
                                                                doc,
                                                                data,
                                                                userId,
                                                                expenseId,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            IconButton.filledTonal(
                                                              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                                              tooltip: 'Delete Record',
                                                              onPressed: () => _confirmDelete(
                                                                context,
                                                                userId,
                                                                expenseId,
                                                                vendor,
                                                                amount,
                                                              ),
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
                                        )
                                      : Scrollbar(
                                          controller: _verticalScrollController,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: _verticalScrollController,
                                            scrollDirection: Axis.vertical,
                                            child: Scrollbar(
                                              controller: _horizontalScrollController,
                                              thumbVisibility: true,
                                              notificationPredicate: (notif) => notif.depth == 1,
                                              child: SingleChildScrollView(
                                                controller: _horizontalScrollController,
                                                scrollDirection: Axis.horizontal,
                                                child: DataTable(
                                                  headingRowColor: WidgetStateProperty.all(
                                                    colorScheme.surfaceContainerLowest,
                                                  ),
                                                  dividerThickness: 1,
                                                  columns: [
                                                    DataColumn(label: Text('DATE', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: colorScheme.onSurfaceVariant))),
                                                    DataColumn(label: Text('USER', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: colorScheme.onSurfaceVariant))),
                                                    DataColumn(label: Text('VENDOR', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: colorScheme.onSurfaceVariant))),
                                                    DataColumn(label: Text('CATEGORY', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: colorScheme.onSurfaceVariant))),
                                                    DataColumn(label: Text('AMOUNT', style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.05, color: colorScheme.onSurfaceVariant))),
                                                    DataColumn(
                                                      label: SizedBox(
                                                        width: 150,
                                                        child: Text(
                                                          'ACTIONS',
                                                          style: TextStyle(
                                                            fontFamily: 'Inter',
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w600,
                                                            letterSpacing: 0.05,
                                                            color: colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  rows: filteredDocs.map((doc) {
                                                    final data = doc.data() as Map<String, dynamic>;
                                                    final userId = doc.reference.parent.parent?.id ?? '';
                                                    final expenseId = doc.id;

                                                    final user = _userCache[userId];
                                                    final userEmail = _maskEmail(user?['email'] ?? 'Unknown', isMasked);
                                                    final userName = user?['displayName'] ?? 'User';

                                                    final vendor = data['vendor'] ?? 'N/A';
                                                    final category = data['category'] ?? 'General';
                                                    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

                                                    String dateStr = '';
                                                    if (data['date'] != null) {
                                                      final parsedDate = DateTime.tryParse(data['date']);
                                                      if (parsedDate != null) {
                                                        dateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
                                                      }
                                                    }

                                                    return DataRow(cells: [
                                                      DataCell(Text(dateStr)),
                                                      DataCell(ConstrainedBox(
                                                        constraints: const BoxConstraints(maxWidth: 200),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Text(
                                                              userName,
                                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Text(
                                                              userEmail,
                                                              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                                      DataCell(ConstrainedBox(
                                                        constraints: const BoxConstraints(maxWidth: 200),
                                                        child: Text(
                                                          vendor,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      )),
                                                      DataCell(Chip(
                                                        label: Text(category, style: const TextStyle(fontSize: 11)),
                                                        backgroundColor: colorScheme.surfaceContainerHighest,
                                                        side: BorderSide.none,
                                                      )),
                                                      DataCell(Text('RM ${amount.toStringAsFixed(2)}')),
                                                      DataCell(SizedBox(
                                                        width: 150,
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            IconButton(
                                                              icon: const Icon(Icons.visibility),
                                                              tooltip: 'View Details',
                                                              onPressed: () => _viewDetailsDialog(
                                                                context,
                                                                data,
                                                                userName,
                                                                userEmail,
                                                                dateStr,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.edit),
                                                              tooltip: 'Edit Record',
                                                              onPressed: () => _editExpenseDialog(
                                                                context,
                                                                doc,
                                                                data,
                                                                userId,
                                                                expenseId,
                                                              ),
                                                            ),
                                                            IconButton(
                                                              icon: const Icon(Icons.delete, color: Colors.red),
                                                              tooltip: 'Delete Record',
                                                              onPressed: () => _confirmDelete(
                                                                context,
                                                                userId,
                                                                expenseId,
                                                                vendor,
                                                                amount,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      )),
                                                    ]);
                                                  }).toList(),
                                                ),
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
          );
        },
      ),
    ),
  );
      },
    );
  }

  Widget _buildFiltersCard(ColorScheme colorScheme) {
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
              Icon(Icons.filter_list, color: colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Search Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Vendor',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Categories')),
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                        DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                        DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                        DropdownMenuItem(value: 'Health', child: Text('Health')),
                        DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                        DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                        DropdownMenuItem(value: 'Education', child: Text('Education')),
                        DropdownMenuItem(value: 'General', child: Text('General')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val ?? 'All';
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Amount (RM)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _minAmount = double.tryParse(val);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Amount (RM)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _maxAmount = double.tryParse(val);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _selectedDateRange == null
                            ? 'Pick Date Range'
                            : '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                    ),
                    if (_selectedDateRange != null ||
                        _searchQuery.isNotEmpty ||
                        _selectedCategory != 'All' ||
                        _minAmount != null ||
                        _maxAmount != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.clear),
                        label: const Text('Reset Filters'),
                        onPressed: _resetFilters,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  // Search vendor
                  Expanded(
                    flex: 2,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Vendor',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Category dropdown
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Categories')),
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                        DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                        DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                        DropdownMenuItem(value: 'Health', child: Text('Health')),
                        DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                        DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                        DropdownMenuItem(value: 'Education', child: Text('Education')),
                        DropdownMenuItem(value: 'General', child: Text('General')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCategory = val ?? 'All';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Min Amount
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Min Amount (RM)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _minAmount = double.tryParse(val);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Max Amount
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Max Amount (RM)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _maxAmount = double.tryParse(val);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Date Range Picker button
                  ElevatedButton.icon(
                    onPressed: _pickDateRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _selectedDateRange == null
                          ? 'Pick Date Range'
                          : '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    ),
                  ),
                  const SizedBox(width: 10),

                  if (_selectedDateRange != null ||
                      _searchQuery.isNotEmpty ||
                      _selectedCategory != 'All' ||
                      _minAmount != null ||
                      _maxAmount != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Reset Filters',
                      onPressed: _resetFilters,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await AdminPickerHelper.pickDateRange(
      context: context,
      initialRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All';
      _minAmount = null;
      _maxAmount = null;
      _selectedDateRange = null;
    });
  }

  void _viewDetailsDialog(
    BuildContext context,
    Map<String, dynamic> data,
    String userName,
    String userEmail,
    String dateStr,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Expense Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('User Name', userName),
              _detailRow('User Email', userEmail),
              const Divider(),
              _detailRow('Vendor', data['vendor'] ?? 'N/A'),
              _detailRow('Category', data['category'] ?? 'General'),
              _detailRow('Amount', 'RM ${(data['amount'] as num?)?.toDouble().toStringAsFixed(2)}'),
              _detailRow('Date', dateStr),
            ],
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

  Widget _detailRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(text: val),
          ],
        ),
      ),
    );
  }

  void _editExpenseDialog(
    BuildContext context,
    DocumentSnapshot docSnapshot,
    Map<String, dynamic> data,
    String userId,
    String expenseId,
  ) {
    final vendorController = TextEditingController(text: data['vendor'] ?? '');
    final amountController = TextEditingController(text: (data['amount'] ?? 0.0).toString());
    String category = data['category'] ?? 'General';
    DateTime selectedDate = DateTime.tryParse(data['date'] ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Expense Record'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: vendorController,
                    decoration: const InputDecoration(labelText: 'Vendor'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (RM)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'Food', child: Text('Food')),
                      DropdownMenuItem(value: 'Groceries', child: Text('Groceries')),
                      DropdownMenuItem(value: 'Transport', child: Text('Transport')),
                      DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
                      DropdownMenuItem(value: 'Health', child: Text('Health')),
                      DropdownMenuItem(value: 'Entertainment', child: Text('Entertainment')),
                      DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
                      DropdownMenuItem(value: 'Education', child: Text('Education')),
                      DropdownMenuItem(value: 'General', child: Text('General')),
                    ],
                    onChanged: (val) {
                      setDialogState(() {
                        category = val ?? 'General';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}'),
                      TextButton(
                        onPressed: () async {
                          final date = await AdminPickerHelper.pickDate(
                            context: context,
                            initialDate: selectedDate,
                          );
                          if (date != null) {
                            setDialogState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: const Text('Change Date'),
                      ),
                    ],
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
                    final vendor = vendorController.text.trim();
                    final amount = double.tryParse(amountController.text.trim()) ?? 0.0;

                    if (vendor.isEmpty || amount <= 0) return;

                    await _firestore
                        .collection('users')
                        .doc(userId)
                        .collection('expenses')
                        .doc(expenseId)
                        .update({
                      'vendor': vendor,
                      'amount': amount,
                      'category': category,
                      'date': selectedDate.toIso8601String(),
                    });

                    // Log Audit Event
                    ref.read(auditLogServiceProvider).logAction(
                      action: 'EDIT_EXPENSE',
                      targetId: expenseId,
                      targetType: 'expense',
                      detail: 'Updated expense amount to RM ${amount.toStringAsFixed(2)} for vendor "$vendor".',
                    );

                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    String userId,
    String expenseId,
    String vendor,
    double amount,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Expense Record?'),
          content: Text('Are you sure you want to delete this expense record for "$vendor" (RM ${amount.toStringAsFixed(2)})? This action is permanent and will be logged in the audit log.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await _firestore
                    .collection('users')
                    .doc(userId)
                    .collection('expenses')
                    .doc(expenseId)
                    .delete();

                // Log Audit Action
                ref.read(auditLogServiceProvider).logAction(
                  action: 'DELETE_EXPENSE',
                  targetId: expenseId,
                  targetType: 'expense',
                  detail: 'Deleted expense of RM ${amount.toStringAsFixed(2)} for vendor "$vendor".',
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
