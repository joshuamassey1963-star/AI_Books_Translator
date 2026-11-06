import 'package:flutter/material.dart';

import '../../app/screen_registry.dart';
import '../../core/feature_status.dart';

/// Home tab. In Session 1 it only shows the real state of the app: no books,
/// no jobs, and which areas are still planned. No fake data.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = allScreens
        .where((s) => s.status == FeatureStatus.planned)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('AI Book Translator')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('English → हिंदी', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'No books yet. Book import arrives in milestone V1-B.',
            key: const ValueKey('home-empty'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.construction_outlined),
              title: const Text('Foundation build'),
              subtitle: Text(
                '$planned of ${allScreens.length} screens are planned and '
                'not available yet.',
                key: const ValueKey('home-planned-count'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
