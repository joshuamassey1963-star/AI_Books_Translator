import 'dart:typed_data';

import '../pdf/pdf_models.dart';

/// OCR integration interface (V1-OCR-03). **No OCR engine exists in V1**;
/// engines (ML Kit, Apple Vision, optional server) arrive in V2 (V2-OCR-01).
///
/// OCR output is its own text layer and is never trusted without
/// validation: every result carries confidence and `validated == false`
/// until a user or validator confirms it (V2-OCR-09).
abstract interface class OcrEngine {
  String get engineId;
  String get engineVersion;

  /// BCP-47 language codes this engine can recognise, e.g. `hi`, `en`.
  Set<String> get supportedLanguages;

  /// Whether the engine can run on this device right now.
  Future<bool> isAvailable();

  Future<OcrResult> recognize(OcrRequest request);
}

class OcrRequest {
  const OcrRequest({
    required this.imageBytes,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.languages,
    this.pageNumber,
    this.region,
  });

  /// Encoded page image (PNG), rendered from the untouched original.
  final Uint8List imageBytes;
  final int pixelWidth;
  final int pixelHeight;

  /// Languages to try, in priority order (e.g. `['hi', 'en']`).
  final List<String> languages;
  final int? pageNumber;

  /// Optional region in pixel coordinates (V2-OCR-06). `null` = whole image.
  final PdfBox? region;
}

class OcrWord {
  const OcrWord({required this.text, required this.box, this.confidence});

  final String text;

  /// Pixel coordinates in the request image.
  final PdfBox box;

  /// 0..1, `null` when the engine does not report it.
  final double? confidence;
}

class OcrResult {
  const OcrResult({
    required this.engineId,
    required this.engineVersion,
    required this.text,
    required this.words,
    this.meanConfidence,
  });

  final String engineId;
  final String engineVersion;
  final String text;
  final List<OcrWord> words;
  final double? meanConfidence;

  /// OCR is never accepted automatically.
  bool get validated => false;
}

class OcrUnavailableException implements Exception {
  const OcrUnavailableException([this.reason = 'OCR is not available yet']);
  final String reason;
  @override
  String toString() => 'OcrUnavailableException: $reason';
}

/// The only engine in V1: it says honestly that OCR is not available, so
/// pages stay in "OCR required" instead of getting fake text.
class UnavailableOcrEngine implements OcrEngine {
  const UnavailableOcrEngine();

  @override
  String get engineId => 'none';

  @override
  String get engineVersion => '0';

  @override
  Set<String> get supportedLanguages => const {};

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<OcrResult> recognize(OcrRequest request) =>
      Future.error(const OcrUnavailableException());
}
