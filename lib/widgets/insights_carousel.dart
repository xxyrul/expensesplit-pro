import 'package:flutter/material.dart';
import '../../models/expense_model.dart';
import '../../utils/category_styles.dart';

class InsightsCarousel extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final void Function(ExpenseModel)? onTopExpenseTapped;
  final void Function(String)? onFrequentVendorTapped;
  final void Function(String)? onTopCategoryTapped;

  const InsightsCarousel({
    super.key,
    required this.expenses,
    this.onTopExpenseTapped,
    this.onFrequentVendorTapped,
    this.onTopCategoryTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final List<Widget> cards = [];

    // 1. Top Single Expense
    ExpenseModel? topExpense;
    for (var e in expenses) {
      if (topExpense == null || e.amount > topExpense.amount) {
        topExpense = e;
      }
    }
    if (topExpense != null) {
      cards.add(_buildCard(
        context,
        title: "Top Expense",
        subtitle: "RM ${topExpense.amount.toStringAsFixed(2)} at ${topExpense.vendor}",
        icon: Icons.emoji_events_rounded,
        accentColor: colorScheme.primary,
        onTap: onTopExpenseTapped != null ? () => onTopExpenseTapped!(topExpense!) : null,
      ));
    }

    // 2. Frequent Merchant
    final vendorCounts = <String, int>{};
    for (var e in expenses) {
      if (e.vendor.isNotEmpty) {
        vendorCounts[e.vendor] = (vendorCounts[e.vendor] ?? 0) + 1;
      }
    }
    String? topVendor;
    int maxCount = 0;
    vendorCounts.forEach((v, c) {
      if (c > maxCount) {
        maxCount = c;
        topVendor = v;
      }
    });

    if (topVendor != null && maxCount > 1) {
      cards.add(_buildCard(
        context,
        title: "Frequent Shopper",
        subtitle: "Visited $topVendor $maxCount times",
        icon: Icons.storefront_rounded,
        accentColor: colorScheme.secondary,
        onTap: onFrequentVendorTapped != null ? () => onFrequentVendorTapped!(topVendor!) : null,
      ));
    }

    // 3. Top Category
    final catTotals = <String, double>{};
    for (var e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    String? topCat;
    double maxCatSpend = 0;
    catTotals.forEach((c, amt) {
      if (amt > maxCatSpend) {
        maxCatSpend = amt;
        topCat = c;
      }
    });

    if (topCat != null) {
      final style = getCategoryStyle(topCat!);
      cards.add(_buildCard(
        context,
        title: "Biggest Category",
        subtitle: "RM ${maxCatSpend.toStringAsFixed(2)} on $topCat",
        icon: style.icon,
        accentColor: style.color,
        onTap: onTopCategoryTapped != null ? () => onTopCategoryTapped!(topCat!) : null,
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            "Quick Insights",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(
          height: 94,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => cards[index],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withOpacity(0.15)),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title.toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
}
