import 'dart:convert';
import 'dart:io';

import 'package:ai_book_translator/features/export/pdf_probe/engine_b_android_native.dart';
import 'package:ai_book_translator/features/export/pdf_probe/pdf_export_probe.dart';
import 'package:ai_book_translator/features/export/pdf_probe/probe_cases.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// M2b-3b-1: runs on an Android emulator in CI (job pdf-export-probe-android).
/// Writes the PDFs to the app's external files dir and also prints them in
/// chunks (PROBE lines) so CI can rebuild them if the app is uninstalled.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Engine B (Android native) writes the PoC PDFs', (tester) async {
    if (!Platform.isAndroid) {
      markTestSkipped('Android only');
      return;
    }
    const engine = AndroidNativePdfEngine();
    final fonts = ProbeFontSet(devanagari: Uint8List(0)); // system fonts
    final generation = <Map<String, Object?>>[];
    final pdfs = <String, String>{};
    for (final c in shapingPocCases) {
      final before = c.expectedText;
      final bytes = await engine.render(c, fonts);
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(c.expectedText, before, reason: 'source text unchanged');
      pdfs[c.id] = base64.encode(bytes);
      generation.add({'id': c.id, 'generated': true, 'bytes': bytes.length});
    }
    final manifest = jsonEncode({
      'engine': engine.engineId,
      'device': await engine.deviceInfo(),
      'cases': [
        for (final c in shapingPocCases)
          {'id': c.id, 'title': c.title, 'tCases': c.tCases, 'rtl': c.rtl},
      ],
      'expected': {for (final c in shapingPocCases) c.id: c.expectedText},
      'generation': generation,
      'pdfs': pdfs,
    });
    final dir = await engine.outputDir();
    if (dir != null) {
      File('$dir/manifest.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(manifest);
    }
    final saved = await engine.channel.invokeMethod<String>('saveToDownloads', {
      'name': 'manifest.json',
      'bytes': Uint8List.fromList(utf8.encode(manifest)),
    });
    debugPrint('PROBE_SAVED $saved');
    final b64 = base64.encode(utf8.encode(manifest));
    const chunk = 600;
    final n = (b64.length / chunk).ceil();
    for (var i = 0; i < n; i++) {
      final end = (i + 1) * chunk < b64.length ? (i + 1) * chunk : b64.length;
      debugPrint('PROBE $i/$n ${b64.substring(i * chunk, end)}');
      // logcat drops lines when they arrive in a burst; pace them.
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  });
}
