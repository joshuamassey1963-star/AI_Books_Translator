import 'package:ai_book_translator/app/app.dart';
import 'package:ai_book_translator/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, String location) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        routerProvider.overrideWith(
          (ref) => buildRouter(initialLocation: location),
        ),
      ],
      child: const AiBookTranslatorApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('More shows Developer Tests in debug builds and opens it', (
    tester,
  ) async {
    await _pump(tester, AppRoutes.more);
    await tester.tap(find.byKey(const ValueKey('more-dev-tests')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Developer Tests'), findsOneWidget);
  });

  testWidgets('encoding tab shows real detector output', (tester) async {
    await _pump(tester, AppRoutes.devTests);
    await tester.tap(find.byKey(const ValueKey('enc-run')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byKey(const ValueKey('enc-status'))).data,
      'decoded',
    );
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('enc-original')))
          .data,
      'भारत India 2026',
    );
  });

  testWidgets('Kruti Dev: refuses without confirmation, converts with it', (
    tester,
  ) async {
    await _pump(tester, AppRoutes.devTests);
    await tester.tap(find.byKey(const ValueKey('dev-tab-kruti')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('kruti-example-Hkkjr')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('kruti-convert')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('kruti-refusal')))
          .data,
      'fontNotConfirmed',
    );

    await tester.tap(find.byKey(const ValueKey('kruti-confirm')));
    await tester.tap(find.byKey(const ValueKey('kruti-convert')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SelectableText>(find.byKey(const ValueKey('kruti-output')))
          .data,
      'भारत',
    );
    expect(find.byKey(const ValueKey('kruti-copy')), findsOneWidget);
  });

  testWidgets('TXT tab parses sample and lists unfinished items disabled', (
    tester,
  ) async {
    await _pump(tester, AppRoutes.devTests);
    await tester.tap(find.byKey(const ValueKey('dev-tab-parser')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('txt-run')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byKey(const ValueKey('txt-status'))).data,
      'parsed',
    );
    final picker = tester.widget<ListTile>(
      find.byKey(const ValueKey('dev-file-picker-disabled')),
    );
    expect(picker.enabled, isFalse);
  });
}
