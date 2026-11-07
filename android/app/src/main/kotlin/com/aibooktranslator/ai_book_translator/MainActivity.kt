package com.aibooktranslator.ai_book_translator

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // M2b-3b-1 PDF export probe channel (prototype, no UI uses it).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai_book_translator/pdf_probe")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "renderCase" -> try {
                        @Suppress("UNCHECKED_CAST")
                        val blocks = call.argument<List<Map<String, Any?>>>("blocks")!!
                        val rtl = call.argument<Boolean>("rtl") ?: false
                        result.success(NativePdfProbe.render(blocks, rtl))
                    } catch (e: Exception) {
                        result.error("render_failed", e.toString(), null)
                    }
                    "probeOutputDir" -> result.success(getExternalFilesDir("pdf_probe")?.absolutePath)
                    "deviceInfo" -> result.success(
                        mapOf(
                            "sdkInt" to android.os.Build.VERSION.SDK_INT,
                            "release" to android.os.Build.VERSION.RELEASE,
                            "model" to android.os.Build.MODEL,
                        ),
                    )
                    else -> result.notImplemented()
                }
            }
    }
}
