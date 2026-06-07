import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/brand_theme.dart';
import '../../services/auth_service.dart';
import '../home/set_budget_screen.dart';

class UserOnboardingScreen extends ConsumerStatefulWidget {
  const UserOnboardingScreen({super.key});

  @override
  ConsumerState<UserOnboardingScreen> createState() => _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends ConsumerState<UserOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Prefill the name if it's available in the user object
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(userProfileProvider).value;
      if (user != null) {
        _nameController.text = user.displayName;
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a display name"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw 'No user found';

      final updates = <String, dynamic>{
        'displayName': _nameController.text.trim(),
        'hasCompletedOnboarding': true,
      };

      final rawBudgetText = _budgetController.text.trim();
      if (rawBudgetText.isNotEmpty) {
        // Remove everything except numbers, dots and commas
        String cleaned = rawBudgetText.replaceAll(RegExp(r'[^0-9.,]'), '');
        // Replace commas with dots
        cleaned = cleaned.replaceAll(',', '.');
        
        final budget = double.tryParse(cleaned);
        if (budget != null) {
          updates['monthlyBudget'] = budget;
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .update(updates);

      if (updates.containsKey('monthlyBudget')) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .collection('budgets')
            .doc('Total')
            .set({'limit': updates['monthlyBudget']}, SetOptions(merge: true));
            
        if (mounted) {
          final shouldSetLimits = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Budget Saved!'),
              content: const Text('Would you like to divide your monthly budget into specific category limits (e.g. Food, Transport) now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Maybe Later'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Set Category Limits'),
                ),
              ],
            ),
          );

          // Update onboarding status AFTER dialog
          await FirebaseFirestore.instance
              .collection('users')
              .doc(authUser.uid)
              .update({'hasCompletedOnboarding': true});

          if (shouldSetLimits == true && mounted) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SetBudgetScreen()));
          }
        }
      } else {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .update({'hasCompletedOnboarding': true});
      }
          
      // The AuthWrapper will automatically react to this change and navigate to HomeScreen
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving profile: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Force using the next button
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _buildProfileSetupPage(colorScheme, isDark),
                  _buildFeaturePage(
                    title: 'Track Expenses',
                    description: 'Log your expenses quickly and categorize them to see where your money goes.',
                    icon: Icons.receipt_long_rounded,
                    colorScheme: colorScheme,
                  ),
                  _buildFeaturePage(
                    title: 'Manage Groups & Debts',
                    description: 'Create groups for trips or roommates, and let the app calculate exactly who owes who.',
                    icon: Icons.group_add_rounded,
                    colorScheme: colorScheme,
                  ),
                  _buildFeaturePage(
                    title: 'Achieve Goals',
                    description: 'Set a monthly budget and get actionable reports to reach your financial goals faster.',
                    icon: Icons.track_changes_rounded,
                    colorScheme: colorScheme,
                  ),
                ],
              ),
            ),
            
            // Bottom Controls
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainer : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 16,
                  )
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Indicators
                    Row(
                      children: List.generate(4, (index) {
                        final isActive = _currentPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(right: 8),
                          height: 8,
                          width: isActive ? 24 : 8,
                          decoration: BoxDecoration(
                            color: isActive 
                                ? colorScheme.primary 
                                : colorScheme.outlineVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    
                    // Next / Start Button
                    FilledButton(
                      onPressed: _isLoading ? null : _nextPage,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : Text(
                            _currentPage == 3 ? "Get Started" : "Next",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSetupPage(ColorScheme colorScheme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, size: 30, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          Text(
            "Welcome aboard! \nLet's set up your profile.",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Tell us what to call you and optionally set a monthly budget goal.",
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Display Name",
              hintText: "E.g., John Doe",
              prefixIcon: Icon(Icons.badge_outlined, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _budgetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Monthly Budget (Optional)",
              hintText: "E.g., 2000",
              prefixIcon: Icon(Icons.attach_money_rounded, color: colorScheme.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage({
    required String title,
    required String description,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 60, color: colorScheme.primary),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
