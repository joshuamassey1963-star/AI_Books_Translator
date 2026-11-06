import 'dart:typed_data';

import 'package:ai_book_translator/features/engine/ocr/ocr_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('V1 has no OCR engine: the placeholder says so honestly', () async {
    const engine = UnavailableOcrEngine();
    expect(await engine.isAvailable(), isFalse);
    expect(engine.supportedLanguages, isEmpty);
    await expectLater(
      engine.recognize(
        OcrRequest(
          imageBytes: Uint8List(0),
          pixelWidth: 1,
          pixelHeight: 1,
          languages: const ['hi', 'en'],
        ),
      ),
      throwsA(isA<OcrUnavailableException>()),
    );
  });

  test('OCR results are never auto-validated', () {
    const result = OcrResult(
      engineId: 'x',
      engineVersion: '1',
      text: 'नमस्ते',
      words: [],
      meanConfidence: 0.99,
    );
    expect(result.validated, isFalse);
  });
}
