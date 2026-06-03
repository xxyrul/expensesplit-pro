import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/expense_providers.dart';
import 'dart:ui';

class AiAdvisorCard extends ConsumerWidget {
  const AiAdvisorCard({super.key});

  String _generateInsight(double totalSpent) {
    if (totalSpent < 100) {
      return "You're off to a great start! Your spending is very low this month. Keep it up!";
    } else if (totalSpent <= 500) {
      return "You're on track. A moderate pace keeps you safely within budget.";
    } else {
      return "Spending is getting high. Consider pausing non-essential purchases for a bit!";
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 0.5) return Colors.greenAccent;
    if (progress < 0.8) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendData = ref.watch(monthlyTrendProvider(DateTime.now()));
    final totalSpent = trendData.isEmpty ? 0.0 : trendData.values.fold(0.0, (a, b) => a + b);
    final targetBudget = 1000.0;
    
    if (totalSpent == 0.0) {
      return _buildCard(context, "Start tracking your first expense!", totalSpent, targetBudget, isEmpty: true);
    }
    
    return _buildCard(
      context, 
      "You have spent RM ${totalSpent.toStringAsFixed(0)} this month.\n\n${_generateInsight(totalSpent)}", 
      totalSpent, 
      targetBudget,
      isEmpty: false,
    );
  }

  Widget _buildCard(BuildContext context, String text, double totalSpent, double targetBudget, {bool isEmpty = false}) {
    final progress = (totalSpent / targetBudget).clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.85),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "AI Insights",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (!isEmpty) ...[
                        const SizedBox(height: 15),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor(progress)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "${(progress * 100).toStringAsFixed(0)}% of RM ${targetBudget.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
