import 'dart:convert';
import 'dart:typed_data';

import '../engine/legacy/legacy_font_converter.dart';
import '../engine/parser/book_parser.dart';
import '../engine/parser/import_limits.dart';
import '../engine/parser/parse_exception.dart';
import '../engine/text/text_encoding.dart';
import '../engine/text/unicode_normalizer.dart';

/// Developer-only diagnostics (DEV-01, debug builds only). Pure functions
/// over the existing engines, so the screen shows only real engine output.
/// Nothing here logs, stores or uploads text.

/// How the typed sample text is turned into bytes before testing.
enum SampleBytes {
  utf8('UTF-8 (no BOM)'),
  utf8Bom('UTF-8 with BOM'),
  utf16leBom('UTF-16 LE with BOM'),
  utf16beBom('UTF-16 BE with BOM'),
  utf16leNoBom('UTF-16 LE without BOM'),
  invalidUtf8('Invalid UTF-8 (typed text + bad bytes)');

  const SampleBytes(this.label);
  final String label;

  Uint8List encode(String text) => Uint8List.fromList(switch (this) {
    SampleBytes.utf8 => const Utf8Encoder().convert(text),
    SampleBytes.utf8Bom => [
      0xEF,
      0xBB,
      0xBF,
      ...const Utf8Encoder().convert(text),
    ],
    SampleBytes.utf16leBom => [0xFF, 0xFE, ..._le(text)],
    SampleBytes.utf16beBom => [0xFE, 0xFF, ..._be(text)],
    SampleBytes.utf16leNoBom => _le(text),
    SampleBytes.invalidUtf8 => [
      ...const Utf8Encoder().convert(text),
      0xC3,
      0x28,
    ],
  });

  static List<int> _le(String s) => [
    for (final u in s.codeUnits) ...[u & 0xFF, u >> 8],
  ];
  static List<int> _be(String s) => [
    for (final u in s.codeUnits) ...[u >> 8, u & 0xFF],
  ];
}

class EncodingDiagnostics {
  const EncodingDiagnostics({
    required this.byteCount,
    required this.report,
    required this.nfcText,
    required this.wasNfc,
  });

  final int byteCount;
  final EncodingReport report;

  /// NFC form of the decoded text (display only; the original is unchanged).
  final String? nfcText;
  final bool? wasNfc;
}

EncodingDiagnostics inspectEncoding(Uint8List bytes, {TextEncoding? override}) {
  final report = const EncodingDetector().detect(bytes, override: override);
  final text = report.text;
  const n = UnicodeNormalizer();
  return EncodingDiagnostics(
    byteCount: bytes.length,
    report: report,
    nfcText: text == null ? null : n.toNfc(text),
    wasNfc: text == null ? null : n.isNfc(text),
  );
}

/// Legacy fonts offered in the test screen. Only Kruti Dev 010 has a
/// converter; the others exist to show the wrong-font refusal (RC-003).
const devLegacyFontChoices = ['Kruti Dev 010', 'Kruti Dev 011', 'Chanakya'];

/// Inputs taken from passing tests in `kruti_dev_010_test.dart`.
const devKrutiExamples = {
  'Hkkjr': 'भारत',
  'fgUnh': 'हिन्दी',
  'fo|ky; esa i<+kbZ': 'विद्यालय में पढ़ाई',
};

LegacyConversionResult convertLegacy(
  String input, {
  required String fontName,
  required bool confirmed,
}) => LegacyFontRegistry().convert(
  input,
  LegacyFontIdentity(fontName, confirmed: confirmed),
);

class ParseDiagnostics {
  const ParseDiagnostics({
    required this.byteCount,
    this.format,
    this.title,
    this.chapters,
    this.paragraphs,
    this.sha256,
    this.warnings = const [],
    this.error,
  });

  final int byteCount;
  final String? format;
  final String? title;
  final int? chapters;
  final int? paragraphs;
  final String? sha256;
  final List<String> warnings;
  final ParseException? error;

  bool get ok => error == null;
}

/// Runs the real [BookParser] (with its import limits) on [bytes].
ParseDiagnostics parseForDiagnostics(
  Uint8List bytes, {
  String? fileName,
  TextEncoding? textEncoding,
}) {
  try {
    final doc = const BookParser().parse(
      bytes,
      fileName: fileName,
      textEncoding: textEncoding,
    );
    return ParseDiagnostics(
      byteCount: bytes.length,
      format: doc.format.name.toUpperCase(),
      title: doc.title,
      chapters: doc.chapters.length,
      paragraphs: doc.paragraphCount,
      sha256: doc.sha256,
      warnings: doc.warnings,
    );
  } on ParseException catch (e) {
    return ParseDiagnostics(byteCount: bytes.length, error: e);
  }
}

/// Max characters rendered in the TXT preview (bounded UI, M-DEV-02a).
const devPreviewMaxChars = 3000;

/// Diagnostics for a real TXT file picked by the user (M-DEV-02a).
class TxtFileDiagnostics {
  const TxtFileDiagnostics({
    required this.fileName,
    required this.byteCount,
    required this.parse,
    this.encoding,
    this.preview,
    this.previewTruncated = false,
  });

  final String fileName;
  final int byteCount;

  /// Detector report; `null` when the file was refused before reading.
  final EncodingReport? encoding;
  final ParseDiagnostics parse;

  /// First [devPreviewMaxChars] characters of the decoded original text.
  final String? preview;
  final bool previewTruncated;

  bool get needsEncodingChoice =>
      encoding?.status == EncodingStatus.needsConfirmation;
}

/// Size check done before any bytes are read.
ParseException? checkPickedSize(
  int size, {
  ImportLimits limits = const ImportLimits(),
}) {
  if (size <= 0) return const ParseException(ParseErrorCode.empty);
  if (size > limits.maxFileBytes) {
    return ParseException(ParseErrorCode.tooLarge, '$size bytes');
  }
  return null;
}

TxtFileDiagnostics refusedBeforeRead(
  String fileName,
  int size,
  ParseException e,
) => TxtFileDiagnostics(
  fileName: fileName,
  byteCount: size,
  parse: ParseDiagnostics(byteCount: size, error: e),
);

/// Runs the encoding detector and the real [BookParser] on [bytes].
/// [bytes] are never modified.
TxtFileDiagnostics inspectTxtFile(
  String fileName,
  Uint8List bytes, {
  TextEncoding? encoding,
}) {
  final report = const EncodingDetector().detect(bytes, override: encoding);
  final parse = parseForDiagnostics(
    bytes,
    fileName: fileName,
    textEncoding: encoding,
  );
  final text = report.status == EncodingStatus.decoded ? report.text : null;
  final truncated = text != null && text.length > devPreviewMaxChars;
  return TxtFileDiagnostics(
    fileName: fileName,
    byteCount: bytes.length,
    encoding: report,
    parse: parse,
    preview: truncated ? text.substring(0, devPreviewMaxChars) : text,
    previewTruncated: truncated,
  );
}

/// A picked file kept in memory for re-parsing with a chosen encoding.
class LoadedTxt {
  const LoadedTxt(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}
