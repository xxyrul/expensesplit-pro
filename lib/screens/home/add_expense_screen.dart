import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/vendor_intelligence_service.dart';
import '../../widgets/scan_receipt_button.dart';
import '../../utils/category_styles.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialVendor;
  final DateTime? initialDate;
  final String? rawText;
  final String? capturedImagePath;

  const AddExpenseScreen({
    super.key,
    this.initialAmount,
    this.initialVendor,
    this.initialDate,
    this.rawText,
    this.capturedImagePath,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _vendorController;
  String _selectedCategory = 'Food';
  DateTime _selectedDate = DateTime.now(); // Automatically sets today's date
  bool _isAiCategory = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount != null ? widget.initialAmount.toString() : '',
    );
    _vendorController = TextEditingController(text: widget.initialVendor ?? '');

    if (widget.initialDate != null) {
      _selectedDate = widget.initialDate!;
    } else {
      _selectedDate = DateTime.now();
    }

    _checkSmartVendor();
  }

  Future<void> _checkSmartVendor() async {
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

  // Category styles come from the shared utility (category_styles.dart)
  // so colours/icons are always consistent with the rest of the app.

  // Date Picker Logic
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F766E),
              onPrimary: Colors.white,
              onSurface: Colors.black,
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

  void _submitData() async {
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

    final newExpense = ExpenseModel(
      amount: enteredAmount,
      vendor: enteredVendor, // Saves names like "Zus Coffee"
      category: _selectedCategory,
      date: _selectedDate, // Saves either the auto-date or manually picked date
    );

    try {
      await ref.read(expenseServiceProvider).addExpense(newExpense);

      final vendorService = ref.read(vendorIntelligenceServiceProvider);
      // AI Logic: Save user's selected category for this vendor
      await vendorService.saveVendorCategory(enteredVendor, _selectedCategory);

      // AI Logic: Check for OCR corrections
      if (widget.initialAmount != null && widget.rawText != null) {
        if (widget.initialAmount != enteredAmount) {
          await vendorService.logOcrCorrection(
            rawText: widget.rawText!,
            systemSuggestedAmount: widget.initialAmount!,
            userCorrectedAmount: enteredAmount,
          );
        }
      }

      if (mounted) {
        _showSnackBar("Expense Saved Successfully!");
        // Returns to Home (bypassing any intermediate screens like camera scanner)
        // and refreshes the list
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) _showSnackBar("Error saving expense: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),

            const SizedBox(height: 20),

            // 1. AMOUNT CARD
            _buildInputCard(
              label: "Amount",
              child: Row(
                children: [
                  const Text(
                    "RM ",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
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
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "0.00",
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. VENDOR/MERCHANT CARD
            _buildInputCard(
              label: "Merchant / Vendor",
              child: TextField(
                controller: _vendorController,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: "e.g. Starbucks, Zus Coffee",
                  icon: Icon(Icons.storefront, color: Color(0xFF0F766E)),
                ),
              ),
            ),

            // 3. DATE PICKER CARD
            _buildInputCard(
              label: "Date",
              child: InkWell(
                onTap: () => _selectDate(context),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: Color(0xFF0F766E),
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

            // 4. CATEGORY GRID
            _buildCategorySection(),

            const SizedBox(height: 30),

            // AI SCAN BUTTON
            const ScanReceiptButton(),

            const SizedBox(height: 15),

            // 5. SAVE BUTTON
            _buildGradientSaveButton(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard({required String label, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
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
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF134E4A), Color(0xFF0F766E), Color(0xFF0EA5A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                },
              ),
              const Text(
                "Add Expense",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (hasImage)
            Hero(
              tag: 'receipt_image',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(
                  File(widget.capturedImagePath!),
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                border: Border.all(color: Colors.white.withOpacity(0.24)),
                borderRadius: BorderRadius.circular(25),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
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
                    _isAiCategory = false; // User manually changed category
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? style.color
                        : style.color.withOpacity(0.06),
                    border: Border.all(
                      color: isSelected
                          ? style.color
                          : style.color.withOpacity(0.18),
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
                          color: isSelected ? Colors.white : style.color,
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
    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0EA5A0)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submitData,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: const Text(
          "Save Expense",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
