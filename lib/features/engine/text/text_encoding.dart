import 'dart:convert';
import 'dart:typed_data';

/// Character-encoding detection and strict decoding for plain text
/// (M2b-1c, V1-ENC-01, V1-ENC-02, V1-ENC-05, RC-012).
///
/// Rules:
/// - A BOM decides (UTF-8, UTF-16 LE, UTF-16 BE). UTF-32 BOMs are refused.
/// - Without a BOM, strict UTF-8 is accepted only if it decodes cleanly and
///   has no NUL bytes.
/// - UTF-16 without a BOM is only *suggested* from the byte pattern; the
///   result then needs the user's confirmation (or an explicit override).
///   Nothing is guessed silently.
/// - Invalid UTF-8, odd-length UTF-16 and unpaired surrogates are refused
///   with the byte offset; [EncodingDetector.preview] can still show a
///   lossy preview (U+FFFD), clearly marked as lossy.
/// - The original bytes are copied and never modified; the decoded text is
///   the original text (only the BOM removed), never normalized.
enum TextEncoding {
  utf8('UTF-8'),
  utf16le('UTF-16 LE'),
  utf16be('UTF-16 BE');

  const TextEncoding(this.label);
  final String label;
}

/// How the encoding was chosen.
enum EncodingSource { bom, strictUtf8, bytePattern, override }

enum EncodingStatus {
  /// Text decoded without loss; safe to import.
  decoded,

  /// A plausible decoding exists, but only from a heuristic: ask the user.
  needsConfirmation,

  /// Not decodable without loss (or not text): refuse, offer a preview.
  refused,
}

enum EncodingIssueCode {
  invalidUtf8,
  oddByteLength,
  unpairedSurrogate,
  nulBytes,
  binaryContent,
  utf32NotSupported,
  utf16WithoutBom,
  overrideContradictsBom,
  controlCharacters,
}

class EncodingIssue {
  const EncodingIssue(this.code, {this.byteOffset, this.count = 1});

  final EncodingIssueCode code;

  /// First offending byte offset in the original bytes, when known.
  final int? byteOffset;
  final int count;

  @override
  String toString() =>
      '${code.name}${byteOffset == null ? '' : '@$byteOffset'}×$count';
}

class EncodingReport {
  EncodingReport._({
    required Uint8List originalBytes,
    required this.status,
    required this.encoding,
    required this.source,
    required this.hadBom,
    required this.text,
    required this.issues,
  }) : originalBytes = Uint8List.fromList(originalBytes).asUnmodifiableView();

  /// Unmodifiable copy of the input bytes (L0 source of truth).
  final Uint8List originalBytes;
  final EncodingStatus status;

  /// Chosen or suggested encoding; `null` when nothing fits.
  final TextEncoding? encoding;
  final EncodingSource? source;
  final bool hadBom;

  /// Decoded original text without BOM, not normalized. Set for
  /// [EncodingStatus.decoded] and (as a candidate) for
  /// [EncodingStatus.needsConfirmation]; `null` when refused.
  final String? text;
  final List<EncodingIssue> issues;

  bool get isDecoded => status == EncodingStatus.decoded;

  bool has(EncodingIssueCode code) => issues.any((i) => i.code == code);
}

/// A display-only preview; [lossy] is true when bytes were replaced.
class EncodingPreview {
  const EncodingPreview(
    this.text, {
    required this.encoding,
    required this.lossy,
  });
  final String text;
  final TextEncoding encoding;
  final bool lossy;
}

class EncodingDetector {
  const EncodingDetector();

  static const _utf8Bom = [0xEF, 0xBB, 0xBF];

  /// Detects and strictly decodes [bytes]. With [override], that encoding is
  /// used (a contradicting BOM is refused, never ignored).
  EncodingReport detect(Uint8List bytes, {TextEncoding? override}) {
    EncodingReport result(
      EncodingStatus status, {
      TextEncoding? encoding,
      EncodingSource? source,
      bool hadBom = false,
      String? text,
      List<EncodingIssue> issues = const [],
    }) => EncodingReport._(
      originalBytes: bytes,
      status: status,
      encoding: encoding,
      source: source,
      hadBom: hadBom,
      text: text,
      issues: issues,
    );

    if (_startsWith(bytes, const [0xFF, 0xFE, 0x00, 0x00]) ||
        _startsWith(bytes, const [0x00, 0x00, 0xFE, 0xFF])) {
      return result(
        EncodingStatus.refused,
        issues: const [EncodingIssue(EncodingIssueCode.utf32NotSupported)],
      );
    }
    final bom = bomEncoding(bytes);
    if (override != null) {
      if (bom != null && bom != override) {
        return result(
          EncodingStatus.refused,
          encoding: bom,
          source: EncodingSource.bom,
          hadBom: true,
          issues: const [
            EncodingIssue(EncodingIssueCode.overrideContradictsBom),
          ],
        );
      }
      return _strict(
        bytes,
        override,
        bom != null ? EncodingSource.bom : EncodingSource.override,
        result,
      );
    }
    if (bom != null) return _strict(bytes, bom, EncodingSource.bom, result);

    final nulCount = bytes.where((b) => b == 0).length;
    if (nulCount == 0) {
      return _strict(
        bytes,
        TextEncoding.utf8,
        EncodingSource.strictUtf8,
        result,
      );
    }
    final guess = utf16PatternGuess(bytes);
    if (guess != null) {
      final strict = _strict(bytes, guess, EncodingSource.bytePattern, result);
      if (strict.status == EncodingStatus.decoded) {
        return result(
          EncodingStatus.needsConfirmation,
          encoding: guess,
          source: EncodingSource.bytePattern,
          text: strict.text,
          issues: [
            const EncodingIssue(EncodingIssueCode.utf16WithoutBom),
            ...strict.issues,
          ],
        );
      }
      return strict;
    }
    return result(
      EncodingStatus.refused,
      issues: [
        EncodingIssue(
          EncodingIssueCode.binaryContent,
          byteOffset: bytes.indexOf(0),
          count: nulCount,
        ),
      ],
    );
  }

  /// Lossy, display-only decoding (invalid sequences become U+FFFD).
  EncodingPreview preview(
    Uint8List bytes, {
    TextEncoding? encoding,
    int maxChars = 500,
  }) {
    final enc =
        encoding ??
        bomEncoding(bytes) ??
        utf16PatternGuess(bytes) ??
        TextEncoding.utf8;
    final body = bytes.sublist(_bomLength(bytes, enc));
    final String text;
    var lossy = false;
    if (enc == TextEncoding.utf8) {
      text = utf8.decode(body, allowMalformed: true);
      lossy = !_validUtf8(body);
    } else {
      final units = <int>[];
      for (var i = 0; i + 1 < body.length; i += 2) {
        units.add(_unit(body, i, enc));
      }
      if (body.length.isOdd) {
        units.add(0xFFFD);
        lossy = true;
      }
      final buf = StringBuffer();
      for (var i = 0; i < units.length; i++) {
        final u = units[i];
        if (u >= 0xD800 && u <= 0xDBFF) {
          if (i + 1 < units.length &&
              units[i + 1] >= 0xDC00 &&
              units[i + 1] <= 0xDFFF) {
            buf
              ..writeCharCode(u)
              ..writeCharCode(units[++i]);
            continue;
          }
          buf.writeCharCode(0xFFFD);
          lossy = true;
        } else if (u >= 0xDC00 && u <= 0xDFFF) {
          buf.writeCharCode(0xFFFD);
          lossy = true;
        } else {
          buf.writeCharCode(u);
        }
      }
      text = buf.toString();
    }
    final cut = text.length > maxChars ? text.substring(0, maxChars) : text;
    return EncodingPreview(cut, encoding: enc, lossy: lossy);
  }

  /// Encoding named by a byte-order mark, if any.
  static TextEncoding? bomEncoding(Uint8List bytes) {
    if (_startsWith(bytes, _utf8Bom)) return TextEncoding.utf8;
    if (_startsWith(bytes, const [0xFF, 0xFE])) return TextEncoding.utf16le;
    if (_startsWith(bytes, const [0xFE, 0xFF])) return TextEncoding.utf16be;
    return null;
  }

  /// UTF-16 suggestion for BOM-less bytes: even length, and the bytes at
  /// one parity (the high bytes) take very few distinct values while the
  /// other parity varies. Works for ASCII (high byte 0x00) and Devanagari
  /// (high byte 0x09). Returns `null` when the pattern is not clear.
  static TextEncoding? utf16PatternGuess(Uint8List bytes) {
    if (bytes.length < 4 || bytes.length.isOdd) return null;
    final sample = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
    double top3Share(int parity) {
      final counts = <int, int>{};
      var n = 0;
      for (var i = parity; i < sample.length; i += 2) {
        counts[sample[i]] = (counts[sample[i]] ?? 0) + 1;
        n++;
      }
      final sorted = counts.values.toList()..sort((a, b) => b - a);
      return sorted.take(3).fold<int>(0, (a, b) => a + b) / n;
    }

    final even = top3Share(0);
    final odd = top3Share(1);
    // LE: high byte at odd positions.
    if (odd >= 0.9 && even < odd - 0.25) return TextEncoding.utf16le;
    if (even >= 0.9 && odd < even - 0.25) return TextEncoding.utf16be;
    return null;
  }

  EncodingReport _strict(
    Uint8List bytes,
    TextEncoding enc,
    EncodingSource source,
    EncodingReport Function(
      EncodingStatus, {
      TextEncoding? encoding,
      EncodingSource? source,
      bool hadBom,
      String? text,
      List<EncodingIssue> issues,
    })
    result,
  ) {
    final bomLen = _bomLength(bytes, enc);
    final hadBom = bomLen > 0;
    final body = bytes.sublist(bomLen);
    String text;
    if (enc == TextEncoding.utf8) {
      try {
        text = utf8.decode(body);
      } on FormatException catch (e) {
        final offset = e.offset;
        return result(
          EncodingStatus.refused,
          encoding: enc,
          source: source,
          hadBom: hadBom,
          issues: [
            EncodingIssue(
              EncodingIssueCode.invalidUtf8,
              byteOffset: offset == null ? null : offset + bomLen,
            ),
          ],
        );
      }
      if (text.contains('\u0000')) {
        return result(
          EncodingStatus.refused,
          encoding: enc,
          source: source,
          hadBom: hadBom,
          issues: [
            EncodingIssue(
              EncodingIssueCode.nulBytes,
              byteOffset: bytes.indexOf(0),
              count: '\u0000'.allMatches(text).length,
            ),
          ],
        );
      }
    } else {
      if (body.length.isOdd) {
        return result(
          EncodingStatus.refused,
          encoding: enc,
          source: source,
          hadBom: hadBom,
          issues: [
            EncodingIssue(
              EncodingIssueCode.oddByteLength,
              byteOffset: bytes.length - 1,
            ),
          ],
        );
      }
      final units = Uint16List(body.length ~/ 2);
      for (var i = 0; i < units.length; i++) {
        units[i] = _unit(body, i * 2, enc);
      }
      for (var i = 0; i < units.length; i++) {
        final u = units[i];
        final isHigh = u >= 0xD800 && u <= 0xDBFF;
        final isLow = u >= 0xDC00 && u <= 0xDFFF;
        if (isHigh &&
            i + 1 < units.length &&
            units[i + 1] >= 0xDC00 &&
            units[i + 1] <= 0xDFFF) {
          i++;
          continue;
        }
        if (isHigh || isLow) {
          return result(
            EncodingStatus.refused,
            encoding: enc,
            source: source,
            hadBom: hadBom,
            issues: [
              EncodingIssue(
                EncodingIssueCode.unpairedSurrogate,
                byteOffset: bomLen + i * 2,
              ),
            ],
          );
        }
      }
      text = String.fromCharCodes(units);
      if (text.contains('\u0000')) {
        return result(
          EncodingStatus.refused,
          encoding: enc,
          source: source,
          hadBom: hadBom,
          issues: [
            EncodingIssue(
              EncodingIssueCode.nulBytes,
              count: '\u0000'.allMatches(text).length,
            ),
          ],
        );
      }
    }
    final controls = RegExp(r'[\u0001-\u0008\u000B\u000E-\u001F\u007F]')
        .allMatches(text)
        .length;
    return result(
      EncodingStatus.decoded,
      encoding: enc,
      source: source,
      hadBom: hadBom,
      text: text,
      issues: [
        if (controls > 0)
          EncodingIssue(EncodingIssueCode.controlCharacters, count: controls),
      ],
    );
  }

  static int _bomLength(Uint8List bytes, TextEncoding enc) {
    switch (enc) {
      case TextEncoding.utf8:
        return _startsWith(bytes, _utf8Bom) ? 3 : 0;
      case TextEncoding.utf16le:
        return _startsWith(bytes, const [0xFF, 0xFE]) ? 2 : 0;
      case TextEncoding.utf16be:
        return _startsWith(bytes, const [0xFE, 0xFF]) ? 2 : 0;
    }
  }

  static int _unit(Uint8List b, int i, TextEncoding enc) =>
      enc == TextEncoding.utf16le
      ? b[i] | (b[i + 1] << 8)
      : (b[i] << 8) | b[i + 1];

  static bool _validUtf8(List<int> bytes) {
    try {
      utf8.decode(bytes);
      return true;
    } on FormatException {
      return false;
    }
  }

  static bool _startsWith(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }
}

/// Encoding named in an XML declaration (`<?xml ... encoding="..."?>`),
/// lower-cased, or `null` when none is declared (EN06).
String? xmlDeclaredEncoding(String xml) {
  final m = RegExp(
    r'''^\s*<\?xml[^>]*\bencoding\s*=\s*["']([A-Za-z0-9._\-]+)["']''',
  ).firstMatch(xml);
  return m?.group(1)?.toLowerCase();
}

/// Decodes an XML part of a book container (EN06): BOM-aware UTF-8/UTF-16,
/// and a declared encoding that does not match is refused instead of
/// producing mojibake. Returns `null` when the part cannot be read safely.
String? decodeXmlPart(Uint8List bytes) {
  final report = const EncodingDetector().detect(bytes);
  if (!report.isDecoded) return null;
  final declared = xmlDeclaredEncoding(report.text!);
  if (declared == null) return report.text;
  final ok = switch (report.encoding!) {
    TextEncoding.utf8 =>
      declared == 'utf-8' ||
          declared == 'utf8' ||
          ((declared == 'us-ascii' || declared == 'ascii') &&
              report.text!.codeUnits.every((c) => c < 0x80)),
    TextEncoding.utf16le || TextEncoding.utf16be =>
      declared.startsWith('utf-16') || declared == 'utf16',
  };
  return ok ? report.text : null;
}
