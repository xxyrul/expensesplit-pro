import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/budget_service.dart';
import '../../utils/category_styles.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../../theme/brand_theme.dart';

class SetBudgetScreen extends ConsumerStatefulWidget {
  const SetBudgetScreen({super.key});

  @override
  ConsumerState<SetBudgetScreen> createState() => _SetBudgetScreenState();
}

class _SetBudgetScreenState extends ConsumerState<SetBudgetScreen> {
  final _totalController = TextEditingController();
  final List<String> _categories = kCategories;

  final Map<String, TextEditingController> _controllers = {};
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    for (var cat in _categories) {
      _controllers[cat] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _populateExistingData(Map<String, double> budgetData) {
    if (_isInitialized) return;

    if (budgetData.containsKey('Total')) {
      _totalController.text = budgetData['Total']!.toStringAsFixed(0);
    }

    for (var cat in _categories) {
      if (budgetData.containsKey(cat)) {
        _controllers[cat]!.text = budgetData[cat]!.toStringAsFixed(0);
      }
    }
    _isInitialized = true;
  }

  // --- NEW: CLEAR ALL FUNCTION ---
  Future<void> _clearAllBudgets() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Budgets?"),
        content: const Text(
          "This will reset all your limits to zero. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _totalController.clear();
        for (var c in _controllers.values) {
          c.clear();
        }
      });
      // You can optionally call a service method here to delete docs from Firestore
      ModernBottomToast.show(
        context,
        message: 'Form cleared locally. Save to update database.',
        type: ModernToastType.info,
      );
    }
  }

  Future<void> _saveBudgets() async {
    final double? totalLimit = double.tryParse(_totalController.text);
    if (totalLimit == null) {
      ModernBottomToast.show(
        context,
        message: 'Please enter a total budget amount',
        type: ModernToastType.error,
      );
      return;
    }

    Map<String, double> budgetData = {'Total': totalLimit};
    _controllers.forEach((key, controller) {
      final val = double.tryParse(controller.text);
      if (val != null) budgetData[key] = val;
    });

    try {
      await ref.read(budgetServiceProvider).updateBudgets(budgetData);
      if (mounted) {
        Navigator.pop(context);
        ModernBottomToast.show(
          context,
          message: 'Budgets updated successfully!',
          type: ModernToastType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Error: $e',
          type: ModernToastType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: budgetsAsync.when(
        data: (budgetData) {
          _populateExistingData(budgetData);
          final totalBudget = double.tryParse(_totalController.text) ?? 0;
          final filledCategories = _controllers.values
              .where((controller) => controller.text.trim().isNotEmpty)
              .length;
          final categories = _categories;
          debugPrint('Category List Size: ${categories.length}');

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCard(totalBudget, filledCategories),
                      const SizedBox(height: 18),
                      _buildSectionHeader(
                        "Main Monthly Budget",
                        "Set the total amount you want to manage this month.",
                      ),
                      const SizedBox(height: 12),
                      _buildInputCard(
                        "Total Amount",
                        _totalController,
                        Icons.account_balance_wallet,
                        colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        "Category Limits",
                        "Give each spending area a clear limit.",
                      ),
                      const SizedBox(height: 15),
                      ...categories.map((cat) {
                        debugPrint(
                          'SetBudgetScreen: building category input for $cat',
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildInputCard(
                            cat,
                            _controllers[cat]!,
                            getCategoryStyle(cat).icon,
                            getCategoryStyle(cat).color,
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                      _buildSaveButton(),
                      const SizedBox(height: 12),
                      Text(
                        "${filledCategories.toString()} category limits are filled.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Your changes update budgets across the app.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 24,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
              const Expanded(
                child: Text(
                  "Set Monthly Budget",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      onPressed: _clearAllBudgets,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "Shape your monthly limits before you start spending.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(double totalBudget, int filledCategories) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Budget Snapshot",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "RM ${totalBudget.toStringAsFixed(0)}",
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$filledCategories category limits filled",
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(
    String label,
    TextEditingController controller,
    IconData icon,
    Color iconColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 4,
          height: 56,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              prefixText: "RM ",
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: iconColor, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: FilledButton(
        onPressed: _saveBudgets,
        child: const Text(
          "Save Budget Settings",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
