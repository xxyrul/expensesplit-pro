import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../../utils/category_styles.dart';
import '../../widgets/add_goal_sheet.dart';
import '../../widgets/add_savings_sheet.dart';

class FinancialGoalsView extends ConsumerStatefulWidget {
  const FinancialGoalsView({super.key});

  @override
  ConsumerState<FinancialGoalsView> createState() => _FinancialGoalsViewState();
}

class _FinancialGoalsViewState extends ConsumerState<FinancialGoalsView>
    with SingleTickerProviderStateMixin {
  bool _showCompleted = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );

  void _showAddGoalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddGoalSheet(),
    );
  }

  void _showAddSavingsSheet(GoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddSavingsSheet(goal: goal),
    );
  }

  Future<void> _confirmDeleteGoal(GoalModel goal) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Goal"),
        content: Text("Are you sure you want to delete '${goal.name}'?"),
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

    if (confirm == true && goal.id != null) {
      await ref.read(goalServiceProvider).deleteGoal(goal.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Goal deleted successfully")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F8),
      body: goalsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F766E)),
        ),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (goals) {
          final activeGoals = goals.where((g) => !g.isCompleted).toList();
          final completedGoals = goals.where((g) => g.isCompleted).toList();
          final displayGoals = _showCompleted ? completedGoals : activeGoals;

          double totalSaved = displayGoals.fold(
            0,
            (sum, g) => sum + g.currentAmount,
          );
          double totalTarget = displayGoals.fold(
            0,
            (sum, g) => sum + g.targetAmount,
          );
          double summaryProgress = totalTarget > 0
              ? (totalSaved / totalTarget).clamp(0.0, 1.0)
              : 0.0;

          return CustomScrollView(
            slivers: [
              // HEADER
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _buildGradientBackground(),
                    SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          _buildAppBar(),
                          const SizedBox(height: 10),
                          _buildSummaryCard(
                            totalSaved,
                            totalTarget,
                            summaryProgress,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // TAB SELECTOR
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 50,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  child: _buildTabSelector(
                    activeGoals.length,
                    completedGoals.length,
                  ),
                ),
              ),

              // GOAL LIST
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                sliver: displayGoals.isEmpty
                    ? SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 60,
                                  color: Colors.blueGrey.withOpacity(0.3),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _showCompleted
                                      ? "No completed goals yet."
                                      : "No active goals.\nTap + to start saving!",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
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
                          final goal = displayGoals[index];
                          return _buildGoalCard(goal);
                        }, childCount: displayGoals.length),
                      ),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 50),
              ), // bottom padding
            ],
          );
        },
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildGradientBackground() {
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "Financial Goals",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: Colors.white,
                size: 26,
              ),
              onPressed: _showAddGoalSheet,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double saved, double target, double progress) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Total Saved",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _currencyFormat.format(saved),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FFFB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Color(0xFF0F766E),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Target: ${_currencyFormat.format(target)}",
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: const TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF0F766E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(int activeCount, int completedCount) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: _showCompleted
                ? Alignment.centerRight
                : Alignment.centerLeft,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF0EA5A0)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.24),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showCompleted = false),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      "Active ($activeCount)",
                      style: TextStyle(
                        color: _showCompleted
                            ? const Color(0xFF64748B)
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showCompleted = true),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Text(
                      "Completed ($completedCount)",
                      style: TextStyle(
                        color: _showCompleted
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
    final type = getGoalType(goal.category);
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0.0,
      double.infinity,
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
                      goal.name,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Target ${DateFormat('MMM d, yyyy').format(goal.targetDate)}",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!goal.isCompleted)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _confirmDeleteGoal(goal),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFDC2626),
                        size: 28,
                      ),
                      padding: const EdgeInsets.only(right: 12),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () => _showAddSavingsSheet(goal),
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF0F766E),
                        size: 30,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => _confirmDeleteGoal(goal),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFDC2626),
                        size: 28,
                      ),
                      padding: const EdgeInsets.only(right: 12),
                      constraints: const BoxConstraints(),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 30,
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${_currencyFormat.format(goal.currentAmount)} / ${_currencyFormat.format(goal.targetAmount)}",
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: type.color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: type.color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(type.color),
            ),
          ),
          const SizedBox(height: 12),
          if (!goal.isCompleted)
            Text(
              "${_currencyFormat.format(remaining)} remaining to go",
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const Text(
              "Goal achieved! 🎉",
              style: TextStyle(
                color: Color(0xFF0F766E),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
