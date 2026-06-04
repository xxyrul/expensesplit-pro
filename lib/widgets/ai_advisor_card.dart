import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../providers/expense_providers.dart';
import '../../providers/budget_providers.dart';
import 'dart:ui';
import 'modern_bottom_toast.dart';

class AiAdvisorCard extends ConsumerWidget {
  final double totalSpent;
  final String dateStr;
  
  const AiAdvisorCard({
    super.key,
    required this.totalSpent,
    required this.dateStr,
  });

  String _generateInsight(double totalSpent, double targetBudget) {
    if (totalSpent == 0) return "Start tracking your first expense to get tips!";
    if (totalSpent < targetBudget * 0.5) return "Great job! You've spent less than half your budget. Keep saving!";
    if (totalSpent <= targetBudget * 0.9) return "You're getting close to your limit. Time to cut back on non-essentials.";
    if (totalSpent <= targetBudget) return "Warning! You are right at your budget limit. Freeze spending if possible.";
    return "You've exceeded your budget this month! Let's plan better for next month.";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendData = ref.watch(monthlyTrendProvider(DateTime.now()));
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    
    final targetBudget = budgetsAsync.maybeWhen(
      data: (budgets) => (budgets['Total'] != null && budgets['Total']! > 0) ? budgets['Total']! : 1000.0,
      orElse: () => 1000.0,
    );
    
    final isDefaultBudget = budgetsAsync.maybeWhen(
      data: (budgets) => (budgets['Total'] == null || budgets['Total'] == 0),
      orElse: () => true,
    );
    
    if (totalSpent == 0.0) {
      return _buildCard(
        context, 
        Text(
          "Start tracking your first expense!",
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ), 
        totalSpent, 
        targetBudget, 
        isDefaultBudget, 
        isEmpty: true
      );
    }
    
    final localAdvice = _generateInsight(totalSpent, targetBudget);
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final todayStr = dateStr;

    if (userId == null) {
      return _buildCard(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "You have used RM ${totalSpent.toStringAsFixed(0)} of your RM ${targetBudget.toStringAsFixed(0)} monthly limit.\n",
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              localAdvice,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        totalSpent,
        targetBudget,
        isDefaultBudget,
        isEmpty: false,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('daily_insights')
          .doc(todayStr)
          .snapshots(),
      builder: (context, snapshot) {
        String displayInsight = localAdvice;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['insight'] != null && data['insight'].toString().isNotEmpty) {
            displayInsight = data['insight'];
          }
        }

        return _buildCard(
          context, 
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "You have used RM ${totalSpent.toStringAsFixed(0)} of your RM ${targetBudget.toStringAsFixed(0)} monthly limit.\n",
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                displayInsight,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ), 
          totalSpent, 
          targetBudget,
          isDefaultBudget,
          isEmpty: false,
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, Widget contentWidget, double totalSpent, double targetBudget, bool isDefaultBudget, {bool isEmpty = false}) {
    final progress = (totalSpent / targetBudget).clamp(0.0, 1.0);
    final progressColor = totalSpent <= targetBudget ? Colors.green : Colors.red;
    
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
                GestureDetector(
                  onTap: () async {
                    try {
                      ModernBottomToast.show(
                        context,
                        message: 'Generating new AI insight...',
                        type: ModernToastType.info,
                      );
                      final callable = FirebaseFunctions.instance.httpsCallable('generateDailyInsight');
                      await callable.call({
                        'dateStr': dateStr,
                        'currentMonthSpent': totalSpent,
                        'monthlyBudget': targetBudget
                      });
                    } catch (e) {
                      if (context.mounted) {
                        ModernBottomToast.show(
                          context,
                          message: 'Failed to fetch AI insight. Try again later.',
                          type: ModernToastType.error,
                        );
                      }
                    }
                  },
                  child: Container(
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
                      contentWidget,
                      if (isDefaultBudget) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Set your budget in Profile to track goals.",
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (!isEmpty) ...[
                        const SizedBox(height: 15),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
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
