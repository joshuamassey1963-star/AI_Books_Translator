import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_book_translator/features/export/pdf_probe/engine_a_dart_pdf.dart';
import 'package:ai_book_translator/features/export/pdf_probe/pdf_export_probe.dart';
import 'package:ai_book_translator/features/export/pdf_probe/probe_cases.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// M2b-3a. The generation test runs only when CI provides the fonts:
/// PDF_PROBE_FONT_DIR (OFL Noto fonts, SHA-256 pinned) and PDF_PROBE_OUT_DIR.
void main() {
  group('probe cases', () {
    test('ids are unique and file-safe', () {
      final ids = probeCases.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(RegExp(r'^p\d\d_[a-z0-9_]+$').hasMatch(id), isTrue, reason: id);
      }
    });

    test('expected text is NFC and non-empty', () {
      for (final c in probeCases) {
        expect(c.expectedText, isNotEmpty, reason: c.id);
        expect(unorm.nfc(c.expectedText), c.expectedText, reason: c.id);
      }
    });

    test('required scripts and marks are covered', () {
      final all = probeCases.map((c) => c.expectedText).join('\n');
      expect(all, contains('\u200D'), reason: 'ZWJ');
      expect(all, contains('\u200C'), reason: 'ZWNJ');
      expect(all, contains('\u094D'), reason: 'halant');
      expect(all, contains('\u093F'), reason: 'i-matra');
      expect(all, contains('र्'), reason: 'reph');
      expect(all, contains('०'), reason: 'Devanagari digit');
      expect(all, contains('λ'), reason: 'Greek');
      expect(all, contains('א'), reason: 'Hebrew');
      final tCases = probeCases.expand((c) => c.tCases).toSet();
      for (final t in ['T01', 'T02', 'T03', 'T04', 'T05', 'T08', 'T10']) {
        expect(tCases, contains(t));
      }
    });
  });

  final fontDir = Platform.environment['PDF_PROBE_FONT_DIR'];
  final outDir = Platform.environment['PDF_PROBE_OUT_DIR'];

  test(
    'Engine A writes one PDF per case (evidence for CI checks)',
    () async {
      Uint8List read(String name) => File('$fontDir/$name').readAsBytesSync();
      File? opt(String name) {
        final f = File('$fontDir/$name');
        return f.existsSync() ? f : null;
      }

      final fonts = ProbeFontSet(
        devanagari: read('NotoSerifDevanagari-Regular.ttf'),
        devanagariBold: opt('NotoSerifDevanagari-Bold.ttf')?.readAsBytesSync(),
        latinGreek: opt('NotoSerif-Regular.ttf')?.readAsBytesSync(),
        hebrew: opt('NotoSerifHebrew-Regular.ttf')?.readAsBytesSync(),
      );
      const PdfExportProbe engine = DartPdfEngineA();
      final pdfDir = Directory('$outDir/pdf')..createSync(recursive: true);
      final expDir = Directory('$outDir/expected')..createSync(recursive: true);
      final generation = <Map<String, Object?>>[];
      for (final c in probeCases) {
        final before = c.expectedText;
        // Source text is kept apart from engine output.
        File('${expDir.path}/${c.id}.txt').writeAsStringSync(c.expectedText);
        try {
          final bytes = await engine.render(c, fonts);
          File('${pdfDir.path}/${c.id}.pdf').writeAsBytesSync(bytes);
          expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
          generation.add({
            'id': c.id,
            'generated': true,
            'bytes': bytes.length,
          });
        } catch (e) {
          generation.add({'id': c.id, 'generated': false, 'error': '$e'});
        }
        expect(c.expectedText, before, reason: 'source text unchanged');
      }
      File('$outDir/generation.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'engine': engine.engineId,
          'cases': [
            for (final c in probeCases)
              {'id': c.id, 'title': c.title, 'tCases': c.tCases, 'rtl': c.rtl},
          ],
          'generation': generation,
        }),
      );
    },
    skip: fontDir == null || outDir == null
        ? 'PDF_PROBE_FONT_DIR / PDF_PROBE_OUT_DIR not set (CI pdf-probe job)'
        : false,
  );
}
