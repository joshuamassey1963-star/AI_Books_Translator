import 'dart:math' as math;

import 'pdf_models.dart';

// Character-level extraction diagnostics and the translation quality gate
// (M2b-1b, V1-PDF-05, V1-PDF-07, V1-OCR-02, RC-007, RC-014).
//
// Counts only what is visible in the extracted text; legacy-font
// detection proper is M2b-2 (here only a "suspicious Latin-1" signal).

enum QualityIssueCode {
  replacementChars,
  controlChars,
  privateUseChars,
  ligatureChars,
  duplicateGlyphs,
  suspiciousLatin1,
  highRiskFont,
  unknownRiskFont,
  ocrRequired,
}

class QualityIssue {
  const QualityIssue(this.code, this.pageNumber, this.count);
  final QualityIssueCode code;
  final int pageNumber;
  final int count;

  @override
  String toString() => '${code.name}@p$pageNumber×$count';
}

class PageCharDiagnostics {
  const PageCharDiagnostics({
    required this.pageNumber,
    required this.totalChars,
    required this.replacementChars,
    required this.controlChars,
    required this.privateUseChars,
    required this.ligatureChars,
    required this.duplicateGlyphs,
    required this.suspiciousLatin1,
  });

  final int pageNumber;

  /// Non-whitespace characters (Unicode code points).
  final int totalChars;

  /// U+FFFD – the engine could not map a glyph (missing character).
  final int replacementChars;

  /// C0/C1 control characters other than tab/newline – unmapped glyph codes.
  final int controlChars;

  /// Private Use Area (U+E000–U+F8FF, planes 15–16): font-specific codes.
  final int privateUseChars;

  /// Alphabetic presentation forms (U+FB00–U+FB4F), e.g. "ﬁ"; fixable by
  /// compatibility decomposition, reported so it is never silent.
  final int ligatureChars;

  /// Same character drawn twice at (almost) the same place (fake bold /
  /// shadow text) – would be read as repeated letters.
  final int duplicateGlyphs;

  /// Latin-1 symbols/letters (U+00A0–U+00FF) typical for legacy Hindi fonts.
  final int suspiciousLatin1;
}

/// Pure functions; no engine needed.
class PdfCharDiagnostics {
  const PdfCharDiagnostics({this.duplicateOverlap = 0.8});

  /// Intersection-over-union above which two identical glyphs count as a
  /// duplicate.
  final double duplicateOverlap;

  PageCharDiagnostics analyze(PdfPageInfo page) {
    var total = 0;
    var replacement = 0;
    var control = 0;
    var pua = 0;
    var ligature = 0;
    var latin1 = 0;
    for (final r in page.text.runes) {
      if (r == 0x09 || r == 0x0A || r == 0x0D || r == 0x20) continue;
      if (String.fromCharCode(r).trim().isEmpty) continue;
      total++;
      if (r == 0xFFFD) {
        replacement++;
      } else if (r < 0x20 || (r >= 0x7F && r <= 0x9F)) {
        control++;
      } else if ((r >= 0xE000 && r <= 0xF8FF) || r >= 0xF0000) {
        pua++;
      } else if (r >= 0xFB00 && r <= 0xFB4F) {
        ligature++;
      } else if (r >= 0xA0 && r <= 0xFF) {
        latin1++;
      }
    }
    return PageCharDiagnostics(
      pageNumber: page.pageNumber,
      totalChars: total,
      replacementChars: replacement,
      controlChars: control,
      privateUseChars: pua,
      ligatureChars: ligature,
      duplicateGlyphs: _duplicates(page.glyphs),
      suspiciousLatin1: latin1,
    );
  }

  int _duplicates(List<PdfGlyph> glyphs) {
    var count = 0;
    for (var i = 0; i < glyphs.length; i++) {
      final a = glyphs[i];
      if (a.char.trim().isEmpty) continue;
      // Duplicates are normally drawn right after the original.
      for (var j = i + 1; j < glyphs.length && j <= i + 3; j++) {
        final b = glyphs[j];
        if (b.char == a.char && _iou(a.box, b.box) >= duplicateOverlap) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  static double _iou(PdfBox a, PdfBox b) {
    final w = math.min(a.right, b.right) - math.max(a.left, b.left);
    final h = math.min(a.top, b.top) - math.max(a.bottom, b.bottom);
    if (w <= 0 || h <= 0) return 0;
    final inter = w * h;
    final union = a.width * a.height + b.width * b.height - inter;
    return union <= 0 ? 0 : inter / union;
  }
}

enum QualityVerdict {
  /// Good enough to translate.
  pass,

  /// Translate only after the user confirms (issues listed).
  warn,

  /// Translation blocked until conversion/OCR/manual correction.
  block,
}

class QualityReport {
  const QualityReport({
    required this.score,
    required this.verdict,
    required this.issues,
    required this.pageScores,
  });

  /// 0–100, character-weighted over pages that have text.
  final int score;
  final QualityVerdict verdict;
  final List<QualityIssue> issues;
  final Map<int, int> pageScores;

  bool get canTranslate => verdict != QualityVerdict.block;
}

/// Translation-blocking quality gate (V1-PDF-07). Thresholds are
/// deliberately conservative and documented; tune with real books in M2b-5.
class ExtractionQualityGate {
  const ExtractionQualityGate({
    this.passScore = 80,
    this.blockScore = 50,
    this.diagnostics = const PdfCharDiagnostics(),
  });

  final int passScore;
  final int blockScore;
  final PdfCharDiagnostics diagnostics;

  /// Score of one page, plus its issues.
  (int, List<QualityIssue>) scorePage(PdfPageInfo page) {
    final issues = <QualityIssue>[];
    if (page.status.ocrRequired) {
      issues.add(
        QualityIssue(QualityIssueCode.ocrRequired, page.pageNumber, 1),
      );
      return (0, issues);
    }
    final d = diagnostics.analyze(page);
    if (d.totalChars == 0) return (100, issues);
    double penalty(int count, double weight, double cap, QualityIssueCode c) {
      if (count == 0) return 0;
      issues.add(QualityIssue(c, page.pageNumber, count));
      return math.min(cap, count / d.totalChars * weight);
    }

    var score = 100.0;
    score -= penalty(
      d.replacementChars,
      400,
      50,
      QualityIssueCode.replacementChars,
    );
    score -= penalty(d.controlChars, 400, 50, QualityIssueCode.controlChars);
    score -= penalty(
      d.privateUseChars,
      300,
      50,
      QualityIssueCode.privateUseChars,
    );
    score -= penalty(
      d.duplicateGlyphs,
      200,
      25,
      QualityIssueCode.duplicateGlyphs,
    );
    score -= penalty(d.ligatureChars, 50, 5, QualityIssueCode.ligatureChars);
    score -= penalty(
      d.suspiciousLatin1,
      150,
      40,
      QualityIssueCode.suspiciousLatin1,
    );
    final high = page.fonts
        .where((f) => f.mappingRisk == UnicodeMappingRisk.high)
        .length;
    final unknown = page.fonts
        .where((f) => f.mappingRisk == UnicodeMappingRisk.unknown)
        .length;
    if (high > 0) {
      issues.add(
        QualityIssue(QualityIssueCode.highRiskFont, page.pageNumber, high),
      );
      score -= 20;
    }
    if (unknown > 0) {
      issues.add(
        QualityIssue(
          QualityIssueCode.unknownRiskFont,
          page.pageNumber,
          unknown,
        ),
      );
      score -= 5;
    }
    return (score.clamp(0, 100).round(), issues);
  }

  QualityReport evaluate(List<PdfPageInfo> pages) {
    final issues = <QualityIssue>[];
    final pageScores = <int, int>{};
    var weighted = 0.0;
    var weight = 0;
    var ocrPages = 0;
    var contentPages = 0;
    for (final page in pages) {
      if (page.status == PageTextStatus.blank) continue;
      contentPages++;
      final (score, pageIssues) = scorePage(page);
      pageScores[page.pageNumber] = score;
      issues.addAll(pageIssues);
      if (page.status.ocrRequired) {
        ocrPages++;
        continue;
      }
      final chars = math.max(1, diagnostics.analyze(page).totalChars);
      weighted += score * chars;
      weight += chars;
    }
    final score = weight == 0 ? 0 : (weighted / weight).round();
    final QualityVerdict verdict;
    if (contentPages == 0 || ocrPages == contentPages || score < blockScore) {
      verdict = QualityVerdict.block;
    } else if (score < passScore || ocrPages > 0 || issues.isNotEmpty) {
      verdict = QualityVerdict.warn;
    } else {
      verdict = QualityVerdict.pass;
    }
    return QualityReport(
      score: score,
      verdict: verdict,
      issues: issues,
      pageScores: pageScores,
    );
  }
}
