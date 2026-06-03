import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/expense_model.dart';

class PdfReportService {
  static Future<void> generateAndPrintReport(
    List<ExpenseModel> expenses,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);
    
    final totalSpent = expenses.fold(0.0, (sum, item) => sum + item.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(dateFormat.format(startDate), dateFormat.format(endDate), currencyFormat.format(totalSpent)),
            pw.SizedBox(height: 20),
            _buildTable(expenses, dateFormat, currencyFormat),
          ];
        },
      ),
    );

    // Use printing package to show the native save/share dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ExpenseSplit_Pro_Report_${dateFormat.format(DateTime.now()).replaceAll(' ', '_')}.pdf',
    );
  }

  static pw.Widget _buildHeader(String startDateStr, String endDateStr, String totalSpentStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ExpenseSplit Pro',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Expense Report',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Date Range: $startDateStr - $endDateStr', style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 4),
        pw.Text('Total Spent: $totalSpentStr', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.Divider(color: PdfColors.grey400),
      ],
    );
  }

  static pw.Widget _buildTable(List<ExpenseModel> expenses, DateFormat dateFormat, NumberFormat currencyFormat) {
    if (expenses.isEmpty) {
      return pw.Center(
        child: pw.Text('No expenses found for this date range.', style: pw.TextStyle(fontSize: 16, color: PdfColors.grey600)),
      );
    }

    final headers = ['Date', 'Category', 'Vendor', 'Amount'];
    
    final data = expenses.map((e) {
      return [
        dateFormat.format(e.date),
        e.category,
        e.vendor.isEmpty ? '-' : e.vendor,
        currencyFormat.format(e.amount),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: .5)),
      ),
    );
  }
}
