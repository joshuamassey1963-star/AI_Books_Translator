import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Generates small, legally clean PDFs in memory for tests (M2b-1a).
///
/// No fonts are embedded except dummy bytes, no book text is used, and
/// nothing is read from disk, so the public repo carries no private files.

/// One indirect object: a dictionary/array/etc. body, plus optional stream
/// bytes (the `/Length` entry is added automatically).
class PdfObj {
  PdfObj(this.body, [this.stream]);
  final String body;
  final List<int>? stream;
}

/// Assembles objects numbered 1..n (object 1 must be the catalog) with a
/// correct xref table. [trailerExtra] is appended to the trailer dict.
Uint8List buildPdf(List<PdfObj> objects, {String trailerExtra = ''}) {
  final out = BytesBuilder();
  void write(String s) => out.add(latin1.encode(s));
  write('%PDF-1.7\n');
  out.add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(out.length);
    final o = objects[i];
    write('${i + 1} 0 obj\n');
    if (o.stream == null) {
      write('${o.body}\nendobj\n');
    } else {
      final body = o.body.trim();
      final dict =
          '${body.substring(0, body.length - 2)} '
          '/Length ${o.stream!.length} >>';
      write('$dict\nstream\n');
      out.add(o.stream!);
      write('\nendstream\nendobj\n');
    }
  }
  final xref = out.length;
  write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final off in offsets) {
    write('${off.toString().padLeft(10, '0')} 00000 n \n');
  }
  write(
    'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R $trailerExtra>>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return out.toBytes();
}

List<int> flate(String s) => const ZLibEncoder().encodeBytes(latin1.encode(s));

const _helvetica =
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
    '/Encoding /WinAnsiEncoding >>';

/// One page per entry of [pageTexts], Helvetica, text at (72, 700).
/// [compress] stores content streams with FlateDecode.
Uint8List textPdf(List<String> pageTexts, {bool compress = false}) {
  // 1 catalog, 2 pages, 3 font, then (page, content) pairs.
  final kids = [for (var i = 0; i < pageTexts.length; i++) '${4 + 2 * i} 0 R'];
  final objects = <PdfObj>[
    PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
    PdfObj(
      '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pageTexts.length} >>',
    ),
    PdfObj(_helvetica),
  ];
  for (var i = 0; i < pageTexts.length; i++) {
    final content = 'BT /F1 24 Tf 72 700 Td (${pageTexts[i]}) Tj ET';
    objects
      ..add(
        PdfObj(
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + 2 * i} 0 R >>',
        ),
      )
      ..add(
        compress
            ? PdfObj('<< /Filter /FlateDecode >>', flate(content))
            : PdfObj('<< >>', latin1.encode(content)),
      );
  }
  return buildPdf(objects);
}

/// A "scanned" page: one 2x2 RGB image XObject, no text at all (RC-013).
Uint8List imageOnlyPdf({int pages = 1}) {
  final kids = [for (var i = 0; i < pages; i++) '${4 + 2 * i} 0 R'];
  final objects = <PdfObj>[
    PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
    PdfObj('<< /Type /Pages /Kids [${kids.join(' ')}] /Count $pages >>'),
    PdfObj(
      '<< /Type /XObject /Subtype /Image /Width 2 /Height 2 '
      '/ColorSpace /DeviceRGB /BitsPerComponent 8 >>',
      [255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255],
    ),
  ];
  for (var i = 0; i < pages; i++) {
    objects
      ..add(
        PdfObj(
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Resources << /XObject << /Im1 3 0 R >> >> /Contents ${5 + 2 * i} 0 R >>',
        ),
      )
      ..add(
        PdfObj('<< >>', latin1.encode('q 400 0 0 400 100 200 cm /Im1 Do Q')),
      );
  }
  return buildPdf(objects);
}

/// A page with an inline image only.
Uint8List inlineImagePdf() => buildPdf([
  PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
  PdfObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  PdfObj(
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>',
  ),
  PdfObj('<< >>', [
    ...latin1.encode('q 100 0 0 100 50 50 cm BI /W 2 /H 2 /CS /G /BPC 8 ID '),
    0x00, 0xFF, 0x45, 0x49, // binary that contains "EI" without whitespace
    ...latin1.encode('\nEI Q'),
  ]),
]);

/// One empty page.
Uint8List blankPdf() => buildPdf([
  PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
  PdfObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  PdfObj(
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>',
  ),
  PdfObj('<< >>', <int>[]),
]);

/// First page has text, second page is image-only (mixed document).
Uint8List mixedPdf() => buildPdf([
  PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
  PdfObj(
    '<< /Type /Pages /Kids [4 0 R 6 0 R] /Count 2 /MediaBox [0 0 612 792] '
    '/Resources << /Font << /F1 3 0 R >> /XObject << /Im1 8 0 R >> >> >>',
  ),
  PdfObj(_helvetica),
  // Page 1 inherits MediaBox and Resources from the Pages node.
  PdfObj('<< /Type /Page /Parent 2 0 R /Contents 5 0 R >>'),
  PdfObj('<< >>', latin1.encode('BT /F1 18 Tf 72 700 Td (Chapter One) Tj ET')),
  PdfObj('<< /Type /Page /Parent 2 0 R /Contents 7 0 R >>'),
  PdfObj('<< >>', latin1.encode('q 300 0 0 300 100 300 cm /Im1 Do Q')),
  PdfObj(
    '<< /Type /XObject /Subtype /Image /Width 1 /Height 1 '
    '/ColorSpace /DeviceGray /BitsPerComponent 8 >>',
    [128],
  ),
]);

const _toUnicodeCMap = '''/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def
/CMapName /Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
2 beginbfchar
<0001> <0928>
<0002> <092E>
endbfchar
endcmap
CMapName currentdict /CIDResource defineresource pop
end
end''';

/// A Type0 / Identity-H font named `ABCDEF+TestDeva`, not embedded.
/// Without [toUnicode] its text cannot be mapped to Unicode (RC-008).
/// With it, codes 1,2 map to "नम" (U+0928 U+092E).
Uint8List type0Pdf({required bool toUnicode}) => buildPdf([
  PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
  PdfObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  PdfObj(
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
    '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
  ),
  PdfObj('<< >>', latin1.encode('BT /F1 24 Tf 72 700 Td <00010002> Tj ET')),
  PdfObj(
    '<< /Type /Font /Subtype /Type0 /BaseFont /ABCDEF+TestDeva '
    '/Encoding /Identity-H /DescendantFonts [6 0 R]'
    '${toUnicode ? ' /ToUnicode 8 0 R' : ''} >>',
  ),
  PdfObj(
    '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /ABCDEF+TestDeva '
    '/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> '
    '/FontDescriptor 7 0 R /DW 600 >>',
  ),
  PdfObj(
    '<< /Type /FontDescriptor /FontName /ABCDEF+TestDeva /Flags 4 '
    '/FontBBox [0 -200 1000 900] /ItalicAngle 0 /Ascent 900 /Descent -200 '
    '/CapHeight 700 /StemV 80 >>',
  ),
  PdfObj('<< >>', latin1.encode(_toUnicodeCMap)),
]);

/// Structure-only fixture (not opened with PDFium): an embedded subset
/// TrueType font (dummy font bytes), a legacy-looking simple font without
/// encoding, a Differences-encoded font, a Type3 font, and a form XObject
/// that draws text with its own font.
Uint8List fontVarietyPdf() => buildPdf([
  PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
  PdfObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
  PdfObj(
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
    '/Resources << /Font << /F1 5 0 R /F2 8 0 R /F3 9 0 R /F4 10 0 R >> '
    '/XObject << /Fm1 11 0 R >> >> /Contents 4 0 R >>',
  ),
  PdfObj(
    '<< >>',
    latin1.encode(
      'BT /F1 12 Tf 72 700 Td (a) Tj /F2 12 Tf [(b) 10 (c)] TJ '
      "/F3 12 Tf (d) ' /F4 12 Tf 1 2 (e) \" ET /Fm1 Do",
    ),
  ),
  PdfObj(
    '<< /Type /Font /Subtype /TrueType /BaseFont /QWERTY+NotoSerifDevanagari '
    '/FontDescriptor 6 0 R /Encoding /WinAnsiEncoding >>',
  ),
  PdfObj(
    '<< /Type /FontDescriptor /FontName /QWERTY+NotoSerifDevanagari '
    '/Flags 32 /FontFile2 7 0 R >>',
  ),
  PdfObj('<< >>', [0, 1, 0, 0, 0, 0]),
  // Legacy-looking font: no descriptor, no encoding, not a standard-14 name.
  PdfObj('<< /Type /Font /Subtype /TrueType /BaseFont /KrutiDev010 >>'),
  PdfObj(
    '<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman '
    '/Encoding << /Type /Encoding /Differences [65 /uni0915] >> >>',
  ),
  PdfObj(
    '<< /Type /Font /Subtype /Type3 /FontBBox [0 0 1 1] '
    '/FontMatrix [0.001 0 0 0.001 0 0] /CharProcs << >> /Encoding << '
    '/Differences [] >> /FirstChar 0 /LastChar 0 /Widths [0] >>',
  ),
  PdfObj(
    '<< /Type /XObject /Subtype /Form /BBox [0 0 100 100] '
    '/Resources << /Font << /F9 12 0 R >> >> >>',
    latin1.encode('BT /F9 10 Tf (inner) Tj ET'),
  ),
  PdfObj('<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>'),
]);

/// Structure-only fixture: the font dictionary lives inside a compressed
/// object stream (PDF 1.5+ style).
Uint8List objectStreamPdf() {
  const fontObj =
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
      '/Encoding /WinAnsiEncoding >>';
  const header = '6 0 ';
  const objStm = '$header$fontObj';
  return buildPdf([
    PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
    PdfObj('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'),
    PdfObj(
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
      '/Resources << /Font << /F1 6 0 R >> >> /Contents 4 0 R >>',
    ),
    PdfObj(
      '<< /Filter /FlateDecode >>',
      flate('BT /F1 12 Tf 72 700 Td (x) Tj ET'),
    ),
    PdfObj(
      '<< /Type /ObjStm /N 1 /First ${header.length} /Filter /FlateDecode >>',
      flate(objStm),
    ),
  ]);
}

/// Marked as encrypted in the trailer (the content itself is plain, which
/// is enough to check that the scanner refuses to inspect streams).
Uint8List encryptedMarkerPdf() {
  final plain = textPdf(['Secret']);
  final text = latin1
      .decode(plain)
      .replaceFirst('/Root 1 0 R ', '/Root 1 0 R /Encrypt 99 0 R ');
  return Uint8List.fromList(latin1.encode(text));
}

/// A positioned piece of Helvetica text for [layoutPdf].
typedef PlacedText = ({double x, double y, String text, double size});

/// One page per entry; each text is drawn in the given order (which can
/// differ from reading order on purpose).
Uint8List layoutPdf(List<List<PlacedText>> pages) {
  final kids = [for (var i = 0; i < pages.length; i++) '${4 + 2 * i} 0 R'];
  final objects = <PdfObj>[
    PdfObj('<< /Type /Catalog /Pages 2 0 R >>'),
    PdfObj(
      '<< /Type /Pages /Kids [${kids.join(' ')}] /Count ${pages.length} >>',
    ),
    PdfObj(_helvetica),
  ];
  for (var i = 0; i < pages.length; i++) {
    final ops = StringBuffer();
    for (final t in pages[i]) {
      ops.write('BT /F1 ${t.size} Tf ${t.x} ${t.y} Td (${t.text}) Tj ET\n');
    }
    objects
      ..add(
        PdfObj(
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
          '/Resources << /Font << /F1 3 0 R >> >> /Contents ${5 + 2 * i} 0 R >>',
        ),
      )
      ..add(PdfObj('<< >>', latin1.encode(ops.toString())));
  }
  return buildPdf(objects);
}
