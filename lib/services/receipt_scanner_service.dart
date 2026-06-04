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
    try {
      if (rawText.trim().isEmpty) return null;

      print("========== RAW OCR TEXT ==========\n$rawText\n==============================");
      
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
      print("Error analyzing text with Hybrid AI: $e");
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
  }
}
