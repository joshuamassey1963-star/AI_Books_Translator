import 'dart:convert';
import 'dart:typed_data';

import 'package:ai_book_translator/features/engine/parser/book_document.dart';
import 'package:ai_book_translator/features/engine/parser/book_parser.dart';
import 'package:ai_book_translator/features/engine/parser/import_limits.dart';
import 'package:ai_book_translator/features/engine/parser/parse_exception.dart';
import 'package:ai_book_translator/features/engine/parser/safe_zip.dart';
import 'package:ai_book_translator/features/engine/text/text_encoding.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/book_fixtures.dart';
import '../../../support/encoding_fixtures.dart';

Matcher throwsParse(ParseErrorCode code) =>
    throwsA(isA<ParseException>().having((e) => e.code, 'code', code));

List<String> texts(Chapter c) => c.blocks.map((b) => b.text).toList();

void main() {
  const parser = BookParser();

  group('format detection', () {
    test('sniffs content, not the extension', () {
      expect(detectFormat(sampleEpub()), DetectedFormat.zip);
      expect(detectFormat(utf8Bytes('%PDF-1.7\n...')), DetectedFormat.pdf);
      expect(detectFormat(utf8Bytes('hello')), DetectedFormat.text);
      expect(
        detectFormat(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 1])),
        DetectedFormat.unknownBinary,
      );
    });

    test('empty, PDF and binary files are refused honestly', () {
      expect(
        () => parser.parse(Uint8List(0)),
        throwsParse(ParseErrorCode.empty),
      );
      expect(
        () => parser.parse(utf8Bytes('%PDF-1.4 x'), fileName: 'a.txt'),
        throwsParse(ParseErrorCode.pdfNotYetSupported),
      );
      expect(
        () => parser.parse(Uint8List.fromList([1, 0, 2, 0])),
        throwsParse(ParseErrorCode.unsupportedFormat),
      );
    });

    test('file size limit', () {
      const small = BookParser(limits: ImportLimits(maxFileBytes: 4));
      expect(
        () => small.parse(utf8Bytes('12345')),
        throwsParse(ParseErrorCode.tooLarge),
      );
    });

    test('SHA-256 fingerprint of the original bytes', () {
      final bytes = utf8Bytes('Some text.');
      expect(parser.parse(bytes).sha256, sha256.convert(bytes).toString());
    });
  });

  group('TXT', () {
    test('paragraphs, CRLF, BOM, hard wraps and chapters', () {
      final book = parser.parse(
        utf8Bytes(
          '\uFEFFMy Book\r\n\r\n'
          'Chapter 1\r\n\r\n'
          'First line\r\nwrapped here.\r\n\r\n'
          'Part of me wanted to stay.\r\n\r\n'
          'CHAPTER II: The Road\r\n\r\n'
          'Second chapter text.\n\n'
          'अध्याय ३\n\n'
          'हिंदी पाठ।',
        ),
        fileName: 'my_book.txt',
      );
      expect(book.format, SourceFormat.txt);
      expect(book.title, 'my book');
      expect(book.chapters.map((c) => c.title), [
        'Chapter 1',
        'Chapter 1',
        'CHAPTER II: The Road',
        'अध्याय ३',
      ]);
      // "My Book" has no heading, so chapter 0 falls back to "Chapter 1".
      expect(texts(book.chapters[0]), ['My Book']);
      expect(texts(book.chapters[1]), [
        'Chapter 1',
        'First line wrapped here.',
        'Part of me wanted to stay.',
      ]);
      expect(texts(book.chapters[3]).last, 'हिंदी पाठ।');
      expect(book.chapters[1].blocks.first.id, 'c1-b0');
    });

    test('invalid UTF-8 is refused, never guessed', () {
      expect(
        () => parser.parse(Uint8List.fromList([0x48, 0x69, 0xFF, 0xFE, 0x41])),
        throwsParse(ParseErrorCode.invalidEncoding),
      );
    });

    test('whitespace-only text has no readable text', () {
      expect(
        () => parser.parse(utf8Bytes(' \n\n \t\n')),
        throwsParse(ParseErrorCode.noText),
      );
    });
  });

  group('EPUB', () {
    test('metadata, spine order, skipped cover/script, %20 hrefs', () {
      final book = parser.parse(sampleEpub(), fileName: 'x.epub');
      expect(book.format, SourceFormat.epub);
      expect(book.title, 'The Sample Book');
      expect(book.author, 'Test Author');
      expect(book.language, 'en');
      expect(book.warnings, isEmpty);
      expect(book.chapters, hasLength(2));
      expect(book.chapters[0].title, 'Chapter One');
      expect(texts(book.chapters[0]), [
        'Chapter One',
        'It was a bright cold day in April.',
        'The clocks were striking thirteen.',
      ]);
      expect(book.chapters[1].title, 'Chapter Two');
      expect(texts(book.chapters[1]), [
        'Chapter Two',
        'First paragraph of two.',
        'List item one',
        'List item two',
        'A quoted line.',
        'Loose text in a div.',
      ]);
      expect(book.chapters[1].sourcePath, 'OEBPS/text/part two/ch2.xhtml');
      expect(book.paragraphCount, 7);
    });

    test('Devanagari text survives unchanged (NFC kept)', () {
      const hindi = 'क्षत्रिय ज्ञान श्री — “उद्धरण”';
      final book = parser.parse(
        sampleEpub(chapter1: '<h1>अध्याय १</h1><p>$hindi</p>'),
      );
      expect(book.chapters.first.blocks.last.text, hindi);
    });

    test('missing container.xml', () {
      final zip = zipOf({'mimetype': 'application/epub+zip', 'a.txt': 'x'});
      expect(
        () => parser.parse(zip),
        throwsParse(ParseErrorCode.unsupportedFormat),
      );
    });

    test('XXE / entity declarations are blocked', () {
      final bomb = zipOf({
        'mimetype': 'application/epub+zip',
        'META-INF/container.xml': '<container><rootfiles><rootfile full-path="c.opf"/></rootfiles></container>',
        'c.opf':
            '<package><metadata/><manifest><item id="a" href="a.xhtml"/></manifest>'
            '<spine><itemref idref="a"/></spine></package>',
        'a.xhtml':
            '<?xml version="1.0"?><!DOCTYPE html [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>'
            '<html><body><p>&xxe;</p></body></html>',
      });
      expect(() => parser.parse(bomb), throwsParse(ParseErrorCode.unsafeXml));
    });

    test('malformed XHTML is reported as corrupt', () {
      final book = sampleEpub(chapter1: '<p>unclosed');
      expect(
        () => parser.parse(book),
        throwsParse(ParseErrorCode.corruptContainer),
      );
    });

    test('random bytes after a zip header are corrupt, not a crash', () {
      final bytes = Uint8List.fromList([
        0x50,
        0x4B,
        0x03,
        0x04,
        ...List.filled(64, 7),
      ]);
      expect(() => parser.parse(bytes), throwsA(isA<ParseException>()));
    });
  });

  group('zip safety', () {
    test('path traversal names are blocked', () {
      final zip = zipOf({
        'META-INF/container.xml': '<container/>',
        '../../evil.txt': 'x',
      });
      expect(
        () => parser.parse(zip),
        throwsParse(ParseErrorCode.unsafeContainer),
      );
    });

    test('compression-ratio (zip bomb) guard', () {
      final zip = zipOf({
        'META-INF/container.xml': '<container/>',
        'big.txt': 'A' * 200000,
      });
      const strict = BookParser(limits: ImportLimits(maxCompressionRatio: 10));
      expect(
        () => strict.parse(zip),
        throwsParse(ParseErrorCode.unsafeContainer),
      );
    });

    test('entry-count guard', () {
      final zip = zipOf({for (var i = 0; i < 5; i++) 'f$i.txt': 'x'});
      const strict = BookParser(limits: ImportLimits(maxEntries: 3));
      expect(
        () => strict.parse(zip),
        throwsParse(ParseErrorCode.unsafeContainer),
      );
    });

    test('path helpers', () {
      expect(isSafeEntryName('OEBPS/a.xhtml'), isTrue);
      expect(isSafeEntryName('/etc/passwd'), isFalse);
      expect(isSafeEntryName(r'a\b'), isFalse);
      expect(isSafeEntryName('C:/x'), isFalse);
      expect(resolveZipHref('OEBPS/content.opf', '../img/a.png'), 'img/a.png');
      expect(
        resolveZipHref('OEBPS/c.opf', 'text/a.xhtml#p1'),
        'OEBPS/text/a.xhtml',
      );
      expect(normalizeZipPath('../../x'), '');
    });
  });

  group('DOCX', () {
    test('paragraphs, headings, chapters, tab/br, metadata', () {
      final book = parser.parse(sampleDocx(), fileName: 'file.docx');
      expect(book.format, SourceFormat.docx);
      expect(book.title, 'Docx Sample');
      expect(book.chapters.map((c) => c.title), [
        'Book Title',
        'Chapter 1',
        'Chapter 2',
      ]);
      expect(texts(book.chapters[0]), ['Book Title', 'Intro paragraph.']);
      expect(texts(book.chapters[1]), [
        'Chapter 1',
        'Left right next line',
        'Section',
      ]);
      expect(book.chapters[1].blocks[2].type, BlockType.heading);
      expect(book.chapters[1].blocks[2].level, 2);
      expect(texts(book.chapters[2]).last, 'हिंदी अनुच्छेद।');
    });

    test('docx without document.xml is not mistaken for EPUB', () {
      final zip = zipOf({'[Content_Types].xml': '<Types/>'});
      expect(
        () => parser.parse(zip),
        throwsParse(ParseErrorCode.unsupportedFormat),
      );
    });

    test('SafeZip reads entries by normalized path', () {
      final zip = SafeZip.open(
        zipOf({'word/document.xml': 'abc'}),
        const ImportLimits(),
      );
      expect(zip.readText('word/./document.xml'), 'abc');
      expect(zip.readText('word/missing.xml'), isNull);
      expect(utf8.decode(zip.readBytes('word/document.xml')!), 'abc');
    });
  });

  group('M2b-1c: TXT encodings (RC-012)', () {
    test('RC-012: UTF-16 LE/BE TXT with BOM is text, not binary', () {
      for (final bytes in [utf16le(mixedText), utf16be(mixedText)]) {
        expect(detectFormat(bytes), DetectedFormat.text);
        final book = parser.parse(bytes, fileName: 'hindi.txt');
        expect(book.format, SourceFormat.txt);
        final all = book.chapters
            .expand((c) => c.blocks)
            .map((b) => b.text)
            .join('\n');
        expect(all, contains('भारत एक देश है।'));
        expect(all, contains('क्\u200Dष'));
      }
    });

    test(
      'UTF-16 without BOM needs confirmation, then imports with override',
      () {
        final bytes = utf16le(mixedText, bom: false);
        expect(detectFormat(bytes), DetectedFormat.text);
        expect(
          () => parser.parse(bytes),
          throwsParse(ParseErrorCode.encodingNeedsConfirmation),
        );
        final book = parser.parse(bytes, textEncoding: TextEncoding.utf16le);
        expect(book.chapters, isNotEmpty);
      },
    );

    test('malformed UTF-16 TXT is refused, original bytes untouched', () {
      final bytes = Uint8List.fromList([0xFF, 0xFE, 0x41, 0x00, 0x00, 0xD8]);
      final copy = Uint8List.fromList(bytes);
      expect(
        () => parser.parse(bytes),
        throwsParse(ParseErrorCode.invalidEncoding),
      );
      expect(bytes, copy);
    });
  });
}
