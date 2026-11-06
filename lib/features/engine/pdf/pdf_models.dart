/// Data model for PDF text extraction (M2b-1a, V1-PDF-01, V1-PDF-04,
/// V1-OCR-01).
///
/// Rule: a field is `null` when the engine that produced it cannot tell.
/// Nothing here is guessed (see docs/TEXT_ENCODING_FONT_COMPATIBILITY.md).
library;

/// Rectangle in PDF page coordinates: points (1/72 inch), origin at the
/// bottom-left of the page, `top >= bottom`.
class PdfBox {
  const PdfBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => top - bottom;

  @override
  String toString() => 'PdfBox($left, $top, $right, $bottom)';
}

/// One run of text as the extraction engine reports it, in extraction
/// order (which may differ from visual reading order – V1-PDF-02).
class PdfTextRun {
  const PdfTextRun({
    required this.text,
    required this.pageNumber,
    required this.box,
    this.fontName,
  });

  /// Text exactly as extracted (raw layer L0, not normalized).
  final String text;

  /// 1-based page number.
  final int pageNumber;

  /// Bounding box of the run.
  final PdfBox box;

  /// Font of this run, only when the engine reports fonts per run.
  /// `null` = not available from the engine (see
  /// [PdfTextSourceCapabilities.perRunFontName]); page-level fonts are in
  /// [PdfPageInfo.fonts].
  final String? fontName;
}

/// How likely it is that text in this font can be mapped to Unicode.
enum UnicodeMappingRisk {
  /// ToUnicode CMap present, or a simple font with a standard encoding.
  low,

  /// Custom `/Differences` encoding without ToUnicode: depends on glyph
  /// names, may or may not map.
  medium,

  /// No ToUnicode and an encoding that carries no character meaning
  /// (Identity-H/V CID fonts, Type3 fonts). Extraction is unreliable (RC-008).
  high,

  /// Not enough information in the font dictionary.
  unknown,
}

/// Font metadata read from a page's font resources.
class PdfFontInfo {
  const PdfFontInfo({
    required this.resourceName,
    required this.subtype,
    required this.baseFont,
    required this.subsetTag,
    required this.embedded,
    required this.hasToUnicode,
    required this.encoding,
    required this.mappingRisk,
  });

  /// Resource key on the page, e.g. `F1`.
  final String resourceName;

  /// `/Subtype`: Type1, TrueType, Type0, Type3, MMType1 … (`null` if absent).
  final String? subtype;

  /// `/BaseFont` exactly as written, e.g. `ABCDEF+NotoSansDevanagari`.
  final String? baseFont;

  /// Six-letter subset prefix (`ABCDEF`) when the font is a subset.
  final String? subsetTag;

  /// Whether a font program is embedded (FontFile/FontFile2/FontFile3, or a
  /// Type3 font). `null` when the dictionary could not be resolved.
  final bool? embedded;

  /// Whether a `/ToUnicode` CMap entry exists (its contents are not
  /// validated in M2b-1a).
  final bool hasToUnicode;

  /// `/Encoding` name (e.g. `WinAnsiEncoding`, `Identity-H`), `custom` for an
  /// encoding dictionary, `null` if absent.
  final String? encoding;

  final UnicodeMappingRisk mappingRisk;

  /// Font name without the subset prefix, e.g. `NotoSansDevanagari`.
  String? get fontName {
    final name = baseFont;
    if (name == null) return null;
    return subsetTag == null ? name : name.substring(subsetTag!.length + 1);
  }

  bool get isSubset => subsetTag != null;
}

/// Text-layer status of a page (V1-OCR-01).
enum PageTextStatus {
  /// Extractable text found.
  textLayer,

  /// No extractable text, but images are drawn: typical scanned page.
  imageOnly,

  /// Text-showing operators exist, but nothing could be extracted (e.g.
  /// fonts without usable Unicode mapping).
  textNotExtractable,

  /// No text, no images, no text operators: an empty page.
  blank,

  /// No extractable text and the page structure could not be inspected.
  unknownNoText;

  /// Whether this page needs OCR before it can be translated.
  bool get ocrRequired =>
      this == imageOnly || this == textNotExtractable || this == unknownNoText;
}

/// Everything known about one page.
class PdfPageInfo {
  const PdfPageInfo({
    required this.pageNumber,
    required this.width,
    required this.height,
    required this.runs,
    required this.fonts,
    required this.imageCount,
    required this.textOperatorCount,
    required this.status,
  });

  final int pageNumber;

  /// Page size in points (as reported by the text engine).
  final double width;
  final double height;

  final List<PdfTextRun> runs;

  /// Fonts in the page resources (incl. nested form XObjects). Not
  /// associated with individual runs in M2b-1a.
  final List<PdfFontInfo> fonts;

  /// Images drawn on the page (image XObjects + inline images), `null` when
  /// the structure could not be inspected.
  final int? imageCount;

  /// Number of text-showing operators (Tj, TJ, ', "), `null` when unknown.
  final int? textOperatorCount;

  final PageTextStatus status;

  String get text => runs.map((r) => r.text).join();
}

/// What an engine can and cannot report. Used to write honest diagnostics.
class PdfTextSourceCapabilities {
  const PdfTextSourceCapabilities({
    required this.textRuns,
    required this.coordinates,
    required this.perRunFontName,
    required this.pageFontDictionary,
    required this.imageDetection,
  });

  final bool textRuns;
  final bool coordinates;
  final bool perRunFontName;
  final bool pageFontDictionary;
  final bool imageDetection;
}

/// Result of reading one PDF.
class PdfDocumentInfo {
  const PdfDocumentInfo({
    required this.engineId,
    required this.capabilities,
    required this.sha256,
    required this.pages,
    required this.encrypted,
    required this.warnings,
  });

  final String engineId;
  final PdfTextSourceCapabilities capabilities;

  /// SHA-256 of the original bytes (the original is never modified).
  final String sha256;
  final List<PdfPageInfo> pages;

  /// `/Encrypt` present. Structure inspection of streams is skipped then.
  final bool encrypted;

  /// Technical notes for diagnostics. Never contain book text.
  final List<String> warnings;

  int get pageCount => pages.length;

  /// No page has an extractable text layer (V1-OCR-01).
  bool get missingTextLayer =>
      pages.every((p) => p.status != PageTextStatus.textLayer);

  /// Every non-blank page needs OCR: treated as a scanned PDF.
  bool get looksScanned {
    final content = pages.where((p) => p.status != PageTextStatus.blank);
    return content.isNotEmpty && content.every((p) => p.status.ocrRequired);
  }

  List<int> get pagesNeedingOcr => [
    for (final p in pages)
      if (p.status.ocrRequired) p.pageNumber,
  ];
}
