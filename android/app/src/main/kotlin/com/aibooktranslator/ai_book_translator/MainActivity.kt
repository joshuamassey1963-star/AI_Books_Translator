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
                    "saveToDownloads" -> try {
                        val name = call.argument<String>("name")!!
                        val bytes = call.argument<ByteArray>("bytes")!!
                        result.success(saveToDownloads(name, bytes))
                    } catch (e: Exception) {
                        result.error("save_failed", e.toString(), null)
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

    // Probe evidence only: files in Downloads survive the test-run uninstall,
    // so CI can adb-pull them. Needs API 29+ (no storage permission).
    private fun saveToDownloads(name: String, bytes: ByteArray): String? {
        if (android.os.Build.VERSION.SDK_INT < 29) return null
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(android.provider.MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
            put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "Download/pdf_probe_b")
        }
        val uri = contentResolver.insert(
            android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values,
        ) ?: return null
        contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
        return uri.toString()
    }
}
