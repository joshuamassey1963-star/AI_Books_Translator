# Changelog

## [Unreleased]
### Added (Session 2 / M1, 2026-11-06)
- Committed `android/` and `ios/` platform folders (Flutter 3.47.9 template), app name "AI Book Translator".
- `pubspec.lock` committed for reproducible builds.
- CI: blocking `dart format` check; iOS `--no-codesign` build job on macOS.
### Changed
- Applied `dart format` to 4 files; CI no longer generates platform folders.

### Added (Session 1, 2026-11-06)
- Flutter app skeleton: Riverpod + go_router, Material 3 theme.
- Bottom navigation shell (Home, Library, Translate, Tasks, More) with per-tab stacks.
- Screen registry with honest PLANNED placeholders for all 15 screens.
- Unit + widget tests, integration test stub.
- GitHub Actions CI (analyze, test, Android debug APK).
- Docs: roadmap, architecture, feature matrix (101 features), decisions, dependencies, research, test plan, progress, handover.
