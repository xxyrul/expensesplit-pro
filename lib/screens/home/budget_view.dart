import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/debt_model.dart';
import '../../models/goal_model.dart';
import '../../services/expense_service.dart';
import '../../services/budget_service.dart';
import '../../services/debt_service.dart';
import '../../services/goal_service.dart';
import '../../services/month_end_surplus_service.dart';
import '../../services/budget_reallocation_service.dart';
import '../../services/burst_detection_provider.dart';
import '../../utils/category_styles.dart';
import 'set_budget_screen.dart';

class BudgetView extends ConsumerWidget {
  final VoidCallback? onBack; // NEW: Callback to return to dashboard

  const BudgetView({super.key, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F8),
      body: budgetsAsync.when(
        data: (budgetLimits) {
          return expensesAsync.when(
            data: (expenses) {
              final now = DateTime.now();
              final currentMonthExpenses = expenses.where((e) {
                return e.date.year == now.year && e.date.month == now.month;
              }).toList();

              final double totalLimit = budgetLimits['Total'] ?? 0.0;
              final totalSpent = currentMonthExpenses.fold(
                0.0,
                (sum, e) => sum + e.amount,
              );

              return Column(
                children: [
                  _buildTopOverviewCard(context, ref, totalLimit, totalSpent),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      children: [
                        ...kCategories.map((cat) {
                          final style = getCategoryStyle(cat);
                          return _buildCategoryCard(
                            context,
                            ref,
                            cat,
                            style.icon,
                            style.color,
                            currentMonthExpenses,
                            budgetLimits[cat] ?? 0.0,
                          );
                        }).toList(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
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

  Widget _buildTopOverviewCard(
    BuildContext context,
    WidgetRef ref,
    double limit,
    double spent,
  ) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onLongPress: () => _handleMonthEndSurplus(context, ref, limit, spent),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 6,
          bottom: 26,
          left: 16,
          right: 16,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF0EA5A0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: onBack,
                    ),
                    const Text(
                      "Budget Overview",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SetBudgetScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.24)),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _overviewStat(
                        "Total Budget",
                        "RM ${limit.toStringAsFixed(0)}",
                      ),
                      _overviewStat("Spent", "RM ${spent.toStringAsFixed(2)}"),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      color: getBudgetProgressColor(progress),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Long press to redirect any month-end surplus',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    WidgetRef ref,
    String category,
    IconData icon,
    Color color,
    List expenses,
    double limit,
  ) {
    final categorySpent = expenses
        .where((e) => e.category == category)
        .fold(0.0, (sum, e) => sum + e.amount);
    final remaining = limit - categorySpent;
    final progress = limit > 0 ? (categorySpent / limit).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toInt();
    final isBurst = remaining < 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "RM ${remaining.toStringAsFixed(2)} left",
                      style: TextStyle(
                        color: remaining < 0 ? Colors.red : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "RM ${categorySpent.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "of RM ${limit.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: getBudgetProgressColor(progress),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "$percent% used",
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              if (isBurst)
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: () => _handleFixBudget(context, ref, category),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Fix Budget',
                      style: TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleMonthEndSurplus(
    BuildContext context,
    WidgetRef ref,
    double limit,
    double spent,
  ) async {
    final surplus = limit - spent;

    if (surplus <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No surplus available to redirect.')),
      );
      return;
    }

    final action = await showCupertinoModalPopup<MonthEndSurplusRedirectType>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: Text('Surplus of RM ${surplus.toStringAsFixed(2)}'),
          message: const Text('Choose where to redirect the remaining funds.'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(context, MonthEndSurplusRedirectType.rollover),
              child: const Text('Roll Over to Next Month'),
            ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(context, MonthEndSurplusRedirectType.goal),
              child: const Text('Invest in Goals'),
            ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.pop(context, MonthEndSurplusRedirectType.debt),
              child: const Text('Slash Debt'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (action == null) return;

    final service = MonthEndSurplusService.instance;
    final now = DateTime.now();

    try {
      switch (action) {
        case MonthEndSurplusRedirectType.rollover:
          await service.rollOverSurplus(surplus: surplus, month: now);
          break;
        case MonthEndSurplusRedirectType.goal:
          final goals = await ref.read(goalsStreamProvider.future);
          if (!context.mounted) return;
          if (goals.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No goals found to invest in.')),
            );
            return;
          }

          final selectedGoal = await _pickGoal(context, goals, surplus);
          if (selectedGoal == null) return;

          await service.redirectToGoal(
            goal: selectedGoal,
            surplus: surplus,
            month: now,
          );
          break;
        case MonthEndSurplusRedirectType.debt:
          final debts = await ref.read(debtsStreamProvider.future);
          if (!context.mounted) return;
          if (debts.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No debts found to pay down.')),
            );
            return;
          }

          final selectedDebt = await _pickDebt(context, debts, surplus);
          if (selectedDebt == null) return;

          await service.redirectToDebt(
            debt: selectedDebt,
            surplus: surplus,
            month: now,
          );
          break;
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Surplus of RM ${surplus.toStringAsFixed(2)} has been successfully redirected!',
          ),
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to redirect surplus: $err')),
      );
    }
  }

  Future<GoalModel?> _pickGoal(
    BuildContext context,
    List<GoalModel> goals,
    double surplus,
  ) {
    return showCupertinoModalPopup<GoalModel>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Select a goal'),
          message: Text(
            'Redirect RM ${surplus.toStringAsFixed(2)} into a goal.',
          ),
          actions: goals
              .map(
                (goal) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, goal),
                  child: Text(
                    '${goal.name}  •  RM ${goal.currentAmount.toStringAsFixed(0)} / RM ${goal.targetAmount.toStringAsFixed(0)}',
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  Future<DebtModel?> _pickDebt(
    BuildContext context,
    List<DebtModel> debts,
    double surplus,
  ) {
    return showCupertinoModalPopup<DebtModel>(
      context: context,
      builder: (context) {
        return CupertinoActionSheet(
          title: const Text('Select a debt'),
          message: Text(
            'Redirect RM ${surplus.toStringAsFixed(2)} toward a debt.',
          ),
          actions: debts
              .map(
                (debt) => CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context, debt),
                  child: Text(
                    '${debt.title}  •  RM ${debt.currentBalance.toStringAsFixed(0)} remaining',
                  ),
                ),
              )
              .toList(),
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        );
      },
    );
  }

  Future<void> _handleFixBudget(
    BuildContext context,
    WidgetRef ref,
    String burstCategory,
  ) async {
    final available = await ref.read(
      availableCategoriesProvider(burstCategory).future,
    );

    if (!context.mounted) return;

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No categories with available balance to borrow from.'),
        ),
      );
      return;
    }

    _showReallocationSheet(context, ref, burstCategory, available);
  }

  void _showReallocationSheet(
    BuildContext context,
    WidgetRef ref,
    String burstCategory,
    List<AvailableCategory> available,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _ReallocationSheet(
          burstCategory: burstCategory,
          availableCategories: available,
          onReallocate: (sourceCategory, amount) async {
            Navigator.pop(context);
            await _performReallocation(
              context,
              ref,
              sourceCategory,
              burstCategory,
              amount,
            );
          },
        );
      },
    );
  }

  Future<void> _performReallocation(
    BuildContext context,
    WidgetRef ref,
    String sourceCategory,
    String burstCategory,
    double amount,
  ) async {
    try {
      await BudgetReallocationService.instance.reallocateBudget(
        sourceCategoryId: sourceCategory,
        burstCategoryId: burstCategory,
        amount: amount,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reallocated RM ${amount.toStringAsFixed(2)} from $sourceCategory to $burstCategory',
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      // The UI will update automatically via the budget stream
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reallocate: $err')));
    }
  }
}

class _ReallocationSheet extends StatefulWidget {
  final String burstCategory;
  final List<AvailableCategory> availableCategories;
  final Function(String sourceCategory, double amount) onReallocate;

  const _ReallocationSheet({
    required this.burstCategory,
    required this.availableCategories,
    required this.onReallocate,
  });

  @override
  State<_ReallocationSheet> createState() => _ReallocationSheetState();
}

class _ReallocationSheetState extends State<_ReallocationSheet> {
  String? selectedSource;
  double borrowAmount = 0.0;
  late TextEditingController amountController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController();
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = selectedSource != null
        ? widget.availableCategories.firstWhere(
            (c) => c.categoryId == selectedSource,
          )
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Fix ${widget.burstCategory} Budget',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Select a category to borrow from',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  // Category selector
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButton<String>(
                      value: selectedSource,
                      isExpanded: true,
                      hint: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text('Select source category'),
                      ),
                      underline: const SizedBox(),
                      items: widget.availableCategories
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat.categoryId,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                ),
                                child: Text(
                                  '${cat.categoryId}  •  RM ${cat.available.toStringAsFixed(2)} available',
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedSource = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Amount input
                  if (selectedCategory != null) ...[
                    Text(
                      'Amount to borrow (max RM ${selectedCategory.available.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixText: 'RM ',
                      ),
                      onChanged: (value) {
                        setState(
                          () => borrowAmount = double.tryParse(value) ?? 0.0,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    // Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'From:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                selectedCategory.categoryId,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('To:', style: TextStyle(fontSize: 12)),
                              Text(
                                widget.burstCategory,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Amount:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                'RM ${borrowAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Confirm button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          borrowAmount > 0 &&
                              borrowAmount <= (selectedCategory?.available ?? 0)
                          ? () => widget.onReallocate(
                              selectedSource!,
                              borrowAmount,
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        disabledBackgroundColor: Colors.grey[300],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Confirm Reallocation',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
