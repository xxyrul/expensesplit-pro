import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/debt_model.dart';
import '../../services/debt_service.dart';
import '../../utils/category_styles.dart';

class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key});

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final _titleController = TextEditingController();
  final _originalController = TextEditingController();
  final _currentController = TextEditingController();
  final _paymentController = TextEditingController();
  final _interestController = TextEditingController();
  
  String _selectedType = 'Credit Card';
  int _dueDate = 1;
  bool _isSaving = false;

  Future<void> _saveDebt() async {
    final title = _titleController.text.trim();
    final original = double.tryParse(_originalController.text.trim());
    final current = double.tryParse(_currentController.text.trim());
    final payment = double.tryParse(_paymentController.text.trim());
    final interest = double.tryParse(_interestController.text.trim());

    if (title.isEmpty || original == null || current == null || payment == null || interest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields with valid numbers')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final debt = DebtModel(
        title: title,
        type: _selectedType,
        originalBalance: original,
        currentBalance: current,
        monthlyPayment: payment,
        interestRate: interest,
        dueDate: _dueDate,
      );

      await ref.read(debtServiceProvider).addDebt(debt);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Text(
              "Add New Debt",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 20),
            
            // TITLE
            _buildField(_titleController, "Debt Title (e.g. Student Loan)"),
            const SizedBox(height: 15),
            
            // TYPE SELECTOR
            const Text("Debt Type", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: kDebtTypes.keys.map((type) {
                  final style = getDebtType(type);
                  final isSelected = _selectedType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? style.color : const Color(0xFFF8F9FE),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        children: [
                          Icon(style.icon, color: isSelected ? Colors.white : style.color, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            type,
                            style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _buildField(_originalController, "Original Balance (RM)", isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildField(_currentController, "Current Balance (RM)", isNumber: true)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildField(_paymentController, "Monthly Payment (RM)", isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildField(_interestController, "Interest Rate (% APR)", isNumber: true)),
              ],
            ),
            const SizedBox(height: 15),
            
            // DUE DATE
            DropdownButtonFormField<int>(
              value: _dueDate,
              decoration: InputDecoration(
                labelText: "Payment Due Day",
                filled: true,
                fillColor: const Color(0xFFF8F9FE),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              items: List.generate(31, (index) => index + 1).map((day) {
                return DropdownMenuItem(value: day, child: Text("Day $day"));
              }).toList(),
              onChanged: (val) => setState(() => _dueDate = val ?? 1),
            ),

            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveDebt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366f1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isSaving 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Track Debt", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}
