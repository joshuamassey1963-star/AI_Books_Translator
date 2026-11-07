import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/glyph_pdf_writer.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/pdf_structure_check.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/pdf_text_string.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/shaped_run.dart';
import 'package:flutter_test/flutter_test.dart';

/// M2b-3b-2a. Uses the committed HarfBuzz output for किताब
/// (test/fixtures/pdf_probe/c01_kitab.hb.json, Noto Serif Devanagari Regular,
/// HarfBuzz 15.0.0) and a fake font blob; no font file is needed here.
ShapedRun runFromJson(Map<String, Object?> j) => ShapedRun(
  text: j['text']! as String,
  unitsPerEm: j['upem']! as int,
  glyphs: [
    for (final g in (j['glyphs']! as List).cast<Map<String, Object?>>())
      ShapedGlyph(
        glyphId: g['gid']! as int,
        cluster: g['cluster']! as int,
        xAdvance: g['ax']! as int,
        xOffset: g['dx']! as int,
        yOffset: g['dy']! as int,
      ),
  ],
);

String cps(String s) => s.runes
    .map((r) => r.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join(' ');

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/pdf_probe/c01_kitab.hb.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final expected = File('test/fixtures/pdf_probe/c01_kitab.txt')
      .readAsStringSync();
  final fakeFont = Uint8List.fromList(utf8.encode('FAKE-FONT-BYTES'));
  const writer = GlyphPdfWriter();
  final toUni = {
    for (final e in (fixture['glyph_to_unicode']! as Map).entries)
      int.parse(e.key as String): e.value as int,
  };

  test('expected fixture is किताब with pinned code points', () {
    expect(cps(expected), '0915 093F 0924 093E 092C');
    expect(fixture['text'], expected);
  });

  test('clusters map visual glyphs back to logical source text', () {
    final clusters = runFromJson(fixture).clusters();
    expect(clusters.map((c) => c.text).toList(), ['कि', 'ता', 'ब']);
    expect(clusters.map((c) => c.text).join(), expected);
    // i-matra glyph (558) is drawn before क (57), text stays क + ि.
    expect(clusters.first.glyphs.map((g) => g.glyphId).toList(), [558, 57]);
    expect(cps(clusters.first.text), '0915 093F');
  });

  test('UTF-16BE text strings with BOM', () {
    expect(pdfUtf16BeHex('कि'), 'FEFF0915093F');
    expect(pdfUtf16BeHex('𝄞'), 'FEFFD834DD1E');
    expect(decodePdfUtf16BeHex(pdfUtf16BeHex(expected)), expected);
    expect(() => decodePdfUtf16BeHex('0915'), throwsFormatException);
  });

  test('one balanced /ActualText span per cluster, no duplicate text', () {
    final content = writer.contentStream(
      runFromJson(fixture),
      ActualTextScope.cluster,
    );
    expect(markedContentBalanced(content), isTrue);
    final spans = RegExp(r'/Span <</ActualText <([0-9A-F]+)>>> BDC')
        .allMatches(content)
        .map((m) => decodePdfUtf16BeHex(m.group(1)!));
    expect(spans.toList(), ['कि', 'ता', 'ब']);
    expect(spans.join(), expected, reason: 'source text exactly once');
    expect(RegExp(r'\bBDC\b').allMatches(content).length, 3);
    expect(RegExp(r'\bEMC\b').allMatches(content).length, 3);
    // Every glyph is drawn exactly once, inside a span.
    expect(RegExp(r'Tj').allMatches(content).length, 5);
    expect(content.indexOf('<022E> Tj') < content.indexOf('<0039> Tj'), isTrue);
  });

  test('run scope has one span; control has none', () {
    final run = runFromJson(fixture);
    final whole = writer.contentStream(run, ActualTextScope.run);
    expect(RegExp(r'\bBDC\b').allMatches(whole).length, 1);
    expect(whole, contains(pdfUtf16BeHex(expected)));
    final none = writer.contentStream(run, ActualTextScope.none);
    expect(none, isNot(contains('BDC')));
    expect(none, isNot(contains('ActualText')));
  });

  test('written PDF is structurally valid and embeds the font', () {
    final run = runFromJson(fixture);
    final pdf = writer.write(
      run: run,
      fontBytes: fakeFont,
      fontName: 'NotoSerifDevanagari-Regular',
      glyphToUnicode: toUni,
    );
    expect(checkPdfStructure(pdf), isEmpty);
    final s = latin1.decode(pdf);
    expect(s, contains('/Encoding /Identity-H'));
    expect(s, contains('/CIDToGIDMap /Identity'));
    expect(s, contains('/FontFile2 8 0 R'));
    expect(s, contains('FAKE-FONT-BYTES'));
    expect(s, contains('/MarkInfo << /Marked true >>'));
    expect(RegExp('/ActualText').allMatches(s).length, 3);
    expect(s, contains('<0039> <0915>'), reason: 'क ToUnicode');
    expect(s, isNot(contains('<022E> <')), reason: 'i-matra variant unmapped');
    expect(run.text, expected, reason: 'source unchanged');
  });

  test('broken PDFs are rejected by the structure check', () {
    final pdf = writer.write(
      run: runFromJson(fixture),
      fontBytes: fakeFont,
      fontName: 'NotoSerifDevanagari-Regular',
    );
    final s = latin1.decode(pdf);
    final i = s.indexOf('0000000015 00000 n');
    expect(i, greaterThan(0));
    final bad = s.replaceRange(i, i + 10, '0000000016');
    expect(
      checkPdfStructure(Uint8List.fromList(latin1.encode(bad))),
      isNotEmpty,
    );
    final cut = Uint8List.sublistView(pdf, 0, pdf.length - 7);
    expect(checkPdfStructure(cut), isNotEmpty);
    expect(
      checkPdfStructure(Uint8List.fromList(utf8.encode('hello'))),
      isNotEmpty,
    );
    expect(markedContentBalanced('EMC BDC'), isFalse);
    expect(markedContentBalanced('BDC BDC EMC'), isFalse);
  });

  test('unmapped or malformed clusters fail loudly', () {
    ShapedRun runOf(List<ShapedGlyph> g) =>
        ShapedRun(text: expected, glyphs: g, unitsPerEm: 1000);
    const g0 = ShapedGlyph(glyphId: 57, cluster: 0, xAdvance: 700);
    expect(
      () =>
          runOf([g0, const ShapedGlyph(glyphId: 1, cluster: 9, xAdvance: 1)])
              .clusters(),
      throwsA(isA<ShapedRunException>()),
    );
    expect(
      () =>
          runOf([const ShapedGlyph(glyphId: 1, cluster: 2, xAdvance: 1), g0])
              .clusters(),
      throwsA(isA<ShapedRunException>()),
    );
    expect(
      () =>
          runOf([const ShapedGlyph(glyphId: 1, cluster: 1, xAdvance: 1)])
              .clusters(),
      throwsA(isA<ShapedRunException>()),
    );
    expect(() => runOf([]).clusters(), throwsA(isA<ShapedRunException>()));
    expect(
      () => writer.contentStream(
        runOf([const ShapedGlyph(glyphId: 70000, cluster: 0, xAdvance: 1)]),
        ActualTextScope.cluster,
      ),
      throwsA(isA<ShapedRunException>()),
    );
  });

  test('glyph list is immutable; source text never modified', () {
    final run = runFromJson(fixture);
    expect(
      () => run.glyphs.add(
        const ShapedGlyph(glyphId: 1, cluster: 0, xAdvance: 1),
      ),
      throwsUnsupportedError,
    );
    writer.write(run: run, fontBytes: fakeFont, fontName: 'X');
    expect(run.text, expected);
    expect(cps(run.text), '0915 093F 0924 093E 092C');
  });
}
