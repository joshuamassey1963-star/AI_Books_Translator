import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/glyph_pdf_writer.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/pdf_structure_check.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'hb_fixture.dart';

/// M2b-3b-2b. Runs only in CI job pdf-export-probe: HarfBuzz shaping
/// (uharfbuzz, pinned) writes fresh `<case>.hb.json` + retain-gids subsets
/// into PDF_PROBE_HB_DIR; OFL fonts are in PDF_PROBE_FONT_DIR. Writes PDFs
/// for the independent checks in tool/pdf_probe/verify.py.
const cases = {
  'c01_kitab': 'C01 किताब: i-matra reordering',
  'c02_kshetra': 'C02 क्षेत्र: conjunct ligatures + zero-width e-matra',
  'c03_rashtra_mixed': 'C03 राष्ट्र धर्म India 123: conjuncts, reph, two fonts',
};

void main() {
  final hbDir = Platform.environment['PDF_PROBE_HB_DIR'];
  final fontDir = Platform.environment['PDF_PROBE_FONT_DIR'];
  final outDir = Platform.environment['PDF_PROBE_C_OUT_DIR'];

  test(
    'Engine C writes full-font, subset and control PDFs for C01–C03',
    () {
      Directory('$outDir/pdf').createSync(recursive: true);
      Directory('$outDir/expected').createSync(recursive: true);
      final meta = <Map<String, Object?>>[];
      final generation = <Map<String, Object?>>[];
      void emit(
        String id,
        String title,
        String text,
        Uint8List pdf, {
        String? control,
        Map<String, Object?> extra = const {},
      }) {
        expect(checkPdfStructure(pdf), isEmpty, reason: id);
        File('$outDir/pdf/$id.pdf').writeAsBytesSync(pdf);
        File('$outDir/expected/$id.txt').writeAsStringSync(text);
        meta.add({
          'id': id,
          'title': title,
          'tCases': ['T01', 'T02'],
          'rtl': false,
          'control': ?control,
        });
        generation.add({
          'id': id,
          'generated': true,
          'bytes': pdf.length,
          'sha256': sha256.convert(pdf).toString(),
          ...extra,
        });
      }

      for (final e in cases.entries) {
        final fx = HbFixture.load('$hbDir/${e.key}.hb.json');
        final expected = File(
          'test/fixtures/pdf_probe/${e.key}.txt',
        ).readAsStringSync();
        expect(fx.text, expected, reason: 'shaped text = fixture');
        final run = fx.run();
        final content = const GlyphPdfWriter().contentStream(
          run,
          ActualTextScope.cluster,
        );
        expect(checkActualText(content, expected), isEmpty, reason: e.key);

        Uint8List full(int i) {
          final b = File('$fontDir/${fx.font(i)['file']}').readAsBytesSync();
          expect(sha256.convert(b).toString(), fx.font(i)['sha256']);
          return b;
        }

        Uint8List subset(int i) {
          final s = fx.font(i)['subset']! as Map<String, Object?>;
          final b = File('$hbDir/${s['file']}').readAsBytesSync();
          expect(sha256.convert(b).toString(), s['sha256']);
          return b;
        }

        final fullFonts = fx.pdfFonts(full);
        emit(
          e.key,
          '${e.value} – full fonts',
          expected,
          const GlyphPdfWriter().write(run: run, fonts: fullFonts),
          extra: {
            'fonts': [for (final f in fullFonts) f.bytes.length],
          },
        );
        final subFonts = fx.pdfFonts(subset);
        emit(
          '${e.key}_subset',
          '${e.value} – hb-subset retain-gids fonts',
          expected,
          const GlyphPdfWriter().write(run: run, fonts: subFonts),
          extra: {
            'fonts': [for (final f in subFonts) f.bytes.length],
          },
        );
        if (e.key == 'c01_kitab') {
          emit(
            'c01_kitab_control_no_actualtext',
            'Control: no /ActualText, ToUnicode (cmapAll) only',
            expected,
            const GlyphPdfWriter().write(
              run: run,
              fonts: fullFonts,
              scope: ActualTextScope.none,
              toUnicode: ToUnicodePolicy.cmapAll,
            ),
            control: 'expected to lose the i-matra',
          );
        }
        if (e.key == 'c02_kshetra') {
          emit(
            'c02_kshetra_control_cmapall',
            'Control: /ActualText + ToUnicode for every cmap glyph (S12 policy)',
            expected,
            const GlyphPdfWriter().write(
              run: run,
              fonts: fullFonts,
              toUnicode: ToUnicodePolicy.cmapAll,
            ),
            control: 'shows extractor disagreement on a zero-width matra',
          );
        }
        expect(run.text, expected, reason: 'source unchanged');
      }
      File('$outDir/generation.json').writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert({
          'engine': 'engine_c_hb_actualtext',
          'cases': meta,
          'generation': generation,
        }),
      );
    },
    skip: hbDir == null || fontDir == null || outDir == null
        ? 'needs PDF_PROBE_HB_DIR, PDF_PROBE_FONT_DIR, PDF_PROBE_C_OUT_DIR (CI)'
        : false,
  );
}
