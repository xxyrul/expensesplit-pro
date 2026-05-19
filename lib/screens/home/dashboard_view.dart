import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/budget_service.dart';
import '../../theme/brand_theme.dart';
import '../../utils/receipt_processing_ui.dart';
import '../../utils/category_styles.dart';
import '../home/add_expense_screen.dart';
import '../home/set_budget_screen.dart';
import '../goals/financial_goals_view.dart';
import '../debts/debt_management_view.dart';
import '../../widgets/notifications_sheet.dart';

class DashboardView extends ConsumerWidget {
  // NEW: Add the onSettingsPressed callback
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
    final expensesAsync = ref.watch(expensesStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: budgetsAsync.when(
        data: (budgetLimits) {
          final double totalLimit = budgetLimits['Total'] ?? 0.0;
          return expensesAsync.when(
            data: (expenses) {
              final now = DateTime.now();
              final currentMonthExpenses = expenses.where((e) {
                return e.date.year == now.year && e.date.month == now.month;
              }).toList();
              final totalSpent = currentMonthExpenses.fold(
                0.0,
                (sum, e) => sum + e.amount,
              );

              final recentExpenses = [...currentMonthExpenses]
                ..sort((a, b) => b.date.compareTo(a.date));

              return Column(
                children: [
                  _buildHeader(context, ref, totalLimit, totalSpent),
                  _buildQuickActions(context, ref),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildRecentExpenses(context, recentExpenses),
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

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    double limit,
    double spent,
  ) {
    final remaining = limit - spent;
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 18,
        left: 24,
        right: 24,
        bottom: 30,
      ),
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "ExpenseSplit Pro",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Financial Command Center",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      border: Border.all(color: Colors.white.withOpacity(0.26)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                      onPressed: () => NotificationsSheet.show(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      border: Border.all(color: Colors.white.withOpacity(0.26)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: onSettingsPressed, // UPDATED: Calls the callback
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _amountColumn("Monthly Budget", "RM ${limit.toStringAsFixed(0)}"),
              _amountColumn("Spent", "RM ${spent.toStringAsFixed(2)}"),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              color: getBudgetProgressColor(progress),
              minHeight: 9,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "RM ${remaining.toStringAsFixed(2)} remaining",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SetBudgetScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        "Set Budget",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helper methods _amountColumn, _buildQuickActions, _actionItem, _buildRecentExpenses, _expenseTile remain the same ---
  Widget _amountColumn(String label, String amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          amount,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _actionItem(
                  context,
                  icon: Icons.add_rounded,
                  label: "Add",
                  color: colorScheme.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionItem(
                  context,
                  icon: Icons.document_scanner_outlined,
                  label: "Scan",
                  color: colorScheme.primary,
                  onTap: () => ReceiptProcessingUI.startLiveScanFlow(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionItem(
                  context,
                  icon: Icons.emoji_events_outlined,
                  label: "Goals",
                  color: colorScheme.secondary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FinancialGoalsView()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionItem(
                  context,
                  icon: Icons.account_balance_wallet_outlined,
                  label: "Debts",
                  color: colorScheme.secondary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DebtManagementView()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.28 : 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentExpenses(BuildContext context, List<ExpenseModel> expenses) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Expenses",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              TextButton(
                onPressed: onViewAllPressed,
                child: Text(
                  "View All",
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
          if (expenses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No expenses this month yet.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else
            ...expenses.take(5).map((e) => _expenseTile(context, e)),
        ],
      ),
    );
  }

  Widget _expenseTile(BuildContext context, ExpenseModel expense) {
    final style = getCategoryStyle(expense.category);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onExpenseTap?.call(expense),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.vendor,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        expense.category,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-RM ${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
