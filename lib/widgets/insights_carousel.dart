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
        title: "Top Expense",
        subtitle: "RM ${topExpense.amount.toStringAsFixed(2)} at ${topExpense.vendor}",
        icon: Icons.emoji_events_rounded,
        colors: [const Color(0xFFf59e0b), const Color(0xFFfbbf24)],
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
        title: "Frequent Shopper",
        subtitle: "Visited $topVendor $maxCount times",
        icon: Icons.storefront_rounded,
        colors: [const Color(0xFF3b82f6), const Color(0xFF60a5fa)],
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
      cards.add(_buildCard(
        title: "Biggest Category",
        subtitle: "RM ${maxCatSpend.toStringAsFixed(2)} on $topCat",
        icon: getCategoryStyle(topCat!).icon,
        colors: [const Color(0xFFec4899), const Color(0xFFf43f5e)],
        onTap: onTopCategoryTapped != null ? () => onTopCategoryTapped!(topCat!) : null,
      ));
    }

    if (cards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            "Quick Insights",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 15),
            itemBuilder: (context, index) => cards[index],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    VoidCallback? onTap,
  }) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
