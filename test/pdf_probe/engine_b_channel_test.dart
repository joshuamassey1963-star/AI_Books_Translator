import 'dart:typed_data';

import 'package:ai_book_translator/features/export/pdf_probe/engine_b_android_native.dart';
import 'package:ai_book_translator/features/export/pdf_probe/pdf_export_probe.dart';
import 'package:ai_book_translator/features/export/pdf_probe/probe_cases.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

String _cps(String s) => s.runes
    .map((r) => r.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join(' ');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(AndroidNativePdfEngine.channelName);
  final fonts = ProbeFontSet(devanagari: Uint8List(0));
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('PoC source strings are the pinned code points', () {
    final byId = {for (final c in shapingPocCases) c.id: c.expectedText};
    expect(_cps(byId['s01_kitab']!), '0915 093F 0924 093E 092C');
    expect(_cps(byId['s02_kshetra']!), '0915 094D 0937 0947 0924 094D 0930');
    expect(
      _cps(byId['s03_rashtra_mixed']!),
      '0930 093E 0937 094D 091F 094D 0930 0020 0927 0930 094D 092E 0020 '
      '0049 006E 0064 0069 0061 0020 0031 0032 0033',
    );
  });

  test('sends the case text unchanged and returns the PDF bytes', () async {
    MethodCall? seen;
    messenger.setMockMethodCallHandler(channel, (call) async {
      seen = call;
      return Uint8List.fromList('%PDF-1.4'.codeUnits);
    });
    final c = shapingPocCases[2];
    final bytes = await const AndroidNativePdfEngine().render(c, fonts);
    expect(String.fromCharCodes(bytes), '%PDF-1.4');
    expect(seen!.method, 'renderCase');
    final args = seen!.arguments as Map;
    expect(args['id'], c.id);
    expect(args['rtl'], isFalse);
    final blocks = args['blocks'] as List;
    expect((blocks.single as Map)['text'], c.blocks.single.text);
    expect((blocks.single as Map)['kind'], 'paragraph');
    expect(c.expectedText, 'राष्ट्र धर्म India 123');
  });

  test('empty native result is an error, not a silent pass', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    expect(
      const AndroidNativePdfEngine().render(shapingPocCases.first, fonts),
      throwsStateError,
    );
  });

  test('without the Android handler (e.g. iOS) it is unsupported', () async {
    expect(
      const AndroidNativePdfEngine().render(shapingPocCases.first, fonts),
      throwsUnsupportedError,
    );
  });

  test('native error is passed on', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'render_failed', message: 'boom');
    });
    expect(
      const AndroidNativePdfEngine().render(shapingPocCases.first, fonts),
      throwsA(isA<PlatformException>()),
    );
  });
}
