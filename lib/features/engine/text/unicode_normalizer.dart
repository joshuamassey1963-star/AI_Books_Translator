import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// NFC policy helper (D-017, V1-ENC-03, EN11, EN14).
///
/// - L0 (original) text is never changed: [normalizeForL1] returns it
///   untouched next to the NFC text.
/// - Only canonical (NFC) normalization. Never NFKC: that would turn
///   ligatures, superscripts and full-width forms into other characters.
/// - ZWJ/ZWNJ (U+200D/U+200C) are kept (NFC does not touch them; checked).
/// - Digits are never converted: ASCII 0–9 and Devanagari ०–९ stay as they
///   are (digit policy is V1-TRP-03, applied elsewhere).
/// - Protected spans (original-script words, glossary terms, translation
///   data) are copied exactly; only the text between them is normalized.
class UnicodeNormalizer {
  const UnicodeNormalizer();

  String toNfc(String text) => unorm.nfc(text);

  bool isNfc(String text) => unorm.nfc(text) == text;

  /// Comparison/search equality on NFC (D-017).
  bool nfcEquals(String a, String b) => unorm.nfc(a) == unorm.nfc(b);

  /// Builds the L1 text from [original]. Occurrences of [protectedTerms]
  /// in [original] are kept byte-for-byte; everything else becomes NFC.
  NormalizationResult normalizeForL1(
    String original, {
    Iterable<String> protectedTerms = const [],
  }) {
    final terms = {
      for (final t in protectedTerms)
        if (t.isNotEmpty) t,
    }.toList()..sort((a, b) => b.length.compareTo(a.length));
    final spans = <(int, int)>[];
    var i = 0;
    outer:
    while (i < original.length) {
      for (final t in terms) {
        if (original.startsWith(t, i)) {
          spans.add((i, i + t.length));
          i += t.length;
          continue outer;
        }
      }
      i++;
    }

    final out = StringBuffer();
    var changedSegments = 0;
    var protectedNotNfc = 0;
    var cursor = 0;
    void plain(int end) {
      if (end <= cursor) return;
      final part = original.substring(cursor, end);
      final n = unorm.nfc(part);
      if (n != part) changedSegments++;
      out.write(n);
    }

    for (final (start, end) in spans) {
      plain(start);
      final term = original.substring(start, end);
      if (!isNfc(term)) protectedNotNfc++;
      out.write(term);
      cursor = end;
    }
    plain(original.length);
    final normalized = out.toString();
    return NormalizationResult(
      original: original,
      normalized: normalized,
      changedSegments: changedSegments,
      protectedSpans: spans.length,
      protectedNotNfc: protectedNotNfc,
    );
  }
}

class NormalizationResult {
  const NormalizationResult({
    required this.original,
    required this.normalized,
    required this.changedSegments,
    required this.protectedSpans,
    required this.protectedNotNfc,
  });

  /// L0 text, unchanged.
  final String original;

  /// L1 text (NFC outside protected spans).
  final String normalized;

  /// Number of unprotected segments that NFC changed (0 = already NFC).
  final int changedSegments;
  final int protectedSpans;

  /// Protected spans that are not NFC themselves – reported so the review
  /// can decide; they are still kept exactly.
  final int protectedNotNfc;

  bool get changed => normalized != original;
}
