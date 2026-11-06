import 'package:ai_book_translator/features/engine/pdf/pdf_models.dart';

/// Synthetic glyph boxes for layout tests: fixed-width characters (6 pt
/// wide, 10 pt tall) starting at ([x], [y] = baseline).
List<PdfGlyph> glyphsAt(String text, double x, double y, {double w = 6}) => [
  for (var i = 0; i < text.length; i++)
    if (text[i] != ' ')
      PdfGlyph(
        text[i],
        PdfBox(left: x + i * w, top: y + 10, right: x + i * w + w, bottom: y),
      ),
];

PdfPageInfo pageWith(
  List<PdfGlyph> glyphs, {
  int pageNumber = 1,
  String? text,
  List<PdfFontInfo> fonts = const [],
  PageTextStatus status = PageTextStatus.textLayer,
}) => PdfPageInfo(
  pageNumber: pageNumber,
  width: 612,
  height: 792,
  runs: [
    PdfTextRun(
      text: text ?? glyphs.map((g) => g.char).join(),
      pageNumber: pageNumber,
      box: const PdfBox(left: 0, top: 792, right: 612, bottom: 0),
    ),
  ],
  fonts: fonts,
  imageCount: 0,
  textOperatorCount: glyphs.isEmpty ? 0 : 1,
  status: status,
  glyphs: glyphs,
);
