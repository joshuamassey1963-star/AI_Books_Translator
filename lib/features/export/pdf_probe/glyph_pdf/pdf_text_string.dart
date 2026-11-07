/// PDF text string as a hex string: UTF-16BE with the FE FF byte order mark
/// (ISO 32000-1 §7.9.2.2). Surrogate pairs come from Dart's UTF-16 units.
String pdfUtf16BeHex(String s) {
  final b = StringBuffer('FEFF');
  for (final unit in s.codeUnits) {
    b.write(unit.toRadixString(16).toUpperCase().padLeft(4, '0'));
  }
  return b.toString();
}

/// Decodes [pdfUtf16BeHex] output (for tests and checks).
String decodePdfUtf16BeHex(String hex) {
  if (!hex.toUpperCase().startsWith('FEFF') || hex.length % 4 != 0) {
    throw const FormatException('not UTF-16BE with BOM');
  }
  final units = <int>[
    for (var i = 4; i < hex.length; i += 4)
      int.parse(hex.substring(i, i + 4), radix: 16),
  ];
  return String.fromCharCodes(units);
}
