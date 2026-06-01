import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/vendor_intelligence_service.dart';
import '../../widgets/scan_receipt_button.dart';
import '../../utils/category_styles.dart';
import '../../widgets/modern_bottom_toast.dart';
import '../../theme/brand_theme.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialVendor;
  final DateTime? initialDate;
  final String? initialCategory;
  final String? rawText;
  final String? capturedImagePath;
  final String? expenseIdToEdit;
  final bool showScanSuccessBanner;
  final bool needsReview;

  const AddExpenseScreen({
    super.key,
    this.initialAmount,
    this.initialVendor,
    this.initialDate,
    this.initialCategory,
    this.rawText,
    this.capturedImagePath,
    this.expenseIdToEdit,
    this.showScanSuccessBanner = false,
    this.needsReview = false,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _vendorController;
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now();
  bool _isAiCategory = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toStringAsFixed(2)
          : '',
    );
    _vendorController = TextEditingController(text: widget.initialVendor ?? '');

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    } else {
      _selectedDate = DateTime.now();
    }

    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }

    _checkSmartVendor();

    if (widget.showScanSuccessBanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ModernBottomToast.show(
            context,
            message: 'Receipt scanned successfully',
            type: ModernToastType.success,
          );
        }
      });
    }
  }

  Future<void> _checkSmartVendor() async {
    if (widget.expenseIdToEdit != null) return;
    if (widget.initialVendor != null && widget.initialVendor!.isNotEmpty) {
      final vendorService = ref.read(vendorIntelligenceServiceProvider);
      final category = await vendorService.getCategoryForVendor(
        widget.initialVendor!,
      );
      if (category != null && mounted) {
        setState(() {
          _selectedCategory = category;
          _isAiCategory = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _vendorController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final theme = Theme.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: theme.colorScheme.primary,
              onPrimary: theme.colorScheme.onPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showSnackBar(String message) {
    ModernBottomToast.show(
      context,
      message: message,
      type: ModernToastType.error,
    );
  }

  void _submitData() async {
    if (_isSaving) return;
    final enteredAmount = double.tryParse(_amountController.text);
    final enteredVendor = _vendorController.text.trim();

    if (enteredAmount == null || enteredAmount <= 0) {
      _showSnackBar("Please enter a valid amount");
      return;
    }

    if (enteredVendor.isEmpty) {
      _showSnackBar("Please enter a merchant name");
      return;
    }

    // Basic validation: vendor should contain at least one letter to avoid numeric-only values
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(enteredVendor);
    if (!hasLetter) {
      _showSnackBar("Please enter a valid merchant name (letters required)");
      return;
    }

    final newExpense = ExpenseModel(
      amount: enteredAmount,
      vendor: enteredVendor,
      category: _selectedCategory,
      date: _selectedDate,
      needsReview: widget.needsReview,
    );

    setState(() => _isSaving = true);
    try {
      final svc = ref.read(expenseServiceProvider);
      if (widget.expenseIdToEdit != null) {
        // Edit mode
        await svc.updateExpense(widget.expenseIdToEdit!, newExpense);
      } else {
        // Add mode
        await svc.addExpense(newExpense);
      }

      final vendorService = ref.read(vendorIntelligenceServiceProvider);
      await vendorService.saveVendorCategory(enteredVendor, _selectedCategory);

      // AI Logic: Check for OCR corrections (amount and/or vendor)
      if (widget.rawText != null) {
        final amountChanged =
            widget.initialAmount != null &&
            widget.initialAmount != enteredAmount;
        final vendorChanged =
            widget.initialVendor != null &&
            widget.initialVendor != enteredVendor;

        if (amountChanged || vendorChanged) {
          await vendorService.logOcrCorrection(
            rawText: widget.rawText!,
            systemSuggestedAmount: widget.initialAmount ?? enteredAmount,
            userCorrectedAmount: enteredAmount,
            systemSuggestedVendor: widget.initialVendor,
            userCorrectedVendor: enteredVendor,
          );
        }
      }

      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Expense saved successfully',
          type: ModernToastType.success,
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.startsWith('Exception: Failed to save:')) {
          msg = msg.replaceFirst('Exception: ', '');
        } else {
          msg = 'Failed to save: $e';
        }
        ModernBottomToast.show(
          context,
          message: msg,
          type: ModernToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF3F7F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildInputCard(
              label: "Amount",
              child: Row(
                children: [
                  Text(
                    "RM ",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "0.00",
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white24 : Colors.grey[400],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildInputCard(
              label: "Merchant / Vendor",
              child: TextField(
                controller: _vendorController,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: "e.g. Starbucks, Zus Coffee",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
                  icon: Icon(
                    Icons.storefront,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            _buildInputCard(
              label: "Date",
              child: InkWell(
                onTap: () => _selectDate(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 15),
                    Text(
                      DateFormat('dd MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            _buildCategorySection(),
            const SizedBox(height: 10),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 10,
          top: 10,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color(0xFFF3F7F8),
          boxShadow: [
            if (isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: ScanReceiptButton(),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: _buildGradientSaveButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required String label, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final bool hasImage = widget.capturedImagePath != null;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: context.brandHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.of(context).pushReplacementNamed('/');
                      }
                    },
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.expenseIdToEdit != null
                      ? "Edit Expense"
                      : "Add Expense",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          if (hasImage)
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FullScreenImageViewer(
                    imagePath: widget.capturedImagePath!,
                  ),
                ),
              ),
              child: Hero(
                tag: 'receipt_image',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      Image.file(
                        File(widget.capturedImagePath!),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  Icons.zoom_out_map,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              SizedBox(width: 4),
                              Text(
                                'Tap to expand',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    "Manual Entry Mode",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                "Category",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isAiCategory) ...[
                const SizedBox(width: 8),
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                const Text(
                  "Auto-filled",
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 15),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: kCategories.length,
            itemBuilder: (context, index) {
              final key = kCategories[index];
              final style = getCategoryStyle(key);
              final isSelected = _selectedCategory == key;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = key;
                    _isAiCategory = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? style.color
                        : (isDark
                              ? style.color.withOpacity(0.12)
                              : style.color.withOpacity(0.06)),
                    border: Border.all(
                      color: isSelected
                          ? style.color
                          : (isDark
                                ? style.color.withOpacity(0.35)
                                : style.color.withOpacity(0.18)),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? style.color.withOpacity(0.22)
                            : Colors.black.withOpacity(0.02),
                        blurRadius: isSelected ? 10 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        style.icon,
                        color: isSelected ? Colors.white : style.color,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? style.color.withOpacity(0.9)
                                    : style.color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGradientSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: _isSaving ? null : _submitData,
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                "Save Expense",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen image viewer with pinch-to-zoom
// ─────────────────────────────────────────────────────────────────────────────
class _FullScreenImageViewer extends StatelessWidget {
  final String imagePath;
  const _FullScreenImageViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Receipt',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Hero(tag: 'receipt_image', child: Image.file(File(imagePath))),
        ),
      ),
    );
  }
}
