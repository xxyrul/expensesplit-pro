package com.example.expensesplit_pro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.mlkit.genai.prompt.Generation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.expensesplit.pro/gemini_nano"
    private val mainScope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkStatus" -> {
                    mainScope.launch {
                        try {
                            val client = Generation.getClient()
                            val status = client.checkStatus()
                            result.success(status.toString()) 
                        } catch (e: Exception) {
                            result.error("STATUS_ERROR", e.message, null)
                        }
                    }
                }
                "downloadModel" -> {
                    val client = Generation.getClient()
                    mainScope.launch {
                        try {
                            client.download().collect {
                                // Ignore intermediate progress, just wait for flow completion
                            }
                            result.success("DOWNLOAD_COMPLETE")
                        } catch (e: Exception) {
                            result.error("DOWNLOAD_ERROR", e.message, null)
                        }
                    }
                }
                "generateAdvice" -> {
                    val prompt = call.argument<String>("prompt")
                    if (prompt == null) {
                        result.error("INVALID_ARGUMENT", "Prompt cannot be null", null)
                        return@setMethodCallHandler
                    }
                    
                    val client = Generation.getClient()
                    mainScope.launch {
                        try {
                            val response = client.generateContent(prompt)
                            result.success(response)
                        } catch (e: Exception) {
                            result.error("GENERATE_ERROR", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
