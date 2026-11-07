import 'dart:convert';
import 'dart:typed_data';

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
