import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/glyph_pdf_writer.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/pdf_structure_check.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/pdf_text_string.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/shaped_run.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/truetype_info.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hb_fixture.dart';

/// M2b-3b-2a/2b. Uses the committed HarfBuzz output
/// (test/fixtures/pdf_probe/<case>.hb.json, Noto Serif Devanagari Regular +
/// Noto Serif Regular, HarfBuzz 15.0.0) and fake font blobs; no font file is
/// needed here. Visual correctness is NOT claimed by these tests.
const dir = 'test/fixtures/pdf_probe';
const cases = ['c01_kitab', 'c02_kshetra', 'c03_rashtra_mixed'];

String cps(String s) => s.runes
    .map((r) => r.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join(' ');

void main() {
  const writer = GlyphPdfWriter();
  final fx = {for (final c in cases) c: HbFixture.load('$dir/$c.hb.json')};
  final expected = {
    for (final c in cases) c: File('$dir/$c.txt').readAsStringSync(),
  };
  Uint8List fake(int _) => fakeTtf(1000);

  test('expected fixtures keep the exact source code points', () {
    expect(cps(expected['c01_kitab']!), '0915 093F 0924 093E 092C');
    expect(cps(expected['c02_kshetra']!), '0915 094D 0937 0947 0924 094D 0930');
    expect(
      cps(expected['c03_rashtra_mixed']!),
      '0930 093E 0937 094D 091F 094D 0930 0020 0927 0930 094D 092E 0020 '
      '0049 006E 0064 0069 0061 0020 0031 0032 0033',
    );
    for (final c in cases) {
      expect(fx[c]!.text, expected[c], reason: c);
    }
  });

  test('C01: i-matra glyph first, text stays logical', () {
    final clusters = fx['c01_kitab']!.run().clusters();
    expect(clusters.map((c) => c.text).toList(), ['कि', 'ता', 'ब']);
    expect(clusters.first.glyphs.map((g) => g.glyphId).toList(), [558, 57]);
    expect(cps(clusters.first.text), '0915 093F');
  });

  test('C02: conjunct ligatures and e-matra map to source ranges', () {
    final run = fx['c02_kshetra']!.run();
    final clusters = run.clusters();
    expect(run.glyphs.length, 3, reason: '7 code points, 3 glyphs');
    expect(clusters.map((c) => c.text).toList(), ['क्षे', 'त्र']);
    expect(clusters.map((c) => [c.start, c.end]).toList(), [
      [0, 4],
      [4, 7],
    ]);
    // क्ष ligature + zero-width e-matra share one cluster.
    expect(clusters.first.glyphs.map((g) => g.glyphId).toList(), [92, 40]);
    expect(clusters.first.glyphs[1].xAdvance, 0);
    expect(clusters.map((c) => c.text).join(), expected['c02_kshetra']);
  });

  test('C03: mixed fonts, reph after its base, digits kept as 123', () {
    final run = fx['c03_rashtra_mixed']!.run();
    final clusters = run.clusters();
    expect(clusters.map((c) => c.text).toList(), [
      'रा', 'ष्ट्र', ' ', 'ध', 'र्म', ' ', //
      'I', 'n', 'd', 'i', 'a', ' ', '1', '2', '3',
    ]);
    expect(clusters.map((c) => c.font).toList(), [
      0, 0, 0, 0, 0, 0, //
      1, 1, 1, 1, 1, 1, 1, 1, 1,
    ]);
    final rm = clusters[4];
    expect(rm.glyphs.map((g) => g.glyphId).toList(), [82, 514]);
    expect(cps(rm.text), '0930 094D 092E', reason: 'reph drawn after म');
    expect(clusters.map((c) => c.text).join(), expected['c03_rashtra_mixed']);
    final content = writer.contentStream(run, ActualTextScope.cluster);
    expect(RegExp(r'/F1 28 Tf').allMatches(content).length, 1);
    expect(RegExp(r'/F2 28 Tf').allMatches(content).length, 1);
    expect(content.indexOf('/F1 28 Tf') < content.indexOf('/F2 28 Tf'), isTrue);
  });

  test('UTF-16BE text strings with BOM', () {
    expect(pdfUtf16BeHex('कि'), 'FEFF0915093F');
    expect(pdfUtf16BeHex('𝄞'), 'FEFFD834DD1E');
    expect(pdfUtf16BeHex('123'), 'FEFF003100320033');
    for (final c in cases) {
      expect(decodePdfUtf16BeHex(pdfUtf16BeHex(expected[c]!)), expected[c]);
    }
    expect(() => decodePdfUtf16BeHex('0915'), throwsFormatException);
  });

  test(
    'every case: spans cover the source exactly once, all glyphs inside',
    () {
      for (final c in cases) {
        final run = fx[c]!.run();
        final content = writer.contentStream(run, ActualTextScope.cluster);
        expect(checkActualText(content, expected[c]!), isEmpty, reason: c);
        expect(markedContentBalanced(content), isTrue, reason: c);
        expect(
          RegExp(r'\bTj\b').allMatches(content).length,
          run.glyphs.length,
          reason: c,
        );
        expect(
          RegExp(r'\bBDC\b').allMatches(content).length,
          run.clusters().length,
          reason: c,
        );
      }
    },
  );

  test('ActualText checker catches duplicates, nesting and bad encoding', () {
    final src = expected['c01_kitab']!;
    final ok = writer.contentStream(
      fx['c01_kitab']!.run(),
      ActualTextScope.cluster,
    );
    final span =
        '/Span <</ActualText <${pdfUtf16BeHex('ब')}>>> BDC <0050> Tj EMC';
    expect(
      checkActualText('$ok\n$span', src),
      contains(contains('duplicates')),
    );
    expect(
      checkActualText(
        '/Span <</ActualText <${pdfUtf16BeHex('कि')}>>> BDC '
        '/Span <</ActualText <${pdfUtf16BeHex('ताब')}>>> BDC <0001> Tj EMC EMC',
        src,
      ),
      contains('nested /ActualText span'),
    );
    expect(
      checkActualText(
        '/Span <</ActualText <0915093F>>> BDC <0001> Tj EMC',
        'कि',
      ),
      contains('replacement text is not UTF-16BE with BOM'),
    );
    expect(
      checkActualText('<0001> Tj', 'क'),
      contains('glyph drawn outside an /ActualText span'),
    );
    expect(checkActualText('EMC', ''), contains('EMC without BDC'));
    expect(markedContentBalanced('EMC BDC'), isFalse);
    expect(markedContentBalanced('BDC BDC EMC'), isFalse);
  });

  test('strict ToUnicode never contradicts /ActualText; cmapAll does', () {
    final c01 = fx['c01_kitab']!;
    expect(
      GlyphPdfWriter.toUnicodeEntries(
        c01.run(),
        0,
        c01.glyphToUnicode(0),
        ToUnicodePolicy.strict,
      ),
      {80: 0x092C},
      reason: 'only ब is a single-glyph, single-code-point cluster',
    );
    final c02 = fx['c02_kshetra']!;
    expect(
      GlyphPdfWriter.toUnicodeEntries(
        c02.run(),
        0,
        c02.glyphToUnicode(0),
        ToUnicodePolicy.strict,
      ),
      isEmpty,
    );
    expect(
      GlyphPdfWriter.toUnicodeEntries(
        c02.run(),
        0,
        c02.glyphToUnicode(0),
        ToUnicodePolicy.cmapAll,
      ),
      {40: 0x0947},
      reason: 'the e-matra glyph alone would extract as े a second time',
    );
    final c03 = fx['c03_rashtra_mixed']!;
    final latin = GlyphPdfWriter.toUnicodeEntries(
      c03.run(),
      1,
      c03.glyphToUnicode(1),
      ToUnicodePolicy.strict,
    );
    expect(latin.values.toSet(), 'India 123'.runes.toSet());
  });

  test('two-font PDF is structurally valid with two embedded fonts', () {
    final c03 = fx['c03_rashtra_mixed']!;
    final pdf = writer.write(run: c03.run(), fonts: c03.pdfFonts(fake));
    expect(checkPdfStructure(pdf), isEmpty);
    final s = latin1.decode(pdf);
    expect(RegExp('/Subtype /Type0').allMatches(s).length, 2);
    expect(RegExp('/FontFile2').allMatches(s).length, 2);
    expect(s, contains('/BaseFont /NotoSerifDevanagari-Regular'));
    expect(s, contains('/BaseFont /NotoSerif-Regular'));
    expect(s, contains('/Encoding /Identity-H'));
    expect(s, contains('/CIDToGIDMap /Identity'));
    expect(s, contains('/MarkInfo << /Marked true >>'));
    expect(RegExp('/ActualText').allMatches(s).length, 15);
  });

  test('broken PDFs are rejected by the structure check', () {
    final c01 = fx['c01_kitab']!;
    final pdf = writer.write(run: c01.run(), fonts: c01.pdfFonts(fake));
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
  });

  test('missing or too small embedded fonts are refused', () {
    final c01 = fx['c01_kitab']!;
    expect(sfntNumGlyphs(fakeTtf(600)), 600);
    expect(sfntNumGlyphs(Uint8List(0)), isNull);
    expect(
      () => writer.write(
        run: c01.run(),
        fonts: c01.pdfFonts((_) => Uint8List(0)),
      ),
      throwsArgumentError,
    );
    // glyph 558 cannot exist in a font with 100 glyphs (e.g. a bad subset).
    expect(
      () => writer.write(
        run: c01.run(),
        fonts: c01.pdfFonts((_) => fakeTtf(100)),
      ),
      throwsA(isA<ShapedRunException>()),
    );
    expect(
      () => writer.write(run: c01.run(), fonts: const []),
      throwsArgumentError,
    );
  });

  test('missing glyphs and malformed clusters fail loudly', () {
    final src = expected['c01_kitab']!;
    ShapedRun runOf(List<ShapedGlyph> g, {int fonts = 1}) =>
        ShapedRun(text: src, glyphs: g, unitsPerEm: List.filled(fonts, 1000));
    const g0 = ShapedGlyph(glyphId: 57, cluster: 0, xAdvance: 700);
    void bad(ShapedRun r) =>
        expect(r.clusters, throwsA(isA<ShapedRunException>()));
    bad(runOf([const ShapedGlyph(glyphId: 0, cluster: 0, xAdvance: 1)]));
    bad(runOf([g0, const ShapedGlyph(glyphId: 1, cluster: 9, xAdvance: 1)]));
    bad(runOf([const ShapedGlyph(glyphId: 1, cluster: 2, xAdvance: 1), g0]));
    bad(runOf([const ShapedGlyph(glyphId: 1, cluster: 1, xAdvance: 1)]));
    bad(runOf([]));
    bad(runOf([const ShapedGlyph(glyphId: 70000, cluster: 0, xAdvance: 1)]));
    bad(
      runOf([const ShapedGlyph(glyphId: 5, cluster: 0, xAdvance: 1, font: 1)]),
    );
    bad(
      runOf([
        g0,
        const ShapedGlyph(glyphId: 5, cluster: 0, xAdvance: 1, font: 1),
      ], fonts: 2),
    );
  });

  test('glyph list is immutable; source text never modified', () {
    final c03 = fx['c03_rashtra_mixed']!;
    final run = c03.run();
    expect(
      () => run.glyphs.add(
        const ShapedGlyph(glyphId: 1, cluster: 0, xAdvance: 1),
      ),
      throwsUnsupportedError,
    );
    expect(() => run.unitsPerEm.add(1), throwsUnsupportedError);
    writer.write(run: run, fonts: c03.pdfFonts(fake));
    expect(run.text, expected['c03_rashtra_mixed']);
    expect(cps(run.text), cps(expected['c03_rashtra_mixed']!));
  });
}
