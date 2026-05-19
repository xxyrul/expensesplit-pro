import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/receipt_scanner_service.dart';
import '../../utils/receipt_processing_ui.dart';

class ScanReceiptButton extends ConsumerStatefulWidget {
  const ScanReceiptButton({super.key});

  @override
  ConsumerState<ScanReceiptButton> createState() => _ScanReceiptButtonState();
}

class _ScanReceiptButtonState extends ConsumerState<ScanReceiptButton> {
  bool _isProcessing = false;

  Future<void> _handleScan() async {
    // Open the new live camera scanner screen instead of the old generic image picker
    await ReceiptProcessingUI.startLiveScanFlow(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return SizedBox(
      height: 50,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _handleScan,
        icon: const Icon(Icons.document_scanner),
        label: const Text(
          "Scan AI Receipt",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
