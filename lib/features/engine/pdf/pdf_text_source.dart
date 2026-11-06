import 'dart:typed_data';

import 'pdf_models.dart';

/// Engine-independent access to the text of a PDF (V1-PDF-01).
///
/// Implementations must not modify the input bytes, must not guess
/// metadata they cannot read (leave it `null` and say so in
/// [capabilities]), and must throw `ParseException` for files they refuse.
abstract interface class PdfTextSource {
  /// Stable id for diagnostics, e.g. `pdfrx+structure`.
  String get engineId;

  PdfTextSourceCapabilities get capabilities;

  Future<PdfDocumentInfo> read(Uint8List bytes, {String? fileName});
}

/// Decides a page's text-layer status from what is known about it.
///
/// [hasVisibleText]: the text engine returned non-whitespace text.
/// [imageCount] / [textOperatorCount]: from structure inspection, `null`
/// when unknown.
PageTextStatus classifyPage({
  required bool hasVisibleText,
  required int? imageCount,
  required int? textOperatorCount,
}) {
  if (hasVisibleText) return PageTextStatus.textLayer;
  if (imageCount == null || textOperatorCount == null) {
    return PageTextStatus.unknownNoText;
  }
  if (imageCount > 0) return PageTextStatus.imageOnly;
  if (textOperatorCount > 0) return PageTextStatus.textNotExtractable;
  return PageTextStatus.blank;
}
