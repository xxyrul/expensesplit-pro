import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../../utils/category_styles.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final target = double.tryParse(targetStr);
    if (target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid target amount')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Create New Goal",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Goal Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Goal Name (e.g. New Laptop)',
              filled: true,
              fillColor: const Color(0xFFF8F9FE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Target Amount
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Target Amount (RM)',
              filled: true,
              fillColor: const Color(0xFFF8F9FE),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Target Date
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FE),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF6366f1), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    "Target Date: ${DateFormat('MMM d, yyyy').format(_selectedDate)}",
                    style: const TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Category / Goal Type Picker
          const Text(
            "What is this for?",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600, fontSize: 14),
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
                      color: isSelected ? type.color : const Color(0xFFF8F9FE),
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
                          color: isSelected ? Colors.white : Colors.blueGrey,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          type.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.blueGrey,
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
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveGoal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Create Goal",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
