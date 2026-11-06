import 'package:ai_book_translator/features/engine/pdf/pdf_models.dart';
import 'package:ai_book_translator/features/engine/pdf/pdf_quality.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/glyph_fixtures.dart';

void main() {
  const gate = ExtractionQualityGate();
  const diag = PdfCharDiagnostics();

  PdfPageInfo textPage(String text, {List<PdfFontInfo> fonts = const []}) =>
      pageWith(glyphsAt('x', 72, 700), text: text, fonts: fonts);

  Set<QualityIssueCode> codes(QualityReport r) =>
      r.issues.map((i) => i.code).toSet();

  test('clean text passes with score 100', () {
    final report = gate.evaluate([textPage('A clean English sentence.')]);
    expect(report.score, 100);
    expect(report.verdict, QualityVerdict.pass);
    expect(report.canTranslate, isTrue);
  });

  test('replacement + PUA characters block translation', () {
    final report = gate.evaluate([
      textPage('ab\uFFFD\uFFFD\uE001\uE002\uE003cd'),
    ]);
    expect(report.verdict, QualityVerdict.block);
    expect(report.canTranslate, isFalse);
    expect(
      codes(report),
      containsAll([
        QualityIssueCode.replacementChars,
        QualityIssueCode.privateUseChars,
      ]),
    );
  });

  test('control characters (unmapped glyph codes) are counted', () {
    final d = diag.analyze(textPage('ab\u0001\u0002'));
    expect(d.controlChars, 2);
    expect(d.totalChars, 4);
  });

  test('RC-014: ligature presentation forms are reported, small penalty', () {
    final report = gate.evaluate([textPage('\uFB01nd the \uFB02ow')]);
    expect(codes(report), contains(QualityIssueCode.ligatureChars));
    expect(report.verdict, QualityVerdict.warn);
    expect(report.score, greaterThanOrEqualTo(90));
  });

  test('RC-007: glyphs drawn twice at the same place are duplicates', () {
    final glyphs = [
      for (final g in glyphsAt('ab', 72, 700)) ...[g, g],
    ];
    final d = diag.analyze(pageWith(glyphs));
    expect(d.duplicateGlyphs, 2);
  });

  test('Latin-1 symbol soup (legacy font signal) never passes', () {
    final report = gate.evaluate([textPage('\u00C3\u00C4\u00C5\u00C6 \u00A5\u00AE')]);
    expect(codes(report), contains(QualityIssueCode.suspiciousLatin1));
    expect(report.verdict, isNot(QualityVerdict.pass));
  });

  test('high-risk font (RC-008) lowers the score and warns', () {
    const font = PdfFontInfo(
      resourceName: 'F1',
      subtype: 'Type0',
      baseFont: 'ABCDEF+TestDeva',
      subsetTag: 'ABCDEF',
      embedded: false,
      hasToUnicode: false,
      encoding: 'Identity-H',
      mappingRisk: UnicodeMappingRisk.high,
    );
    final report = gate.evaluate([textPage('Some text', fonts: [font])]);
    expect(codes(report), contains(QualityIssueCode.highRiskFont));
    expect(report.score, 80);
    expect(report.verdict, QualityVerdict.warn);
  });

  test('OCR-required pages: mixed doc warns, all-scanned doc blocks', () {
    final scanned = pageWith(
      const [],
      pageNumber: 2,
      text: '',
      status: PageTextStatus.imageOnly,
    );
    final mixed = gate.evaluate([textPage('Good page text'), scanned]);
    expect(mixed.verdict, QualityVerdict.warn);
    expect(mixed.pageScores[2], 0);
    expect(codes(mixed), contains(QualityIssueCode.ocrRequired));

    final allScanned = gate.evaluate([scanned]);
    expect(allScanned.verdict, QualityVerdict.block);
  });

  test('blank pages are ignored; a doc with no content blocks', () {
    final blank = pageWith(const [], text: '', status: PageTextStatus.blank);
    expect(gate.evaluate([blank]).verdict, QualityVerdict.block);
    expect(
      gate.evaluate([textPage('Fine text'), blank]).verdict,
      QualityVerdict.pass,
    );
  });
}
