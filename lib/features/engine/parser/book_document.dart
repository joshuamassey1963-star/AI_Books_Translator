/// Format-neutral structure of an imported book (V1-IMP-04, M2 spike).
///
/// Pure Dart: no Flutter imports, so it can run in an isolate and in plain
/// unit tests. Every block keeps a stable id (`c<chapter>-b<block>`) so later
/// stages (segmenter, checkpoints, editor) can refer back to the source.
library;

/// The source formats the M2 spike understands.
enum SourceFormat { txt, epub, docx, pdf }

/// Kind of a text block. Kept small on purpose; footnotes, tables and images
/// are added in M4 (V1-B import).
enum BlockType { heading, paragraph }

class TextBlock {
  const TextBlock({
    required this.id,
    required this.type,
    required this.text,
    this.level = 0,
  });

  /// Stable id, unique inside the book: `c<chapterIndex>-b<blockIndex>`.
  final String id;
  final BlockType type;

  /// Plain text, whitespace collapsed, never empty.
  final String text;

  /// Heading level 1-6 for [BlockType.heading], 0 for paragraphs.
  final int level;

  @override
  String toString() => 'TextBlock($id, ${type.name}, "$text")';
}

class Chapter {
  const Chapter({
    required this.index,
    required this.title,
    required this.blocks,
    this.sourcePath,
  });

  /// Zero-based reading-order position.
  final int index;
  final String title;
  final List<TextBlock> blocks;

  /// Where the chapter came from inside the container (EPUB spine item),
  /// for diagnostics only.
  final String? sourcePath;

  int get paragraphCount =>
      blocks.where((b) => b.type == BlockType.paragraph).length;
}

class BookDocument {
  const BookDocument({
    required this.format,
    required this.title,
    required this.chapters,
    required this.sha256,
    this.author,
    this.language,
    this.warnings = const [],
  });

  final SourceFormat format;
  final String title;
  final String? author;

  /// BCP-47 language tag from the file's metadata, if any.
  final String? language;
  final List<Chapter> chapters;

  /// SHA-256 of the original bytes (V1-IMP-06 fingerprint).
  final String sha256;

  /// Non-fatal problems found while parsing (shown in import diagnostics).
  final List<String> warnings;

  int get paragraphCount =>
      chapters.fold(0, (sum, c) => sum + c.paragraphCount);
}

/// Builds chapters with stable block ids.
class ChapterBuilder {
  ChapterBuilder(this.index, {this.title, this.sourcePath});

  final int index;
  String? title;
  final String? sourcePath;
  final List<TextBlock> _blocks = [];

  bool get isEmpty => _blocks.isEmpty;

  void add(BlockType type, String rawText, {int level = 0}) {
    final text = collapseWhitespace(rawText);
    if (text.isEmpty) return;
    _blocks.add(
      TextBlock(
        id: 'c$index-b${_blocks.length}',
        type: type,
        text: text,
        level: type == BlockType.heading ? level : 0,
      ),
    );
    if (type == BlockType.heading && (title == null || title!.isEmpty)) {
      title = text;
    }
  }

  Chapter build() => Chapter(
    index: index,
    title: (title == null || title!.isEmpty) ? 'Chapter ${index + 1}' : title!,
    blocks: List.unmodifiable(_blocks),
    sourcePath: sourcePath,
  );
}

final RegExp _whitespace = RegExp(r'\s+');

/// Collapses runs of whitespace (incl. NBSP and newlines) into one space.
String collapseWhitespace(String input) =>
    input.replaceAll('\u00A0', ' ').replaceAll(_whitespace, ' ').trim();
