import 'package:xml/xml.dart';

import 'book_document.dart';
import 'parse_exception.dart';
import 'safe_xml.dart';
import 'safe_zip.dart';

/// DOCX import (V1-IMP-02, DOCX part, M2 spike).
///
/// Reads `word/document.xml` paragraphs (`w:p`) in order. Text comes from
/// `w:t`, with `w:tab` as a space and `w:br` as a line break. Paragraph
/// styles `Title` and `Heading1`..`Heading6` (or an outline level) become
/// headings; `Title`/`Heading1` start a new chapter.
class DocxParser {
  const DocxParser();

  ParsedDocx parse(SafeZip zip) {
    final documentXml = zip.readText('word/document.xml');
    if (documentXml == null) {
      throw const ParseException(
        ParseErrorCode.missingPart,
        'word/document.xml',
      );
    }
    final doc = parseSafeXml(documentXml, partName: 'word/document.xml');
    final body = firstByLocalName(doc, 'body');
    if (body == null) {
      throw const ParseException(ParseErrorCode.missingPart, 'w:body');
    }

    final chapters = <Chapter>[];
    var current = ChapterBuilder(0);
    for (final paragraph in allByLocalName(body, 'p')) {
      final text = _paragraphText(paragraph);
      if (text.trim().isEmpty) continue;
      final level = _headingLevel(paragraph);
      if (level == 1 && !current.isEmpty) {
        chapters.add(current.build());
        current = ChapterBuilder(chapters.length);
      }
      if (level > 0) {
        current.add(BlockType.heading, text, level: level);
      } else {
        current.add(BlockType.paragraph, text);
      }
    }
    if (!current.isEmpty) chapters.add(current.build());
    if (chapters.isEmpty) {
      throw const ParseException(ParseErrorCode.noText);
    }

    String? title;
    final coreXml = zip.readText('docProps/core.xml');
    if (coreXml != null) {
      final core = parseSafeXml(coreXml, partName: 'docProps/core.xml');
      final t = firstByLocalName(core, 'title')?.innerText;
      if (t != null && collapseWhitespace(t).isNotEmpty) {
        title = collapseWhitespace(t);
      }
    }
    return ParsedDocx(title: title, chapters: chapters);
  }

  static String _paragraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendants.whereType<XmlElement>()) {
      switch (node.localName) {
        case 't':
          buffer.write(node.innerText);
        case 'tab':
          buffer.write(' ');
        case 'br':
        case 'cr':
          buffer.write('\n');
      }
    }
    return buffer.toString();
  }

  static int _headingLevel(XmlElement paragraph) {
    final properties = paragraph.childElements
        .where((e) => e.localName == 'pPr')
        .firstOrNull;
    if (properties == null) return 0;
    for (final element in properties.childElements) {
      if (element.localName == 'pStyle') {
        final style = (attributeByLocalName(element, 'val') ?? '')
            .toLowerCase()
            .replaceAll(' ', '');
        if (style == 'title') return 1;
        final match = RegExp(r'^heading([1-6])$').firstMatch(style);
        if (match != null) return int.parse(match.group(1)!);
      }
      if (element.localName == 'outlineLvl') {
        final value = int.tryParse(attributeByLocalName(element, 'val') ?? '');
        if (value != null && value >= 0 && value <= 5) return value + 1;
      }
    }
    return 0;
  }
}

class ParsedDocx {
  const ParsedDocx({required this.title, required this.chapters});

  final String? title;
  final List<Chapter> chapters;
}
