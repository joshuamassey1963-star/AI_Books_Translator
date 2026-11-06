import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_export_probe.dart';
import 'probe_cases.dart';

/// Engine A: the pure-Dart `pdf` package (Apache-2.0) with embedded
/// TrueType fonts. Prototype only (M2b-3a) – not wired to any screen.
class DartPdfEngineA implements PdfExportProbe {
  const DartPdfEngineA();

  @override
  String get engineId => 'engine_a_dart_pdf';

  static pw.Font _font(Uint8List bytes) =>
      pw.Font.ttf(ByteData.sublistView(bytes));

  @override
  Future<Uint8List> render(ProbeCase probeCase, ProbeFontSet fonts) async {
    final base = _font(fonts.devanagari);
    final bold = fonts.devanagariBold == null
        ? base
        : _font(fonts.devanagariBold!);
    final fallback = <pw.Font>[
      if (fonts.latinGreek != null) _font(fonts.latinGreek!),
      if (fonts.hebrew != null) _font(fonts.hebrew!),
    ];
    final doc = pw.Document(
      title: 'M2b-3a probe ${probeCase.id}',
      creator: 'AI Book Translator PDF probe',
    );
    final direction = probeCase.rtl
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(36),
        theme: pw.ThemeData.withFont(
          base: base,
          bold: bold,
          fontFallback: fallback,
        ),
        build: (context) => [
          for (final b in probeCase.blocks)
            switch (b.kind) {
              ProbeBlockKind.heading => pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6, bottom: 6),
                child: pw.Text(
                  b.text,
                  textDirection: direction,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              ProbeBlockKind.paragraph => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  b.text,
                  textDirection: direction,
                  style: const pw.TextStyle(fontSize: 14, lineSpacing: 4),
                ),
              ),
            },
        ],
      ),
    );
    return doc.save();
  }
}
