import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../../utils/category_styles.dart';
import 'modern_bottom_toast.dart';

class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key});

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 30));
  String _selectedCategory = 'Shopping';

  bool _isSaving = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366f1),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveGoal() async {
    final name = _nameController.text.trim();
    final targetStr = _targetController.text.trim();
    
    if (name.isEmpty || targetStr.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Please fill all fields',
        type: ModernToastType.error,
      );
      return;
    }

    final target = double.tryParse(targetStr);
    if (target == null || target <= 0) {
      ModernBottomToast.show(
        context,
        message: 'Please enter a valid target amount',
        type: ModernToastType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final goal = GoalModel(
        name: name,
        targetAmount: target,
        currentAmount: 0.0,
        targetDate: _selectedDate,
        category: _selectedCategory,
      );

      await ref.read(goalServiceProvider).addGoal(goal);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ModernBottomToast.show(
          context,
          message: 'Error: $e',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? colorScheme.outlineVariant : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Create New Goal",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          // Goal Name
          TextField(
            controller: _nameController,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: const InputDecoration(
              labelText: 'Goal Name (e.g. New Laptop)',
            ),
          ),
          const SizedBox(height: 15),
          // Target Amount
          TextField(
            controller: _targetController,
            style: TextStyle(color: colorScheme.onSurface),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target Amount (RM)',
            ),
          ),
          const SizedBox(height: 15),
          // Target Date
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "Target Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}",
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Category / Goal Type Picker
          Text(
            "What is this for?",
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kGoalTypes.length,
              itemBuilder: (context, index) {
                final type = kGoalTypes.values.elementAt(index);
                final isSelected = _selectedCategory == type.label;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = type.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 15),
                    width: 75,
                    decoration: BoxDecoration(
                      color: isSelected ? type.color : (isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFF8F9FE)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? type.color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          type.icon,
                          color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 30),
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveGoal,
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Create Goal",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
