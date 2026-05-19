import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import 'dart:ui';

class AiAdvisorCard extends StatelessWidget {
  final List<ExpenseModel> expenses;

  const AiAdvisorCard({super.key, required this.expenses});

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    String advice = _generateAdvice(expenses);

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
                        "AI Advisor",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        advice,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

  String _generateAdvice(List<ExpenseModel> expenses) {
    final catTotals = <String, double>{};
    for (var e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    String topCat = "General";
    double maxCatSpend = 0;
    
    catTotals.forEach((c, amt) {
      if (amt > maxCatSpend) {
        maxCatSpend = amt;
        topCat = c;
      }
    });

    if (topCat == "Food") {
      return "You spent RM ${maxCatSpend.toStringAsFixed(0)} on Food! Consider meal prepping this week to save an easy RM 150.";
    } else if (topCat == "Transport") {
      return "High transport costs (RM ${maxCatSpend.toStringAsFixed(0)}). A monthly transit pass might be cheaper depending on your routes.";
    } else if (topCat == "Entertainment") {
      return "Having fun is great, but Entertainment took the #1 spot at RM ${maxCatSpend.toStringAsFixed(0)}. Watch your budget!";
    } else if (topCat == "Shopping") {
      return "RM ${maxCatSpend.toStringAsFixed(0)} on Shopping! Try waiting 48 hours before your next non-essential purchase.";
    } else {
      return "Your biggest expense area is $topCat at RM ${maxCatSpend.toStringAsFixed(0)}. Keep tracking your receipts to find savings!";
    }
  }
}
