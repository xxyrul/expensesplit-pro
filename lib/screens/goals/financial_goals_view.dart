import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../../utils/category_styles.dart';
import '../../widgets/add_goal_sheet.dart';
import '../../widgets/add_savings_sheet.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../../theme/brand_theme.dart';

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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const SingleChildScrollView(
          child: AddGoalSheet(),
        ),
      ),
    );
  }

  void _showAddSavingsSheet(GoalModel goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: AddSavingsSheet(goal: goal),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGoal(GoalModel goal) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Delete Goal"),
        content: Text("Are you sure you want to delete '${goal.name}'?"),
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

    if (confirm == true && goal.id != null) {
      await ref.read(goalServiceProvider).deleteGoal(goal.id!);
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Goal deleted successfully',
          type: ModernToastType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsStreamProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: goalsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: scheme.primary),
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
                                  color: scheme.onSurfaceVariant.withOpacity(0.35),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _showCompleted
                                      ? "No completed goals yet."
                                      : "No active goals.\nTap + to start saving!",
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
              "Financial Goals",
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
                  onPressed: _showAddGoalSheet,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(double saved, double target, double progress) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(22),
      width: double.infinity,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total Saved",
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _currencyFormat.format(saved),
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: scheme.primary,
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
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${(progress * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  color: scheme.primary,
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
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(int activeCount, int completedCount) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: scheme.outlineVariant),
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
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.24),
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
                            ? scheme.onSurfaceVariant
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
                            : scheme.onSurfaceVariant,
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
    final scheme = Theme.of(context).colorScheme;
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
                      goal.name,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Target ${DateFormat('MMM d, yyyy').format(goal.targetDate)}",
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
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
                      icon: Icon(
                        Icons.add_circle,
                        color: scheme.primary,
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
                style: TextStyle(
                  color: scheme.onSurface,
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
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Text(
              "Goal achieved! 🎉",
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
