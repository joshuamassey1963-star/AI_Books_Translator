import 'dart:convert';
import 'dart:typed_data';

/// Small synthetic encoding fixtures (M2b-1c). No real books.
const mixedText =
    'Chapter 1\n\nभारत एक देश है। India has 28 states.\n\n'
    'क्षत्रिय, ज्ञान, श्री — ZWJ: क्\u200Dष, ZWNJ: क्\u200Cष। 2026 ९८';

Uint8List utf8NoBom(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List utf8WithBom(String s) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(s)]);

Uint8List utf16le(String s, {bool bom = true}) => Uint8List.fromList([
  if (bom) ...[0xFF, 0xFE],
  for (final u in s.codeUnits) ...[u & 0xFF, u >> 8],
]);

Uint8List utf16be(String s, {bool bom = true}) => Uint8List.fromList([
  if (bom) ...[0xFE, 0xFF],
  for (final u in s.codeUnits) ...[u >> 8, u & 0xFF],
]);
