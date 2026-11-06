import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Commit SHA injected at build time by CI:
/// `flutter build apk --dart-define=GIT_SHA=<sha>`. Never hardcoded.
const String buildGitSha = String.fromEnvironment('GIT_SHA');

String get buildTypeLabel => kReleaseMode
    ? 'Release'
    : kProfileMode
    ? 'Profile'
    : 'Debug';

class BuildInfo {
  const BuildInfo({
    required this.version,
    required this.buildNumber,
    required this.buildType,
    required this.gitSha,
  });

  final String version;
  final String buildNumber;
  final String buildType;

  /// Empty when the build had no `GIT_SHA` define (e.g. a local build).
  final String gitSha;

  String get shaLabel => gitSha.isEmpty ? 'not set (local build)' : gitSha;
}

/// Version and build number come from the installed package (pubspec).
final buildInfoProvider = FutureProvider<BuildInfo>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return BuildInfo(
    version: info.version,
    buildNumber: info.buildNumber,
    buildType: buildTypeLabel,
    gitSha: buildGitSha,
  );
});

/// Small "About this build" section shown at the end of More.
class BuildInfoTile extends ConsumerWidget {
  const BuildInfoTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(buildInfoProvider);
    return ListTile(
      key: const ValueKey('more-build-info'),
      leading: const Icon(Icons.info_outline),
      title: const Text('About this build'),
      subtitle: switch (info) {
        AsyncData(:final value) => SelectableText(
          'Version ${value.version} (build ${value.buildNumber})\n'
          '${value.buildType} build\n'
          'Commit ${value.shaLabel}',
          key: const ValueKey('build-info-text'),
        ),
        AsyncError() => const Text('Build information unavailable'),
        _ => const Text('Loading…'),
      },
      isThreeLine: true,
    );
  }
}
