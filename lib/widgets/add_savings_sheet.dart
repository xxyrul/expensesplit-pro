import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/goal_model.dart';
import '../../services/goal_service.dart';
import '../../providers/goal_providers.dart';
import 'modern_bottom_toast.dart';

class AddSavingsSheet extends ConsumerStatefulWidget {
  final GoalModel goal;
  const AddSavingsSheet({super.key, required this.goal});

  @override
  ConsumerState<AddSavingsSheet> createState() => _AddSavingsSheetState();
}

class _AddSavingsSheetState extends ConsumerState<AddSavingsSheet> {
  final _amountController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addSavings() async {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) {
      ModernBottomToast.show(
        context,
        message: 'Please enter an amount',
        type: ModernToastType.error,
      );
      return;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ModernBottomToast.show(
        context,
        message: 'Please enter a valid amount',
        type: ModernToastType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (widget.goal.id != null) {
        await ref.read(goalServiceProvider).addSavings(widget.goal.id!, amount);
      }
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
            "Add Savings to ${widget.goal.name}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: colorScheme.onSurface),
            decoration: const InputDecoration(
              labelText: 'Amount (RM)',
              prefixText: 'RM ',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: FilledButton(
              onPressed: _isSaving ? null : _addSavings,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: const Color(0xFF10B981).withOpacity(0.35),
                  width: 1.5,
                ),
              ),
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
                      "Add Savings",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
