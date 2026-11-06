import 'package:ai_book_translator/features/dev_tests/dev_diagnostics.dart';
import 'package:ai_book_translator/features/engine/legacy/legacy_font_converter.dart';
import 'package:ai_book_translator/features/engine/parser/parse_exception.dart';
import 'package:ai_book_translator/features/engine/text/text_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const text = 'भारत India';

  group('DEV-01 encoding diagnostics', () {
    test('UTF-8 and UTF-16 with BOM decode to the same text', () {
      for (final s in [
        SampleBytes.utf8,
        SampleBytes.utf8Bom,
        SampleBytes.utf16leBom,
        SampleBytes.utf16beBom,
      ]) {
        final d = inspectEncoding(s.encode(text));
        expect(d.report.status, EncodingStatus.decoded, reason: s.label);
        expect(d.report.text, text, reason: s.label);
        expect(d.nfcText, text);
        expect(d.wasNfc, isTrue);
      }
    });

    test('UTF-16 without BOM needs confirmation; override decodes it', () {
      final bytes = SampleBytes.utf16leNoBom.encode('Hello world text');
      expect(
        inspectEncoding(bytes).report.status,
        EncodingStatus.needsConfirmation,
      );
      final forced = inspectEncoding(bytes, override: TextEncoding.utf16le);
      expect(forced.report.status, EncodingStatus.decoded);
    });

    test('invalid UTF-8 is refused, no text is invented', () {
      final d = inspectEncoding(SampleBytes.invalidUtf8.encode('abc'));
      expect(d.report.status, EncodingStatus.refused);
      expect(d.nfcText, isNull);
    });

    test('NFC is shown separately from the original', () {
      const decomposed = 'e\u0301';
      final d = inspectEncoding(SampleBytes.utf8.encode(decomposed));
      expect(d.report.text, decomposed);
      expect(d.nfcText, '\u00e9');
      expect(d.wasNfc, isFalse);
    });
  });

  group('DEV-01 Kruti Dev examples', () {
    test('every example converts to its tested output', () {
      devKrutiExamples.forEach((input, expected) {
        final r = convertLegacy(
          input,
          fontName: 'Kruti Dev 010',
          confirmed: true,
        );
        expect(r.converted, expected);
        expect(r.original, input);
      });
    });

    test('unconfirmed or other fonts are refused', () {
      expect(
        convertLegacy(
          'Hkkjr',
          fontName: 'Kruti Dev 010',
          confirmed: false,
        ).refusal,
        LegacyRefusal.fontNotConfirmed,
      );
      expect(
        convertLegacy('Hkkjr', fontName: 'Chanakya', confirmed: true).refusal,
        LegacyRefusal.unsupportedFont,
      );
    });
  });

  group('DEV-01 TXT parser diagnostics', () {
    test('UTF-16 LE with BOM parses as TXT', () {
      final d = parseForDiagnostics(
        SampleBytes.utf16leBom.encode('Chapter 1\n\nभारत एक देश है।'),
        fileName: 'sample.txt',
      );
      expect(d.ok, isTrue);
      expect(d.format, 'TXT');
      expect(d.paragraphs, greaterThan(0));
    });

    test('errors are reported, not hidden', () {
      expect(
        parseForDiagnostics(SampleBytes.utf8.encode('')).error?.code,
        ParseErrorCode.empty,
      );
      expect(
        parseForDiagnostics(SampleBytes.utf16leNoBom.encode('Hello world '))
            .error
            ?.code,
        ParseErrorCode.encodingNeedsConfirmation,
      );
    });
  });
}
