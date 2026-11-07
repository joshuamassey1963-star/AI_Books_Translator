import 'dart:convert';
import 'dart:typed_data';

import 'pdf_text_string.dart';
import 'shaped_run.dart';

/// Where `/ActualText` replacement text is attached.
enum ActualTextScope {
  /// One `/Span` per shaped cluster (default).
  cluster,

  /// One `/Span` around the whole run.
  run,

  /// No `/ActualText` (negative control: text comes from ToUnicode only).
  none,
}

/// M2b-3b-2a spike: a tiny one-page PDF writer for one HarfBuzz-shaped run.
///
/// Font: Type0 / CIDFontType2, `Identity-H`, `CIDToGIDMap /Identity`, so the
/// 2-byte codes in the content stream are glyph ids. The whole font file is
/// embedded (no subsetting yet). Each glyph is placed with its own text
/// matrix from the HarfBuzz advances/offsets. The logical source text is kept
/// in marked content `/Span <</ActualText <FEFF...>>> BDC ... EMC`, so glyphs
/// drawn in visual order (i-matra first) still extract in source order.
///
/// Not a production writer: one line, one font, LTR only, no wrapping.
class GlyphPdfWriter {
  const GlyphPdfWriter({
    this.fontSize = 36,
    this.pageWidth = 300,
    this.pageHeight = 200,
    this.originX = 50,
    this.baselineY = 100,
  });

  final double fontSize;
  final double pageWidth;
  final double pageHeight;
  final double originX;
  final double baselineY;

  /// Content stream text (ASCII). Exposed for tests.
  String contentStream(ShapedRun run, ActualTextScope scope) {
    final clusters = run.clusters();
    final scale = fontSize / run.unitsPerEm;
    final ops = <String>['BT', '/F1 ${_n(fontSize)} Tf'];
    if (scope == ActualTextScope.run) {
      ops.add(_bdc(run.text));
    }
    var x = originX;
    for (final c in clusters) {
      if (scope == ActualTextScope.cluster) {
        ops.add(_bdc(c.text));
      }
      for (final g in c.glyphs) {
        if (g.glyphId < 0 || g.glyphId > 0xFFFF) {
          throw ShapedRunException('glyph id ${g.glyphId} out of range');
        }
        final gx = x + g.xOffset * scale;
        final gy = baselineY + g.yOffset * scale;
        final hex = g.glyphId.toRadixString(16).toUpperCase().padLeft(4, '0');
        ops.add('1 0 0 1 ${_n(gx)} ${_n(gy)} Tm <$hex> Tj');
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

  /// Writes the PDF. [glyphToUnicode] lists only glyphs that are the direct
  /// `cmap` image of one code point; shaped-only glyphs get no ToUnicode
  /// entry (their text comes from `/ActualText`).
  Uint8List write({
    required ShapedRun run,
    required Uint8List fontBytes,
    required String fontName,
    Map<int, int> glyphToUnicode = const {},
    ActualTextScope scope = ActualTextScope.cluster,
  }) {
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(fontName)) {
      throw ArgumentError.value(fontName, 'fontName', 'PDF name chars only');
    }
    final content = ascii.encode(contentStream(run, scope));
    final upem = run.unitsPerEm;
    final widths = <int, int>{};
    for (final g in run.glyphs) {
      widths.putIfAbsent(g.glyphId, () => (g.xAdvance * 1000 / upem).round());
    }
    final ids = widths.keys.toList()..sort();
    final w = ids.map((id) => '$id [${widths[id]}]').join(' ');
    final used = ids.toSet();
    final bf = [
      for (final e in glyphToUnicode.entries)
        if (used.contains(e.key))
          '<${_hex4(e.key)}> <${pdfUtf16BeHex(String.fromCharCode(e.value)).substring(4)}>',
    ];

    final objs = <Uint8List>[
      _a('<< /Type /Catalog /Pages 2 0 R /MarkInfo << /Marked true >> >>'),
      _a('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
      _a(
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${_n(pageWidth)} '
        '${_n(pageHeight)}] /Resources << /Font << /F1 5 0 R >> >> '
        '/Contents 4 0 R >>',
      ),
      _stream('', content),
      _a(
        '<< /Type /Font /Subtype /Type0 /BaseFont /$fontName '
        '/Encoding /Identity-H /DescendantFonts [6 0 R]'
        '${bf.isEmpty ? '' : ' /ToUnicode 9 0 R'} >>',
      ),
      _a(
        '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /$fontName '
        '/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) '
        '/Supplement 0 >> /FontDescriptor 7 0 R /CIDToGIDMap /Identity '
        '/W [$w] /DW 1000 >>',
      ),
      _a(
        '<< /Type /FontDescriptor /FontName /$fontName /Flags 4 '
        '/FontBBox [-500 -400 1500 1100] /ItalicAngle 0 /Ascent 1069 '
        '/Descent -400 /CapHeight 714 /StemV 80 /FontFile2 8 0 R >>',
      ),
      _stream(' /Length1 ${fontBytes.length}', fontBytes),
      if (bf.isNotEmpty) _stream('', ascii.encode(_toUnicodeCMap(bf))),
    ];
    return _assemble(objs);
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
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
        : s;
  }
}
