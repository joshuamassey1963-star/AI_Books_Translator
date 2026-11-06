import 'package:xml/xml.dart';

import 'parse_exception.dart';

final RegExp _entityDeclaration = RegExp(r'<!ENTITY', caseSensitive: false);
final RegExp _externalDoctype = RegExp(
  r'<!DOCTYPE[^>\[]*\b(SYSTEM|PUBLIC)\b[^>\[]*\[',
  caseSensitive: false,
);

/// Parses XML/XHTML from a book container (V1-SEC-02).
///
/// - Any `<!ENTITY` declaration is refused (XXE, billion-laughs).
/// - A DOCTYPE with an internal subset is refused.
/// - Named HTML entities such as `&nbsp;` are decoded (common in EPUB XHTML).
/// - Malformed XML becomes [ParseErrorCode.corruptContainer].
XmlDocument parseSafeXml(String source, {required String partName}) {
  if (_entityDeclaration.hasMatch(source) ||
      _externalDoctype.hasMatch(source)) {
    throw ParseException(ParseErrorCode.unsafeXml, partName);
  }
  try {
    return XmlDocument.parse(
      source,
      entityMapping: const XmlDefaultEntityMapping.html5(),
    );
  } on XmlException catch (e) {
    throw ParseException(
      ParseErrorCode.corruptContainer,
      '$partName: ${e.runtimeType}',
    );
  }
}

/// First descendant element with [localName], ignoring namespaces.
XmlElement? firstByLocalName(XmlNode root, String localName) {
  for (final node in root.descendants) {
    if (node is XmlElement && node.localName == localName) return node;
  }
  return null;
}

/// All descendant elements with [localName], ignoring namespaces.
Iterable<XmlElement> allByLocalName(XmlNode root, String localName) => root
    .descendants
    .whereType<XmlElement>()
    .where((e) => e.localName == localName);

/// Attribute by local name, ignoring its namespace prefix.
String? attributeByLocalName(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.localName == localName) return attribute.value;
  }
  return null;
}
