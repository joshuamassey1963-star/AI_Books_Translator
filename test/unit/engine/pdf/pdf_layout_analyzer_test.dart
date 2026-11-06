import 'package:ai_book_translator/features/engine/pdf/pdf_layout_analyzer.dart';
import 'package:ai_book_translator/features/engine/pdf/pdf_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_fixtures.dart';

/// Pure-geometry tests on synthetic glyph boxes (no PDFium).
void main() {
  const analyzer = PdfLayoutAnalyzer();

  List<String> lineTexts(PdfPageLayout l) => [for (final x in l.lines) x.text];

  test('RC-005: words split on gaps, not inside words', () {
    final layout = analyzer.analyzePage(
      pageWith(glyphsAt('Hello world again', 72, 700)),
    );
    expect(layout.lines.single.words.map((w) => w.text), [
      'Hello',
      'world',
      'again',
    ]);
    expect(layout.lines.single.text, 'Hello world again');
  });

  test('RC-005: overlapping Devanagari marks stay in the same word', () {
    // न + ि (matra drawn overlapping), then a gap, then म.
    const glyphs = [
      PdfGlyph('न', PdfBox(left: 72, top: 710, right: 80, bottom: 700)),
      PdfGlyph('ि', PdfBox(left: 70, top: 714, right: 79, bottom: 700)),
      PdfGlyph('म', PdfBox(left: 90, top: 710, right: 98, bottom: 700)),
    ];
    final words = analyzer.analyzePage(pageWith(glyphs)).lines.single.words;
    expect(words, hasLength(2));
    expect(words.first.glyphs, hasLength(2));
  });

  test('paragraphs split on larger vertical gaps', () {
    final layout = analyzer.analyzePage(
      pageWith([
        ...glyphsAt('first line', 72, 700),
        ...glyphsAt('second line', 72, 686),
        ...glyphsAt('third line', 72, 672),
        ...glyphsAt('new para', 72, 640),
        ...glyphsAt('more text', 72, 626),
      ]),
    );
    expect(layout.columnCount, 1);
    expect(layout.paragraphs.map((p) => p.text), [
      'first line second line third line',
      'new para more text',
    ]);
  });

  test('first-line indent starts a paragraph', () {
    final layout = analyzer.analyzePage(
      pageWith([
        ...glyphsAt('one two', 72, 700),
        ...glyphsAt('three four', 72, 686),
        ...glyphsAt('indented', 96, 672),
        ...glyphsAt('five six', 72, 658),
      ]),
    );
    expect(layout.paragraphs, hasLength(2));
    expect(layout.paragraphs.last.text, 'indented five six');
  });

  test('V1-PDF-02: two columns read left column first', () {
    // Drawn right column first on purpose.
    final layout = analyzer.analyzePage(
      pageWith([
        ...glyphsAt('Right one', 330, 700),
        ...glyphsAt('Right two', 330, 686),
        ...glyphsAt('Right three', 330, 672),
        ...glyphsAt('Left one', 72, 700),
        ...glyphsAt('Left two', 72, 686),
        ...glyphsAt('Left three', 72, 672),
      ]),
    );
    expect(layout.columnCount, 2);
    expect(lineTexts(layout), [
      'Left one',
      'Left two',
      'Left three',
      'Right one',
      'Right two',
      'Right three',
    ]);
    expect(layout.paragraphs, hasLength(2));
  });

  test('a centred title above two columns comes first', () {
    final layout = analyzer.analyzePage(
      pageWith([
        ...glyphsAt('Right one', 330, 700),
        ...glyphsAt('Right two', 330, 686),
        ...glyphsAt('Left one', 72, 700),
        ...glyphsAt('Left two', 72, 686),
        ...glyphsAt('A Title That Spans', 200, 740),
      ]),
    );
    expect(lineTexts(layout), [
      'A Title That Spans',
      'Left one',
      'Left two',
      'Right one',
      'Right two',
    ]);
  });

  test('RC-006: repeated header and page-number footer are candidates', () {
    final pages = [
      for (var i = 1; i <= 3; i++)
        pageWith(pageNumber: i, [
          ...glyphsAt('My Book Title', 72, 770),
          ...glyphsAt('Body text of page $i', 72, 600),
          ...glyphsAt('$i', 300, 30),
        ]),
    ];
    final doc = analyzer.analyzeDocument(pages);
    final headers = doc.headerFooter.where(
      (c) => c.position == MarginPosition.header,
    );
    final footers = doc.headerFooter.where(
      (c) => c.position == MarginPosition.footer,
    );
    expect(headers.map((c) => c.text).toSet(), {'My Book Title'});
    expect(headers, hasLength(3));
    expect(footers, hasLength(3));
    expect(doc.headerFooter.any((c) => c.text.startsWith('Body')), isFalse);
    // Candidates are reported, not deleted: the text is still in the layout.
    expect(
      doc.pages.first.paragraphs.any((p) => p.text == 'My Book Title'),
      isTrue,
    );
  });

  test('single page: bare page number is a candidate, header is not', () {
    final doc = analyzer.analyzeDocument([
      pageWith([...glyphsAt('Only Title', 72, 770), ...glyphsAt('7', 300, 30)]),
    ]);
    expect(doc.headerFooter.single.text, '7');
    expect(doc.headerFooter.single.reason, HeaderFooterReason.pageNumber);
  });

  test('empty page gives an empty layout', () {
    final layout = analyzer.analyzePage(pageWith(const []));
    expect(layout.lines, isEmpty);
    expect(layout.columnCount, 0);
  });
}
