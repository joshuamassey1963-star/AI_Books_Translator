/// Safety limits for imports (V1-IMP-05, V1-SEC-02).
///
/// Defaults are deliberately generous for real books and strict for
/// archive abuse. Tests pass tighter limits to exercise each guard.
class ImportLimits {
  const ImportLimits({
    this.maxFileBytes = 200 * 1024 * 1024,
    this.maxEntries = 10000,
    this.maxTotalUncompressedBytes = 1024 * 1024 * 1024,
    this.maxEntryUncompressedBytes = 256 * 1024 * 1024,
    this.maxCompressionRatio = 200,
  });

  /// Largest original file accepted.
  final int maxFileBytes;

  /// Most entries allowed inside an EPUB/DOCX zip.
  final int maxEntries;

  /// Sum of declared uncompressed sizes (zip-bomb guard).
  final int maxTotalUncompressedBytes;

  /// Largest single entry after decompression.
  final int maxEntryUncompressedBytes;

  /// Largest uncompressed/compressed ratio of the whole archive.
  final int maxCompressionRatio;
}
