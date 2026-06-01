import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/debt_model.dart';
import '../../services/debt_service.dart';
import '../../providers/debt_providers.dart';
import '../../utils/category_styles.dart';
import '../../widgets/add_debt_sheet.dart';
import '../../widgets/update_debt_sheet.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../../theme/brand_theme.dart';

class DebtManagementView extends ConsumerStatefulWidget {
  const DebtManagementView({super.key});

  @override
  ConsumerState<DebtManagementView> createState() => _DebtManagementViewState();
}

class _DebtManagementViewState extends ConsumerState<DebtManagementView> {
  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  void _showAddDebtSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const SingleChildScrollView(
          child: AddDebtSheet(),
        ),
      ),
    );
  }

  void _showUpdateDebtSheet(DebtModel debt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: UpdateDebtSheet(debt: debt),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDebt(DebtModel debt) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Debt"),
        content: Text("Are you sure you want to delete '${debt.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && debt.id != null) {
      await ref.read(debtServiceProvider).deleteDebt(debt.id!);
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Debt deleted successfully',
          type: ModernToastType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: debtsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF115E59)),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (debts) {
          final totalRemaining = debts.fold(
            0.0,
            (sum, d) => sum + d.currentBalance,
          );
          final totalOriginal = debts.fold(
            0.0,
            (sum, d) => sum + d.originalBalance,
          );
          final totalPaid = (totalOriginal - totalRemaining).clamp(
            0.0,
            double.infinity,
          );
          final totalMonthly = debts.fold(
            0.0,
            (sum, d) => sum + d.monthlyPayment,
          );

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildGradientHeader(),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _buildAppBar(),
                          _buildSummaryCard(
                            totalRemaining,
                            totalPaid,
                            totalMonthly,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 50)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: debts.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.account_balance_outlined,
                                  size: 60,
                                  color: scheme.onSurfaceVariant.withOpacity(0.35),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "No debts recorded.\nTap + to stay on top of your balances!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _buildDebtCard(debts[index]);
                        }, childCount: debts.length),
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGradientHeader() {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              "Debt Management",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  onPressed: _showAddDebtSheet,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double remaining, double paid, double monthly) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _summaryItem(
                "Total Remaining",
                remaining,
                const Color(0xFFf43f5e),
              ),
              _summaryItem("Total Paid", paid, const Color(0xFF115E59)),
            ],
          ),
          const Divider(height: 40),
          _summaryItem(
            "Monthly Obligation",
            monthly,
            const Color(0xFF6366f1),
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    String label,
    double amount,
    Color color, {
    bool isLarge = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: isLarge
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currencyFormat.format(amount),
          style: TextStyle(
            color: color,
            fontSize: isLarge ? 28 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDebtCard(DebtModel debt) {
    final scheme = Theme.of(context).colorScheme;
    final type = getDebtType(debt.type);
    final service = ref.read(debtServiceProvider);
    final monthsToPayoff = service.calculatePayoffTime(
      debt.currentBalance,
      debt.monthlyPayment,
      debt.interestRate,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: type.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(type.icon, color: type.color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Due on day ${debt.dueDate} • ${debt.interestRate}% APR",
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${(debt.progress * 100).toStringAsFixed(0)}%",
                        style: TextStyle(
                          color: type.color,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Paid",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (debt.currentBalance > 0) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _showUpdateDebtSheet(debt),
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF115E59),
                        size: 30,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () => _confirmDeleteDebt(debt),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFDC2626),
                      size: 26,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: debt.progress,
              minHeight: 8,
              backgroundColor: type.color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(type.color),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _debtCardDetail(
                "Remaining",
                _currencyFormat.format(debt.currentBalance),
              ),
              _debtCardDetail(
                "Monthly",
                _currencyFormat.format(debt.monthlyPayment),
              ),
              _debtCardDetail(
                "Est. Payoff",
                monthsToPayoff == -1 ? "∞" : "$monthsToPayoff months",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _debtCardDetail(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
