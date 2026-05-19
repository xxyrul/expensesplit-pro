import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audit_log_service.dart';
import '../services/vendor_dictionary_service.dart';

/// Dialog to promote OCR text into the global [ocr_learning] dictionary.
class VendorLearnDialog {
  VendorLearnDialog._();

  static Future<bool?> show(
    BuildContext context,
    WidgetRef ref, {
    String? initialVendor,
    String? initialAlias,
    String initialCategory = 'Food',
    String? ocrLogUserId,
    String? ocrLogDocId,
    Future<void> Function()? onOcrApproved,
  }) {
    final vendorController = TextEditingController(text: initialVendor ?? '');
    final aliasController = TextEditingController(text: initialAlias ?? '');
    var selectedCategory = initialCategory;
    final dictionary = VendorDictionaryService();

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add to global dictionary'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Maps vendor names and OCR noise to categories for all users.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: vendorController,
                      decoration: const InputDecoration(
                        labelText: 'Master vendor name',
                        hintText: "e.g. McDonald's",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aliasController,
                      decoration: const InputDecoration(
                        labelText: 'OCR alias / keyword',
                        hintText: 'e.g. MCDONAL or receipt snippet',
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: kVendorDictionaryCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedCategory = val ?? 'General');
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final master = vendorController.text.trim();
                    if (master.isEmpty) return;

                    try {
                      final alias = aliasController.text.trim();
                      await dictionary.upsertMapping(
                        vendorName: master,
                        category: selectedCategory,
                        aliases: alias.isNotEmpty ? [alias] : [],
                      );

                      if (ocrLogUserId != null &&
                          ocrLogDocId != null &&
                          onOcrApproved != null) {
                        await onOcrApproved();
                      }

                      ref.read(auditLogServiceProvider).logAction(
                            action: 'LEARN_OCR_MAPPING',
                            targetId: ocrLogDocId ?? master,
                            targetType: 'ocr_learning',
                            detail:
                                'Dictionary: "$master" → $selectedCategory${alias.isNotEmpty ? ' (alias: $alias)' : ''}.',
                          );

                      if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                    } catch (e) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text('Save failed: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save mapping'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
