import 'package:ai_book_translator/features/engine/text/unicode_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const n = UnicodeNormalizer();

  test('EN11: decomposed Latin becomes NFC, original kept', () {
    const original = 'Cafe\u0301 and re\u0301sume\u0301';
    final r = n.normalizeForL1(original);
    expect(r.original, original);
    expect(r.normalized, 'Café and résumé');
    expect(r.changed, isTrue);
    expect(n.isNfc(r.normalized), isTrue);
  });

  test('EN11: Devanagari nukta forms follow NFC (composition exclusions)', () {
    // U+0929 (ऩ) composes; U+0958 (क़) is a composition exclusion and
    // becomes क + ़ in NFC.
    expect(n.toNfc('\u0928\u093C'), '\u0929');
    expect(n.toNfc('\u0958'), '\u0915\u093C');
    expect(n.nfcEquals('\u0958', '\u0915\u093C'), isTrue);
  });

  test('EN12/EN14: already-NFC mixed text is unchanged (matras, viramas, '
      'ZWJ/ZWNJ, digits)', () {
    const text =
        'भारत India क्षत्रिय ज्ञान श्री क्\u200Dष क्\u200Cष 0123456789 ०१२३४५६७८९ ﬁ';
    final r = n.normalizeForL1(text);
    expect(r.normalized, text);
    expect(r.changed, isFalse);
    expect(r.changedSegments, 0);
  });

  test('NFC never does compatibility folding (no NFKC)', () {
    expect(n.toNfc('\uFB01'), '\uFB01'); // ﬁ ligature stays
    expect(n.toNfc('x²'), 'x²');
    expect(n.toNfc('１２'), '１２'); // full-width digits not folded
  });

  test('protected terms are kept byte-for-byte', () {
    const protectedTerm = 'Rene\u0301'; // decomposed on purpose
    const original = 'Cafe\u0301 by Rene\u0301 and Cafe\u0301';
    final r = n.normalizeForL1(original, protectedTerms: [protectedTerm]);
    expect(r.normalized, 'Café by Rene\u0301 and Café');
    expect(r.protectedSpans, 1);
    expect(r.protectedNotNfc, 1);
    expect(r.original, original);
  });

  test('no data loss: NFD of NFC round-trips and lengths are sane', () {
    const text = 'हिन्दी Café क़लम';
    final nfc = n.toNfc(text);
    expect(n.nfcEquals(nfc, text), isTrue);
    expect(nfc.replaceAll(RegExp(r'\s'), '').isNotEmpty, isTrue);
    expect(n.toNfc(nfc), nfc); // idempotent
  });
}
