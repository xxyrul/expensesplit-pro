import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/expense_model.dart';

final exportServiceProvider = Provider<ExportService>((ref) {
  return ExportService();
});

class ExportService {
  Future<void> exportExpensesToCsv(List<ExpenseModel> expenses, String monthLabel) async {
    if (expenses.isEmpty) return;

    List<List<dynamic>> rows = [];
    
    // Header Row
    rows.add(["Date", "Merchant", "Category", "Amount"]);

    // Data Rows
    for (var exp in expenses) {
      rows.add([
        DateFormat('dd MMM yyyy').format(exp.date),
        exp.vendor,
        exp.category,
        exp.amount.toStringAsFixed(2),
      ]);
    }

    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final sanitizedMonth = monthLabel.replaceAll(' ', '_');
    final filePath = '\${directory.path}/Expenses_\$sanitizedMonth.csv';
    final file = File(filePath);

    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(filePath)], text: 'Expense Report for \$monthLabel');
  }
}
