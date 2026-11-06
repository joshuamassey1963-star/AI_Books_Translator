import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pdf_models.dart';

/// Minimal, read-only PDF structure reader (M2b-1a, V1-PDF-04, V1-OCR-01).
///
/// It does **not** extract text. It reads what the text engine (PDFium via
/// pdfrx) does not expose: per-page font dictionaries (BaseFont, subset
/// prefix, embedded font program, ToUnicode, encoding), image XObjects and
/// text-showing operators. Pure Dart, synchronous, no I/O.
///
/// Scope and limits (documented in docs/TEXT_ENCODING_FONT_COMPATIBILITY.md):
/// - objects are found by scanning for `n g obj` and inside `/ObjStm`
///   object streams; the xref table is not trusted or needed;
/// - only `FlateDecode` streams are decoded (no LZW/ASCII85 yet);
/// - encrypted files: dictionaries are read, streams are not (warning).
class PdfStructureScanner {
  const PdfStructureScanner({
    this.maxObjects = 500000,
    this.maxDecodedStreamBytes = 64 * 1024 * 1024,
    this.maxTotalDecodedBytes = 512 * 1024 * 1024,
    this.maxDepth = 32,
  });

  final int maxObjects;
  final int maxDecodedStreamBytes;
  final int maxTotalDecodedBytes;
  final int maxDepth;

  PdfStructureReport scan(Uint8List bytes) =>
      _Scan(bytes, this).run();
}

class PdfStructurePage {
  const PdfStructurePage({
    required this.pageNumber,
    required this.fonts,
    required this.imageCount,
    required this.textOperatorCount,
    required this.contentReadable,
  });

  final int pageNumber;
  final List<PdfFontInfo> fonts;

  /// `null` when the content could not be read (encrypted, unknown filter).
  final int? imageCount;
  final int? textOperatorCount;
  final bool contentReadable;
}

class PdfStructureReport {
  const PdfStructureReport({
    required this.pages,
    required this.encrypted,
    required this.warnings,
  });

  final List<PdfStructurePage> pages;
  final bool encrypted;
  final List<String> warnings;
}

// ---------------------------------------------------------------------------
// Object model

class PdfName {
  const PdfName(this.value);
  final String value;
  @override
  bool operator ==(Object other) => other is PdfName && other.value == value;
  @override
  int get hashCode => value.hashCode;
  @override
  String toString() => '/$value';
}

class PdfRef {
  const PdfRef(this.number, this.generation);
  final int number;
  final int generation;
}

class PdfKeyword {
  const PdfKeyword(this.value);
  final String value;
}

class PdfStream {
  PdfStream(this.dict, this.raw);
  final Map<String, Object?> dict;
  final Uint8List raw;
}

class _PdfParseError implements Exception {
  _PdfParseError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Tokenizer/parser for PDF objects and content streams.
class PdfObjectParser {
  PdfObjectParser(this.b, [this.pos = 0]);

  final Uint8List b;
  int pos;

  static bool isWhite(int c) =>
      c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09 || c == 0x0C || c == 0;

  static bool isDelim(int c) =>
      c == 0x28 || // (
      c == 0x29 || // )
      c == 0x3C || // <
      c == 0x3E || // >
      c == 0x5B || // [
      c == 0x5D || // ]
      c == 0x7B || // {
      c == 0x7D || // }
      c == 0x2F || // /
      c == 0x25; // %

  bool get atEnd => pos >= b.length;

  void skipWhite() {
    while (pos < b.length) {
      final c = b[pos];
      if (isWhite(c)) {
        pos++;
      } else if (c == 0x25) {
        while (pos < b.length && b[pos] != 0x0A && b[pos] != 0x0D) {
          pos++;
        }
      } else {
        break;
      }
    }
  }

  /// Parses one object. Returns [PdfKeyword] for bare keywords/operators.
  Object? parse({int depth = 0}) {
    if (depth > 64) throw _PdfParseError('nesting too deep');
    skipWhite();
    if (atEnd) throw _PdfParseError('unexpected end');
    final c = b[pos];
    if (c == 0x3C) {
      if (pos + 1 < b.length && b[pos + 1] == 0x3C) {
        pos += 2;
        return _dict(depth);
      }
      return _hexString();
    }
    if (c == 0x28) return _literalString();
    if (c == 0x5B) {
      pos++;
      final list = <Object?>[];
      while (true) {
        skipWhite();
        if (atEnd) throw _PdfParseError('unterminated array');
        if (b[pos] == 0x5D) {
          pos++;
          return list;
        }
        list.add(parse(depth: depth + 1));
      }
    }
    if (c == 0x2F) return PdfName(_name());
    if (c == 0x2B || c == 0x2D || c == 0x2E || (c >= 0x30 && c <= 0x39)) {
      return _numberOrRef();
    }
    if (c == 0x5D || c == 0x3E || c == 0x29 || c == 0x7B || c == 0x7D) {
      pos++;
      return PdfKeyword(String.fromCharCode(c));
    }
    final word = _regular();
    switch (word) {
      case 'true':
        return true;
      case 'false':
        return false;
      case 'null':
        return null;
    }
    return PdfKeyword(word);
  }

  String _regular() {
    final start = pos;
    while (pos < b.length && !isWhite(b[pos]) && !isDelim(b[pos])) {
      pos++;
    }
    if (pos == start) pos++;
    return latin1.decode(b.sublist(start, pos));
  }

  Map<String, Object?> _dict(int depth) {
    final map = <String, Object?>{};
    while (true) {
      skipWhite();
      if (atEnd) throw _PdfParseError('unterminated dictionary');
      if (b[pos] == 0x3E && pos + 1 < b.length && b[pos + 1] == 0x3E) {
        pos += 2;
        return map;
      }
      final key = parse(depth: depth + 1);
      if (key is! PdfName) throw _PdfParseError('dictionary key is not a name');
      skipWhite();
      if (!atEnd && b[pos] == 0x3E && pos + 1 < b.length && b[pos + 1] == 0x3E) {
        map[key.value] = null;
        continue;
      }
      map[key.value] = parse(depth: depth + 1);
    }
  }

  String _name() {
    pos++; // '/'
    final out = <int>[];
    while (pos < b.length && !isWhite(b[pos]) && !isDelim(b[pos])) {
      final c = b[pos];
      if (c == 0x23 && pos + 2 < b.length) {
        final hex = int.tryParse(
          String.fromCharCodes([b[pos + 1], b[pos + 2]]),
          radix: 16,
        );
        if (hex != null) {
          out.add(hex);
          pos += 3;
          continue;
        }
      }
      out.add(c);
      pos++;
    }
    return latin1.decode(out);
  }

  Uint8List _hexString() {
    pos++; // '<'
    final digits = <int>[];
    while (pos < b.length && b[pos] != 0x3E) {
      final c = b[pos++];
      if (!isWhite(c)) digits.add(c);
    }
    pos++; // '>'
    if (digits.length.isOdd) digits.add(0x30);
    final out = Uint8List(digits.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] =
          int.tryParse(
            String.fromCharCodes([digits[2 * i], digits[2 * i + 1]]),
            radix: 16,
          ) ??
          0;
    }
    return out;
  }

  Uint8List _literalString() {
    pos++; // '('
    final out = <int>[];
    var level = 1;
    while (pos < b.length) {
      final c = b[pos++];
      if (c == 0x5C) {
        if (pos >= b.length) break;
        final e = b[pos++];
        switch (e) {
          case 0x6E:
            out.add(0x0A);
          case 0x72:
            out.add(0x0D);
          case 0x74:
            out.add(0x09);
          case 0x62:
            out.add(0x08);
          case 0x66:
            out.add(0x0C);
          case 0x0D:
            if (pos < b.length && b[pos] == 0x0A) pos++;
          case 0x0A:
            break;
          default:
            if (e >= 0x30 && e <= 0x37) {
              var v = e - 0x30;
              for (var i = 0; i < 2 && pos < b.length; i++) {
                final d = b[pos];
                if (d < 0x30 || d > 0x37) break;
                v = v * 8 + (d - 0x30);
                pos++;
              }
              out.add(v & 0xFF);
            } else {
              out.add(e);
            }
        }
        continue;
      }
      if (c == 0x28) level++;
      if (c == 0x29) {
        level--;
        if (level == 0) break;
      }
      out.add(c);
    }
    return Uint8List.fromList(out);
  }

  Object _numberOrRef() {
    final first = _number();
    if (first is int && first >= 0) {
      final save = pos;
      skipWhite();
      if (!atEnd && b[pos] >= 0x30 && b[pos] <= 0x39) {
        final second = _number();
        if (second is int) {
          skipWhite();
          if (!atEnd && b[pos] == 0x52) {
            final after = pos + 1;
            if (after >= b.length || isWhite(b[after]) || isDelim(b[after])) {
              pos = after;
              return PdfRef(first, second);
            }
          }
        }
      }
      pos = save;
    }
    return first;
  }

  num _number() {
    final start = pos;
    while (pos < b.length) {
      final c = b[pos];
      if (c == 0x2B || c == 0x2D || c == 0x2E || (c >= 0x30 && c <= 0x39)) {
        pos++;
      } else {
        break;
      }
    }
    final text = latin1.decode(b.sublist(start, pos));
    return int.tryParse(text) ?? double.tryParse(text) ?? 0;
  }
}

// ---------------------------------------------------------------------------
// Scan

const _standard14 = {
  'Times-Roman', 'Times-Bold', 'Times-Italic', 'Times-BoldItalic', //
  'Helvetica', 'Helvetica-Bold', 'Helvetica-Oblique',
  'Helvetica-BoldOblique', 'Courier', 'Courier-Bold', 'Courier-Oblique',
  'Courier-BoldOblique', 'Symbol', 'ZapfDingbats',
};

const _standardEncodings = {
  'WinAnsiEncoding',
  'MacRomanEncoding',
  'StandardEncoding',
  'PDFDocEncoding',
};

final _subsetPattern = RegExp(r'^([A-Z]{6})\+');
final _objPattern = RegExp(r'(\d+)\s+(\d+)\s+obj\b');

class _Scan {
  _Scan(this.bytes, this.cfg);

  final Uint8List bytes;
  final PdfStructureScanner cfg;
  final objects = <int, Object?>{};
  final warnings = <String>[];
  var _decodedTotal = 0;
  var encrypted = false;

  PdfStructureReport run() {
    _collectObjects();
    final pages = <PdfStructurePage>[];
    final root = _findCatalog();
    if (root == null) {
      warnings.add('no document catalog found');
    } else {
      final pagesRoot = _resolve(root['Pages']);
      if (pagesRoot is Map<String, Object?>) {
        _walkPages(pagesRoot, null, pages, <Object>{}, 0);
      } else {
        warnings.add('catalog has no page tree');
      }
    }
    return PdfStructureReport(
      pages: pages,
      encrypted: encrypted,
      warnings: warnings,
    );
  }

  void _collectObjects() {
    final text = latin1.decode(bytes);
    if (RegExp(r'/Encrypt\s*\d+\s+\d+\s+R|/Encrypt\s*<<').hasMatch(text)) {
      encrypted = true;
      warnings.add('encrypted PDF: streams not inspected');
    }
    final objStreams = <PdfStream>[];
    for (final m in _objPattern.allMatches(text)) {
      if (objects.length >= cfg.maxObjects) {
        warnings.add('object limit reached');
        break;
      }
      final number = int.parse(m.group(1)!);
      try {
        final parser = PdfObjectParser(bytes, m.end);
        var value = parser.parse();
        if (value is Map<String, Object?>) {
          parser.skipWhite();
          if (_startsWith(parser.pos, 'stream')) {
            value = _readStream(value, parser.pos + 6);
          }
        }
        objects[number] = value;
        if (value is PdfStream && _nameOf(value.dict['Type']) == 'ObjStm') {
          objStreams.add(value);
        }
      } on Object {
        // Damaged object: skip it, keep scanning.
      }
    }
    for (final stream in objStreams) {
      _expandObjectStream(stream);
    }
  }

  bool _startsWith(int at, String word) {
    if (at + word.length > bytes.length) return false;
    for (var i = 0; i < word.length; i++) {
      if (bytes[at + i] != word.codeUnitAt(i)) return false;
    }
    return true;
  }

  PdfStream _readStream(Map<String, Object?> dict, int afterKeyword) {
    var start = afterKeyword;
    if (start < bytes.length && bytes[start] == 0x0D) start++;
    if (start < bytes.length && bytes[start] == 0x0A) start++;
    final length = dict['Length'];
    if (length is int && length >= 0 && start + length <= bytes.length) {
      var p = start + length;
      while (p < bytes.length && PdfObjectParser.isWhite(bytes[p])) {
        p++;
      }
      if (_startsWith(p, 'endstream')) {
        return PdfStream(dict, Uint8List.sublistView(bytes, start, start + length));
      }
    }
    // Indirect or wrong /Length: fall back to searching for `endstream`.
    var end = _indexOf('endstream', start);
    if (end < 0) end = bytes.length;
    var e = end;
    if (e > start && bytes[e - 1] == 0x0A) e--;
    if (e > start && bytes[e - 1] == 0x0D) e--;
    return PdfStream(dict, Uint8List.sublistView(bytes, start, e));
  }

  int _indexOf(String word, int from) {
    final first = word.codeUnitAt(0);
    for (var i = from; i <= bytes.length - word.length; i++) {
      if (bytes[i] == first && _startsWith(i, word)) return i;
    }
    return -1;
  }

  void _expandObjectStream(PdfStream stream) {
    final data = _decode(stream);
    if (data == null) return;
    final n = stream.dict['N'];
    final first = stream.dict['First'];
    if (n is! int || first is! int || first > data.length) return;
    final header = PdfObjectParser(data);
    final entries = <(int, int)>[];
    try {
      for (var i = 0; i < n; i++) {
        final number = header.parse();
        final offset = header.parse();
        if (number is int && offset is int) entries.add((number, offset));
      }
    } on Object {
      return;
    }
    for (final (number, offset) in entries) {
      if (objects.containsKey(number)) continue;
      try {
        objects[number] = PdfObjectParser(data, first + offset).parse();
      } on Object {
        // skip damaged entry
      }
    }
  }

  /// Decodes a stream; `null` if the filter is unsupported or limits hit.
  Uint8List? _decode(PdfStream stream) {
    if (encrypted) return null;
    final filter = _resolve(stream.dict['Filter']);
    final filters = <String>[
      if (filter is PdfName) filter.value,
      if (filter is List)
        for (final f in filter)
          if (f is PdfName) f.value,
    ];
    Uint8List data = stream.raw;
    for (final f in filters) {
      if (f == 'FlateDecode' || f == 'Fl') {
        try {
          data = const ZLibDecoder().decodeBytes(
            data,
            maxOutputSize: cfg.maxDecodedStreamBytes,
          );
        } on Object {
          try {
            data = const ZLibDecoder().decodeBytes(
              data,
              raw: true,
              maxOutputSize: cfg.maxDecodedStreamBytes,
            );
          } on Object {
            return null;
          }
        }
      } else {
        return null;
      }
    }
    if (data.length > cfg.maxDecodedStreamBytes) return null;
    _decodedTotal += data.length;
    if (_decodedTotal > cfg.maxTotalDecodedBytes) {
      warnings.add('decoded-size limit reached');
      return null;
    }
    return data;
  }

  Object? _resolve(Object? value, [int depth = 0]) {
    var v = value;
    var d = depth;
    while (v is PdfRef) {
      if (++d > cfg.maxDepth) return null;
      v = objects[v.number];
    }
    return v;
  }

  Map<String, Object?>? _dictOf(Object? value) {
    final v = _resolve(value);
    if (v is Map<String, Object?>) return v;
    if (v is PdfStream) return v.dict;
    return null;
  }

  String? _nameOf(Object? value) {
    final v = _resolve(value);
    return v is PdfName ? v.value : null;
  }

  Map<String, Object?>? _findCatalog() {
    Map<String, Object?>? found;
    final keys = objects.keys.toList()..sort();
    for (final k in keys) {
      final d = _dictOf(objects[k]);
      if (d != null && _nameOf(d['Type']) == 'Catalog') found = d;
    }
    return found;
  }

  void _walkPages(
    Map<String, Object?> node,
    Object? inheritedResources,
    List<PdfStructurePage> out,
    Set<Object> visited,
    int depth,
  ) {
    if (depth > cfg.maxDepth || !visited.add(node)) return;
    final resources = node['Resources'] ?? inheritedResources;
    final type = _nameOf(node['Type']);
    final kids = _resolve(node['Kids']);
    if (type == 'Pages' || (type == null && kids is List)) {
      if (kids is! List) return;
      for (final kid in kids) {
        final k = _dictOf(kid);
        if (k != null) _walkPages(k, resources, out, visited, depth + 1);
      }
      return;
    }
    out.add(_inspectPage(out.length + 1, node, resources));
  }

  PdfStructurePage _inspectPage(
    int number,
    Map<String, Object?> page,
    Object? resources,
  ) {
    final fonts = <String, PdfFontInfo>{};
    final stats = _ContentStats();
    final contents = _resolve(page['Contents']);
    final streams = <PdfStream>[
      if (contents is PdfStream) contents,
      if (contents is List)
        for (final c in contents)
          if (_resolve(c) case final PdfStream s) s,
    ];
    final data = BytesBuilder(copy: false);
    var readable = true;
    for (final s in streams) {
      final decoded = _decode(s);
      if (decoded == null) {
        readable = false;
        break;
      }
      data
        ..add(decoded)
        ..addByte(0x0A);
    }
    _collectFonts(_dictOf(resources), fonts);
    if (readable) {
      readable = _scanContent(data.takeBytes(), _dictOf(resources), stats, fonts, 0);
    }
    return PdfStructurePage(
      pageNumber: number,
      fonts: fonts.values.toList(),
      imageCount: readable ? stats.images : null,
      textOperatorCount: readable ? stats.textOps : null,
      contentReadable: readable,
    );
  }

  void _collectFonts(Map<String, Object?>? resources, Map<String, PdfFontInfo> out) {
    final fontDict = _dictOf(resources?['Font']);
    if (fontDict == null) return;
    for (final entry in fontDict.entries) {
      final font = _dictOf(entry.value);
      if (font == null) continue;
      out.putIfAbsent(entry.key, () => _fontInfo(entry.key, font));
    }
  }

  PdfFontInfo _fontInfo(String resourceName, Map<String, Object?> font) {
    final subtype = _nameOf(font['Subtype']);
    final baseFont = _nameOf(font['BaseFont']);
    final subsetTag = baseFont == null
        ? null
        : _subsetPattern.firstMatch(baseFont)?.group(1);
    final hasToUnicode = font.containsKey('ToUnicode') && font['ToUnicode'] != null;

    final encodingValue = _resolve(font['Encoding']);
    String? encoding;
    var hasDifferences = false;
    if (encodingValue is PdfName) {
      encoding = encodingValue.value;
    } else if (encodingValue is Map<String, Object?>) {
      encoding = 'custom';
      hasDifferences = encodingValue.containsKey('Differences');
      final base = _nameOf(encodingValue['BaseEncoding']);
      if (base != null && !hasDifferences) encoding = base;
    } else if (encodingValue is PdfStream) {
      // Embedded CMap stream for a Type0 font.
      encoding = _nameOf(encodingValue.dict['CMapName']) ?? 'custom';
    }

    bool hasFontFile(Map<String, Object?> d) =>
        d.containsKey('FontFile') ||
        d.containsKey('FontFile2') ||
        d.containsKey('FontFile3');

    final bool? embedded;
    if (subtype == 'Type3') {
      // Type3 glyphs are drawn by content procedures inside the file.
      embedded = true;
    } else if (subtype == 'Type0') {
      final descendants = _resolve(font['DescendantFonts']);
      final cid = descendants is List && descendants.isNotEmpty
          ? _dictOf(descendants.first)
          : null;
      final descriptor = _dictOf(cid?['FontDescriptor']);
      embedded = descriptor == null ? null : hasFontFile(descriptor);
    } else {
      final descriptor = _dictOf(font['FontDescriptor']);
      // No descriptor (e.g. the standard 14 fonts) means no font program.
      embedded = descriptor != null && hasFontFile(descriptor);
    }

    final plainName = subsetTag == null
        ? baseFont
        : baseFont!.substring(subsetTag.length + 1);
    final UnicodeMappingRisk risk;
    if (hasToUnicode) {
      risk = UnicodeMappingRisk.low;
    } else if (subtype == 'Type3') {
      risk = UnicodeMappingRisk.high;
    } else if (subtype == 'Type0') {
      risk = (encoding == 'Identity-H' || encoding == 'Identity-V')
          ? UnicodeMappingRisk.high
          : UnicodeMappingRisk.unknown;
    } else if (hasDifferences ||
        plainName == 'Symbol' ||
        plainName == 'ZapfDingbats') {
      risk = UnicodeMappingRisk.medium;
    } else if (encoding != null && _standardEncodings.contains(encoding)) {
      risk = UnicodeMappingRisk.low;
    } else if (encoding == null && _standard14.contains(plainName)) {
      risk = UnicodeMappingRisk.low;
    } else {
      // Built-in encoding of a non-standard font: depends on the font
      // program (typical for legacy Hindi fonts) – cannot tell here.
      risk = UnicodeMappingRisk.unknown;
    }

    return PdfFontInfo(
      resourceName: resourceName,
      subtype: subtype,
      baseFont: baseFont,
      subsetTag: subsetTag,
      embedded: embedded,
      hasToUnicode: hasToUnicode,
      encoding: encoding,
      mappingRisk: risk,
    );
  }

  /// Counts text operators and images; follows form XObjects. Returns false
  /// when a nested stream could not be decoded.
  bool _scanContent(
    Uint8List data,
    Map<String, Object?>? resources,
    _ContentStats stats,
    Map<String, PdfFontInfo> fonts,
    int depth,
  ) {
    if (depth > 8) return true;
    final xobjects = _dictOf(resources?['XObject']);
    final parser = PdfObjectParser(data);
    Object? lastOperand;
    var ok = true;
    while (true) {
      parser.skipWhite();
      if (parser.atEnd) break;
      Object? token;
      try {
        token = parser.parse();
      } on Object {
        parser.pos++;
        continue;
      }
      if (token is PdfKeyword) {
        switch (token.value) {
          case 'Tj' || 'TJ' || "'" || '"':
            stats.textOps++;
          case 'BI':
            stats.images++;
            _skipInlineImage(parser);
          case 'Do':
            if (lastOperand is PdfName && xobjects != null) {
              final x = _resolve(xobjects[lastOperand.value]);
              if (x is PdfStream) {
                final sub = _nameOf(x.dict['Subtype']);
                if (sub == 'Image') {
                  stats.images++;
                } else if (sub == 'Form') {
                  final formRes = _dictOf(x.dict['Resources']) ?? resources;
                  _collectFonts(formRes, fonts);
                  final decoded = _decode(x);
                  if (decoded == null) {
                    ok = false;
                  } else if (!_scanContent(decoded, formRes, stats, fonts, depth + 1)) {
                    ok = false;
                  }
                }
              }
            }
        }
      }
      lastOperand = token;
    }
    return ok;
  }

  void _skipInlineImage(PdfObjectParser p) {
    // Skip the parameter dictionary up to `ID`, then the binary data up to
    // a whitespace-delimited `EI`.
    while (!p.atEnd) {
      final t = p.parse();
      if (t is PdfKeyword && t.value == 'ID') break;
    }
    p.pos++;
    final b = p.b;
    while (p.pos + 2 < b.length) {
      if (PdfObjectParser.isWhite(b[p.pos]) &&
          b[p.pos + 1] == 0x45 &&
          b[p.pos + 2] == 0x49 &&
          (p.pos + 3 >= b.length ||
              PdfObjectParser.isWhite(b[p.pos + 3]) ||
              PdfObjectParser.isDelim(b[p.pos + 3]))) {
        p.pos += 3;
        return;
      }
      p.pos++;
    }
    p.pos = b.length;
  }
}

class _ContentStats {
  int textOps = 0;
  int images = 0;
}
