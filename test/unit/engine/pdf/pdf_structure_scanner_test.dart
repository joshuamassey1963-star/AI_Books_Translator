import 'package:ai_book_translator/features/engine/pdf/pdf_models.dart';
import 'package:ai_book_translator/features/engine/pdf/pdf_structure_scanner.dart';
import 'package:ai_book_translator/features/engine/pdf/pdf_text_source.dart';
import 'package:ai_book_translator/features/engine/pdf/pdfrx_text_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/book_fixtures.dart';
import '../../../support/pdf_fixtures.dart';

/// Pure-Dart tests: no PDFium needed.
void main() {
  const scanner = PdfStructureScanner();

  PdfFontInfo font(PdfStructurePage page, String resource) =>
      page.fonts.firstWhere((f) => f.resourceName == resource);

  group('PdfStructureScanner – pages, text operators, images', () {
    test('text PDF: pages found, text operators counted, no images', () {
      final report = scanner.scan(textPdf(['Hello World', 'Second page']));
      expect(report.pages, hasLength(2));
      expect(report.encrypted, isFalse);
      for (final page in report.pages) {
        expect(page.contentReadable, isTrue);
        expect(page.textOperatorCount, 1);
        expect(page.imageCount, 0);
      }
    });

    test('FlateDecode content streams are decoded', () {
      final page = scanner.scan(textPdf(['Zipped'], compress: true)).pages.single;
      expect(page.contentReadable, isTrue);
      expect(page.textOperatorCount, 1);
    });

    test('RC-013: image-only page has images and no text operators', () {
      final report = scanner.scan(imageOnlyPdf(pages: 2));
      expect(report.pages, hasLength(2));
      for (final page in report.pages) {
        expect(page.imageCount, 1);
        expect(page.textOperatorCount, 0);
      }
    });

    test('inline images are counted and their binary data skipped', () {
      final page = scanner.scan(inlineImagePdf()).pages.single;
      expect(page.imageCount, 1);
      expect(page.textOperatorCount, 0);
    });

    test('blank page: no text operators, no images', () {
      final page = scanner.scan(blankPdf()).pages.single;
      expect(page.imageCount, 0);
      expect(page.textOperatorCount, 0);
    });

    test('inherited Resources from the Pages node are used', () {
      final report = scanner.scan(mixedPdf());
      expect(report.pages, hasLength(2));
      expect(report.pages[0].textOperatorCount, 1);
      expect(report.pages[0].fonts.single.baseFont, 'Helvetica');
      expect(report.pages[1].imageCount, 1);
      expect(report.pages[1].textOperatorCount, 0);
    });

    test('form XObjects: nested text and fonts are included', () {
      final page = scanner.scan(fontVarietyPdf()).pages.single;
      // Tj, TJ, ', " on the page + Tj inside the form.
      expect(page.textOperatorCount, 5);
      expect(page.fonts.map((f) => f.resourceName), contains('F9'));
    });

    test('objects inside compressed object streams are found', () {
      final page = scanner.scan(objectStreamPdf()).pages.single;
      expect(font(page, 'F1').baseFont, 'Helvetica');
      expect(page.textOperatorCount, 1);
    });

    test('encrypted PDF: streams are not inspected, counts unknown', () {
      final report = scanner.scan(encryptedMarkerPdf());
      expect(report.encrypted, isTrue);
      final page = report.pages.single;
      expect(page.contentReadable, isFalse);
      expect(page.imageCount, isNull);
      expect(page.textOperatorCount, isNull);
      expect(report.warnings.join(), contains('encrypted'));
    });

    test('garbage input gives an empty report, not a crash', () {
      final report = scanner.scan(utf8Bytes('%PDF-1.7\n1 0 obj << /Type '));
      expect(report.pages, isEmpty);
      expect(report.warnings, isNotEmpty);
    });
  });

  group('PdfStructureScanner – font metadata (V1-PDF-04)', () {
    test('standard Helvetica: not embedded, no subset, low risk', () {
      final f = font(scanner.scan(textPdf(['a'])).pages.single, 'F1');
      expect(f.subtype, 'Type1');
      expect(f.baseFont, 'Helvetica');
      expect(f.isSubset, isFalse);
      expect(f.embedded, isFalse);
      expect(f.hasToUnicode, isFalse);
      expect(f.encoding, 'WinAnsiEncoding');
      expect(f.mappingRisk, UnicodeMappingRisk.low);
    });

    test('RC-008: Type0 Identity-H without ToUnicode is high risk', () {
      final f = font(scanner.scan(type0Pdf(toUnicode: false)).pages.single, 'F1');
      expect(f.subtype, 'Type0');
      expect(f.baseFont, 'ABCDEF+TestDeva');
      expect(f.subsetTag, 'ABCDEF');
      expect(f.fontName, 'TestDeva');
      expect(f.encoding, 'Identity-H');
      expect(f.embedded, isFalse);
      expect(f.hasToUnicode, isFalse);
      expect(f.mappingRisk, UnicodeMappingRisk.high);
    });

    test('RC-008: the same font with ToUnicode is low risk', () {
      final f = font(scanner.scan(type0Pdf(toUnicode: true)).pages.single, 'F1');
      expect(f.hasToUnicode, isTrue);
      expect(f.mappingRisk, UnicodeMappingRisk.low);
    });

    test('embedded subset TrueType is detected via FontFile2', () {
      final f = font(scanner.scan(fontVarietyPdf()).pages.single, 'F1');
      expect(f.embedded, isTrue);
      expect(f.subsetTag, 'QWERTY');
      expect(f.fontName, 'NotoSerifDevanagari');
    });

    test('legacy-looking font without encoding is unknown, never low', () {
      final f = font(scanner.scan(fontVarietyPdf()).pages.single, 'F2');
      expect(f.baseFont, 'KrutiDev010');
      expect(f.encoding, isNull);
      expect(f.embedded, isFalse);
      expect(f.mappingRisk, UnicodeMappingRisk.unknown);
    });

    test('Differences encoding without ToUnicode is medium risk', () {
      final f = font(scanner.scan(fontVarietyPdf()).pages.single, 'F3');
      expect(f.encoding, 'custom');
      expect(f.mappingRisk, UnicodeMappingRisk.medium);
    });

    test('Type3 font: embedded, high risk without ToUnicode', () {
      final f = font(scanner.scan(fontVarietyPdf()).pages.single, 'F4');
      expect(f.subtype, 'Type3');
      expect(f.embedded, isTrue);
      expect(f.mappingRisk, UnicodeMappingRisk.high);
    });
  });

  group('page classification (V1-OCR-01)', () {
    test('rules', () {
      expect(
        classifyPage(hasVisibleText: true, imageCount: 3, textOperatorCount: 0),
        PageTextStatus.textLayer,
      );
      expect(
        classifyPage(hasVisibleText: false, imageCount: 1, textOperatorCount: 0),
        PageTextStatus.imageOnly,
      );
      expect(
        classifyPage(hasVisibleText: false, imageCount: 0, textOperatorCount: 4),
        PageTextStatus.textNotExtractable,
      );
      expect(
        classifyPage(hasVisibleText: false, imageCount: 0, textOperatorCount: 0),
        PageTextStatus.blank,
      );
      expect(
        classifyPage(
          hasVisibleText: false,
          imageCount: null,
          textOperatorCount: null,
        ),
        PageTextStatus.unknownNoText,
      );
    });

    test('OCR required only where text is missing', () {
      expect(PageTextStatus.textLayer.ocrRequired, isFalse);
      expect(PageTextStatus.blank.ocrRequired, isFalse);
      expect(PageTextStatus.imageOnly.ocrRequired, isTrue);
      expect(PageTextStatus.textNotExtractable.ocrRequired, isTrue);
      expect(PageTextStatus.unknownNoText.ocrRequired, isTrue);
    });
  });

  test('PDF header check allows leading junk, refuses non-PDF', () {
    expect(hasPdfHeader(utf8Bytes('junk\n%PDF-1.4\n')), isTrue);
    expect(hasPdfHeader(utf8Bytes('hello world')), isFalse);
  });
}
