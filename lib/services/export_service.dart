import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
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
    final sanitizedMonth = monthLabel.replaceAll(' ', '_');

    if (kIsWeb) {
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'Expenses_$sanitizedMonth.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    final directory = await getTemporaryDirectory();
    final filePath = '${directory.path}/Expenses_$sanitizedMonth.csv';
    final file = File(filePath);

    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(filePath, mimeType: 'text/csv')], text: 'Expense Report for $monthLabel');
  }
}
