import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/debt_model.dart';
import '../../services/debt_service.dart';
import 'modern_bottom_toast.dart';

class UpdateDebtSheet extends ConsumerStatefulWidget {
  final DebtModel debt;
  const UpdateDebtSheet({super.key, required this.debt});

  @override
  ConsumerState<UpdateDebtSheet> createState() => _UpdateDebtSheetState();
}

class _UpdateDebtSheetState extends ConsumerState<UpdateDebtSheet> {
  final _amountController = TextEditingController();
  bool _isSaving = false;

  Future<void> _addPayment() async {
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
      if (widget.debt.id != null) {
        await ref.read(debtServiceProvider).addPayment(widget.debt.id!, amount);
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
            "Add Payment for ${widget.debt.title}",
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
              labelText: 'Payment Amount (RM)',
              prefixText: 'RM ',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: FilledButton(
              onPressed: _isSaving ? null : _addPayment,
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
                      "Add Payment",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
