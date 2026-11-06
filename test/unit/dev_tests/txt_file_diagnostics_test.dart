import 'dart:io';
import 'dart:typed_data';

import 'package:ai_book_translator/features/dev_tests/dev_diagnostics.dart';
import 'package:ai_book_translator/features/engine/parser/import_limits.dart';
import 'package:ai_book_translator/features/engine/parser/parse_exception.dart';
import 'package:ai_book_translator/features/engine/text/text_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mixed = 'Chapter 1\n\nभारत एक देश है। India has 28 states.\n\n'
      'Chapter 2\n\nदूसरा भाग। Second part.';

  group('M-DEV-02a TXT file diagnostics', () {
    test('valid UTF-8 TXT parses with chapters, paragraphs and SHA-256', () {
      final d = inspectTxtFile('a.txt', SampleBytes.utf8.encode(mixed));
      expect(d.encoding!.status, EncodingStatus.decoded);
      expect(d.encoding!.encoding, TextEncoding.utf8);
      expect(d.parse.ok, isTrue);
      expect(d.parse.chapters, greaterThanOrEqualTo(1));
      expect(d.parse.paragraphs, greaterThan(0));
      expect(d.parse.sha256, hasLength(64));
    });

    test('Hindi + English mixed text is previewed unchanged', () {
      final d = inspectTxtFile('m.txt', SampleBytes.utf8.encode(mixed));
      expect(d.preview, mixed);
      expect(d.previewTruncated, isFalse);
    });

    test('UTF-16 LE and BE with BOM parse', () {
      for (final s in [SampleBytes.utf16leBom, SampleBytes.utf16beBom]) {
        final d = inspectTxtFile('u.txt', s.encode(mixed));
        expect(d.encoding!.hadBom, isTrue, reason: s.label);
        expect(d.parse.ok, isTrue, reason: s.label);
        expect(d.preview, mixed, reason: s.label);
      }
    });

    test('UTF-16 without BOM needs a choice; the choice parses it', () {
      final bytes = SampleBytes.utf16leNoBom.encode('Hello world, plain text.');
      final d = inspectTxtFile('n.txt', bytes);
      expect(d.needsEncodingChoice, isTrue);
      expect(d.parse.error?.code, ParseErrorCode.encodingNeedsConfirmation);
      expect(d.preview, isNull);
      final c = inspectTxtFile('n.txt', bytes, encoding: TextEncoding.utf16le);
      expect(c.parse.ok, isTrue);
      expect(c.preview, 'Hello world, plain text.');
    });

    test('invalid encoding is refused with no preview', () {
      final d = inspectTxtFile('x.txt', SampleBytes.invalidUtf8.encode('abc'));
      expect(d.encoding!.status, EncodingStatus.refused);
      expect(d.parse.error?.code, ParseErrorCode.invalidEncoding);
      expect(d.preview, isNull);
    });

    test('empty file is refused before reading', () {
      expect(checkPickedSize(0)?.code, ParseErrorCode.empty);
      final d = inspectTxtFile('e.txt', Uint8List(0));
      expect(d.parse.error?.code, ParseErrorCode.empty);
    });

    test('oversized file is refused before reading', () {
      const limits = ImportLimits();
      expect(checkPickedSize(limits.maxFileBytes), isNull);
      expect(
        checkPickedSize(limits.maxFileBytes + 1)?.code,
        ParseErrorCode.tooLarge,
      );
    });

    test('preview is bounded', () {
      final long = 'अ' * (devPreviewMaxChars + 500);
      final d = inspectTxtFile('l.txt', SampleBytes.utf8.encode(long));
      expect(d.preview!.length, devPreviewMaxChars);
      expect(d.previewTruncated, isTrue);
    });

    test('binary content is a parser failure, reported', () {
      final bytes = Uint8List.fromList([0x00, 0x01, 0x02, 0xFF, 0x00, 0x10]);
      final d = inspectTxtFile('b.txt', bytes);
      expect(d.parse.ok, isFalse);
    });

    test('file bytes are not modified', () {
      final bytes = SampleBytes.utf16leBom.encode(mixed);
      final copy = Uint8List.fromList(bytes);
      inspectTxtFile('c.txt', bytes);
      inspectTxtFile('c.txt', bytes, encoding: TextEncoding.utf16le);
      expect(bytes, copy);
    });
  });

  test('Android manifest requests no storage permissions', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    for (final p in [
      'READ_EXTERNAL_STORAGE',
      'WRITE_EXTERNAL_STORAGE',
      'MANAGE_EXTERNAL_STORAGE',
      'READ_MEDIA_',
    ]) {
      expect(manifest.contains(p), isFalse, reason: p);
    }
  });
}
