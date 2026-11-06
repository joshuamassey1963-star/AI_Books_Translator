import 'package:xml/xml.dart';

import 'book_document.dart';
import 'parse_exception.dart';
import 'safe_xml.dart';
import 'safe_zip.dart';

/// EPUB 2/3 import (V1-IMP-01, M2 spike).
///
/// Own implementation on `archive` + `xml` (D-011): container.xml → OPF →
/// manifest + spine → XHTML body walk. Reading order follows the spine.
/// Headings h1-h6 and block text (p, li, blockquote, pre, dt/dd, and
/// text-only divs) become blocks; scripts, styles and images are skipped.
class EpubParser {
  const EpubParser();

  static const _blockTags = {
    'p',
    'li',
    'blockquote',
    'pre',
    'dt',
    'dd',
    'figcaption',
    'caption',
    'td',
    'th',
  };
  static const _skipTags = {'script', 'style', 'head', 'svg', 'math', 'nav'};

  ParsedEpub parse(SafeZip zip) {
    final mimetype = zip.readText('mimetype')?.trim();
    final warnings = <String>[];
    if (mimetype != null && mimetype != 'application/epub+zip') {
      warnings.add('Unexpected mimetype "$mimetype".');
    }

    final containerXml = zip.readText('META-INF/container.xml');
    if (containerXml == null) {
      throw const ParseException(
        ParseErrorCode.missingPart,
        'META-INF/container.xml',
      );
    }
    final container = parseSafeXml(containerXml, partName: 'container.xml');
    final rootfile = firstByLocalName(container, 'rootfile');
    final opfPath = rootfile?.getAttribute('full-path');
    if (opfPath == null || opfPath.isEmpty) {
      throw const ParseException(ParseErrorCode.missingPart, 'rootfile');
    }
    final opfText = zip.readText(opfPath);
    if (opfText == null) {
      throw ParseException(ParseErrorCode.missingPart, opfPath);
    }
    final opf = parseSafeXml(opfText, partName: opfPath);

    final title = _text(firstByLocalName(opf, 'title'));
    final author = _text(firstByLocalName(opf, 'creator'));
    final language = _text(firstByLocalName(opf, 'language'));

    final manifest = <String, String>{};
    for (final item in allByLocalName(opf, 'item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id != null && href != null) {
        manifest[id] = resolveZipHref(opfPath, href);
      }
    }

    final spine = allByLocalName(opf, 'itemref')
        .map((e) => e.getAttribute('idref'))
        .whereType<String>()
        .toList();
    if (spine.isEmpty) {
      throw const ParseException(ParseErrorCode.missingPart, 'spine');
    }

    final chapters = <Chapter>[];
    for (final idref in spine) {
      final path = manifest[idref];
      if (path == null || path.isEmpty) {
        warnings.add('Spine item "$idref" is not in the manifest.');
        continue;
      }
      final xhtml = zip.readText(path);
      if (xhtml == null) {
        warnings.add('Spine file "$path" is missing.');
        continue;
      }
      final doc = parseSafeXml(xhtml, partName: path);
      final builder = ChapterBuilder(chapters.length, sourcePath: path);
      final body = firstByLocalName(doc, 'body') ?? doc.rootElement;
      _walk(body, builder);
      if (builder.isEmpty) continue; // cover/blank pages
      chapters.add(builder.build());
    }
    if (chapters.isEmpty) {
      throw const ParseException(ParseErrorCode.noText);
    }

    return ParsedEpub(
      title: (title == null || title.isEmpty) ? null : title,
      author: (author == null || author.isEmpty) ? null : author,
      language: (language == null || language.isEmpty) ? null : language,
      chapters: chapters,
      warnings: warnings,
    );
  }

  void _walk(XmlElement element, ChapterBuilder builder) {
    for (final child in element.childElements) {
      final tag = child.localName.toLowerCase();
      if (_skipTags.contains(tag)) continue;
      final headingLevel = _headingLevel(tag);
      if (headingLevel > 0) {
        builder.add(BlockType.heading, child.innerText, level: headingLevel);
      } else if (_blockTags.contains(tag) && !_hasBlockChildren(child)) {
        builder.add(BlockType.paragraph, child.innerText);
      } else if (child.childElements.isEmpty ||
          (tag == 'div' && !_hasBlockChildren(child))) {
        // Text-only container (e.g. <div>text</div>, stray <span>).
        builder.add(BlockType.paragraph, child.innerText);
      } else {
        _walk(child, builder);
      }
    }
  }

  static int _headingLevel(String tag) {
    if (tag.length == 2 && tag.startsWith('h')) {
      final n = int.tryParse(tag.substring(1));
      if (n != null && n >= 1 && n <= 6) return n;
    }
    return 0;
  }

  static bool _hasBlockChildren(XmlElement element) =>
      element.descendants.whereType<XmlElement>().any((e) {
        final tag = e.localName.toLowerCase();
        return _blockTags.contains(tag) ||
            _headingLevel(tag) > 0 ||
            tag == 'div' ||
            tag == 'section';
      });

  static String? _text(XmlElement? element) =>
      element == null ? null : collapseWhitespace(element.innerText);
}

class ParsedEpub {
  const ParsedEpub({
    required this.title,
    required this.author,
    required this.language,
    required this.chapters,
    required this.warnings,
  });

  final String? title;
  final String? author;
  final String? language;
  final List<Chapter> chapters;
  final List<String> warnings;
}
