import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  String? _focusExpenseId;

  @override
  void initState() {
    super.initState();
    _syncFcmToken();
    _checkLostData();
  }

  Future<void> _checkLostData() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final picker = ImagePicker();
        final response = await picker.retrieveLostData();
        if (response.isEmpty) {
          return;
        }
        if (response.file != null && mounted) {
          // The app was restarted by Android, but we caught the image!
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(
                capturedImagePath: response.file!.path,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error retrieving lost data: $e");
    }
  }

  Future<void> _syncFcmToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;

      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userRef.set({
        'fcmTokens': FieldValue.arrayUnion([token])
      }, SetOptions(merge: true));
      debugPrint('Sync FCM Token successfully: $token');
    } catch (e) {
      debugPrint('Failed to sync FCM Token: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // We use a getter for screens so it can access 'setState'
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
    final currentScreen = _screens[_selectedIndex];

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
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              key: ValueKey(_selectedIndex),
              children: [
                Positioned(
                  top: -120,
                  right: -70,
                  child: _ambientCircle(
                    size: 250,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  left: -90,
                  child: _ambientCircle(
                    size: 220,
                    color: Theme.of(context).colorScheme.secondary.withOpacity(0.10),
                  ),
                ),
                currentScreen,
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: _selectedIndex == 4
          ? null
          : SafeArea(
              minimum: const EdgeInsets.only(left: 36, right: 36, bottom: 14),
              child: Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 28,
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: isSelected 
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.08) 
              : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
              size: 21,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
