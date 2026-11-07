package com.aibooktranslator.ai_book_translator

import android.graphics.Color
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextDirectionHeuristics
import java.io.ByteArrayOutputStream

/**
 * M2b-3b-1 prototype (Engine B): Android's own text stack (Minikin +
 * HarfBuzz shaping, system font fallback) drawn into android.graphics.pdf.PdfDocument.
 * Probe only – no screen uses it. The text is passed through unchanged.
 */
object NativePdfProbe {
    private const val PAGE_W = 420 // A5 in PDF points
    private const val PAGE_H = 595
    private const val MARGIN = 36

    fun render(blocks: List<Map<String, Any?>>, rtl: Boolean): ByteArray {
        val doc = PdfDocument()
        try {
            val page = doc.startPage(PdfDocument.PageInfo.Builder(PAGE_W, PAGE_H, 1).create())
            val canvas = page.canvas
            val width = PAGE_W - 2 * MARGIN
            var y = MARGIN.toFloat()
            for (b in blocks) {
                val text = b["text"] as String
                val heading = b["kind"] == "heading"
                val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG).apply {
                    color = Color.BLACK
                    textSize = if (heading) 18f else 14f
                }
                val layout = buildLayout(text, paint, width, rtl)
                canvas.save()
                canvas.translate(MARGIN.toFloat(), y)
                layout.draw(canvas)
                canvas.restore()
                y += layout.height + 8f
            }
            doc.finishPage(page)
            val out = ByteArrayOutputStream()
            doc.writeTo(out)
            return out.toByteArray()
        } finally {
            doc.close()
        }
    }

    @Suppress("DEPRECATION")
    private fun buildLayout(text: String, paint: TextPaint, width: Int, rtl: Boolean): StaticLayout {
        return if (Build.VERSION.SDK_INT >= 23) {
            StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setTextDirection(if (rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.FIRSTSTRONG_LTR)
                .setLineSpacing(4f, 1f)
                .setIncludePad(true)
                .build()
        } else {
            StaticLayout(text, paint, width, Layout.Alignment.ALIGN_NORMAL, 1f, 4f, true)
        }
    }
}
