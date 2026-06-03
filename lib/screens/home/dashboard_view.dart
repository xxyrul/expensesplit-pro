import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../providers/expense_providers.dart';
import '../../providers/budget_providers.dart';
import '../../utils/category_styles.dart';

class DashboardStats {
  final List<ExpenseModel> recentExpenses;
  final double totalSpent;
  final double projectedSpending;
  final Map<String, double> categorySpending;

  DashboardStats({
    required this.recentExpenses,
    required this.totalSpent,
    required this.projectedSpending,
    required this.categorySpending,
  });
}

final dashboardStatsProvider = FutureProvider.autoDispose<DashboardStats>((ref) async {
  final expenses = await ref.watch(expensesStreamProvider.future);
  
  return await Future.microtask(() {
    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) {
      return e.date.year == now.year && e.date.month == now.month;
    }).toList();
    
    final totalSpent = currentMonthExpenses.fold(0.0, (sum, e) => sum + e.amount);
    
    final categorySpending = <String, double>{};
    for (var e in currentMonthExpenses) {
      categorySpending[e.category] = (categorySpending[e.category] ?? 0.0) + e.amount;
    }

    final daysElapsed = now.day;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projectedSpending = (totalSpent / daysElapsed) * daysInMonth;

    final recentExpenses = [...currentMonthExpenses]
      ..sort((a, b) => b.date.compareTo(a.date));

    return DashboardStats(
      recentExpenses: recentExpenses,
      totalSpent: totalSpent,
      projectedSpending: projectedSpending,
      categorySpending: categorySpending,
    );
  });
});

class DashboardView extends ConsumerWidget {
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onViewAllPressed;
  final void Function(ExpenseModel expense)? onExpenseTap;

  const DashboardView({
    super.key,
    this.onSettingsPressed,
    this.onViewAllPressed,
    this.onExpenseTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: budgetsAsync.when(
        data: (budgetLimits) {
          final double totalLimit = budgetLimits['Total'] ?? 5000.0;
          return statsAsync.when(
            data: (stats) {
              return CustomScrollView(
                slivers: [
                  _buildAppBar(context),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAvailableBalance(context, totalLimit, stats.totalSpent),
                          const SizedBox(height: 32),
                          _buildMonthlyFlow(context, stats.categorySpending, totalLimit),
                          const SizedBox(height: 32),
                          _buildRecentActivity(context, stats.recentExpenses),
                          const SizedBox(height: 120), // Padding for bottom nav
                        ],
                      ),
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
        error: (err, stack) => const Center(child: Text("Error loading data")),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 20,
      toolbarHeight: 70,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            backgroundImage: const NetworkImage('https://i.pravatar.cc/150?img=5'),
          ),
          const Expanded(
            child: Text(
              "Financial Calm",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Color(0xFF0057C3),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            color: Theme.of(context).colorScheme.outline,
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBalance(BuildContext context, double totalLimit, double totalSpent) {
    final available = (totalLimit - totalSpent).clamp(0.0, double.infinity);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0057C3).withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "Available Balance",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "RM ${available.toStringAsFixed(2)}",
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6DFE9C),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.trending_up, color: Color(0xFF007439), size: 18),
                SizedBox(width: 8),
                Text(
                  "On track for your goals",
                  style: TextStyle(
                    color: Color(0xFF007439),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyFlow(BuildContext context, Map<String, double> categorySpending, double totalLimit) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                "Monthly Flow",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAllPressed,
              child: const Text(
                "View All",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0057C3).withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: categorySpending.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text("No spending yet", style: TextStyle(color: colorScheme.outline)),
              ))
            : Column(
                children: categorySpending.entries.take(4).map((entry) {
                  final category = entry.key;
                  final spent = entry.value;
                  final catLimit = (totalLimit / 4).clamp(500.0, 5000.0);
                  final progress = (spent / catLimit).clamp(0.0, 1.0);
                  final style = getCategoryStyle(category);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(style.icon, color: style.color, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  category,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "RM ${spent.toStringAsFixed(0)} / RM ${catLimit.toStringAsFixed(0)}",
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: colorScheme.surfaceContainerHighest,
                            color: style.color,
                            minHeight: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context, List<ExpenseModel> expenses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text(
            "Recent Activity",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0057C3).withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: expenses.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text("No expenses found.", style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                ),
              )
            : Column(
                children: expenses.take(5).map((e) => _expenseTile(context, e)).toList(),
              ),
        ),
      ],
    );
  }

  Widget _expenseTile(BuildContext context, ExpenseModel expense) {
    final style = getCategoryStyle(expense.category);
    final colorScheme = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final isToday = expense.date.year == now.year && expense.date.month == now.month && expense.date.day == now.day;
    final isYesterday = expense.date.year == now.year && expense.date.month == now.month && expense.date.day == now.day - 1;
    String dateStr = "";
    if (isToday) dateStr = "Today";
    else if (isYesterday) dateStr = "Yesterday";
    else dateStr = "${expense.date.day}/${expense.date.month}/${expense.date.year}";

    final timeStr = "${expense.date.hour > 12 ? expense.date.hour - 12 : (expense.date.hour == 0 ? 12 : expense.date.hour)}:${expense.date.minute.toString().padLeft(2, '0')} ${expense.date.hour >= 12 ? 'PM' : 'AM'}";

    return InkWell(
      onTap: () => onExpenseTap?.call(expense),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: style.color.withOpacity(0.15),
                shape: BoxShape.circle,
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "$dateStr, $timeStr",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '- RM ${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
