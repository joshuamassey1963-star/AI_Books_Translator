import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds small, legally clean test books in memory, so the repo carries no
/// copyrighted fixtures. Texts are public-domain style placeholders.

Uint8List zipOf(Map<String, String> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile.string(entry.key, entry.value));
  }
  return ZipEncoder().encodeBytes(archive);
}

Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

const _container = '''<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

String xhtml(String body, {String doctype = '<!DOCTYPE html>'}) =>
    '''<?xml version="1.0" encoding="UTF-8"?>
$doctype
<html xmlns="http://www.w3.org/1999/xhtml"><head><title>t</title>
<style>p { color: red; }</style></head>
<body>$body</body></html>''';

/// A three-file EPUB: cover (image only), chapter 1, chapter 2 in a
/// sub-folder with a space in its name. Spine order is ch1 before ch2 even
/// though the manifest lists ch2 first.
Uint8List sampleEpub({
  String title = 'The Sample Book',
  String? chapter1,
  String? chapter2,
}) {
  final opf =
      '''<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="id">sample-1</dc:identifier>
    <dc:title>$title</dc:title>
    <dc:creator>Test Author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="ch2" href="text/part%20two/ch2.xhtml" media-type="application/xhtml+xml"/>
    <item id="cover" href="cover.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch1" href="text/ch1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="cover"/>
    <itemref idref="ch1"/>
    <itemref idref="ch2"/>
  </spine>
</package>''';
  return zipOf({
    'mimetype': 'application/epub+zip',
    'META-INF/container.xml': _container,
    'OEBPS/content.opf': opf,
    'OEBPS/cover.xhtml': xhtml('<div><img src="cover.jpg" alt=""/></div>'),
    'OEBPS/text/ch1.xhtml': xhtml(
      chapter1 ??
          '<h1>Chapter One</h1>'
              '<p>It was a <em>bright</em> cold day&nbsp;in April.</p>'
              '<p>The clocks were striking thirteen.</p>'
              '<script>alert(1)</script>',
    ),
    'OEBPS/text/part two/ch2.xhtml': xhtml(
      chapter2 ??
          '<section><h2>Chapter Two</h2>'
              '<div><p>First paragraph of two.</p>'
              '<ul><li>List item one</li><li>List item two</li></ul>'
              '<blockquote><p>A quoted line.</p></blockquote></div>'
              '<div>Loose text in a div.</div></section>',
      doctype:
          '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" '
          '"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
    ),
  });
}

String _docxParagraph(String text, {String? style}) {
  final props = style == null
      ? ''
      : '<w:pPr><w:pStyle w:val="$style"/></w:pPr>';
  return '<w:p>$props<w:r><w:t xml:space="preserve">$text</w:t></w:r></w:p>';
}

/// A DOCX with a Title, two Heading1 chapters, a Heading2, a tab and a
/// line break inside a paragraph, and core.xml metadata.
Uint8List sampleDocx({String coreTitle = 'Docx Sample'}) {
  final body = StringBuffer()
    ..write(_docxParagraph('Book Title', style: 'Title'))
    ..write(_docxParagraph('Intro paragraph.'))
    ..write(_docxParagraph('Chapter 1', style: 'Heading1'))
    ..write(
      '<w:p><w:r><w:t>Left</w:t><w:tab/><w:t>right</w:t><w:br/>'
      '<w:t>next line</w:t></w:r></w:p>',
    )
    ..write(_docxParagraph('Section', style: 'Heading2'))
    ..write(_docxParagraph('   '))
    ..write(_docxParagraph('Chapter 2', style: 'Heading1'))
    ..write(_docxParagraph('हिंदी अनुच्छेद।'));
  return zipOf({
    '[Content_Types].xml': '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"/>',
    'word/document.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:body>$body</w:body></w:document>',
    'docProps/core.xml':
        '<?xml version="1.0"?><cp:coreProperties '
        'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
        'xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>$coreTitle</dc:title>'
        '</cp:coreProperties>',
  });
}
