import 'package:flutter/foundation.dart';
import '../utils/category_styles.dart';

class _NaiveBayesEngine {
  final Map<String, int> _categoryCounts = {};
  final Map<String, Map<String, int>> _wordCounts = {};
  final Set<String> _vocabulary = {};
  int _totalDocuments = 0;

  void add(String category, List<String> tokens) {
    _categoryCounts[category] = (_categoryCounts[category] ?? 0) + 1;
    _wordCounts[category] ??= {};
    for (final token in tokens) {
      _wordCounts[category]![token] = (_wordCounts[category]![token] ?? 0) + 1;
      _vocabulary.add(token);
    }
    _totalDocuments++;
  }

  Map<String, double> classify(List<String> tokens) {
    final result = <String, double>{};
    if (_totalDocuments == 0) return result;

    double sum = 0.0;
    for (final category in _categoryCounts.keys) {
      double prob = _categoryCounts[category]! / _totalDocuments; 
      
      final int totalWordsInCategory = _wordCounts[category]!.values.fold(0, (a, b) => a + b);
      final int vocabSize = _vocabulary.length;

      for (final token in tokens) {
        int wordCount = _wordCounts[category]![token] ?? 0;
        double wordProb = (wordCount + 1) / (totalWordsInCategory + vocabSize);
        prob *= wordProb;
      }
      
      result[category] = prob;
      sum += prob;
    }

    if (sum > 0) {
      for (final category in result.keys) {
        result[category] = result[category]! / sum;
      }
    }
    
    return result;
  }
}

class OfflineVendorAiModel {
  late _NaiveBayesEngine _classifier;
  bool _isTrained = false;

  OfflineVendorAiModel() {
    _classifier = _NaiveBayesEngine();
  }

  List<String> _tokenize(String input) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return [];

    final tokens = <String>{};
    
    final words = text.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.length > 2) tokens.add(word);
    }

    final cleanText = text.replaceAll(RegExp(r'\s+'), '');
    for (int i = 0; i < cleanText.length - 1; i++) {
      tokens.add(cleanText.substring(i, i + 2)); 
      if (i < cleanText.length - 2) {
        tokens.add(cleanText.substring(i, i + 3)); 
      }
    }

    return tokens.toList();
  }

  void trainWithCatalog(List<Map<String, dynamic>> catalogItems) {
    _classifier = _NaiveBayesEngine();
    _isTrained = false;

    int totalSamples = 0;
    for (final item in catalogItems) {
      final vendorName = item['vendorName'] as String?;
      final category = item['defaultCategoryId'] as String?;
      final usageCount = item['usageCount'] as int? ?? 1;
      
      if (vendorName != null && category != null && kCategories.contains(category)) {
        final aliases = List<String>.from((item['aliases'] as List<dynamic>?)?.map((e) => e.toString()) ?? []);
        
        // Weight the tokens by usageCount to exponentially influence category prediction
        for (int i = 0; i < usageCount; i++) {
          _classifier.add(category, _tokenize(vendorName));
          totalSamples++;

          for (final alias in aliases) {
            if (alias.isNotEmpty) {
              _classifier.add(category, _tokenize(alias));
              totalSamples++;
            }
          }
        }
      }
    }

    if (totalSamples > 0) {
      _isTrained = true;
      debugPrint('OfflineVendorAiModel trained on $totalSamples samples (frequency-weighted).');
    }
  }

  String? predictCategory(String vendorName) {
    if (!_isTrained || vendorName.trim().isEmpty) return null;

    final tokens = _tokenize(vendorName);
    if (tokens.isEmpty) return null;

    try {
      final probabilities = _classifier.classify(tokens);
      if (probabilities.isEmpty) return null;

      String? bestCategory;
      double maxProb = 0.0;

      probabilities.forEach((category, prob) {
        if (prob > maxProb) {
          maxProb = prob;
          bestCategory = category;
        }
      });

      if (maxProb > 0.6) {
        debugPrint('OfflineVendorAiModel predicted: $bestCategory for "$vendorName" with ${maxProb.toStringAsFixed(2)} confidence.');
        return bestCategory;
      }
    } catch (e) {
      debugPrint('Error predicting category: $e');
    }

    return null;
  }
}
