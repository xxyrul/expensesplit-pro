import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    print("AI Analysis disabled. Using offline Regex parser directly.");
    
    return await _offlineParse(rawText);
  }

  /// Self-Learning Engine: Learns the keyword next to the correct amount
  /// when a user manually overrides the total amount.
  Future<void> learnTotalKeyword(String rawText, double correctAmount) async {
    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final amountStr = correctAmount.toStringAsFixed(2);
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains(amountStr)) {
        // Find the words immediately preceding the amount on the same line
        final beforeStr = line.split(amountStr).first.trim().toUpperCase();
        if (beforeStr.isNotEmpty) {
          final words = beforeStr.split(RegExp(r'\s+'));
          final cleanWords = words.map((w) => w.replaceAll(RegExp(r'[^A-Z]'), '')).where((w) => w.isNotEmpty).toList();
          if (cleanWords.isNotEmpty) {
            final takeCount = cleanWords.length > 3 ? 3 : cleanWords.length;
            final keyword = cleanWords.sublist(cleanWords.length - takeCount).join(' ');
            if (keyword.length > 2) {
              await _saveLearnedKeyword(keyword);
              return;
            }
          }
        } else if (i > 0) {
          // If the amount is on a line by itself, learn from the previous line
          final prevLineWords = lines[i - 1].toUpperCase().split(RegExp(r'\s+'));
          final cleanWords = prevLineWords.map((w) => w.replaceAll(RegExp(r'[^A-Z]'), '')).where((w) => w.isNotEmpty).toList();
          if (cleanWords.isNotEmpty) {
            final takeCount = cleanWords.length > 3 ? 3 : cleanWords.length;
            final keyword = cleanWords.sublist(cleanWords.length - takeCount).join(' ');
            if (keyword.length > 2) {
              await _saveLearnedKeyword(keyword);
              return;
            }
          }
        }
      }
    }
  }

  Future<void> _saveLearnedKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> keywords = prefs.getStringList('learned_total_keywords') ?? [];
    if (!keywords.contains(keyword)) {
      keywords.add(keyword);
      await prefs.setStringList('learned_total_keywords', keywords);
      print("Self-Learning Scanner learned new total keyword: \$keyword");
    }
  }

  /// Offline regex-based receipt parser used as a fallback
  static Future<Map<String, dynamic>?> _offlineParse(String rawText) async {
    try {
      final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return null;

      // --- 1. Total amount ---
      double? totalAmount;
      
      final prefs = await SharedPreferences.getInstance();
      final learnedKeywords = prefs.getStringList('learned_total_keywords') ?? [];
      final customKeywordsStr = learnedKeywords.isNotEmpty ? '|' + learnedKeywords.join('|') : '';

      final totalRegex = RegExp(
        r'\b(?:TOTAL|GRAND\s*TOTAL|AMOUNT\s*DUE|AMOUNT\s*PAID|AMOUNT|JUMLAH|JUMLAH\s*BESAR|BAYARAN|NET\s*AMT|NET\s*AMOUNT|PAYABLE|CASH|BALANCE\s*DUE|TOTAL\s*PEMBAYARAN' + customKeywordsStr + r')\b.*?(?:RM|USD|\$)?\s*(\d+\.\d{2})',
        caseSensitive: false,
      );
      final totalMatches = totalRegex.allMatches(rawText);
      if (totalMatches.isNotEmpty) {
        for (var i = totalMatches.length - 1; i >= 0; i--) {
          final val = double.tryParse(totalMatches.elementAt(i).group(1)!);
          if (val != null && val > 0.10) {
            totalAmount = val;
            break;
          }
        }
        if (totalAmount == null) {
          totalAmount = double.tryParse(totalMatches.last.group(1)!);
        }
      }

      // --- 1.5 Handle Column Misalignment ---
      // If no valid total was found on the SAME line as a keyword, check if the amount 
      // was pushed to a completely separate line (common in ML Kit OCR misreads).
      if (totalAmount == null || totalAmount <= 0.10) {
        final lines = rawText.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final keywordRegex = RegExp(r'\b(?:TOTAL|AMOUNT|JUMLAH|BAYARAN|NET|PAYABLE|CASH|DUE' + customKeywordsStr + r')\b', caseSensitive: false);
        final looseNumberRegex = RegExp(r'^(?:RM|USD|\$)?\s*(\d+\.\d{2})$', caseSensitive: false);

        for (int i = lines.length - 1; i > 0; i--) {
          final currentLine = lines[i].trim();
          final prevLine = lines[i - 1].trim();
          
          final match = looseNumberRegex.firstMatch(currentLine);
          if (match != null) {
            final val = double.tryParse(match.group(1)!);
            if (val != null && val > 0.10) {
               // Check if the previous line looks like a total label
               if (keywordRegex.hasMatch(prevLine)) {
                 totalAmount = val;
                 break;
               }
            }
          }
        }
      }

      // --- 2. Vendor / Merchant ---
      // Skip common header words that aren't the store name
      String vendor = 'Unknown Merchant';
      for (final line in lines) {
        final l = line.trim().toUpperCase();
        if (l.contains('INVOICE') || l.contains('RECEIPT') || l == 'TAX' || l == 'CASH' || l.startsWith('TABLE:') || l.startsWith('BILL NO') || l.startsWith('DATE') || l.startsWith('CASHIER') || l.startsWith('PAYMENT') || l.startsWith('TO ') || l.startsWith('ITEM ') || l.startsWith('QTY ')) {
          continue;
        }
        vendor = line.trim();
        break;
      }

      // --- 3. Date ---
      DateTime? parsedDate;

      // DD/MM/YYYY  DD-MM-YYYY  DD.MM.YYYY (supports 2 or 4 digit year)
      final dmyRegex = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})\b');
      // YYYY-MM-DD  YYYY.MM.DD  YYYY/MM/DD
      final ymdRegex = RegExp(r'\b(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})\b');
      // 05 Jun 2026 / 5 June 26
      final textDateRegex = RegExp(
        r'\b(\d{1,2})\s+(Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|Jun(?:e)?|Jul(?:y)?|Aug(?:ust)?|Sep(?:tember)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?)\s+(\d{2,4})\b',
        caseSensitive: false,
      );

      final ymdMatch = ymdRegex.firstMatch(rawText);
      final dmyMatch = dmyRegex.firstMatch(rawText);
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
        int? year = int.tryParse(dmyMatch.group(3)!);
        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
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
    int? year = int.tryParse(match.group(3)!);
    if (day != null && month != null && year != null) {
      if (year < 100) year += 2000;
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
