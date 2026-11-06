import 'dart:io';

import 'package:ai_book_translator/features/engine/parser/parse_exception.dart';
import 'package:ai_book_translator/features/engine/pdf/pdf_models.dart';
import 'package:ai_book_translator/features/engine/pdf/pdfrx_text_source.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;

import '../../../support/book_fixtures.dart';
import '../../../support/pdf_fixtures.dart';

/// Runs the real PDFium engine (pdfrx native asset) on generated PDFs.
void main() {
  const source = PdfrxTextSource();

  setUpAll(() async {
    pdfrx.Pdfrx.cacheDirectoryPath = Directory.systemTemp
        .createTempSync('pdfrx_test')
        .path;
    await pdfrx.pdfrxInitialize();
  });

  test('text PDF: runs, page numbers, coordinates, page fonts', () async {
    final bytes = textPdf(['Hello World', 'Second page']);
    final original = List<int>.from(bytes);
    final doc = await source.read(bytes, fileName: 'sample.pdf');

    expect(doc.pageCount, 2);
    expect(doc.missingTextLayer, isFalse);
    expect(doc.looksScanned, isFalse);
    expect(doc.pages[0].status, PageTextStatus.textLayer);
    expect(doc.pages[0].text, contains('Hello World'));
    expect(doc.pages[1].text, contains('Second page'));
    expect(doc.pages[1].runs.every((r) => r.pageNumber == 2), isTrue);

    final page = doc.pages[0];
    expect(page.width, closeTo(612, 0.5));
    expect(page.height, closeTo(792, 0.5));
    final run = page.runs.firstWhere((r) => r.text.trim().isNotEmpty);
    // Text was drawn at x=72, baseline y=700 (PDF points, origin bottom-left).
    expect(run.box.left, inInclusiveRange(60, 90));
    expect(run.box.bottom, inInclusiveRange(680, 712));
    expect(run.box.top, greaterThan(run.box.bottom));
    expect(run.fontName, isNull, reason: 'pdfrx gives no per-run font');
    expect(page.fonts.single.baseFont, 'Helvetica');

    expect(doc.sha256, sha256.convert(original).toString());
    expect(bytes, original, reason: 'original bytes must stay unchanged');
  });

  test('RC-013: image-only PDF is flagged as scanned, OCR required', () async {
    final doc = await source.read(imageOnlyPdf(pages: 2));
    expect(doc.pageCount, 2);
    expect(doc.missingTextLayer, isTrue);
    expect(doc.looksScanned, isTrue);
    expect(doc.pagesNeedingOcr, [1, 2]);
    expect(doc.pages.first.status, PageTextStatus.imageOnly);
    expect(doc.pages.first.runs.where((r) => r.text.trim().isNotEmpty), isEmpty);
  });

  test('mixed PDF: only the image page needs OCR', () async {
    final doc = await source.read(mixedPdf());
    expect(doc.pages[0].status, PageTextStatus.textLayer);
    expect(doc.pages[1].status, PageTextStatus.imageOnly);
    expect(doc.pagesNeedingOcr, [2]);
    expect(doc.looksScanned, isFalse);
  });

  test('blank page is not sent to OCR', () async {
    final doc = await source.read(blankPdf());
    expect(doc.pages.single.status, PageTextStatus.blank);
    expect(doc.pagesNeedingOcr, isEmpty);
  });

  test('RC-008: Type0 font with ToUnicode extracts Devanagari', () async {
    final doc = await source.read(type0Pdf(toUnicode: true));
    final page = doc.pages.single;
    expect(page.fonts.single.mappingRisk, UnicodeMappingRisk.low);
    expect(page.text, contains('\u0928\u092E'));
  });

  test('RC-008: Type0 font without ToUnicode is flagged high risk', () async {
    final doc = await source.read(type0Pdf(toUnicode: false));
    final page = doc.pages.single;
    expect(page.fonts.single.hasToUnicode, isFalse);
    expect(page.fonts.single.mappingRisk, UnicodeMappingRisk.high);
    // Whatever PDFium returns here, it is not the Devanagari text.
    expect(page.text, isNot(contains('\u0928\u092E')));
  });

  test('refuses empty, non-PDF and broken input with honest codes', () async {
    await expectLater(
      source.read(utf8Bytes('')),
      throwsA(isA<ParseException>().having((e) => e.code, 'code', ParseErrorCode.empty)),
    );
    await expectLater(
      source.read(utf8Bytes('just text')),
      throwsA(
        isA<ParseException>().having(
          (e) => e.code,
          'code',
          ParseErrorCode.unsupportedFormat,
        ),
      ),
    );
    await expectLater(
      source.read(utf8Bytes('%PDF-1.7\nthis is not a real pdf')),
      throwsA(
        isA<ParseException>().having(
          (e) => e.code,
          'code',
          ParseErrorCode.corruptContainer,
        ),
      ),
    );
  });
}
