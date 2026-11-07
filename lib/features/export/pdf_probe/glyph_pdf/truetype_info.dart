import 'dart:typed_data';

/// Reads `maxp.numGlyphs` from a TrueType/OpenType font (sfnt). Returns null
/// when the bytes are not a readable sfnt with a `maxp` table. Used by the
/// spike writer to refuse fonts that cannot hold the glyph ids it draws.
int? sfntNumGlyphs(Uint8List bytes) {
  if (bytes.length < 12) {
    return null;
  }
  final d = ByteData.sublistView(bytes);
  final version = d.getUint32(0);
  if (version != 0x00010000 && version != 0x4F54544F && version != 0x74727565) {
    return null;
  }
  final numTables = d.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    if (rec + 16 > bytes.length) {
      return null;
    }
    final tag = String.fromCharCodes(bytes.sublist(rec, rec + 4));
    if (tag == 'maxp') {
      final off = d.getUint32(rec + 8);
      if (off + 6 > bytes.length) {
        return null;
      }
      return d.getUint16(off + 4);
    }
  }
  return null;
}
