import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dev_tests/dev_tests_screen.dart';
import '../features/home/home_screen.dart';
import '../features/more/more_screen.dart';
import '../features/planned/planned_screen.dart';
import '../features/shell/app_shell.dart';
import 'screen_registry.dart';

/// Route paths, derived from the screen registry so they cannot drift.
abstract final class AppRoutes {
  static const String home = '/home';
  static const String library = '/library';
  static const String translate = '/translate';
  static const String tasks = '/tasks';
  static const String more = '/more';

  static String bookDetails() => '$library/${bookDetailsScreen.path}';
  static String moreSub(AppScreen screen) => '$more/${screen.path}';

  /// Debug builds only (DEV-01).
  static const String devTests = '$more/dev-tests';
}

GoRouter buildRouter({String initialLocation = AppRoutes.home}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.library,
                builder: (_, _) => PlannedScreen(screen: bottomTabs[1]),
                routes: [
                  GoRoute(
                    path: bookDetailsScreen.path,
                    builder: (_, _) =>
                        const PlannedScreen(screen: bookDetailsScreen),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.translate,
                builder: (_, _) => PlannedScreen(screen: bottomTabs[2]),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tasks,
                builder: (_, _) => PlannedScreen(screen: bottomTabs[3]),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (_, _) => const MoreScreen(),
                routes: [
                  for (final screen in moreScreens)
                    GoRoute(
                      path: screen.path,
                      builder: (_, _) => PlannedScreen(screen: screen),
                    ),
                  if (kDebugMode)
                    GoRoute(
                      path: 'dev-tests',
                      builder: (_, _) => const DevTestsScreen(),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const _UnknownRoute(),
  );
}

/// App-wide router. Overridable in tests.
final routerProvider = Provider<GoRouter>((ref) {
  final router = buildRouter();
  ref.onDispose(router.dispose);
  return router;
});

class _UnknownRoute extends StatelessWidget {
  const _UnknownRoute();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Page not found', textDirection: TextDirection.ltr),
    );
  }
}
