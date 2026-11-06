import 'dart:typed_data';

import 'package:ai_book_translator/app/app.dart';
import 'package:ai_book_translator/app/router.dart';
import 'package:ai_book_translator/features/dev_tests/dev_diagnostics.dart';
import 'package:ai_book_translator/features/dev_tests/txt_file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakePicker implements TxtFilePicker {
  _FakePicker(this.result, {this.fail = false});
  final PickedTxtFile? result;
  final bool fail;
  int reads = 0;

  @override
  Future<PickedTxtFile?> pickTxt() async {
    if (fail) throw StateError('picker failed');
    final r = result;
    if (r == null) return null;
    return PickedTxtFile(
      name: r.name,
      size: r.size,
      readBytes: () {
        reads++;
        return r.readBytes();
      },
    );
  }
}

PickedTxtFile _file(String name, Uint8List bytes, {int? size}) =>
    PickedTxtFile(
      name: name,
      size: size ?? bytes.length,
      readBytes: () async => bytes,
    );

Future<void> _open(WidgetTester tester, TxtFilePicker picker) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWith(
          (ref) => buildRouter(initialLocation: AppRoutes.devTests),
        ),
        txtFilePickerProvider.overrideWithValue(picker),
      ],
      child: const AiBookTranslatorApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('dev-tab-parser')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('txt-choose-file')));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<SelectableText>(find.byKey(ValueKey(key))).data!;

void main() {
  const mixed = 'Chapter 1\n\nभारत एक देश है। India.\n\nChapter 2\n\nदूसरा।';

  testWidgets('picked UTF-8 file shows metadata and preview', (tester) async {
    final bytes = SampleBytes.utf8.encode(mixed);
    await _open(tester, _FakePicker(_file('book.txt', bytes)));
    expect(_text(tester, 'file-name'), 'book.txt');
    expect(_text(tester, 'file-size'), '${bytes.length} bytes');
    expect(_text(tester, 'file-encoding'), startsWith('UTF-8 · decoded'));
    expect(_text(tester, 'file-status'), 'parsed');
    expect(_text(tester, 'file-sha'), hasLength(64));
    expect(_text(tester, 'file-preview'), mixed);
    expect(find.byKey(const ValueKey('file-copy-preview')), findsOneWidget);
  });

  testWidgets('UTF-16 BOM file parses', (tester) async {
    await _open(
      tester,
      _FakePicker(_file('u16.txt', SampleBytes.utf16leBom.encode(mixed))),
    );
    expect(_text(tester, 'file-encoding'), contains('UTF-16 LE'));
    expect(_text(tester, 'file-status'), 'parsed');
  });

  testWidgets('no-BOM UTF-16 asks for a choice, then parses', (tester) async {
    await _open(
      tester,
      _FakePicker(
        _file('n.txt', SampleBytes.utf16leNoBom.encode('Hello world text.')),
      ),
    );
    expect(
      _text(tester, 'file-status'),
      'refused: encodingNeedsConfirmation',
    );
    await tester.tap(find.byKey(const ValueKey('file-confirm-utf16le')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'file-status'), 'parsed');
    expect(_text(tester, 'file-preview'), 'Hello world text.');
  });

  testWidgets('invalid encoding is explained', (tester) async {
    await _open(
      tester,
      _FakePicker(_file('bad.txt', SampleBytes.invalidUtf8.encode('abc'))),
    );
    expect(_text(tester, 'file-status'), 'refused: invalidEncoding');
    expect(find.byKey(const ValueKey('file-preview')), findsNothing);
  });

  testWidgets('empty file is refused', (tester) async {
    await _open(tester, _FakePicker(_file('e.txt', Uint8List(0))));
    expect(_text(tester, 'file-status'), 'refused: empty');
  });

  testWidgets('oversized file is refused without reading bytes', (
    tester,
  ) async {
    final picker = _FakePicker(
      _file('big.txt', Uint8List(4), size: 200 * 1024 * 1024 + 1),
    );
    await _open(tester, picker);
    expect(_text(tester, 'file-status'), 'refused: tooLarge');
    expect(picker.reads, 0);
  });

  testWidgets('cancel leaves the screen usable', (tester) async {
    await _open(tester, _FakePicker(null));
    expect(find.byKey(const ValueKey('txt-pick-message')), findsOneWidget);
    expect(find.byKey(const ValueKey('file-status')), findsNothing);
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Choose TXT File'),
        matching: find.byWidgetPredicate((w) => w is FilledButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('picker failure shows a recoverable message', (tester) async {
    await _open(tester, _FakePicker(null, fail: true));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('txt-pick-message')))
          .data,
      contains('Could not open the file'),
    );
    expect(find.text('Choose TXT File'), findsOneWidget);
  });

  testWidgets('More shows build information from the package', (
    tester,
  ) async {
    PackageInfo.setMockInitialValues(
      appName: 'AI Book Translator',
      packageName: 'test',
      version: '0.1.1',
      buildNumber: '2',
      buildSignature: '',
    );
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith(
            (ref) => buildRouter(initialLocation: AppRoutes.more),
          ),
        ],
        child: const AiBookTranslatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    final text = _text(tester, 'build-info-text');
    expect(text, contains('Version 0.1.1 (build 2)'));
    expect(text, contains('Debug build'));
    // Tests run without --dart-define=GIT_SHA, so no SHA is invented.
    expect(text, contains('Commit not set (local build)'));
  });
}
