import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart' as pdfrx;

/// M2b-3b-2b. CI only: extracts text from the Engine C PDFs with PDFium
/// (the engine behind Chrome's and Android's PDF viewers, via pdfrx) and
/// writes `extracted/<id>.pdfium.txt` for verify.py. It records what PDFium
/// returns; it does not decide PASS/FAIL. Needs PDFIUM_PATH (D-021) and
/// PDF_PROBE_C_OUT_DIR with generated PDFs.
void main() {
  final pdfiumPath = Platform.environment['PDFIUM_PATH'];
  final outDir = Platform.environment['PDF_PROBE_C_OUT_DIR'];

  test(
    'PDFium text of every Engine C PDF',
    () async {
      pdfrx.Pdfrx.pdfiumModulePath = pdfiumPath;
      pdfrx.Pdfrx.cacheDirectoryPath = Directory.systemTemp
          .createTempSync('pdfrx_engine_c')
          .path;
      await pdfrx.pdfrxInitialize();
      Directory('$outDir/extracted').createSync(recursive: true);
      final pdfs = Directory('$outDir/pdf')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.pdf'))
          .toList();
      expect(pdfs, isNotEmpty);
      for (final f in pdfs) {
        final id = f.uri.pathSegments.last.replaceAll('.pdf', '');
        final doc = await pdfrx.PdfDocument.openData(
          f.readAsBytesSync(),
          sourceName: '$id.pdf',
        );
        final text = await doc.pages.first.loadStructuredText();
        File('$outDir/extracted/$id.pdfium.txt')
            .writeAsStringSync(text.fullText);
        await doc.dispose();
      }
    },
    skip:
        pdfiumPath == null ||
            outDir == null ||
            !Directory('$outDir/pdf').existsSync()
        ? 'needs PDFIUM_PATH and PDF_PROBE_C_OUT_DIR with PDFs (CI)'
        : false,
  );
}
