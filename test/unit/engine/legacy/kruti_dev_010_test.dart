import 'package:ai_book_translator/features/engine/legacy/legacy_font_converter.dart';
import 'package:ai_book_translator/features/engine/text/unicode_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Synthetic Kruti Dev 010 strings (typed key sequences, no book text).
/// Expected outputs follow the SIL KrutiDev010.map rules; `Hkkjr`→भारत and
/// `fodk`→विका also match independently published examples (D-026).
void main() {
  final registry = LegacyFontRegistry();
  const kruti = LegacyFontIdentity('Kruti Dev 010', confirmed: true);

  String conv(String s) {
    final r = registry.convert(s, kruti);
    expect(r.isConverted, isTrue, reason: '${r.refusal}');
    expect(r.warnings, isEmpty, reason: '$s → ${r.warnings}');
    return r.converted!;
  }

  group('RC-002: Kruti Dev 010 conversion', () {
    test('simple words', () {
      expect(conv('Hkkjr'), 'भारत');
      expect(conv('fd;k'), 'किया');
      expect(conv('vkSj'), 'और');
      expect(conv('fyf[kr'), 'लिखित');
    });

    test('short i-matra is reordered after its consonant (cluster)', () {
      expect(conv('fodk'), 'विका');
      expect(conv('fgUnh'), 'हिन्दी');
      expect(conv('fp='), 'चित्र');
    });

    test('reph moves before its cluster, also with i-matra', () {
      expect(conv('dk;Z'), 'कार्य');
      expect(conv('/keZ'), 'धर्म');
      expect(conv('dhfrZ'), 'कीर्ति');
    });

    test('conjuncts and half forms', () {
      expect(conv('ijh{kk'), 'परीक्षा');
      expect(conv('fo|ky;'), 'विद्यालय');
      expect(conv('jk"Vª'), 'राष्ट्र');
      expect(conv('xzke'), 'ग्राम');
      expect(conv('Øe'), 'क्रम');
      expect(conv('iz/kkuea=h'), 'प्रधानमंत्री');
      expect(conv('mUgksaus'), 'उन्होंने');
      expect(conv('Lo;a'), 'स्वयं');
    });

    test('vowel signs, nasals (also typed before the matra), nukta', () {
      expect(conv('esa'), 'में');
      expect(conv('eas'), 'में');
      expect(conv('gSa'), 'हैं');
      expect(conv('fo|ky; esa i<+kbZ'), 'विद्यालय में पढ़ाई');
    });

    test('halant and punctuation', () {
      expect(conv('d~'), 'क्');
      expect(conv('gS A'), 'है ।');
      expect(conv('gS AA'), 'है ॥');
      expect(conv('D;k\\'), 'क्या?');
      expect(conv('2%3'), '2:3');
    });

    test('output is NFC (nukta letters stay decomposed per Unicode)', () {
      final out = conv('iM+k');
      expect(out, '\u092A\u0921\u093C\u093E');
      expect(const UnicodeNormalizer().isNfc(out), isTrue);
    });

    test('empty input converts to empty output', () {
      final r = registry.convert('', kruti);
      expect(r.converted, '');
      expect(r.warnings, isEmpty);
    });
  });

  group('unknown and unverified characters are kept and reported', () {
    test('unmapped legacy code', () {
      final r = registry.convert('dk€', kruti);
      expect(r.converted, 'का€');
      expect(r.warnings.single.code, LegacyWarningCode.unmappedCharacter);
      expect(r.warnings.single.character, '€');
      expect(r.isClean, isFalse);
    });

    test('unverified zero glyphs (Œ, å) are not guessed', () {
      final r = registry.convert('Œå', kruti);
      expect(r.converted, 'Œå');
      expect(r.warnings.length, 2);
    });

    test('character outside the code page', () {
      final r = registry.convert('dk中', kruti);
      expect(r.converted, 'का中');
      expect(
        r.warnings.single.code,
        LegacyWarningCode.characterOutsideCodePage,
      );
    });

    test('stray i-matra', () {
      final r = registry.convert('f', kruti);
      expect(r.converted, 'ि');
      expect(r.warnings.single.code, LegacyWarningCode.ikarWithoutConsonant);
    });
  });

  group('RC-003: wrong-font mapping prevention', () {
    test('font must be confirmed', () {
      final r = registry.convert(
        'Hkkjr',
        const LegacyFontIdentity('KrutiDev010', confirmed: false),
      );
      expect(r.refusal, LegacyRefusal.fontNotConfirmed);
      expect(r.converted, isNull);
    });

    test('other families are refused, even similar ones', () {
      for (final name in ['Kruti Dev 011', 'Chanakya', 'DevLys 010', 'Arial']) {
        final r = registry.convert(
          'Hkkjr',
          LegacyFontIdentity(name, confirmed: true),
        );
        expect(r.refusal, LegacyRefusal.unsupportedFont, reason: name);
      }
    });

    test('ASCII-looking text alone never selects a converter', () {
      expect(
        registry.converterFor(
          const LegacyFontIdentity('Times New Roman', confirmed: true),
        ),
        isNull,
      );
    });

    test('PDF subset prefix and spacing variants are recognised', () {
      for (final name in [
        'ABCDEF+KrutiDev010',
        'Kruti-Dev-010',
        'KRUTI DEV 010 Bold',
      ]) {
        expect(
          registry.converterFor(LegacyFontIdentity(name, confirmed: true))?.id,
          'krutidev010',
          reason: name,
        );
      }
    });

    test('repeat conversion is refused', () {
      final first = registry.convert('Hkkjr', kruti);
      final again = registry.convert(first.converted!, kruti);
      expect(again.refusal, LegacyRefusal.alreadyUnicode);
      expect(again.converted, isNull);
      expect(
        registry.convert('भारत Hkkjr', kruti).refusal,
        LegacyRefusal.alreadyUnicode,
      );
    });

    test('original input is preserved unchanged', () {
      const input = 'fo|ky; esa';
      final r = registry.convert(input, kruti);
      expect(r.original, input);
      expect(identical(r.original, input), isTrue);
      expect(r.converted, isNot(input));
    });
  });
}
