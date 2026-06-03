import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class GeminiNanoService {
  static const MethodChannel _channel = MethodChannel('com.expensesplit.pro/gemini_nano');

  /// Check if the Gemini Nano model is available on this device.
  /// Returns 'READY', 'DOWNLOADABLE', or other status.
  Future<String> checkStatus() async {
    try {
      final String result = await _channel.invokeMethod('checkStatus');
      return result;
    } on PlatformException catch (e) {
      debugPrint("AICore checkStatus error: '${e.message}'.");
      return "ERROR";
    }
  }

  /// Trigger the model download if it is DOWNLOADABLE.
  Future<bool> downloadModel() async {
    try {
      final String result = await _channel.invokeMethod('downloadModel');
      return result == "DOWNLOAD_COMPLETE";
    } on PlatformException catch (e) {
      debugPrint("AICore download error: '${e.message}'.");
      return false;
    }
  }

  /// Generate content locally using Gemini Nano.
  Future<String?> generateAdvice(String prompt) async {
    try {
      // First, ensure the model is ready
      final status = await checkStatus();
      if (status == "DOWNLOADABLE") {
        debugPrint("Gemini Nano model needs to be downloaded first.");
        // We could auto-download here, but for safety in the fallback, we just return null
        // because downloading a 1GB model silently in the background of a fallback is dangerous.
        return null;
      } else if (status != "READY") {
        debugPrint("Gemini Nano is not ready (Status: $status)");
        return null;
      }

      final String result = await _channel.invokeMethod('generateAdvice', {'prompt': prompt});
      return result;
    } on PlatformException catch (e) {
      debugPrint("AICore generateAdvice error: '${e.message}'.");
      return null;
    }
  }
}
