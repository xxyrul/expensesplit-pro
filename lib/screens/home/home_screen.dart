import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import 'dashboard_view.dart';
import 'add_expense_screen.dart';
import 'expenses_view.dart';
import 'settings_view.dart';
import '../goals/financial_goals_view.dart';
import '../../services/budget_alert_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;
  String? _focusExpenseId;

  @override
  void initState() {
    super.initState();
  }

  List<Widget> get _screens => [
    DashboardView(
      onSettingsPressed: () {
        setState(() => _selectedIndex = 4);
      },
      onViewAllPressed: () {
        setState(() {
          _focusExpenseId = null;
          _selectedIndex = 1;
        });
      },
      onExpenseTap: (expense) {
        setState(() {
          _focusExpenseId = expense.id;
          _selectedIndex = 1;
        });
      },
    ),
    ExpensesView(
      focusExpenseId: _focusExpenseId,
      onFocusHandled: () {
        if (_focusExpenseId != null) {
          setState(() => _focusExpenseId = null);
        }
      },
      onBack: () {
        setState(() {
          _focusExpenseId = null;
          _selectedIndex = 0;
        });
      },
    ),
    const AddExpenseScreen(),
    const FinancialGoalsView(),
    SettingsView(
      onBack: () {
        setState(() => _selectedIndex = 0);
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(budgetAlertListenerProvider);

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _focusExpenseId = null;
          _selectedIndex = 0;
        });
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: _selectedIndex == 2 
            ? null 
            : _buildStitchBottomNav(),
      ),
    );
  }

  Widget _buildStitchBottomNav() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0057C3).withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, "Home", 0),
          _buildNavItem(Icons.receipt_long_rounded, "History", 1),
          _buildNavItem(Icons.add_circle_outline_rounded, "Add", 2),
          _buildNavItem(Icons.track_changes_rounded, "Goals", 3),
          _buildNavItem(Icons.person_outline_rounded, "Profile", 4),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () {
        // If "Add" is tapped, we push it to keep the bottom nav hidden naturally
        if (index == 2) {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
        } else {
           setState(() => _selectedIndex = index);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F0FE) : Colors.transparent, // Soft blue pill
          borderRadius: BorderRadius.circular(999),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0057C3) : colorScheme.outline,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0057C3) : colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
