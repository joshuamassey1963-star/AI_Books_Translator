import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/screen_registry.dart';
import 'build_info.dart';

/// Lists workspace tools, settings and help. Every row opens a real route;
/// each row shows the screen's version and honest status.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.builder(
        itemCount: moreScreens.length + (kDebugMode ? 2 : 1),
        itemBuilder: (context, index) {
          // Last row: build information (all builds).
          if (index == moreScreens.length + (kDebugMode ? 1 : 0)) {
            return const BuildInfoTile();
          }
          if (index == moreScreens.length) {
            // Debug builds only (DEV-01); compiled out of release builds.
            return ListTile(
              key: const ValueKey('more-dev-tests'),
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Developer Tests'),
              subtitle: const Text('Debug build only · engine diagnostics'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(AppRoutes.devTests),
            );
          }
          final screen = moreScreens[index];
          return ListTile(
            key: ValueKey('more-${screen.id}'),
            leading: Icon(screen.icon),
            title: Text(screen.title),
            subtitle: Text(
              '${screen.version.label} · ${screen.status.userLabel}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(AppRoutes.moreSub(screen)),
          );
        },
      ),
    );
  }
}
