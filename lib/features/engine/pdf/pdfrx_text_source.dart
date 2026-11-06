import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;

import '../parser/import_limits.dart';
import '../parser/parse_exception.dart';
import 'pdf_models.dart';
import 'pdf_structure_scanner.dart';
import 'pdf_text_source.dart';

/// [PdfTextSource] built from two parts (M2b-1a):
/// - **pdfrx / PDFium** for text runs and their coordinates;
/// - [PdfStructureScanner] for page fonts, images and text operators, which
///   pdfrx's public API does not expose.
///
/// The PDFium runtime must be initialized by the caller before [read]
/// (`pdfrxFlutterInitialize()` in the app, `pdfrxInitialize()` in tests).
///
/// Known limitation: fonts are reported per page, not per run
/// ([PdfTextSourceCapabilities.perRunFontName] is false).
class PdfrxTextSource implements PdfTextSource {
  const PdfrxTextSource({
    this.limits = const ImportLimits(),
    this.scanner = const PdfStructureScanner(),
  });

  final ImportLimits limits;
  final PdfStructureScanner scanner;

  @override
  String get engineId => 'pdfrx+structure';

  @override
  PdfTextSourceCapabilities get capabilities => const PdfTextSourceCapabilities(
    textRuns: true,
    coordinates: true,
    perRunFontName: false,
    pageFontDictionary: true,
    imageDetection: true,
  );

  @override
  Future<PdfDocumentInfo> read(Uint8List bytes, {String? fileName}) async {
    checkPdfBytes(bytes, limits);
    final warnings = <String>[];

    PdfStructureReport? structure;
    try {
      structure = scanner.scan(bytes);
      warnings.addAll(structure.warnings);
    } on Object catch (e) {
      warnings.add('structure scan failed: ${e.runtimeType}');
    }

    final pdfrx.PdfDocument document;
    try {
      // A copy, so the caller's original bytes are never touched.
      document = await pdfrx.PdfDocument.openData(
        Uint8List.fromList(bytes),
        sourceName: fileName ?? 'import.pdf',
      );
    } on pdfrx.PdfPasswordException {
      throw const ParseException(
        ParseErrorCode.corruptContainer,
        'password-protected PDF',
      );
    } on Object catch (e) {
      throw ParseException(
        ParseErrorCode.corruptContainer,
        'PDF engine could not open the file (${e.runtimeType})',
      );
    }

    try {
      final structurePages = structure?.pages ?? const <PdfStructurePage>[];
      if (structure != null && structurePages.length != document.pages.length) {
        warnings.add(
          'page count differs: engine ${document.pages.length}, '
          'structure ${structurePages.length}',
        );
      }
      final pages = <PdfPageInfo>[];
      for (final page in document.pages) {
        final text = await page.loadStructuredText();
        final runs = <PdfTextRun>[
          for (final f in text.fragments)
            PdfTextRun(
              text: f.text,
              pageNumber: page.pageNumber,
              box: PdfBox(
                left: f.bounds.left,
                top: f.bounds.top,
                right: f.bounds.right,
                bottom: f.bounds.bottom,
              ),
            ),
        ];
        final info =
            page.pageNumber <= structurePages.length &&
                structurePages.length == document.pages.length
            ? structurePages[page.pageNumber - 1]
            : null;
        pages.add(
          PdfPageInfo(
            pageNumber: page.pageNumber,
            width: page.width,
            height: page.height,
            runs: runs,
            fonts: info?.fonts ?? const [],
            imageCount: info?.imageCount,
            textOperatorCount: info?.textOperatorCount,
            status: classifyPage(
              hasVisibleText: text.fullText.trim().isNotEmpty,
              imageCount: info?.imageCount,
              textOperatorCount: info?.textOperatorCount,
            ),
          ),
        );
      }
      return PdfDocumentInfo(
        engineId: engineId,
        capabilities: capabilities,
        sha256: sha256.convert(bytes).toString(),
        pages: pages,
        encrypted: structure?.encrypted ?? false,
        warnings: warnings,
      );
    } finally {
      await document.dispose();
    }
  }
}

/// Refuses empty, oversized or non-PDF input before any engine sees it.
void checkPdfBytes(Uint8List bytes, ImportLimits limits) {
  if (bytes.isEmpty) throw const ParseException(ParseErrorCode.empty);
  if (bytes.length > limits.maxFileBytes) {
    throw ParseException(ParseErrorCode.tooLarge, '${bytes.length} bytes');
  }
  if (!hasPdfHeader(bytes)) {
    throw const ParseException(ParseErrorCode.unsupportedFormat, 'no %PDF-');
  }
}

/// `%PDF-` within the first 1024 bytes (the spec allows leading junk).
bool hasPdfHeader(Uint8List bytes) {
  final end = bytes.length < 1024 ? bytes.length : 1024;
  for (var i = 0; i + 5 <= end; i++) {
    if (bytes[i] == 0x25 &&
        bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 &&
        bytes[i + 3] == 0x46 &&
        bytes[i + 4] == 0x2D) {
      return true;
    }
  }
  return false;
}
