import 'dart:convert';
import 'dart:typed_data';

import 'pdf_text_string.dart';
import 'shaped_run.dart';
import 'truetype_info.dart';

/// Where `/ActualText` replacement text is attached.
enum ActualTextScope {
  /// One `/Span` per shaped cluster (default).
  cluster,

  /// One `/Span` around the whole run.
  run,

  /// No `/ActualText` (negative control: text comes from ToUnicode only).
  none,
}

/// Which glyphs get a ToUnicode entry.
enum ToUnicodePolicy {
  /// Only glyphs that, everywhere in this run, are the single glyph of a
  /// cluster whose source text is exactly the glyph's `cmap` code point.
  /// ToUnicode then never disagrees with `/ActualText` (D-030).
  strict,

  /// Every glyph that is the direct `cmap` image of a code point (Session 12
  /// behaviour). Kept as a control: MuPDF then repeats a zero-width matra.
  cmapAll,
}

/// One font to embed (TrueType outlines, full file or a retain-gids subset).
class PdfFontInput {
  const PdfFontInput({
    required this.bytes,
    required this.name,
    this.glyphToUnicode = const {},
    this.bbox = const [-500, -400, 1500, 1100],
    this.ascent = 1069,
    this.descent = -400,
    this.capHeight = 714,
  });

  final Uint8List bytes;

  /// PDF font name (letters, digits, hyphen).
  final String name;

  /// Glyph id → code point for glyphs that are the direct `cmap` image of one
  /// code point (from the font's `cmap`; computed outside the writer).
  final Map<int, int> glyphToUnicode;

  /// Font metrics in 1/1000 em, read from the font's head/hhea/OS2 tables.
  final List<int> bbox;
  final int ascent;
  final int descent;
  final int capHeight;
}

/// M2b-3b-2 spike: a tiny one-page PDF writer for one HarfBuzz-shaped line.
///
/// Each font: Type0 / CIDFontType2, `Identity-H`, `CIDToGIDMap /Identity`,
/// so the 2-byte codes in the content stream are glyph ids; the font file is
/// embedded as `FontFile2`. Each glyph is placed with its own text matrix
/// from the HarfBuzz advances/offsets. The logical source text is kept in
/// marked content `/Span <</ActualText <FEFF...>>> BDC ... EMC`, so glyphs
/// drawn in visual order (i-matra first, reph last) still extract in source
/// order.
///
/// Not a production writer: one line, LTR only, no wrapping, no pages.
class GlyphPdfWriter {
  const GlyphPdfWriter({
    this.fontSize = 28,
    this.pageWidth = 360,
    this.pageHeight = 100,
    this.originX = 20,
    this.baselineY = 50,
  });

  final double fontSize;
  final double pageWidth;
  final double pageHeight;
  final double originX;
  final double baselineY;

  /// Content stream text (ASCII). Exposed for tests.
  String contentStream(ShapedRun run, ActualTextScope scope) {
    final clusters = run.clusters();
    final ops = <String>['BT'];
    if (scope == ActualTextScope.run) {
      ops.add(_bdc(run.text));
    }
    var x = originX;
    int? currentFont;
    for (final c in clusters) {
      if (scope == ActualTextScope.cluster) {
        ops.add(_bdc(c.text));
      }
      for (final g in c.glyphs) {
        if (g.font != currentFont) {
          currentFont = g.font;
          ops.add('/F${g.font + 1} ${_n(fontSize)} Tf');
        }
        final scale = fontSize / run.unitsPerEm[g.font];
        final gx = x + g.xOffset * scale;
        final gy = baselineY + g.yOffset * scale;
        ops.add('1 0 0 1 ${_n(gx)} ${_n(gy)} Tm <${_hex4(g.glyphId)}> Tj');
        x += g.xAdvance * scale;
      }
      if (scope == ActualTextScope.cluster) {
        ops.add('EMC');
      }
    }
    if (scope == ActualTextScope.run) {
      ops.add('EMC');
    }
    ops.add('ET');
    return ops.join('\n');
  }

  /// ToUnicode entries (glyph id → code point) for [font] under [policy].
  static Map<int, int> toUnicodeEntries(
    ShapedRun run,
    int font,
    Map<int, int> glyphToUnicode,
    ToUnicodePolicy policy,
  ) {
    final clusters = run.clusters().where((c) => c.font == font).toList();
    final used = {
      for (final c in clusters)
        for (final g in c.glyphs) g.glyphId,
    };
    final result = <int, int>{};
    for (final gid in used) {
      final cp = glyphToUnicode[gid];
      if (cp == null) {
        continue;
      }
      if (policy == ToUnicodePolicy.strict) {
        final ok = clusters
            .where((c) => c.glyphs.any((g) => g.glyphId == gid))
            .every(
              (c) => c.glyphs.length == 1 && c.text == String.fromCharCode(cp),
            );
        if (!ok) {
          continue;
        }
      }
      result[gid] = cp;
    }
    return result;
  }

  /// Writes the PDF. [fonts] are indexed by [ShapedGlyph.font].
  Uint8List write({
    required ShapedRun run,
    required List<PdfFontInput> fonts,
    ActualTextScope scope = ActualTextScope.cluster,
    ToUnicodePolicy toUnicode = ToUnicodePolicy.strict,
  }) {
    if (fonts.length != run.unitsPerEm.length) {
      throw ArgumentError('one PdfFontInput per font index is required');
    }
    final content = ascii.encode(contentStream(run, scope));
    final objs = <Uint8List?>[
      _a('<< /Type /Catalog /Pages 2 0 R /MarkInfo << /Marked true >> >>'),
      _a('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      null, // page, written once the font object numbers are known
      _stream('', content),
    ];
    final fontRefs = <String>[];
    for (var fi = 0; fi < fonts.length; fi++) {
      final f = fonts[fi];
      final glyphs = run.glyphs.where((g) => g.font == fi).toList();
      if (glyphs.isEmpty) {
        continue;
      }
      if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(f.name)) {
        throw ArgumentError.value(f.name, 'name', 'PDF name chars only');
      }
      final numGlyphs = sfntNumGlyphs(f.bytes);
      if (numGlyphs == null) {
        throw ArgumentError('font ${f.name}: no embeddable TrueType font data');
      }
      final upem = run.unitsPerEm[fi];
      final widths = <int, int>{};
      for (final g in glyphs) {
        if (g.glyphId >= numGlyphs) {
          throw ShapedRunException(
            'glyph ${g.glyphId} missing from font ${f.name} ($numGlyphs glyphs)',
          );
        }
        widths.putIfAbsent(g.glyphId, () => (g.xAdvance * 1000 / upem).round());
      }
      final ids = widths.keys.toList()..sort();
      final w = ids.map((id) => '$id [${widths[id]}]').join(' ');
      final tu = toUnicodeEntries(run, fi, f.glyphToUnicode, toUnicode);
      final bf = [
        for (final gid in tu.keys.toList()..sort())
          '<${_hex4(gid)}> <${pdfUtf16BeHex(String.fromCharCode(tu[gid]!)).substring(4)}>',
      ];
      final n = objs.length + 1;
      objs
        ..add(
          _a(
            '<< /Type /Font /Subtype /Type0 /BaseFont /${f.name} '
            '/Encoding /Identity-H /DescendantFonts [${n + 1} 0 R]'
            '${bf.isEmpty ? '' : ' /ToUnicode ${n + 4} 0 R'} >>',
          ),
        )
        ..add(
          _a(
            '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /${f.name} '
            '/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) '
            '/Supplement 0 >> /FontDescriptor ${n + 2} 0 R '
            '/CIDToGIDMap /Identity /W [$w] /DW 1000 >>',
          ),
        )
        ..add(
          _a(
            '<< /Type /FontDescriptor /FontName /${f.name} /Flags 4 '
            '/FontBBox [${f.bbox.join(' ')}] /ItalicAngle 0 '
            '/Ascent ${f.ascent} /Descent ${f.descent} '
            '/CapHeight ${f.capHeight} /StemV 80 /FontFile2 ${n + 3} 0 R >>',
          ),
        )
        ..add(_stream(' /Length1 ${f.bytes.length}', f.bytes));
      if (bf.isNotEmpty) {
        objs.add(_stream('', ascii.encode(_toUnicodeCMap(bf))));
      }
      fontRefs.add('/F${fi + 1} $n 0 R');
    }
    objs[2] = _a(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_n(pageWidth)} '
      '${_n(pageHeight)}] /Resources << /Font << ${fontRefs.join(' ')} >> >> '
      '/Contents 4 0 R >>',
    );
    return _assemble([for (final o in objs) o!]);
  }

  static String _bdc(String text) =>
      '/Span <</ActualText <${pdfUtf16BeHex(text)}>>> BDC';

  static String _toUnicodeCMap(List<String> bf) => [
    '/CIDInit /ProcSet findresource begin',
    '12 dict begin',
    'begincmap',
    '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def',
    '/CMapName /Adobe-Identity-UCS def',
    '/CMapType 2 def',
    '1 begincodespacerange',
    '<0000> <FFFF>',
    'endcodespacerange',
    '${bf.length} beginbfchar',
    ...bf,
    'endbfchar',
    'endcmap',
    'CMapName currentdict /CMap defineresource pop',
    'end',
    'end',
  ].join('\n');

  static Uint8List _a(String s) => ascii.encode(s);

  static Uint8List _stream(String extraDict, List<int> data) {
    final b = BytesBuilder(copy: false)
      ..add(ascii.encode('<< /Length ${data.length}$extraDict >>\nstream\n'))
      ..add(data)
      ..add(ascii.encode('\nendstream'));
    return b.toBytes();
  }

  static Uint8List _assemble(List<Uint8List> objs) {
    final out = BytesBuilder(copy: false)
      ..add(ascii.encode('%PDF-1.7\n'))
      ..add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    final offsets = <int>[];
    for (var i = 0; i < objs.length; i++) {
      offsets.add(out.length);
      out
        ..add(ascii.encode('${i + 1} 0 obj\n'))
        ..add(objs[i])
        ..add(ascii.encode('\nendobj\n'));
    }
    final xref = out.length;
    final x = StringBuffer('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      x.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    x
      ..write('trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\n')
      ..write('startxref\n$xref\n%%EOF\n');
    out.add(ascii.encode(x.toString()));
    return out.toBytes();
  }

  static String _hex4(int v) => v.toRadixString(16).toUpperCase().padLeft(4, '0');

  static String _n(double v) {
    final s = v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}
