import 'dart:convert';
import 'dart:io';

import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/glyph_pdf_writer.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/pdf_structure_check.dart';
import 'package:ai_book_translator/features/export/pdf_probe/glyph_pdf/shaped_run.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// M2b-3b-2a. Runs only in CI job pdf-export-probe, which shapes the fixture
/// with HarfBuzz (uharfbuzz, pinned) into PDF_PROBE_HB_JSON and provides the
/// OFL font in PDF_PROBE_FONT_DIR. Writes PDFs for independent checks.
void main() {
  final hbJson = Platform.environment['PDF_PROBE_HB_JSON'];
  final fontDir = Platform.environment['PDF_PROBE_FONT_DIR'];
  final outDir = Platform.environment['PDF_PROBE_C_OUT_DIR'];

  test(
    'Engine C spike writes c01 PDFs (cluster, run, control)',
    () {
      final j = jsonDecode(File(hbJson!).readAsStringSync()) as Map<String, Object?>;
      final expected = File(
        'test/fixtures/pdf_probe/c01_kitab.txt',
      ).readAsStringSync();
      expect(j['text'], expected, reason: 'shaped text = fixture');
      final fontBytes = File('$fontDir/${j['font']}').readAsBytesSync();
      expect(sha256.convert(fontBytes).toString(), j['font_sha256']);
      final run = ShapedRun(
        text: expected,
        unitsPerEm: j['upem']! as int,
        glyphs: [
          for (final g in (j['glyphs']! as List).cast<Map<String, Object?>>())
            ShapedGlyph(
              glyphId: g['gid']! as int,
              cluster: g['cluster']! as int,
              xAdvance: g['ax']! as int,
              xOffset: g['dx']! as int,
              yOffset: g['dy']! as int,
            ),
        ],
      );
      final toUni = {
        for (final e in (j['glyph_to_unicode']! as Map).entries)
          int.parse(e.key as String): e.value as int,
      };
      const variants = {
        'c01_kitab': ActualTextScope.cluster,
        'c01_kitab_run': ActualTextScope.run,
        'c01_kitab_control': ActualTextScope.none,
      };
      const titles = {
        'c01_kitab': 'HarfBuzz glyphs + /ActualText per cluster',
        'c01_kitab_run': 'HarfBuzz glyphs + one /ActualText for the run',
        'c01_kitab_control': 'Control: HarfBuzz glyphs, ToUnicode only',
      };
      Directory('$outDir/pdf').createSync(recursive: true);
      Directory('$outDir/expected').createSync(recursive: true);
      final generation = <Map<String, Object?>>[];
      for (final e in variants.entries) {
        final pdf = const GlyphPdfWriter().write(
          run: run,
          fontBytes: fontBytes,
          fontName: 'NotoSerifDevanagari-Regular',
          glyphToUnicode: toUni,
          scope: e.value,
        );
        expect(checkPdfStructure(pdf), isEmpty, reason: e.key);
        File('$outDir/pdf/${e.key}.pdf').writeAsBytesSync(pdf);
        File('$outDir/expected/${e.key}.txt').writeAsStringSync(expected);
        generation.add({'id': e.key, 'generated': true, 'bytes': pdf.length});
      }
      expect(run.text, expected, reason: 'source unchanged');
      File('$outDir/generation.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'engine': 'engine_c_hb_actualtext',
          'harfbuzz': j['harfbuzz'],
          'uharfbuzz': j['uharfbuzz'],
          'font': j['font'],
          'font_sha256': j['font_sha256'],
          'cases': [
            for (final id in variants.keys)
              {
                'id': id,
                'title': titles[id],
                'tCases': ['T01', 'T02'],
                'rtl': false,
              },
          ],
          'generation': generation,
        }),
      );
    },
    skip: hbJson == null || fontDir == null || outDir == null
        ? 'needs PDF_PROBE_HB_JSON, PDF_PROBE_FONT_DIR, PDF_PROBE_C_OUT_DIR (CI)'
        : false,
  );
}
