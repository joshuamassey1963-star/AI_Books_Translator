import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'import_limits.dart';
import 'parse_exception.dart';

/// Read-only view of a zip container (EPUB, DOCX) with safety checks.
///
/// Nothing is ever extracted to disk; entries are decompressed in memory on
/// demand and size-checked. Guards: entry count, path traversal names,
/// declared total size, compression ratio, per-entry size.
class SafeZip {
  SafeZip._(this._archive, this._limits);

  factory SafeZip.open(Uint8List bytes, ImportLimits limits) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object catch (e) {
      throw ParseException(ParseErrorCode.corruptContainer, e.runtimeType.toString());
    }
    if (archive.isEmpty) {
      throw const ParseException(ParseErrorCode.corruptContainer, 'empty zip');
    }
    if (archive.length > limits.maxEntries) {
      throw ParseException(
        ParseErrorCode.unsafeContainer,
        'too many entries: ${archive.length}',
      );
    }
    var total = 0;
    for (final file in archive) {
      if (!isSafeEntryName(file.name)) {
        throw ParseException(
          ParseErrorCode.unsafeContainer,
          'unsafe entry name: ${file.name}',
        );
      }
      if (file.isFile) total += file.size;
    }
    if (total > limits.maxTotalUncompressedBytes) {
      throw ParseException(
        ParseErrorCode.unsafeContainer,
        'declared size too large: $total',
      );
    }
    if (bytes.isNotEmpty && total ~/ bytes.length > limits.maxCompressionRatio) {
      throw ParseException(
        ParseErrorCode.unsafeContainer,
        'compression ratio too high: ${total ~/ bytes.length}',
      );
    }
    return SafeZip._(archive, limits);
  }

  final Archive _archive;
  final ImportLimits _limits;

  Iterable<String> get fileNames =>
      _archive.where((f) => f.isFile).map((f) => f.name);

  bool contains(String path) => _find(path) != null;

  ArchiveFile? _find(String path) {
    final normalized = normalizeZipPath(path);
    for (final file in _archive) {
      if (file.isFile && normalizeZipPath(file.name) == normalized) {
        return file;
      }
    }
    return null;
  }

  /// Decompressed bytes of [path], or null when the entry does not exist.
  Uint8List? readBytes(String path) {
    final file = _find(path);
    if (file == null) return null;
    if (file.size > _limits.maxEntryUncompressedBytes) {
      throw ParseException(
        ParseErrorCode.unsafeContainer,
        'entry too large: ${file.name}',
      );
    }
    final Uint8List? data;
    try {
      data = file.readBytes();
    } on Object catch (e) {
      throw ParseException(ParseErrorCode.corruptContainer, e.runtimeType.toString());
    }
    if (data == null) return Uint8List(0);
    if (data.length > _limits.maxEntryUncompressedBytes) {
      throw ParseException(
        ParseErrorCode.unsafeContainer,
        'entry too large after inflate: ${file.name}',
      );
    }
    return data;
  }

  /// UTF-8 text of [path] (BOM stripped), or null when missing.
  String? readText(String path) {
    final data = readBytes(path);
    if (data == null) return null;
    try {
      final text = utf8.decode(data);
      return text.startsWith('\uFEFF') ? text.substring(1) : text;
    } on FormatException {
      throw ParseException(ParseErrorCode.invalidEncoding, path);
    }
  }
}

/// Rejects absolute paths, drive letters, backslashes and `..` segments.
bool isSafeEntryName(String name) {
  if (name.isEmpty) return false;
  if (name.startsWith('/') || name.contains('\\') || name.contains(':')) {
    return false;
  }
  return !name.split('/').contains('..');
}

/// Resolves `.` / `..` segments and percent-encoding inside the container.
/// Returns an empty string when the path would leave the container root.
String normalizeZipPath(String path) {
  var decoded = path;
  try {
    decoded = Uri.decodeComponent(path);
  } on ArgumentError {
    // Keep the raw path; it simply will not match any entry.
  }
  final out = <String>[];
  for (final part in decoded.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isEmpty) return '';
      out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}

/// Joins an href found in [baseFile] (e.g. `OEBPS/content.opf`) with [href].
String resolveZipHref(String baseFile, String href) {
  final withoutFragment = href.split('#').first;
  final slash = baseFile.lastIndexOf('/');
  final dir = slash < 0 ? '' : baseFile.substring(0, slash + 1);
  return normalizeZipPath('$dir$withoutFragment');
}
