import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../text/text_encoding.dart';
import 'book_document.dart';
import 'docx_parser.dart';
import 'epub_parser.dart';
import 'import_limits.dart';
import 'parse_exception.dart';
import 'safe_zip.dart';
import 'txt_parser.dart';

/// Entry point of the M2 parser spike: detect format by content (magic
/// bytes, not the file extension) and parse into a [BookDocument].
///
/// Pure Dart and synchronous so it can run inside `Isolate.run` later
/// (V1-PRF-02). Throws [ParseException] with an honest reason on failure.
class BookParser {
  const BookParser({this.limits = const ImportLimits()});

  final ImportLimits limits;

  BookDocument parse(
    Uint8List bytes, {
    String? fileName,
    TextEncoding? textEncoding,
  }) {
    if (bytes.isEmpty) throw const ParseException(ParseErrorCode.empty);
    if (bytes.length > limits.maxFileBytes) {
      throw ParseException(ParseErrorCode.tooLarge, '${bytes.length} bytes');
    }
    final fingerprint = sha256.convert(bytes).toString();
    final fallbackTitle = _titleFromFileName(fileName);

    switch (detectFormat(bytes)) {
      case DetectedFormat.pdf:
        throw const ParseException(ParseErrorCode.pdfNotYetSupported);
      case DetectedFormat.zip:
        final zip = SafeZip.open(bytes, limits);
        if (zip.contains('word/document.xml')) {
          final docx = const DocxParser().parse(zip);
          return BookDocument(
            format: SourceFormat.docx,
            title: docx.title ?? fallbackTitle ?? docx.chapters.first.title,
            chapters: docx.chapters,
            sha256: fingerprint,
          );
        }
        if (zip.contains('META-INF/container.xml')) {
          final epub = const EpubParser().parse(zip);
          return BookDocument(
            format: SourceFormat.epub,
            title: epub.title ?? fallbackTitle ?? epub.chapters.first.title,
            author: epub.author,
            language: epub.language,
            chapters: epub.chapters,
            sha256: fingerprint,
            warnings: epub.warnings,
          );
        }
        throw const ParseException(
          ParseErrorCode.unsupportedFormat,
          'zip without EPUB/DOCX structure',
        );
      case DetectedFormat.unknownBinary:
        throw const ParseException(ParseErrorCode.unsupportedFormat);
      case DetectedFormat.text:
        final txt = const TxtParser().parse(bytes, encoding: textEncoding);
        return BookDocument(
          format: SourceFormat.txt,
          title: fallbackTitle ?? txt.title,
          chapters: txt.chapters,
          sha256: fingerprint,
        );
    }
  }

  static String? _titleFromFileName(String? fileName) {
    if (fileName == null) return null;
    final base = fileName.split(RegExp(r'[/\\]')).last;
    final dot = base.lastIndexOf('.');
    final name = (dot > 0 ? base.substring(0, dot) : base)
        .replaceAll(RegExp(r'[_]+'), ' ')
        .trim();
    return name.isEmpty ? null : name;
  }
}

enum DetectedFormat { zip, pdf, text, unknownBinary }

/// Content sniffing (V1-IMP-05). Text = no NUL bytes in the first 8 KB,
/// or a UTF-8/UTF-16 BOM, or a clear UTF-16 byte pattern (M2b-1c).
DetectedFormat detectFormat(Uint8List bytes) {
  bool startsWith(List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x50, 0x4B, 0x03, 0x04])) return DetectedFormat.zip;
  if (startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return DetectedFormat.pdf;
  }
  // RC-012: a UTF-16 BOM (or a clear UTF-16 byte pattern) is text even
  // though it contains NUL bytes. UTF-32 BOMs are left to the decoder,
  // which refuses them with a clear reason.
  if (EncodingDetector.bomEncoding(bytes) != null) return DetectedFormat.text;
  final sample = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
  if (sample.contains(0)) {
    return EncodingDetector.utf16PatternGuess(
              bytes.length.isOdd ? bytes.sublist(0, bytes.length - 1) : bytes,
            ) ==
            null
        ? DetectedFormat.unknownBinary
        : DetectedFormat.text;
  }
  return DetectedFormat.text;
}
