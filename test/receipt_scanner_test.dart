import 'package:flutter_test/flutter_test.dart';
import 'package:expensesplit_pro/services/receipt_scanner_service.dart';

void main() {
  group('parseReceiptText', () {
    test('parses vendor and amount from simple text', () {
      final text = '''
My Shop
Some address
Total RM 74.23
Thank you''';
      final res = ReceiptScannerService.parseReceiptText(text);
      expect(res['vendor'], isNotNull);
      expect((res['amount'] as double?) ?? 0.0, closeTo(74.23, 0.01));
    });

    test('handles amount on next line', () {
      final text = '''
STORE NAME
TOTAL
74.23
''';
      final res = ReceiptScannerService.parseReceiptText(text);
      expect((res['amount'] as double?) ?? 0.0, closeTo(74.23, 0.01));
    });

    test('returns null amount for no amounts', () {
      final text = 'Just some text without numbers or totals';
      final res = ReceiptScannerService.parseReceiptText(text);
      expect(res['amount'], isNull);
    });
  });
}
