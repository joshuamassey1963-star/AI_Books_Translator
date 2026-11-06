import 'dart:typed_data';

import 'package:ai_book_translator/features/engine/text/text_encoding.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/encoding_fixtures.dart';

void main() {
  const detector = EncodingDetector();

  void expectDecoded(
    EncodingReport r,
    TextEncoding enc,
    EncodingSource source, {
    required bool bom,
  }) {
    expect(r.status, EncodingStatus.decoded, reason: r.issues.join(','));
    expect(r.encoding, enc);
    expect(r.source, source);
    expect(r.hadBom, bom);
    expect(r.text, mixedText);
  }

  test('EN01: UTF-8 without BOM', () {
    expectDecoded(
      detector.detect(utf8NoBom(mixedText)),
      TextEncoding.utf8,
      EncodingSource.strictUtf8,
      bom: false,
    );
  });

  test('EN02: UTF-8 with BOM (BOM removed from text only)', () {
    final bytes = utf8WithBom(mixedText);
    final r = detector.detect(bytes);
    expectDecoded(r, TextEncoding.utf8, EncodingSource.bom, bom: true);
    expect(r.text!.startsWith('\uFEFF'), isFalse);
    expect(r.originalBytes, bytes);
  });

  test('EN03: UTF-16 LE with BOM', () {
    expectDecoded(
      detector.detect(utf16le(mixedText)),
      TextEncoding.utf16le,
      EncodingSource.bom,
      bom: true,
    );
  });

  test('EN04: UTF-16 BE with BOM', () {
    expectDecoded(
      detector.detect(utf16be(mixedText)),
      TextEncoding.utf16be,
      EncodingSource.bom,
      bom: true,
    );
  });

  test('EN05: UTF-16 without BOM is suggested, never silently accepted', () {
    for (final (bytes, enc) in [
      (utf16le(mixedText, bom: false), TextEncoding.utf16le),
      (utf16be(mixedText, bom: false), TextEncoding.utf16be),
    ]) {
      final r = detector.detect(bytes);
      expect(r.status, EncodingStatus.needsConfirmation);
      expect(r.isDecoded, isFalse);
      expect(r.encoding, enc);
      expect(r.has(EncodingIssueCode.utf16WithoutBom), isTrue);
      expect(r.text, mixedText); // candidate shown for confirmation
    }
  });

  test('EN05: Hindi-only UTF-16 LE without BOM is recognised', () {
    final r = detector.detect(
      utf16le('नमस्ते दुनिया। यह एक परीक्षण वाक्य है।', bom: false),
    );
    expect(r.status, EncodingStatus.needsConfirmation);
    expect(r.encoding, TextEncoding.utf16le);
  });

  test('explicit override decodes BOM-less UTF-16', () {
    final r = detector.detect(
      utf16be(mixedText, bom: false),
      override: TextEncoding.utf16be,
    );
    expect(r.status, EncodingStatus.decoded);
    expect(r.source, EncodingSource.override);
    expect(r.text, mixedText);
  });

  test('override that contradicts the BOM is refused', () {
    final r = detector.detect(
      utf16le(mixedText),
      override: TextEncoding.utf16be,
    );
    expect(r.status, EncodingStatus.refused);
    expect(r.has(EncodingIssueCode.overrideContradictsBom), isTrue);
  });

  test('wrong override is refused, not decoded into garbage', () {
    // Valid UTF-16 LE bytes forced as UTF-8 contain NULs → refused.
    final r = detector.detect(
      utf16le('Hello world', bom: false),
      override: TextEncoding.utf8,
    );
    expect(r.status, EncodingStatus.refused);
    expect(r.has(EncodingIssueCode.nulBytes), isTrue);
  });

  test('EN07: invalid UTF-8 is refused with offset; preview is lossy', () {
    final bytes = Uint8List.fromList([0x48, 0x69, 0xC3, 0x28, 0x41]);
    final r = detector.detect(bytes);
    expect(r.status, EncodingStatus.refused);
    expect(r.text, isNull);
    final issue = r.issues.single;
    expect(issue.code, EncodingIssueCode.invalidUtf8);
    expect(issue.byteOffset, inInclusiveRange(2, 3));
    final p = detector.preview(bytes);
    expect(p.lossy, isTrue);
    expect(p.text, contains('\uFFFD'));
    expect(p.text, startsWith('Hi'));
  });

  test('malformed UTF-16: unpaired surrogates and odd length', () {
    final lone = Uint8List.fromList([0xFF, 0xFE, 0x41, 0x00, 0x00, 0xD8, 0x42, 0x00]);
    final r1 = detector.detect(lone);
    expect(r1.status, EncodingStatus.refused);
    expect(r1.issues.single.code, EncodingIssueCode.unpairedSurrogate);
    expect(r1.issues.single.byteOffset, 4);
    expect(detector.preview(lone).lossy, isTrue);

    final lowFirst = Uint8List.fromList([0xFE, 0xFF, 0xDC, 0x00, 0x00, 0x41]);
    expect(
      detector.detect(lowFirst).issues.single.code,
      EncodingIssueCode.unpairedSurrogate,
    );

    final odd = Uint8List.fromList([0xFF, 0xFE, 0x41, 0x00, 0x42]);
    expect(
      detector.detect(odd).issues.single.code,
      EncodingIssueCode.oddByteLength,
    );
  });

  test('valid surrogate pair (emoji) decodes', () {
    final r = detector.detect(utf16le('ok 😀 ठीक'));
    expect(r.status, EncodingStatus.decoded);
    expect(r.text, 'ok 😀 ठीक');
  });

  test('binary content is refused', () {
    final r = detector.detect(
      Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x00, 0x01, 0x02, 0xFF]),
    );
    expect(r.status, EncodingStatus.refused);
    expect(r.has(EncodingIssueCode.binaryContent), isTrue);
  });

  test('UTF-32 BOM is refused clearly', () {
    final r = detector.detect(Uint8List.fromList([0xFF, 0xFE, 0, 0, 0x41, 0, 0, 0]));
    expect(r.issues.single.code, EncodingIssueCode.utf32NotSupported);
  });

  test('control characters are reported, text kept', () {
    final r = detector.detect(utf8NoBom('a\u0001b'));
    expect(r.status, EncodingStatus.decoded);
    expect(r.has(EncodingIssueCode.controlCharacters), isTrue);
    expect(r.text, 'a\u0001b');
  });

  test('original bytes are a copy and cannot be modified', () {
    final bytes = utf16le(mixedText);
    final before = Uint8List.fromList(bytes);
    final r = detector.detect(bytes);
    expect(() => r.originalBytes[0] = 0, throwsUnsupportedError);
    bytes[2] = 0x7A; // caller changes its buffer
    expect(r.originalBytes, before);
  });

  test('EN12/EN14: mixed script, combining marks, ZWJ/ZWNJ and digits '
      'survive every encoding byte-exact', () {
    for (final bytes in [
      utf8NoBom(mixedText),
      utf8WithBom(mixedText),
      utf16le(mixedText),
      utf16be(mixedText),
    ]) {
      final text = detector.detect(bytes).text!;
      expect(text, mixedText);
      expect(text, contains('\u200D'));
      expect(text, contains('\u200C'));
      expect(text, contains('2026'));
      expect(text, contains('९८'));
    }
  });

  group('EN06: XML part encoding', () {
    test('declared encoding is read', () {
      expect(
        xmlDeclaredEncoding('<?xml version="1.0" encoding="UTF-16"?><a/>'),
        'utf-16',
      );
      expect(xmlDeclaredEncoding('<a/>'), isNull);
    });

    test('UTF-16 XML with BOM decodes; mismatching declaration refused', () {
      const xml = '<?xml version="1.0" encoding="UTF-16"?><p>हिंदी</p>';
      expect(decodeXmlPart(utf16le(xml)), xml);
      expect(
        decodeXmlPart(
          utf8NoBom('<?xml version="1.0" encoding="ISO-8859-1"?><p>x</p>'),
        ),
        isNull,
      );
      expect(
        decodeXmlPart(utf8NoBom('<?xml version="1.0" encoding="utf-8"?><p/>')),
        isNotNull,
      );
    });
  });
}
