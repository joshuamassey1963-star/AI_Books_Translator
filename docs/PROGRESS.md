# Progress

- **Current version:** 0.1.0+1 (V1, pre-alpha)
- **Current milestone:** M2b-1a – **DONE**, merged into develop via PR #1 (merge commit d29b0cd). Session 5: system translation + TTS requirements recorded (184 features); M2b-1b merged (PR #2, d7e9601). M2b-1c merged (PR #3, ca887a5). Session 7: M2b-2a Kruti Dev 010 converter on feature branch, PR #4 (run 42174654507: 130/130). Next: M2b-2b only after go + owner samples.
- **Last verified code commit:** `85ce46b` (feature/m2b-1a-pdf-text-source) – run 42158726040: format ✅, analyze ✅, `flutter test` 63/63 ✅, Android debug APK ✅, iOS unsigned ✅.
- **Previous:** `c2dbf7c` – GitHub Actions run 42152743112: format ✅, `flutter analyze` no issues ✅, `flutter test` 34/34 ✅ (14 shell + 20 parser), Android debug APK ✅, iOS unsigned build ✅.

## VERIFIED (automated CI evidence)
- V1-NAV-01 bottom navigation shell
- V1-NAV-02 honest Planned placeholders
- V1-CI-01 CI analyze + tests (+ blocking format check)
- V1-CI-02 Android debug APK in CI

## In progress (code + unit tests exist, feature not complete)
- V1-NAV-03 Home (empty state only)
- V1-CI-03 iOS build verified (debug, unsigned); release builds + SHA-256 pending
- V1-IMP-01 EPUB, V1-IMP-02 TXT/DOCX, V1-IMP-04 structure, V1-IMP-05 sniffing/limits, V1-IMP-06 SHA-256, V1-IMP-07 chapters, V1-SEC-02 hardening, V1-IMP-03/V1-PDF-01/V1-PDF-04/V1-OCR-01/V1-OCR-03 (M2b-1a) – engine only; no import screen, no storage, not tried on real books yet

## Manual smoke test
- 2026-11-06: owner installed the debug APK on an Android phone; navigation shell and placeholders work as designed (see docs/OWNER_REQUESTS.md).

## Not verified yet
- PDF engine tried only on generated PDFs; no real/owner PDFs; no import UI; PDF not wired into BookParser.
- Parsers not run on real-world EPUB/DOCX books (only in-memory fixtures).
- Hindi PDF export, AI providers: not started.
- integration_test not run (V1-CI-04); iOS app not run on simulator/device.

## Known gaps
1. Authoring sandbox cannot run Flutter – all evidence comes from GitHub Actions (format via autoformat workflow, D-015).
2. Release build signs with debug key (D-013) – do not distribute.
3. App IDs provisional (D-012).
4. TXT import accepts UTF-8 only (D-014).

## Next task
M2b – see HANDOVER.md.
