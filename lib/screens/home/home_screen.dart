import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import 'dashboard_view.dart';
import 'add_expense_screen.dart';
import '../../utils/receipt_processing_ui.dart';
import 'budget_view.dart';
import 'settings_view.dart';
import 'expenses_view.dart';
import 'reports_view.dart';
import '../../services/budget_alert_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0;

  // We use a getter for screens so it can access 'setState'
  List<Widget> get _screens => [
    DashboardView(
      onSettingsPressed: () {
        setState(() => _selectedIndex = 4); // Navigate to Settings
      },
      onViewAllPressed: () {
        setState(() => _selectedIndex = 1); // Navigate to Expenses
      },
    ),
    ExpensesView(
      onBack: () {
        setState(() => _selectedIndex = 0); // Back to Dashboard
      },
    ),
    const AddExpenseScreen(),
    BudgetView(
      onBack: () {
        setState(() => _selectedIndex = 0); // Back to Dashboard
      },
    ),
    SettingsView(
      onBack: () {
        setState(() => _selectedIndex = 0); // Back to Dashboard
      },
    ),
    ReportsView(
      onBack: () {
        setState(() => _selectedIndex = 0); // Back to Dashboard
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Keep the budget alert listener alive while HomeScreen is mounted.
    ref.watch(budgetAlertListenerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F8),
      extendBody: true,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            right: -70,
            child: _ambientCircle(
              size: 250,
              color: const Color(0xFF99F6E4).withOpacity(0.35),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -90,
            child: _ambientCircle(
              size: 220,
              color: const Color(0xFFBFDBFE).withOpacity(0.30),
            ),
          ),
          IndexedStack(index: _selectedIndex, children: _screens),
        ],
      ),

      floatingActionButton: Transform.translate(
        offset: const Offset(0, 14),
        child: Container(
          height: 74,
          width: 74,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF0EA5A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              ReceiptProcessingUI.startLiveScanFlow(context);
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            shape: const CircleBorder(),
            child: const Icon(
              Icons.document_scanner_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 26,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _buildNavItem(Icons.home_rounded, "Home", 0)),
              Expanded(
                child: _buildNavItem(
                  Icons.account_balance_wallet_outlined,
                  "Expenses",
                  1,
                ),
              ),
              const SizedBox(width: 54),
              Expanded(
                child: _buildNavItem(
                  Icons.pie_chart_outline_rounded,
                  "Budget",
                  3,
                ),
              ),
              Expanded(
                child: _buildNavItem(Icons.bar_chart_rounded, "Reports", 5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ambientCircle({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? const Color(0xFFE6FFFB) : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF0F766E)
                  : const Color(0xFF64748B),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
