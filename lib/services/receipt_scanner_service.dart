import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';

final receiptScannerProvider = Provider<ReceiptScannerService>((ref) {
  return ReceiptScannerService();
});

class _TextElement {
  final String text;
  final Rect rect;
  _TextElement(this.text, this.rect);
}

class RecognizedTextLine {
  final String text;
  final int index;
  final int totalLines;

  const RecognizedTextLine({
    required this.text,
    required this.index,
    required this.totalLines,
  });
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
      final String rawText = formatRecognizedText(recognizedText);

      return await analyzeTextWithAI(rawText);

    } catch (e) {
      print("Error scanning receipt with Hybrid AI: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> processImageFile(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final String rawText = formatRecognizedText(recognizedText);

      return await analyzeTextWithAI(rawText);
    } catch (e) {
      print("Error processing image file with Hybrid AI: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> analyzeTextWithAI(String rawText) async {
    if (rawText.trim().isEmpty) return null;

    print("========== RAW OCR TEXT ==========\n$rawText\n==============================");

    try {
      // Call Hybrid AI Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('analyzeReceiptText');
      final response = await callable.call({'rawText': rawText});
      
      final Map<String, dynamic> parsedData = Map<String, dynamic>.from(response.data);
      
      // Map JSON to the expected output format
      DateTime? parsedDate;
      if (parsedData['date'] != null) {
        parsedDate = DateTime.tryParse(parsedData['date'].toString());
      }

      return {
        'vendor': parsedData['merchant'],
        'amount': parsedData['total'] is int ? (parsedData['total'] as int).toDouble() : parsedData['total'],
        'date': parsedDate,
        'category': parsedData['category'],
        'rawText': rawText,
        'needsReview': true, // Always allow user to review AI output
      };
    } catch (e) {
      print("AI analysis failed, using offline fallback: $e");
      return _offlineParse(rawText);
    }
  }

  /// Offline regex-based receipt parser used as a fallback when the
  /// Firebase Cloud Function is unavailable (quota exceeded, network error, etc.).
  static Map<String, dynamic>? _offlineParse(String rawText) {
    try {
      final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return null;

      // --- 1. Total amount ---
      double? totalAmount;
      final totalRegex = RegExp(
        r'(?:TOTAL|GRAND\s*TOTAL|AMOUNT\s*DUE|JUMLAH|BAYARAN).*?(?:RM)?\s*(\d+\.\d{2})',
        caseSensitive: false,
      );
      final totalMatches = totalRegex.allMatches(rawText);
      if (totalMatches.isNotEmpty) {
        // Take the LAST match – usually the grand total
        totalAmount = double.tryParse(totalMatches.last.group(1)!);
      }

      // --- 2. Vendor / Merchant ---
      // Skip common header words that aren't the store name
      String vendor = 'Unknown Merchant';
      for (final line in lines) {
        final l = line.trim().toUpperCase();
        if (l.contains('INVOICE') || l.contains('RECEIPT') || l == 'TAX' || l == 'CASH') {
          continue;
        }
        vendor = line.trim();
        break;
      }

      // --- 3. Date ---
      DateTime? parsedDate;

      // DD/MM/YYYY  DD-MM-YYYY  DD.MM.YYYY
      final dmyRegex = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4})');
      // YYYY-MM-DD
      final ymdRegex = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
      // 05 Jun 2026 / 5 June 2026
      final textDateRegex = RegExp(
        r'(\d{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{4})',
        caseSensitive: false,
      );

      final dmyMatch = dmyRegex.firstMatch(rawText);
      final ymdMatch = ymdRegex.firstMatch(rawText);
      final textDateMatch = textDateRegex.firstMatch(rawText);

      if (textDateMatch != null) {
        parsedDate = _parseTextDate(textDateMatch);
      } else if (ymdMatch != null) {
        parsedDate = DateTime.tryParse(
          '${ymdMatch.group(1)}-${ymdMatch.group(2)!.padLeft(2, '0')}-${ymdMatch.group(3)!.padLeft(2, '0')}',
        );
      } else if (dmyMatch != null) {
        final day = int.tryParse(dmyMatch.group(1)!);
        final month = int.tryParse(dmyMatch.group(2)!);
        final year = int.tryParse(dmyMatch.group(3)!);
        if (day != null && month != null && year != null) {
          parsedDate = DateTime.tryParse(
            '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
          );
        }
      }

      // --- 4. Category ---
      final upperVendor = vendor.toUpperCase();
      String category;

      final groceryKeywords = [
        'LOTUS', 'TESCO', 'AEON', 'MYDIN', 'GIANT', '99 SPEEDMART', 'VILLAGE GROCER',
      ];
      final foodKeywords = [
        'RESTAURANT', 'CAFÉ', 'CAFE', 'COFFEE', 'MCDONALD', 'KFC',
      ];

      if (groceryKeywords.any((k) => upperVendor.contains(k))) {
        category = 'Groceries';
      } else if (foodKeywords.any((k) => upperVendor.contains(k))) {
        category = 'Food';
      } else {
        category = 'Other';
      }

      return {
        'vendor': vendor,
        'amount': totalAmount,
        'date': parsedDate,
        'category': category,
        'rawText': rawText,
        'needsReview': true,
      };
    } catch (e) {
      print("Offline fallback parser also failed: $e");
      return null;
    }
  }

  /// Parses a text-style date match like "05 Jun 2026" into a [DateTime].
  static DateTime? _parseTextDate(RegExpMatch match) {
    const months = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    final day = int.tryParse(match.group(1)!);
    final month = months[match.group(2)!.toLowerCase()];
    final year = int.tryParse(match.group(3)!);
    if (day != null && month != null && year != null) {
      return DateTime.tryParse(
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
      );
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
