import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/expense_service.dart';
import '../../providers/expense_providers.dart';
import '../../services/auth_service.dart';
import '../../models/expense_model.dart';
import '../../services/budget_service.dart';
import '../../providers/budget_providers.dart';
import '../../theme/brand_theme.dart';
import '../../utils/category_styles.dart';
import '../../screens/home/add_expense_screen.dart';
import '../../widgets/modern_bottom_toast.dart';
import 'package:intl/intl.dart';

class ExpensesView extends ConsumerStatefulWidget {
  final VoidCallback? onBack;
  final String? focusExpenseId;
  final VoidCallback? onFocusHandled;

  const ExpensesView({
    super.key,
    this.onBack,
    this.focusExpenseId,
    this.onFocusHandled,
  });

  @override
  ConsumerState<ExpensesView> createState() => _ExpensesViewState();
}

class _ExpensesViewState extends ConsumerState<ExpensesView> {
  late String _selectedMonth;
  late List<DateTime> _availableMonthsDates;

  String _searchQuery = '';
  bool _showSearch = false;
  String? _highlightedExpenseId;
  bool _pendingFocusScroll = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _expenseItemKeys = {};

  Stream<QuerySnapshot<Map<String, dynamic>>>? _cachedExpensesStream;
  String? _cachedUserUid;

  @override
  void initState() {
    super.initState();
    _availableMonthsDates = [];
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      _availableMonthsDates.add(DateTime(now.year, now.month - i, 1));
    }
    _availableMonthsDates = _availableMonthsDates.reversed.toList();
    _selectedMonth = DateFormat('MMMM yyyy').format(_availableMonthsDates.last);
    _highlightedExpenseId = widget.focusExpenseId;
    _pendingFocusScroll = widget.focusExpenseId != null;
  }

  @override
  void didUpdateWidget(ExpensesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusExpenseId != null &&
        widget.focusExpenseId != oldWidget.focusExpenseId) {
      _highlightedExpenseId = widget.focusExpenseId;
      _pendingFocusScroll = true;
      _searchQuery = '';
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // _listScrollController.dispose();
    // _categoryScrollController.dispose();
    super.dispose();
  }

  void _scrollToFocusedExpense(List<ExpenseModel> expenses) {
    if (!_pendingFocusScroll || widget.focusExpenseId == null) return;

    final targetId = widget.focusExpenseId!;
    final index = expenses.indexWhere((e) => e.id == targetId);
    if (index < 0) {
      _pendingFocusScroll = false;
      widget.onFocusHandled?.call();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _expenseItemKeys[targetId];
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: 0.25,
        );
      } else if (_listScrollController.hasClients) {
        const estimatedItemHeight = 96.0;
        final offset = (index * estimatedItemHeight).clamp(
          0.0,
          _listScrollController.position.maxScrollExtent,
        );
        _listScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        );
      }
      _pendingFocusScroll = false;
      widget.onFocusHandled?.call();
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _highlightedExpenseId == targetId) {
          setState(() => _highlightedExpenseId = null);
        }
      });
    });
  }

  Future<void> _deleteExpense(ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text(
          'Delete "${expense.vendor}" for RM ${expense.amount.toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(expenseServiceProvider).deleteExpense(expense.id!);
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Expense deleted',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Error: $e',
          type: ModernToastType.error,
        );
      }
    }
  }

  void _editExpense(ExpenseModel expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(
          initialAmount: expense.amount,
          initialVendor: expense.vendor,
          initialDate: expense.date,
          initialCategory: expense.category,
          expenseIdToEdit: expense.id,
          initialReceiptUrl: expense.receiptImageUrl,
          initialSplits: expense.splitSummary,
        ),
      ),
    );
  }

  List<ExpenseModel> _mapExpenseDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final expenses = <ExpenseModel>[];
    for (final doc in docs) {
      try {
        expenses.add(ExpenseModel.fromMap(doc.id, doc.data()));
      } catch (_) {
        // Skip malformed expense documents so one bad record does not break the list.
      }
    }
    return expenses;
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateChangesProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: authAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_cachedUserUid != user.uid || _cachedExpensesStream == null) {
            _cachedUserUid = user.uid;
            _cachedExpensesStream = ref
                .read(expenseServiceProvider)
                .getExpensesSnapshotStreamForUserWithBackfill(user.uid);
          }

          return budgetsAsync.when(
            data: (budgetLimits) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _cachedExpensesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Column(
                      children: [
                        _buildHeader(
                          context,
                          0,
                          0,
                          budgetLimits['Total'] ?? 0.0,
                          0,
                        ),
                        if (_showSearch) _buildSearchBar(),
                        _buildMonthSelector(),
                        Expanded(child: _buildTransactionList(const [])),
                      ],
                    );
                  }

                  final expenses = _mapExpenseDocs(snapshot.data!.docs);
                  var allMonthExpenses = expenses.where((e) {
                    return DateFormat('MMMM yyyy').format(e.date) == _selectedMonth;
                  }).toList();

                  final globalTotalSpent = allMonthExpenses.fold(
                    0.0,
                    (sum, e) => sum + e.amount,
                  );
                  final globalLimit = budgetLimits['Total'] ?? 0.0;

                  var filteredExpenses = allMonthExpenses;

                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    filteredExpenses = filteredExpenses
                        .where(
                          (e) =>
                              e.vendor.toLowerCase().contains(q) ||
                              e.category.toLowerCase().contains(q),
                        )
                        .toList();
                  }

                  filteredExpenses.sort((a, b) => b.date.compareTo(a.date));
                  _scrollToFocusedExpense(filteredExpenses);

                  final filteredTotalSpent = filteredExpenses.fold(
                    0.0,
                    (sum, e) => sum + e.amount,
                  );

                  return Column(
                    children: [
                      _buildHeader(
                        context,
                        filteredTotalSpent,
                        filteredExpenses.length,
                        globalLimit,
                        globalTotalSpent,
                      ),
                      if (_showSearch) _buildSearchBar(),
                      _buildMonthSelector(),
                      Expanded(child: _buildTransactionList(filteredExpenses)),
                    ],
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) =>
                const Center(child: Text("Error loading budgets")),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search vendor or category...',
          prefixIcon: Icon(Icons.search, color: colorScheme.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    double totalSpent,
    int transactionCount,
    double limit,
    double globalTotalSpent,
  ) {
    final progress = limit > 0
        ? (globalTotalSpent / limit).clamp(0.0, 1.0)
        : 0.0;

    Color progressColor;
    if (progress >= 0.9) {
      progressColor = Colors.redAccent;
    } else if (progress >= 0.75) {
      progressColor = Colors.orangeAccent;
    } else {
      progressColor = Colors.greenAccent;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              const Expanded(
                child: Text(
                  "Expense Tracking",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: _showSearch
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.16),
                  border: Border.all(color: Colors.white.withOpacity(0.24)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: IconButton(
                  icon: Icon(
                    _showSearch ? Icons.search_off : Icons.search,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _showSearch = !_showSearch;
                      if (!_showSearch) {
                        _searchQuery = '';
                        _searchController.clear();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Total Spent (${_selectedMonth.split(' ')[0]})",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "RM ${totalSpent.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$transactionCount transactions",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (limit > 0) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: progressColor,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Budget: RM ${globalTotalSpent.toStringAsFixed(0)} / RM ${limit.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    final now = DateTime.now();
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: _availableMonthsDates.map((date) {
            final fullLabel = DateFormat('MMMM yyyy').format(date);
            final isSelected = _selectedMonth == fullLabel;

            String label = DateFormat('MMM').format(date).toUpperCase();
            if (date.year != now.year) {
              label = '$label${DateFormat('yy').format(date)}';
            }

            return GestureDetector(
              onTap: () => setState(() => _selectedMonth = fullLabel),
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                child: Column(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 3,
                      width: 28,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getRelativeDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return 'Today, ${DateFormat('MMMM d').format(date)}';
    } else if (expenseDate == yesterday) {
      return 'Yesterday, ${DateFormat('MMMM d').format(date)}';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
    }
  }

  Widget _buildTransactionList(List<ExpenseModel> expenses) {
    if (expenses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No expenses yet this month',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan a receipt or add one manually\nto get started!',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final Map<String, List<ExpenseModel>> grouped = {};
    for (var e in expenses) {
      final header = _getRelativeDateHeader(e.date);
      grouped.putIfAbsent(header, () => []).add(e);
    }

    final children = <Widget>[];
    children.add(const SizedBox(height: 10));
    children.add(const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        'Transactions',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ));
    children.add(const SizedBox(height: 16));

    for (var entry in grouped.entries) {
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            entry.key,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        )
      );
      
      final groupExpenses = entry.value;
      final cardList = <Widget>[];
      for (var expense in groupExpenses) {
        cardList.add(_buildExpenseCard(expense));
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: cardList),
        )
      );
    }

    return ListView(
      controller: _listScrollController,
      padding: const EdgeInsets.only(bottom: 100),
      children: children,
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense) {
    final style = getCategoryStyle(expense.category);
    final dateStr = DateFormat('dd MMM yyyy').format(expense.date);
    final colorScheme = Theme.of(context).colorScheme;
    final isHighlighted =
        expense.id != null && expense.id == _highlightedExpenseId;
    final itemKey = expense.id != null
        ? _expenseItemKeys.putIfAbsent(expense.id!, () => GlobalKey())
        : null;

    return Dismissible(
      key: Key(expense.id ?? expense.vendor + expense.date.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text(
              'Delete "${expense.vendor}" for RM ${expense.amount.toStringAsFixed(2)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          await ref.read(expenseServiceProvider).deleteExpense(expense.id!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      },
      child: GestureDetector(
        onTap: () => _editExpense(expense),
        child: Container(
          key: itemKey,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHighlighted
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isHighlighted ? 2 : 1,
            ),
            boxShadow: isHighlighted
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: style.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.vendor,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            expense.category,
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (expense.receiptImageUrl != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.receipt_long_rounded,
                              size: 14,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        if (expense.splitSummary != null && expense.splitSummary!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.call_split_rounded,
                              size: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "-RM ${expense.amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (expense.needsReview)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.error_outline, color: Colors.orange, size: 16),
                        ),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
