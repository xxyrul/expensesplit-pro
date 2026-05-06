import 'package:flutter/material.dart';

/// Single source of truth for category colours and icons.
/// Import this wherever a category needs to be displayed.
class CategoryStyle {
  final Color color;
  final IconData icon;
  const CategoryStyle(this.color, this.icon);
}

/// All canonical expense categories.
/// Keys MUST match the strings stored in Firestore / used in ExpenseModel.
const Map<String, CategoryStyle> kCategoryStyles = {
  'Food': CategoryStyle(Color(0xFFf43f5e), Icons.restaurant),
  'Food & Dining': CategoryStyle(Color(0xFFf43f5e), Icons.restaurant),
  'Food & Beverage': CategoryStyle(Color(0xFFf43f5e), Icons.local_dining),
  'Transport': CategoryStyle(Color(0xFF0ea5e9), Icons.directions_bus),
  'Bills': CategoryStyle(Color(0xFF06b6d4), Icons.receipt_long),
  'Shopping': CategoryStyle(Color(0xFF8b5cf6), Icons.shopping_bag),
  'Medical': CategoryStyle(Color(0xFF22c55e), Icons.medical_services),
  'Health': CategoryStyle(Color(0xFF22c55e), Icons.medical_services),
  'Entertainment': CategoryStyle(Color(0xFFa855f7), Icons.movie),
  'Education': CategoryStyle(Color(0xFF6366f1), Icons.school),
  'Books': CategoryStyle(Color(0xFF6366f1), Icons.school),
  'Books & Education': CategoryStyle(Color(0xFF6366f1), Icons.school),
  'Others': CategoryStyle(Color(0xFF9ca3af), Icons.all_inclusive),
  'Other': CategoryStyle(Color(0xFF9ca3af), Icons.all_inclusive),
  'Other Expenses': CategoryStyle(Color(0xFF9ca3af), Icons.all_inclusive),
};

/// Fallback style when a category key is not in the map.
const CategoryStyle kDefaultCategoryStyle = CategoryStyle(
  Color(0xFF64748B),
  Icons.category,
);

/// Convenience helper — never returns null.
CategoryStyle getCategoryStyle(String category) =>
    kCategoryStyles[category] ?? kDefaultCategoryStyle;

/// The canonical list of categories shown in the Add Expense screen.
const List<String> kCategories = [
  'Food',
  'Transport',
  'Bills',
  'Shopping',
  'Health',
  'Entertainment',
  'Education',
  'Others',
];

/// Helper to determine the color of budget progress bars based on percentage.
Color getBudgetProgressColor(double progress) {
  if (progress >= 0.9) return Colors.redAccent;
  if (progress >= 0.75) return Colors.orangeAccent;
  return Colors.greenAccent;
}

// --- GOAL SPECIFIC STYLES ---

class GoalType {
  final String label;
  final IconData icon;
  final Color color;
  const GoalType(this.label, this.icon, this.color);
}

const Map<String, GoalType> kGoalTypes = {
  'Travel': GoalType('Travel', Icons.flight_takeoff, Color(0xFF6366f1)),
  'Savings': GoalType('Savings', Icons.savings, Color(0xFF10b981)),
  'Gadget': GoalType('Gadget', Icons.laptop_mac, Color(0xFF3b82f6)),
  'Home': GoalType('Home', Icons.home, Color(0xFFf59e0b)),
  'Vehicle': GoalType('Vehicle', Icons.directions_car, Color(0xFF64748b)),
  'Education': GoalType('Education', Icons.school, Color(0xFF8b5cf6)),
  'Gift': GoalType('Gift', Icons.card_giftcard, Color(0xFFec4899)),
  'Other': GoalType('Other', Icons.stars, Color(0xFF94a3b8)),
};

GoalType getGoalType(String type) => kGoalTypes[type] ?? kGoalTypes['Other']!;

// --- DEBT SPECIFIC STYLES ---

class DebtType {
  final String label;
  final IconData icon;
  final Color color;
  const DebtType(this.label, this.icon, this.color);
}

const Map<String, DebtType> kDebtTypes = {
  'Credit Card': DebtType('Credit Card', Icons.credit_card, Color(0xFFf43f5e)),
  'Education': DebtType('Education', Icons.school, Color(0xFF6366f1)),
  'Vehicle': DebtType('Vehicle', Icons.directions_car, Color(0xFF64748b)),
  'Home Loan': DebtType('Home', Icons.home, Color(0xFFf59e0b)),
  'Personal': DebtType('Personal', Icons.person, Color(0xFF10b981)),
};

DebtType getDebtType(String type) =>
    kDebtTypes[type] ?? kDebtTypes['Personal']!;
