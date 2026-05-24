import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/expense_service.dart';
import '../../models/expense_model.dart';
import '../../services/budget_service.dart';
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
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showSearch = false;
  String? _highlightedExpenseId;
  bool _pendingFocusScroll = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listScrollController = ScrollController();
  final Map<String, GlobalKey> _expenseItemKeys = {};

  final List<String> _categories = ['All', ...kCategories];

  @override
  void initState() {
    super.initState();
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
      _selectedCategory = 'All';
      _searchQuery = '';
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
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
            'Delete "${expense.vendor}" for RM ${expense.amount.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: budgetsAsync.when(
        data: (budgetLimits) {
          return expensesAsync.when(
            data: (expenses) {
              final now = DateTime.now();
              var allMonthExpenses = expenses.where((e) {
                return e.date.year == now.year && e.date.month == now.month;
              }).toList();

              final globalTotalSpent = allMonthExpenses.fold(
                0.0,
                (sum, e) => sum + e.amount,
              );
              final globalLimit = budgetLimits['Total'] ?? 0.0;

              var filteredExpenses = allMonthExpenses;

              if (_selectedCategory != 'All') {
                filteredExpenses = filteredExpenses
                    .where((e) => e.category == _selectedCategory)
                    .toList();
              }

              if (_searchQuery.isNotEmpty) {
                final q = _searchQuery.toLowerCase();
                filteredExpenses = filteredExpenses
                    .where((e) =>
                        e.vendor.toLowerCase().contains(q) ||
                        e.category.toLowerCase().contains(q))
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
                  _buildCategoryFilter(),
                  Expanded(child: _buildTransactionList(filteredExpenses)),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text("Error: $err")),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            const Center(child: Text("Error loading budgets")),
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
                const Text(
                  "Total Spent",
                  style: TextStyle(
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

  Widget _buildCategoryFilter() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 70,
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? null : colorScheme.surfaceContainer,
                gradient: isSelected
                    ? LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.85)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.015),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Text(
                category,
                style: TextStyle(
                  color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
          );
        },
      ),
    );
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
                  : _selectedCategory != 'All'
                      ? 'No $_selectedCategory expenses this month'
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

    return ListView.builder(
      controller: _listScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        return _buildExpenseCard(expense);
      },
    );
  }

  Widget _buildExpenseCard(ExpenseModel expense) {
    final style = getCategoryStyle(expense.category);
    final dateStr = DateFormat('dd MMM yyyy').format(expense.date);
    final colorScheme = Theme.of(context).colorScheme;
    final isHighlighted = expense.id != null && expense.id == _highlightedExpenseId;
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
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Expense'),
            content: Text(
                'Delete "${expense.vendor}" for RM ${expense.amount.toStringAsFixed(2)}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        try {
          await ref
              .read(expenseServiceProvider)
              .deleteExpense(expense.id!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Error: $e')));
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
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "•",
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12),
                          ),
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
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
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
