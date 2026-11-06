import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/screen_registry.dart';

/// Bottom-navigation shell. Each tab keeps its own navigation stack
/// (StatefulShellRoute.indexedStack), so switching tabs never loses state.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the active tab returns to its root.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final tab in bottomTabs)
            NavigationDestination(
              key: ValueKey('tab-${tab.id}'),
              icon: Icon(tab.icon),
              label: tab.title,
            ),
        ],
      ),
    );
  }
}
