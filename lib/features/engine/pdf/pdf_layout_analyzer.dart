import 'dart:math' as math;

import 'pdf_models.dart';

/// Rebuilds words, lines, paragraphs, a basic reading order (one or two
/// columns) and header/footer candidates from character boxes (M2b-1b,
/// V1-PDF-02, V1-PDF-03, RC-005, RC-006).
///
/// Pure geometry, no guessing of fonts or languages. Works on PDF points
/// with origin bottom-left. Limits: at most two columns; no table
/// detection; rotated text is not handled.
class PdfLayoutAnalyzer {
  const PdfLayoutAnalyzer({
    this.wordGapFactor = 0.5,
    this.paragraphGapFactor = 1.6,
    this.indentFactor = 1.5,
    this.marginZone = 0.08,
  });

  /// Gap between glyphs (relative to median glyph height) that splits words.
  final double wordGapFactor;

  /// Vertical gap (relative to the median line gap) that starts a paragraph.
  final double paragraphGapFactor;

  /// First-line indent (relative to median glyph height) that starts a
  /// paragraph.
  final double indentFactor;

  /// Fraction of page height at top/bottom where header/footer may sit.
  final double marginZone;

  PdfPageLayout analyzePage(PdfPageInfo page) {
    // A whitespace character in extraction order is a word break even when
    // the boxes are close (tight glyph boxes, narrow spaces).
    final breakBefore = Set<PdfGlyph>.identity();
    final glyphs = <PdfGlyph>[];
    var pendingBreak = false;
    for (final g in page.glyphs) {
      if (g.char.trim().isEmpty) {
        pendingBreak = true;
        continue;
      }
      if (g.box.height <= 0) continue;
      if (pendingBreak) breakBefore.add(g);
      pendingBreak = false;
      glyphs.add(g);
    }
    if (glyphs.isEmpty) {
      return PdfPageLayout(
        pageNumber: page.pageNumber,
        lines: const [],
        columnCount: 0,
        paragraphs: const [],
      );
    }
    final medianHeight = _median([for (final g in glyphs) g.box.height]);
    final lines = _buildLines(glyphs, medianHeight, breakBefore);
    final gutter = _findGutter(lines, page.width);
    final ordered = gutter == null ? lines : _orderTwoColumns(lines, gutter);
    final paragraphs = _buildParagraphs(ordered, medianHeight, gutter);
    return PdfPageLayout(
      pageNumber: page.pageNumber,
      lines: ordered,
      columnCount: gutter == null ? 1 : 2,
      paragraphs: paragraphs,
    );
  }

  /// Analyzes all pages and marks lines that repeat in the top/bottom
  /// margin zone on many pages (or are bare page numbers) as header/footer
  /// candidates. Candidates are reported, never deleted silently.
  PdfDocumentLayout analyzeDocument(List<PdfPageInfo> pages) {
    final layouts = [for (final p in pages) analyzePage(p)];
    final counts = <String, int>{};
    final zoneLines = <int, List<PdfLine>>{};
    for (var i = 0; i < pages.length; i++) {
      final zone = [
        for (final l in layouts[i].lines)
          if (_inMarginZone(l, pages[i].height)) l,
      ];
      zoneLines[i] = zone;
      for (final key in {for (final l in zone) _normalize(l.text)}) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    final minRepeats = math.max(2, (pages.length / 2).ceil());
    final candidates = <HeaderFooterCandidate>[];
    for (var i = 0; i < pages.length; i++) {
      for (final line in zoneLines[i]!) {
        final repeated = (counts[_normalize(line.text)] ?? 0) >= minRepeats;
        final pageNumber = _pageNumberPattern.hasMatch(line.text);
        if (!repeated && !pageNumber) continue;
        candidates.add(
          HeaderFooterCandidate(
            pageNumber: pages[i].pageNumber,
            text: line.text,
            position: line.box.top > pages[i].height / 2
                ? MarginPosition.header
                : MarginPosition.footer,
            reason: repeated
                ? HeaderFooterReason.repeated
                : HeaderFooterReason.pageNumber,
          ),
        );
      }
    }
    return PdfDocumentLayout(pages: layouts, headerFooter: candidates);
  }

  bool _inMarginZone(PdfLine line, double pageHeight) =>
      line.box.bottom >= pageHeight * (1 - marginZone) ||
      line.box.top <= pageHeight * marginZone;

  static final _pageNumberPattern = RegExp(
    r'^\s*(page\s*)?[\d\u0966-\u096F]+(\s*(/|of)\s*[\d\u0966-\u096F]+)?\s*$',
    caseSensitive: false,
  );

  static String _normalize(String text) => text
      .replaceAll(RegExp(r'[\d\u0966-\u096F]+'), '#')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  List<PdfLine> _buildLines(
    List<PdfGlyph> glyphs,
    double medianHeight,
    Set<PdfGlyph> breakBefore,
  ) {
    final sorted = [...glyphs]
      ..sort((a, b) {
        final byTop = b.box.top.compareTo(a.box.top);
        return byTop != 0 ? byTop : a.box.left.compareTo(b.box.left);
      });
    final groups = <List<PdfGlyph>>[];
    final bands = <(double, double)>[]; // (bottom, top) of each line band
    for (final g in sorted) {
      var placed = false;
      for (var i = groups.length - 1; i >= 0 && i >= groups.length - 3; i--) {
        final (bottom, top) = bands[i];
        final overlap =
            math.min(top, g.box.top) - math.max(bottom, g.box.bottom);
        final minHeight = math.min(top - bottom, g.box.height);
        if (minHeight > 0 && overlap >= 0.5 * minHeight) {
          groups[i].add(g);
          bands[i] = (math.min(bottom, g.box.bottom), math.max(top, g.box.top));
          placed = true;
          break;
        }
      }
      if (!placed) {
        groups.add([g]);
        bands.add((g.box.bottom, g.box.top));
      }
    }
    final lines = <PdfLine>[];
    for (final group in groups) {
      group.sort((a, b) => a.box.left.compareTo(b.box.left));
      lines.addAll(_splitLine(group, medianHeight, breakBefore));
    }
    lines.sort((a, b) => b.box.top.compareTo(a.box.top));
    return lines;
  }

  /// Splits one visual row into words, and into separate lines when a very
  /// wide gap separates two column fragments on the same row.
  List<PdfLine> _splitLine(
    List<PdfGlyph> row,
    double medianHeight,
    Set<PdfGlyph> breakBefore,
  ) {
    final wordGap = medianHeight * wordGapFactor;
    final columnGap = medianHeight * 3;
    final result = <PdfLine>[];
    var words = <PdfWord>[];
    var current = <PdfGlyph>[row.first];
    void closeWord() {
      words.add(PdfWord(current));
      current = [];
    }

    for (var i = 1; i < row.length; i++) {
      final gap = row[i].box.left - row[i - 1].box.right;
      if (gap > columnGap) {
        closeWord();
        result.add(PdfLine(words));
        words = [];
      } else if (gap > wordGap || (breakBefore.contains(row[i]) && gap >= 0)) {
        closeWord();
      }
      current.add(row[i]);
    }
    closeWord();
    result.add(PdfLine(words));
    return result;
  }

  /// A vertical gutter between 30% and 70% of the page width that no line
  /// crosses (allowing up to 20% spanning lines, e.g. a title), with at
  /// least two lines on each side.
  double? _findGutter(List<PdfLine> lines, double pageWidth) {
    if (lines.length < 4 || pageWidth <= 0) return null;
    double? best;
    var bestSpanning = lines.length + 1;
    var bestDistance = double.infinity;
    final center = pageWidth / 2;
    for (var x = pageWidth * 0.3; x <= pageWidth * 0.7; x += pageWidth / 100) {
      var left = 0;
      var right = 0;
      var spanning = 0;
      for (final l in lines) {
        if (l.box.right <= x) {
          left++;
        } else if (l.box.left >= x) {
          right++;
        } else {
          spanning++;
        }
      }
      if (left >= 2 && right >= 2 && spanning <= lines.length * 0.2) {
        // Fewest spanning lines first, then the gutter closest to the
        // page centre (keeps a centred title out of a column).
        final distance = (x - center).abs();
        if (spanning < bestSpanning ||
            (spanning == bestSpanning && distance < bestDistance)) {
          bestSpanning = spanning;
          bestDistance = distance;
          best = x;
        }
      }
    }
    return best;
  }

  /// Top-to-bottom sections separated by spanning lines; inside each
  /// section the left column is read before the right column.
  List<PdfLine> _orderTwoColumns(List<PdfLine> lines, double gutter) {
    final out = <PdfLine>[];
    var left = <PdfLine>[];
    var right = <PdfLine>[];
    void flush() {
      out
        ..addAll(left)
        ..addAll(right);
      left = [];
      right = [];
    }

    for (final l in lines) {
      if (l.box.right <= gutter) {
        left.add(l);
      } else if (l.box.left >= gutter) {
        right.add(l);
      } else {
        flush();
        out.add(l);
      }
    }
    flush();
    return out;
  }

  List<PdfParagraph> _buildParagraphs(
    List<PdfLine> lines,
    double medianHeight,
    double? gutter,
  ) {
    if (lines.isEmpty) return const [];
    int column(PdfLine l) => gutter == null
        ? 0
        : l.box.right <= gutter
        ? 0
        : l.box.left >= gutter
        ? 1
        : -1;
    final gaps = <double>[
      for (var i = 1; i < lines.length; i++)
        if (column(lines[i]) == column(lines[i - 1]) &&
            lines[i - 1].box.bottom > lines[i].box.top)
          lines[i - 1].box.bottom - lines[i].box.top,
    ];
    final medianGap = gaps.isEmpty ? medianHeight * 0.4 : _median(gaps);
    // A gap of more than two glyph heights always separates blocks, even
    // when few lines make the median gap itself large.
    final breakGap = math.min(
      math.max(medianGap * paragraphGapFactor, medianHeight * 0.6),
      medianHeight * 2,
    );
    final paragraphs = <PdfParagraph>[];
    var current = <PdfLine>[lines.first];
    for (var i = 1; i < lines.length; i++) {
      final prev = lines[i - 1];
      final line = lines[i];
      final gap = prev.box.bottom - line.box.top;
      final newBlock =
          column(line) != column(prev) ||
          gap < -medianHeight || // moved up: new column/section
          gap > breakGap ||
          line.box.left > prev.box.left + medianHeight * indentFactor;
      if (newBlock) {
        paragraphs.add(PdfParagraph(current));
        current = [];
      }
      current.add(line);
    }
    paragraphs.add(PdfParagraph(current));
    return paragraphs;
  }

  static double _median(List<double> values) {
    final v = [...values]..sort();
    return v[v.length ~/ 2];
  }
}

class PdfWord {
  PdfWord(this.glyphs);
  final List<PdfGlyph> glyphs;
  String get text => glyphs.map((g) => g.char).join();
  PdfBox get box => _union(glyphs.map((g) => g.box));
}

class PdfLine {
  PdfLine(this.words);
  final List<PdfWord> words;
  String get text => words.map((w) => w.text).join(' ');
  PdfBox get box => _union(words.map((w) => w.box));
}

class PdfParagraph {
  PdfParagraph(this.lines);
  final List<PdfLine> lines;
  String get text => lines.map((l) => l.text).join(' ');
}

class PdfPageLayout {
  const PdfPageLayout({
    required this.pageNumber,
    required this.lines,
    required this.columnCount,
    required this.paragraphs,
  });

  final int pageNumber;

  /// Lines in reconstructed reading order.
  final List<PdfLine> lines;
  final int columnCount;
  final List<PdfParagraph> paragraphs;
}

enum MarginPosition { header, footer }

enum HeaderFooterReason { repeated, pageNumber }

class HeaderFooterCandidate {
  const HeaderFooterCandidate({
    required this.pageNumber,
    required this.text,
    required this.position,
    required this.reason,
  });

  final int pageNumber;
  final String text;
  final MarginPosition position;
  final HeaderFooterReason reason;
}

class PdfDocumentLayout {
  const PdfDocumentLayout({required this.pages, required this.headerFooter});
  final List<PdfPageLayout> pages;
  final List<HeaderFooterCandidate> headerFooter;
}

PdfBox _union(Iterable<PdfBox> boxes) {
  var left = double.infinity;
  var bottom = double.infinity;
  var right = double.negativeInfinity;
  var top = double.negativeInfinity;
  for (final b in boxes) {
    left = math.min(left, b.left);
    bottom = math.min(bottom, b.bottom);
    right = math.max(right, b.right);
    top = math.max(top, b.top);
  }
  return PdfBox(left: left, top: top, right: right, bottom: bottom);
}
