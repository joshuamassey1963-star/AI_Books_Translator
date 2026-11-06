import 'package:ai_book_translator/app/app.dart';
import 'package:ai_book_translator/app/router.dart';
import 'package:ai_book_translator/app/screen_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      // Fresh router per test so navigation state never leaks between tests.
      overrides: [routerProvider.overrideWith((ref) => buildRouter())],
      child: const AiBookTranslatorApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('app launches on Home with honest empty state', (tester) async {
    await _pumpApp(tester);
    expect(find.byKey(const ValueKey('home-empty')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final tab in bottomTabs) {
      expect(find.byKey(ValueKey('tab-${tab.id}')), findsOneWidget);
    }
  });

  testWidgets('each planned tab shows a Not-available status, no buttons', (
    tester,
  ) async {
    await _pumpApp(tester);
    for (final tab in bottomTabs.where(
      (t) => t.title != 'Home' && t.title != 'More',
    )) {
      await tester.tap(find.byKey(ValueKey('tab-${tab.id}')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, tab.title), findsOneWidget);
      expect(find.byKey(const ValueKey('planned-status')), findsOneWidget);
      expect(find.text('Not available yet'), findsOneWidget);
      // No dead buttons or fake progress on placeholders.
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }
  });

  testWidgets('More lists every sub-screen and each one opens', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('tab-SCR-MORE')));
    await tester.pumpAndSettle();

    for (final screen in moreScreens) {
      final row = find.byKey(ValueKey('more-${screen.id}'));
      await tester.scrollUntilVisible(
        row,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, screen.title),
        findsOneWidget,
        reason: screen.id,
      );
      expect(find.byKey(const ValueKey('planned-status')), findsOneWidget);
      // Back to the More list.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'More'), findsOneWidget);
    }
  });

  testWidgets('tabs keep their own navigation stack', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('tab-SCR-MORE')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('more-${moreScreens.first.id}')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, moreScreens.first.title),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('tab-SCR-HOME')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tab-SCR-MORE')));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AppBar, moreScreens.first.title),
      findsOneWidget,
    );
  });

  testWidgets('Book Details route resolves to its planned screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerProvider.overrideWith(
            (ref) => buildRouter(initialLocation: AppRoutes.bookDetails()),
          ),
        ],
        child: const AiBookTranslatorApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Book Details'), findsOneWidget);
  });
}
