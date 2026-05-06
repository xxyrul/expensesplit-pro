import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/receipt_scanner_service.dart';
import '../screens/home/add_expense_screen.dart';
import '../screens/home/camera_scanner_view.dart';

class ReceiptProcessingUI {
  /// Opens the high-fidelity live camera scanner screen.
  static Future<void> startLiveScanFlow(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScannerView(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Legacy gallery-pick flow (kept as fallback).
  static Future<void> startScanFlow(BuildContext context, WidgetRef ref) async {
    // 1. Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              color: Color(0xFF6366f1),
            ),
          ),
        );
      },
    );

    // 2. Perform scan
    final scanner = ref.read(receiptScannerProvider);
    final result = await scanner.scanReceipt();

    // 3. Dismiss dialog
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (result != null && context.mounted) {
      final double? amount = result['amount'];
      final String? vendor = result['vendor'];
      final DateTime? date = result['date'];
      final String? rawText = result['rawText'];

      // 4. Navigate to Add Expense with pre-filled items
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddExpenseScreen(
            initialAmount: amount,
            initialVendor: vendor,
            initialDate: date,
            rawText: rawText,
          ),
        ),
      );
    }
  }
}

