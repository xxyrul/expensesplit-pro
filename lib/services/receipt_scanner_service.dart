import 'dart:io';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

final receiptScannerProvider = Provider<ReceiptScannerService>((ref) {
  return ReceiptScannerService();
});

class _TextElement {
  final String text;
  final Rect rect;
  _TextElement(this.text, this.rect);
}

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// ML Kit often returns columnar receipts in separate blocks (labels as one block, amounts as another).
  /// This physically aligns the text items by their vertical Y coordinates to perfectly reconstruct rows.
  static String formatRecognizedText(RecognizedText recognizedText) {
    final elements = <_TextElement>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        elements.add(_TextElement(line.text, line.boundingBox));
      }
    }

    if (elements.isEmpty) return '';

    // Sort heavily by Y, and secondarily by X
    elements.sort((a, b) {
      // If they are roughly on the same line (e.g. within half an element's height), sort horizontally
      final heightAvg = (a.rect.height + b.rect.height) / 2;
      if ((a.rect.top - b.rect.top).abs() < heightAvg * 0.5) {
        return a.rect.left.compareTo(b.rect.left);
      }
      return a.rect.top.compareTo(b.rect.top);
    });

    final sb = StringBuffer();
    _TextElement? prev;
    
    for (final elem in elements) {
      if (prev == null) {
        sb.write(elem.text);
      } else {
        final heightAvg = (prev.rect.height + elem.rect.height) / 2;
        // If on the same horizontal line
        if ((prev.rect.top - elem.rect.top).abs() < heightAvg * 0.5) {
          sb.write(' ');
          sb.write(elem.text);
        } else {
          sb.write('\n');
          sb.write(elem.text);
        }
      }
      prev = elem;
    }
    return sb.toString();
  }

  Future<Map<String, dynamic>?> scanReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      
      if (image == null) {
        return null; // User cancelled
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      return parseReceiptText(formatRecognizedText(recognizedText));
    } catch (e) {
      print("Error scanning receipt: $e");
      return null;
    }
  }

  Map<String, dynamic> parseReceiptText(String text) {
    print("========== OCR TEXT ==========\n\$text\n==============================");
    String? vendor;
    double? amount;

    // Split text into lines, trimming whitespace
    List<String> lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    if (lines.isEmpty) {
      return {'vendor': null, 'amount': null};
    }

    // --- 1. Extract Vendor Name ---
    // Common words to skip when looking for the vendor name
    final skipPatterns = [
      'receipt', 'invoice', 'tax', 'cash', 'copy', 'duplicated', 'store',
      'welcome', 'hello', 'merchant', 'terminal', 'pos', 'visa', 'mastercard',
      'change', 'total', 'amount', 'date', 'time', 'card', 'auth'
    ];
    
    for (String line in lines) {
      final lowerLine = line.toLowerCase();
      // Skip lines without alphabetic characters
      if (!line.contains(RegExp(r'[a-zA-Z]'))) continue;
      
      bool shouldSkip = false;
      for (String pattern in skipPatterns) {
        if (lowerLine.contains(pattern)) {
          shouldSkip = true;
          break;
        }
      }
      
      // Avoid lines that look like a date or time
      if (RegExp(r'\d{2,4}[/.-]\d{2}[/.-]\d{2,4}').hasMatch(line) || 
          RegExp(r'\d{2}:\d{2}').hasMatch(line) ||
          RegExp(r'[\d-]{8,}').hasMatch(line)) {
        shouldSkip = true;
      }

      if (!shouldSkip && line.length >= 3) {
        vendor = line;
        break;
      }
    }
    
    // Fallback if all lines were skipped (rare, but possible)
    vendor ??= lines.first;

    // --- 2. Extract Amount ---
    // Matches numbers with exactly 2 decimal places (e.g. 12.34, 1,234.56, 1.234,56)
    final RegExp amountRegex = RegExp(r'([0-9]+(?:[,.][0-9]{3})*[.,][0-9]{2})');
    double? foundTotal;

    double? parseAmountString(String amtStr) {
      amtStr = amtStr.replaceAll(' ', '');
      final int lastComma = amtStr.lastIndexOf(',');
      final int lastDot   = amtStr.lastIndexOf('.');
      if (lastComma > lastDot) {
        amtStr = amtStr.replaceAll('.', '').replaceAll(',', '.');
      } else if (lastDot > lastComma) {
        amtStr = amtStr.replaceAll(',', '');
      } else if (lastComma != -1) {
        amtStr = amtStr.replaceAll(',', '.');
      }
      return double.tryParse(amtStr);
    }

    // Post-total payment lines — skipped everywhere.
    // NOTE: 'discount' intentionally removed because "TOTAL AFTER DISCOUNT" is valid.
    final noisePatterns = [
      'cash', 'change', 'rounding', 'tender', 'paid',
      'bayaran tunai', 'baki', 'kembalian', 'duit balik',
    ];
    bool isNoise(String lowercaseLine) =>
        noisePatterns.any((p) => lowercaseLine.contains(p));

    // ── TIER 1: Keyword scan ──────────────────────────────────────────────────
    // Highly resilient against OCR misreads for "TOTAL", "JUMLAH", "AMAUN"
    final totalRegex = RegExp(
        r'\b(grand|t0tal|tota1|totai|tota|10tal|total|nett?|payable|amount|jumlah|jum|jumiah|jml|amaun)\b');
    final subtotalRegex = RegExp(r'\b(sub|tax|sst|gst)\b');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].toLowerCase();
      if (isNoise(line)) continue;

      final lineAmounts = amountRegex
          .allMatches(line)
          .map((m) => parseAmountString(m.group(1)!))
          .whereType<double>()
          .toList();

      final bool hasTotalKeyword = totalRegex.hasMatch(line);
      final bool isSubtotal = subtotalRegex.hasMatch(line);

      if (hasTotalKeyword && !isSubtotal) {
        double? matched = lineAmounts.isNotEmpty ? lineAmounts.last : null;
        if (matched == null && i + 1 < lines.length) {
          // Amount may be on the next line
          final nextLine = lines[i + 1].toLowerCase();
          if (!isNoise(nextLine)) {
            final nextAmts = amountRegex
                .allMatches(nextLine)
                .map((m) => parseAmountString(m.group(1)!))
                .whereType<double>()
                .toList();
            if (nextAmts.isNotEmpty) matched = nextAmts.last;
          }
        }
        // Always overwrite — last keyword match wins (grand total is last on receipts)
        if (matched != null) foundTotal = matched;
      }
    }

    // ── TIER 2: Position-based scan ───────────────────────────────────────────
    // ONLY triggered if a noise section (CASH/CHANGE) WAS EXPLICITLY FOUND.
    // If the receipt has a clear CASH boundary, the total is the last amount before it.
    if (foundTotal == null) {
      int noiseStart = -1;
      for (int i = 0; i < lines.length; i++) {
        if (isNoise(lines[i].toLowerCase())) { noiseStart = i; break; }
      }

      if (noiseStart != -1) { // Only do this if a boundary exists!
        for (int i = noiseStart - 1; i >= 0; i--) {
          final line = lines[i].toLowerCase();
          if (subtotalRegex.hasMatch(line) || line.contains('discount')) continue;

          final amts = amountRegex
              .allMatches(line)
              .map((m) => parseAmountString(m.group(1)!))
              .whereType<double>()
              .toList();
          if (amts.isNotEmpty) {
            foundTotal = amts.last;
            break;
          }
        }
      }
    }

    // ── TIER 3: Last-resort ───────────────────────────────────────────────────
    // Take the highest amount. To avoid picking unlabelled "CASH 50.00" lines,
    // we slightly penalize flat notes (10, 20, 50, 100) if a non-flat number exists.
    if (foundTotal == null) {
      final allAmounts = <double>[];
      for (final ln in lines) {
        final l = ln.toLowerCase();
        if (isNoise(l)) continue;
        for (final m in amountRegex.allMatches(l)) {
          final a = parseAmountString(m.group(1)!);
          if (a != null) allAmounts.add(a);
        }
      }
      if (allAmounts.isNotEmpty) {
        allAmounts.sort();
        // If the highest amount is exactly 50.00 or 100.00 and there is another amount,
        // it's highly likely cash tendered. Pick the highest non-flat amount.
        double best = allAmounts.last;
        if (allAmounts.length > 1 && (best == 10.0 || best == 20.0 || best == 50.0 || best == 100.0)) {
          // Take the second highest
          foundTotal = allAmounts[allAmounts.length - 2];
        } else {
          foundTotal = best;
        }
      }
    }

    amount = foundTotal;

    // --- 3. Extract Date ---
    final RegExp dateRegex = RegExp(r'(?<!\d)(\d{1,4})\s*[/.,|lI\-\\]\s*(\d{1,2})\s*[/.,|lI\-\\]\s*(\d{1,4})(?!\d)');
    DateTime? receiptDate;

    for (int i = 0; i < lines.length; i++) {
        final match = dateRegex.firstMatch(lines[i]);
        if (match != null) {
            try {
                int p1 = int.parse(match.group(1)!);
                int p2 = int.parse(match.group(2)!);
                int p3 = int.parse(match.group(3)!);
                
                int year, month, day;
                if (p1 > 1000) { 
                    year = p1; month = p2; day = p3;
                } else if (p3 > 1000) { 
                    year = p3; month = p2; day = p1;
                } else { 
                    year = 2000 + p3; month = p2; day = p1;
                }
                
                // OCR often swaps DD and MM based on US vs Rest-of-World formats
                if (month > 12 && day <= 12) {
                    final temp = month;
                    month = day;
                    day = temp;
                }
                
                if (month > 0 && month <= 12 && day > 0 && day <= 31) {
                    receiptDate = DateTime(year, month, day);
                    break;
                }
            } catch(e) {
                // Ignore parsing issues and keep searching
            }
        }
    }

    print('--- RAW TEXT BEGIN ---');
    print(text);
    print('--- RAW TEXT END ---');
    print('--- PARSED DATE: $receiptDate ---');

    return {
      'vendor': vendor,
      'amount': amount,
      'date': receiptDate,
      'rawText': text,
    };
  }

  void dispose() {
    _textRecognizer.close();
  }
}
