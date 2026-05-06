import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/debt_model.dart';
import '../../services/debt_service.dart';
import '../../utils/category_styles.dart';
import '../../widgets/add_debt_sheet.dart';

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
      builder: (context) => const AddDebtSheet(),
    );
  }

  Future<void> _confirmDeleteDebt(DebtModel debt) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Debt"),
        content: Text("Are you sure you want to delete '${debt.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && debt.id != null) {
      await ref.read(debtServiceProvider).deleteDebt(debt.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Debt deleted successfully")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F8),
      body: debtsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
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
                                  color: Colors.blueGrey.withOpacity(0.3),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  "No debts recorded.\nTap + to stay on top of your balances!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.blueGrey,
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF0EA5A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "Debt Management",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _showAddDebtSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double remaining, double paid, double monthly) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
              _summaryItem("Total Paid", paid, const Color(0xFF0F766E)),
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
    return Column(
      crossAxisAlignment: isLarge
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Due on day ${debt.dueDate} • ${debt.interestRate}% APR",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
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
                          color: Color(0xFF64748B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  if (debt.currentBalance > 0) ...[
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
