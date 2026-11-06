import 'dart:typed_data';

import '../text/text_encoding.dart';
import 'book_document.dart';
import 'parse_exception.dart';

/// Plain-text import (V1-IMP-02, TXT part).
///
/// - UTF-8 (with/without BOM) and UTF-16 LE/BE with BOM (M2b-1c, RC-012).
///   UTF-16 without BOM needs an explicit [encoding] (user confirmation);
///   invalid bytes are refused instead of producing mojibake.
/// - Paragraphs are separated by blank lines; single line breaks inside a
///   paragraph are joined (hard-wrapped Gutenberg texts).
/// - A line like `Chapter 3`, `CHAPTER IV`, `Part One` or `अध्याय 2` that
///   stands alone starts a new chapter.
class TxtParser {
  const TxtParser();

  static final RegExp chapterHeading = RegExp(
    r'^(?:(?:chapter|part|book|अध्याय|भाग)\s+'
    r'(?:[0-9]+|[ivxlcdm]+|[०-९]+|one|two|three|four|five|six|seven|eight|'
    r'nine|ten|eleven|twelve|first|second|third|last)'
    r'(?:\s*[.:\-–—]\s*.{0,70})?'
    r'|prologue|epilogue|प्रस्तावना|उपसंहार)$',
    caseSensitive: false,
    unicode: true,
  );

  ParsedText parse(Uint8List bytes, {TextEncoding? encoding}) {
    final report = const EncodingDetector().detect(bytes, override: encoding);
    switch (report.status) {
      case EncodingStatus.decoded:
        break;
      case EncodingStatus.needsConfirmation:
        throw ParseException(
          ParseErrorCode.encodingNeedsConfirmation,
          report.encoding?.label,
        );
      case EncodingStatus.refused:
        throw ParseException(
          ParseErrorCode.invalidEncoding,
          report.issues.join(', '),
        );
    }
    final normalized = report.text!
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final paragraphs = normalized
        .split(RegExp(r'\n[ \t]*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (paragraphs.isEmpty) {
      throw const ParseException(ParseErrorCode.noText);
    }

    final chapters = <Chapter>[];
    var current = ChapterBuilder(0);
    for (final paragraph in paragraphs) {
      final isHeading =
          !paragraph.contains('\n') && chapterHeading.hasMatch(paragraph);
      if (isHeading) {
        if (!current.isEmpty) {
          chapters.add(current.build());
          current = ChapterBuilder(chapters.length);
        }
        current.add(BlockType.heading, paragraph, level: 1);
      } else {
        current.add(BlockType.paragraph, paragraph);
      }
    }
    if (!current.isEmpty) chapters.add(current.build());

    final firstLine = paragraphs.first.split('\n').first.trim();
    return ParsedText(
      title: firstLine.length <= 120 ? firstLine : firstLine.substring(0, 120),
      chapters: chapters,
    );
  }
}

class ParsedText {
  const ParsedText({required this.title, required this.chapters});

  final String title;
  final List<Chapter> chapters;
}
