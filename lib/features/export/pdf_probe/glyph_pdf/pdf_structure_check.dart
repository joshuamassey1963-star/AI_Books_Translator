import 'dart:convert';
import 'dart:typed_data';

import 'pdf_text_string.dart';

/// Minimal structural check for the spike's own PDFs (header, xref table,
/// object offsets, trailer, `%%EOF`). Not a general PDF validator; CI also
/// runs `qpdf --check`. Returns a list of problems (empty = OK).
List<String> checkPdfStructure(Uint8List bytes) {
  final problems = <String>[];
  final s = latin1.decode(bytes);
  if (!s.startsWith('%PDF-1.')) {
    problems.add('missing %PDF-1.x header');
  }
  if (!s.trimRight().endsWith('%%EOF')) {
    problems.add('missing %%EOF');
  }
  final sx = RegExp(r'startxref\s+(\d+)\s+%%EOF\s*$').firstMatch(s);
  if (sx == null) {
    problems.add('missing startxref');
    return problems;
  }
  final xrefAt = int.parse(sx.group(1)!);
  if (xrefAt >= s.length || !s.startsWith('xref', xrefAt)) {
    problems.add('startxref does not point to xref');
    return problems;
  }
  final head = RegExp(r'xref\s+0 (\d+)\s+').matchAsPrefix(s, xrefAt);
  if (head == null) {
    problems.add('bad xref header');
    return problems;
  }
  final count = int.parse(head.group(1)!);
  var pos = head.end;
  for (var n = 0; n < count; n++) {
    if (pos + 20 > s.length) {
      problems.add('xref truncated');
      return problems;
    }
    final entry = s.substring(pos, pos + 20);
    final m = RegExp(r'^(\d{10}) (\d{5}) ([nf])').firstMatch(entry);
    if (m == null) {
      problems.add('bad xref entry $n');
      return problems;
    }
    if (m.group(3) == 'n') {
      final off = int.parse(m.group(1)!);
      if (!s.startsWith('$n 0 obj', off)) {
        problems.add('object $n not at offset $off');
      }
    }
    pos += 20;
  }
  if (!RegExp(r'trailer\s*<<[^>]*/Root \d+ 0 R').hasMatch(s.substring(pos))) {
    problems.add('trailer without /Root');
  }
  return problems;
}

/// True when every `BDC` has a matching `EMC` and none closes early.
bool markedContentBalanced(String content) {
  var depth = 0;
  for (final m in RegExp(r'\b(BDC|EMC)\b').allMatches(content)) {
    depth += m.group(1) == 'BDC' ? 1 : -1;
    if (depth < 0) {
      return false;
    }
  }
  return depth == 0;
}

/// Checks a spike content stream against the [source] text: spans must not
/// nest, every `Tj` must sit inside an `/ActualText` span, every replacement
/// must be UTF-16BE with BOM, and the replacements in order must equal the
/// source exactly once (no missing or duplicated text). Returns problems.
List<String> checkActualText(String content, String source) {
  final problems = <String>[];
  final texts = <String>[];
  var inSpan = false;
  final tokens = RegExp(
    r'/Span <</ActualText <([^>]*)>>> BDC|\bBDC\b|\bEMC\b|\bTj\b',
  ).allMatches(content);
  for (final m in tokens) {
    final t = m.group(0)!;
    if (t.startsWith('/Span')) {
      if (inSpan) {
        problems.add('nested /ActualText span');
      }
      inSpan = true;
      try {
        texts.add(decodePdfUtf16BeHex(m.group(1)!));
      } on FormatException {
        problems.add('replacement text is not UTF-16BE with BOM');
      }
    } else if (t == 'BDC') {
      problems.add('marked content without /ActualText');
      inSpan = true;
    } else if (t == 'EMC') {
      if (!inSpan) {
        problems.add('EMC without BDC');
      }
      inSpan = false;
    } else if (!inSpan) {
      problems.add('glyph drawn outside an /ActualText span');
    }
  }
  if (inSpan) {
    problems.add('unclosed span');
  }
  final joined = texts.join();
  if (joined != source) {
    problems.add(
      joined.length > source.length
          ? 'replacement text duplicates source text'
          : 'replacement text differs from source text',
    );
  }
  return problems;
}
