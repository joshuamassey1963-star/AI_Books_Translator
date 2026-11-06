import 'package:ai_book_translator/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs on a real device or emulator: `flutter test integration_test`.
/// Not run in CI yet (needs an emulator job, planned in milestone V1-A).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold start reaches Home and bottom navigation', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('home-empty')), findsOneWidget);
  });
}
