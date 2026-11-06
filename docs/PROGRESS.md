# Progress

- **Current version:** 0.1.0+1 (V1, pre-alpha)
- **Current milestone:** M1 Platform folders + CI – **DONE**. Next: M2 (P0 spike).
- **Last verified code commit:** `0602b55` on `develop` – GitHub Actions run 42149165709: format check 0 changes, `flutter analyze` no issues, `flutter test` 14/14, Android debug APK built (artifact 13471217965), iOS debug `--no-codesign` build OK.

## VERIFIED (automated CI evidence)
- V1-NAV-01 bottom navigation shell
- V1-NAV-02 honest Planned placeholders
- V1-CI-01 CI analyze + tests (+ blocking format check)
- V1-CI-02 Android debug APK in CI

## In progress
- V1-NAV-03 Home (empty state only)
- V1-CI-03 iOS build verified (debug, unsigned); release builds + SHA-256 checksums pending

## Manual smoke test
- 2026-11-06: owner installed the debug APK on an Android phone; navigation shell and placeholders work as designed (see docs/OWNER_REQUESTS.md).

## Not verified yet
- Only a manual smoke test on one Android phone; integration_test not run (V1-CI-04).
- iOS app not run on simulator/device.

## Known gaps
1. Authoring sandbox cannot run Flutter – all evidence is from GitHub Actions.
2. Release build signs with debug key (D-013) – do not distribute.
3. App IDs provisional (D-012).
4. Hark's GitHub App cannot dispatch workflows (no actions:write) – trigger CI by pushing.

## Next task
M2 – P0 spike: EPUB/TXT/DOCX parse probes, Hindi PDF font probe, provider ping (BYOK), each behind tests.
