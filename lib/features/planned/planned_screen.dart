import 'package:flutter/material.dart';

import '../../app/screen_registry.dart';

/// Honest placeholder for a screen that is not built yet.
///
/// Rules (see docs/DECISIONS.md D-008): no action buttons, no progress bars,
/// no success messages. It only states what the screen will do, its target
/// version and its current status.
class PlannedScreen extends StatelessWidget {
  const PlannedScreen({super.key, required this.screen});

  final AppScreen screen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(screen.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(screen.icon, size: 56, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                screen.status.userLabel,
                key: const ValueKey('planned-status'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                screen.summary,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Chip(
                label: Text(
                  'Planned for ${screen.version.label} · ${screen.status.code}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
