import '../text/unicode_normalizer.dart';
import 'kruti_dev_010.dart';

/// Legacy Hindi font → Unicode conversion (M2b-2a, V1-LEG-02/03, D-026).
///
/// A converter is chosen only from an explicitly *confirmed* font identity.
/// ASCII-looking text is never treated as proof of a legacy font, and a
/// table is never applied to another font family (RC-003).
class LegacyFontIdentity {
  const LegacyFontIdentity(this.fontName, {required this.confirmed});

  /// Font name as found (PDF subset prefix like `ABCDEF+` allowed).
  final String fontName;

  /// True only when the user or a validated detector confirmed the font.
  final bool confirmed;

  /// Lower-case name without subset prefix, spaces, `-` and `_`.
  String get normalizedName {
    var n = fontName.trim();
    final plus = n.indexOf('+');
    if (plus == 6 && RegExp(r'^[A-Z]{6}$').hasMatch(n.substring(0, 6))) {
      n = n.substring(7);
    }
    return n.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
  }
}

enum LegacyWarningCode {
  /// A legacy code with no verified mapping; the original char is kept.
  unmappedCharacter,

  /// A character outside the legacy code page (e.g. CJK); kept as is.
  characterOutsideCodePage,

  /// An i-matra (`f`) with no consonant after it; kept as ि.
  ikarWithoutConsonant,
}

class LegacyWarning {
  const LegacyWarning(this.code, this.character, {this.count = 1});
  final LegacyWarningCode code;

  /// The original input character concerned.
  final String character;
  final int count;

  @override
  String toString() =>
      '${code.name}(${character.runes.first.toRadixString(16)})×$count';
}

enum LegacyRefusal {
  fontNotConfirmed,
  unsupportedFont,

  /// Input already contains Devanagari: converting again would corrupt it.
  alreadyUnicode,
}

class LegacyConversionResult {
  const LegacyConversionResult._({
    required this.original,
    required this.converted,
    required this.warnings,
    required this.refusal,
    required this.converterId,
  });

  /// Raw input, unchanged (L0).
  final String original;

  /// Unicode output (NFC); `null` when refused.
  final String? converted;
  final List<LegacyWarning> warnings;
  final LegacyRefusal? refusal;
  final String? converterId;

  bool get isConverted => converted != null;
  bool get isClean => isConverted && warnings.isEmpty;
}

abstract class LegacyFontConverter {
  /// Stable id, e.g. `krutidev010`.
  String get id;

  /// Normalized font names this table was built for (exact match only).
  Set<String> get fontNames;

  /// Converts [input]; implementations never drop characters.
  (String, List<LegacyWarning>) convertRaw(String input);
}

class LegacyFontRegistry {
  LegacyFontRegistry([List<LegacyFontConverter>? converters])
    : _converters = converters ?? [const KrutiDev010Converter()];

  final List<LegacyFontConverter> _converters;
  static const _normalizer = UnicodeNormalizer();
  static final _devanagari = RegExp(r'[\u0900-\u097F\uA8E0-\uA8FF]');

  LegacyFontConverter? converterFor(LegacyFontIdentity font) {
    final name = font.normalizedName;
    for (final c in _converters) {
      if (c.fontNames.contains(name)) return c;
    }
    return null;
  }

  LegacyConversionResult convert(String input, LegacyFontIdentity font) {
    LegacyConversionResult refuse(LegacyRefusal r, [String? id]) =>
        LegacyConversionResult._(
          original: input,
          converted: null,
          warnings: const [],
          refusal: r,
          converterId: id,
        );

    if (!font.confirmed) return refuse(LegacyRefusal.fontNotConfirmed);
    final converter = converterFor(font);
    if (converter == null) return refuse(LegacyRefusal.unsupportedFont);
    if (_devanagari.hasMatch(input)) {
      return refuse(LegacyRefusal.alreadyUnicode, converter.id);
    }
    final (text, warnings) = converter.convertRaw(input);
    return LegacyConversionResult._(
      original: input,
      converted: _normalizer.toNfc(text),
      warnings: List.unmodifiable(warnings),
      refusal: null,
      converterId: converter.id,
    );
  }
}
