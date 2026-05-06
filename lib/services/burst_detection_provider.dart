import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/expense_service.dart';
import '../services/budget_service.dart';

/// Represents a category that has exceeded its budget
class BurstCategory {
  final String categoryId;
  final double limit;
  final double spent;
  final double overspend;

  BurstCategory({
    required this.categoryId,
    required this.limit,
    required this.spent,
    required this.overspend,
  });
}

/// Detects categories where currentSpend > allocatedLimit
final burstCategoriesProvider = FutureProvider.autoDispose<List<BurstCategory>>(
  (ref) async {
    final expensesAsync = ref.watch(expensesStreamProvider);
    final budgetsAsync = ref.watch(budgetsStreamProvider);

    final expenses = expensesAsync.when(
      data: (data) => data,
      loading: () => throw Exception('Loading expenses'),
      error: (err, stack) => throw err,
    );

    final budgets = budgetsAsync.when(
      data: (data) => data,
      loading: () => throw Exception('Loading budgets'),
      error: (err, stack) => throw err,
    );

    final now = DateTime.now();
    final currentMonthExpenses = expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();

    final List<BurstCategory> burst = [];

    for (final categoryId in budgets.keys) {
      if (categoryId == 'Total') continue;

      final limit = budgets[categoryId] ?? 0.0;
      if (limit <= 0) continue;

      final spent = currentMonthExpenses
          .where((e) => e.category == categoryId)
          .fold(0.0, (sum, e) => sum + e.amount);

      if (spent > limit) {
        burst.add(
          BurstCategory(
            categoryId: categoryId,
            limit: limit,
            spent: spent,
            overspend: spent - limit,
          ),
        );
      }
    }

    return burst;
  },
);

/// Represents a category with available balance to borrow from
class AvailableCategory {
  final String categoryId;
  final double limit;
  final double spent;
  final double available;

  AvailableCategory({
    required this.categoryId,
    required this.limit,
    required this.spent,
    required this.available,
  });
}

/// Get categories with positive remaining balance (excluding a burst category)
final availableCategoriesProvider = FutureProvider.autoDispose
    .family<List<AvailableCategory>, String?>((ref, excludeCategoryId) async {
      final expensesAsync = ref.watch(expensesStreamProvider);
      final budgetsAsync = ref.watch(budgetsStreamProvider);

      final expenses = expensesAsync.when(
        data: (data) => data,
        loading: () => throw Exception('Loading expenses'),
        error: (err, stack) => throw err,
      );

      final budgets = budgetsAsync.when(
        data: (data) => data,
        loading: () => throw Exception('Loading budgets'),
        error: (err, stack) => throw err,
      );

      final now = DateTime.now();
      final currentMonthExpenses = expenses
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .toList();

      final List<AvailableCategory> available = [];

      for (final categoryId in budgets.keys) {
        if (categoryId == 'Total' || categoryId == excludeCategoryId) {
          continue;
        }

        final limit = budgets[categoryId] ?? 0.0;
        if (limit <= 0) continue;

        final spent = currentMonthExpenses
            .where((e) => e.category == categoryId)
            .fold(0.0, (sum, e) => sum + e.amount);

        final remaining = limit - spent;
        if (remaining > 0) {
          available.add(
            AvailableCategory(
              categoryId: categoryId,
              limit: limit,
              spent: spent,
              available: remaining,
            ),
          );
        }
      }

      return available;
    });
