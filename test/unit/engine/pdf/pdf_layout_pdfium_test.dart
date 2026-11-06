import 'dart:io';

import 'package:ai_book_translator/features/engine/pdf/pdf_layout_analyzer.dart';
import 'package:ai_book_translator/features/engine/pdf/pdf_quality.dart';
import 'package:ai_book_translator/features/engine/pdf/pdfrx_text_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;

import '../../../support/pdf_fixtures.dart';

/// Layout + quality on real PDFium output from generated PDFs.
void main() {
  const source = PdfrxTextSource();
  const analyzer = PdfLayoutAnalyzer();

  setUpAll(() async {
    final pdfiumPath = Platform.environment['PDFIUM_PATH'];
    if (pdfiumPath == null || !File(pdfiumPath).existsSync()) {
      fail('PDFIUM_PATH must point to libpdfium for host tests (D-021).');
    }
    pdfrx.Pdfrx.pdfiumModulePath = pdfiumPath;
    pdfrx.Pdfrx.cacheDirectoryPath = Directory.systemTemp
        .createTempSync('pdfrx_layout_test')
        .path;
    await pdfrx.pdfrxInitialize();
  });

  PlacedText t(double x, double y, String text) =>
      (x: x, y: y, text: text, size: 12);

  test('glyph boxes come through and two columns are reordered', () async {
    final doc = await source.read(
      layoutPdf([
        [
          t(330, 700, 'Right one'),
          t(330, 686, 'Right two'),
          t(72, 700, 'Left one'),
          t(72, 686, 'Left two'),
        ],
      ]),
    );
    final page = doc.pages.single;
    expect(page.glyphs, isNotEmpty);
    final layout = analyzer.analyzePage(page);
    expect(layout.columnCount, 2);
    expect(
      [for (final l in layout.lines) l.text],
      ['Left one', 'Left two', 'Right one', 'Right two'],
    );
  });

  test('header and page numbers repeat across pages → candidates', () async {
    final doc = await source.read(
      layoutPdf([
        for (var i = 1; i <= 3; i++)
          [t(72, 770, 'Running Head'), t(72, 600, 'Body $i'), t(300, 30, '$i')],
      ]),
    );
    final layout = analyzer.analyzeDocument(doc.pages);
    expect(
      layout.headerFooter.where((c) => c.text == 'Running Head'),
      hasLength(3),
    );
    expect(
      layout.headerFooter.where((c) => c.position == MarginPosition.footer),
      hasLength(3),
    );
  });

  test('quality gate passes clean generated text', () async {
    final doc = await source.read(textPdf(['Plain clean text']));
    final report = const ExtractionQualityGate().evaluate(doc.pages);
    expect(report.verdict, QualityVerdict.pass);
  });
}
