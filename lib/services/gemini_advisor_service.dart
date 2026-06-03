import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_nano_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final geminiAdvisorServiceProvider = Provider((ref) => GeminiAdvisorService());

final smartAdviceProvider = FutureProvider.autoDispose.family<String, ({double spent, double budget})>((ref, data) async {
  final service = ref.read(geminiAdvisorServiceProvider);
  return service.getSmartAdvice(data.spent, data.budget);
});

class GeminiAdvisorService {
  /*
   * SECURITY BEST PRACTICE:
   * Do not hardcode your API keys in the final submission!
   * 1. Add 'flutter_dotenv' to pubspec.yaml
   * 2. Create a .env file with GEMINI_API_KEY=your_key_here
   * 3. Add .env to .gitignore and pubspec.yaml assets
   * 4. Call await dotenv.load(fileName: ".env"); in main.dart
   * 5. Replace this hardcoded key with: dotenv.env['GEMINI_API_KEY'] ?? ''
   */
  static const String _apiKey = '';
  static const String _cacheKey = 'gemini_advice_cache';
  static const String _cacheTimeKey = 'gemini_advice_time';

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }

  Future<String> getSmartAdvice(double totalSpent, double targetBudget) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAdvice = prefs.getString(_cacheKey);
      final cachedTimeStr = prefs.getString(_cacheTimeKey);

      if (cachedAdvice != null && cachedTimeStr != null) {
        final cachedTime = DateTime.parse(cachedTimeStr);
        final difference = DateTime.now().difference(cachedTime);

        // If cached advice is younger than 24 hours, return it to save quota
        if (difference.inHours < 24) {
          return cachedAdvice;
        }
      }

      // Initialize the model
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
      );

      final spendingSummary = "RM ${totalSpent.toStringAsFixed(0)} out of RM ${targetBudget.toStringAsFixed(0)}";
      final prompt = "You are a financial advisor for a university student. Analyze this spending data: [$spendingSummary] and provide one concise, encouraging, and actionable tip in under 40 words.";
      final content = [Content.text(prompt)];
      
      final response = await model.generateContent(content);
      final newAdvice = response.text?.trim() ?? _generateLocalAdvice(totalSpent, targetBudget);

      // Cache the new response
      await prefs.setString(_cacheKey, newAdvice);
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());

      return newAdvice;
    } catch (e) {
      // HYBRID FALLBACK 1: Try on-device Gemini Nano via AICore
      try {
        final nanoService = GeminiNanoService();
        final spendingSummary = "RM ${totalSpent.toStringAsFixed(0)} out of RM ${targetBudget.toStringAsFixed(0)}";
        final prompt = "You are a financial advisor. Given this spending data: [$spendingSummary], provide one very short actionable tip.";
        
        final nanoAdvice = await nanoService.generateAdvice(prompt);
        if (nanoAdvice != null && nanoAdvice.isNotEmpty) {
          // Cache the local nano advice too
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cacheKey, nanoAdvice.trim());
          await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
          return nanoAdvice.trim();
        }
      } catch (nanoError) {
        // Nano failed or unavailable, proceed to rule-based fallback
      }

      // HYBRID FALLBACK 2: Local rule-based logic
      return _generateLocalAdvice(totalSpent, targetBudget);
    }
  }

  String _generateLocalAdvice(double totalSpent, double targetBudget) {
    if (totalSpent == 0) return "Financial tip: Start logging expenses to get personalized tips!";
    if (totalSpent < targetBudget * 0.5) return "Financial tip: Great job! You've spent less than half your budget. Keep saving!";
    if (totalSpent <= targetBudget * 0.9) return "Financial tip: You're getting close to your limit. Time to cut back on non-essentials.";
    if (totalSpent <= targetBudget) return "Financial tip: Warning! You are right at your budget limit. Freeze spending if possible.";
    return "Financial tip: You've exceeded your budget this month! Let's plan better for next month.";
  }
}
