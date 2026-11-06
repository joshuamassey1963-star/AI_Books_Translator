/// Why an import was refused. Each code maps to an honest user message.
enum ParseErrorCode {
  empty('The file is empty.'),
  tooLarge('The file is larger than the import limit.'),
  unsupportedFormat('This file type is not supported yet.'),
  pdfNotYetSupported(
    'PDF import is planned (V1-IMP-03) but not available yet.',
  ),
  invalidEncoding(
    'The text encoding could not be read without loss (invalid bytes or '
    'not text). The original file was not changed.',
  ),
  encodingNeedsConfirmation(
    'This looks like UTF-16 text without a byte-order mark. Please confirm '
    'the encoding before importing.',
  ),
  corruptContainer('The file is damaged or not a valid EPUB/DOCX.'),
  unsafeContainer('The file was blocked for safety (suspicious archive).'),
  unsafeXml('The file was blocked for safety (unsafe XML).'),
  missingPart('A required part of the file is missing.'),
  noText('No readable text was found.');

  const ParseErrorCode(this.userMessage);

  final String userMessage;
}

class ParseException implements Exception {
  const ParseException(this.code, [this.detail]);

  final ParseErrorCode code;

  /// Technical detail for diagnostics. Never contains book text.
  final String? detail;

  @override
  String toString() =>
      'ParseException(${code.name}${detail == null ? '' : ': $detail'})';
}
