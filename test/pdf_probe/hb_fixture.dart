import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/glyph_pdf_writer.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/shaped_run.dart';

/// Test helper (M2b-3b-2): reads `<case>.hb.json` written by
/// tool/pdf_probe/hb_shape_fixture.py.
class HbFixture {
  HbFixture(this.json);

  factory HbFixture.load(String path) => HbFixture(
    jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>,
  );

  final Map<String, Object?> json;

  String get text => json['text']! as String;

  List<Map<String, Object?>> get fonts =>
      (json['fonts']! as List).cast<Map<String, Object?>>();

  int get fontCount =>
      fonts.map((f) => f['index']! as int).reduce((a, b) => a > b ? a : b) + 1;

  Map<String, Object?> font(int index) =>
      fonts.firstWhere((f) => f['index'] == index);

  ShapedRun run() => ShapedRun(
    text: text,
    unitsPerEm: [for (var i = 0; i < fontCount; i++) font(i)['upem']! as int],
    glyphs: [
      for (final g in (json['glyphs']! as List).cast<Map<String, Object?>>())
        ShapedGlyph(
          font: g['font']! as int,
          glyphId: g['gid']! as int,
          cluster: g['cluster']! as int,
          xAdvance: g['ax']! as int,
          xOffset: g['dx']! as int,
          yOffset: g['dy']! as int,
        ),
    ],
  );

  Map<int, int> glyphToUnicode(int index) => {
    for (final e in (font(index)['glyph_to_unicode']! as Map).entries)
      int.parse(e.key as String): e.value as int,
  };

  /// [bytesFor] supplies the font file bytes for a font index.
  List<PdfFontInput> pdfFonts(Uint8List Function(int index) bytesFor) => [
    for (var i = 0; i < fontCount; i++)
      PdfFontInput(
        bytes: bytesFor(i),
        name: (font(i)['file']! as String).replaceAll('.ttf', ''),
        glyphToUnicode: glyphToUnicode(i),
        bbox: (font(i)['bbox']! as List).cast<int>(),
        ascent: font(i)['ascent']! as int,
        descent: font(i)['descent']! as int,
        capHeight: font(i)['cap_height']! as int,
      ),
  ];
}

/// A minimal sfnt with only a `maxp` table (enough for the writer's
/// numGlyphs check; not a drawable font).
Uint8List fakeTtf(int numGlyphs) {
  final d = ByteData(34)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, 1)
    ..setUint32(12, 0x6D617870) // 'maxp'
    ..setUint32(20, 28)
    ..setUint32(24, 6)
    ..setUint32(28, 0x00005000)
    ..setUint16(32, numGlyphs);
  return d.buffer.asUint8List();
}
