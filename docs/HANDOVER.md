# Handover

- **Session:** 3 – M2a done (2026-11-06)
- **Current branch:** `develop` (`main` = owner README only; merge needs owner approval)
- **Commits:** S1: 61258d5, f3ce938, 529643f, 7f5f048 · S2: e5fc6bb, f63a95d, a552f0f, 0602b55, 988e9c2 · S3: a0bb6ac, b75d727, c2dbf7c, + docs commit
- **Push status:** ✅ pushed to `origin/develop` (github.com/joshuamassey1963-star/AI_Books_Translator). `main` untouched.

## Files
pubspec.yaml, analysis_options.yaml, lib/main.dart, lib/app/{app,router,theme,screen_registry}.dart, lib/core/feature_status.dart, lib/features/{shell,home,more,planned}/…, test/unit/screen_registry_test.dart, test/widget/navigation_shell_test.dart, integration_test/app_launch_test.dart, android/, ios/, pubspec.lock, .github/workflows/ci.yml, README, LICENSE, CHANGELOG, CONTRIBUTING, SECURITY, .gitignore, docs/*.

## Tests
- GitHub Actions run 42146771459 on `529643f`: ✅ `flutter analyze` – No issues found · ✅ `flutter test` – 14/14 passed (9 unit, 5 widget) · ✅ `flutter build apk --debug` · ⚠️ `dart format` would change 4 files.
- Not run: integration_test (needs emulator), iOS build.

## Known issues / risks
- `dart format` not applied; CI format step is warning-only until M1.
- Java 21 chosen for Android CI build; adjust if the generated Gradle setup needs another JDK.
- integration_test needs an emulator job (not in CI yet).

## Incomplete work
- None for M0.

## Session 3 (M2a) summary
- Branch `feature/m2-parsers`: b75d727 parser spike, c2dbf7c `dart format` (bot via autoformat workflow), + docs commit; fast-forwarded into `develop` after CI.
- Code: `lib/features/engine/parser/` – book_document, parse_exception, import_limits, safe_zip, safe_xml, txt_parser, epub_parser, docx_parser, book_parser (entry point `BookParser().parse(bytes, fileName:)`).
- Tests: `test/unit/engine/parser/book_parser_test.dart` (20 tests), fixtures built in memory by `test/support/book_fixtures.dart`.
- CI run 42152743112 on c2dbf7c: format ✅ analyze ✅ tests 34/34 ✅ Android APK ✅ iOS build ✅.
- Owner requests logged in docs/OWNER_REQUESTS.md (Day/Night/Sepia, rotation, work history, login).

## Requirements update (after M2a, 2026-11-06)
- Owner added text/font/encoding/OCR/export/image requirements: 50 new feature IDs, 8 existing IDs annotated (FEATURE_MATRIX now 155). New docs: TEXT_ENCODING_FONT_COMPATIBILITY.md, REGRESSION_CASES.md. Decisions D-016..D-020. Docs-only commit; no code changed.

## Session 4 (M2b-1a) summary
- Branch `feature/m2b-1a-pdf-text-source`, PR into `develop` (draft for review). Code: `lib/features/engine/pdf/` (pdf_models, pdf_text_source, pdf_structure_scanner, pdfrx_text_source), `lib/features/engine/ocr/ocr_engine.dart`. Tests: `test/unit/engine/pdf/`, `test/unit/engine/ocr/`, fixtures `test/support/pdf_fixtures.dart`.
- CI run 42158726040: format ✅, analyze ✅, 63/63 tests ✅, Android debug APK ✅, iOS unsigned ✅.
- Limitations: fonts page-level only; ToUnicode contents not validated; FlateDecode only; no garbled-text score yet; not integrated into BookParser (PDF still returns `pdfNotYetSupported` there); no import UI; no real PDFs tried.

## Session 5 – checkpoints A–C
- A: PR #1 merged into develop (merge commit d29b0cd); evidence runs 42159548254 (push) + 42159584549 (PR) on 69cfc6b, all green, 63/63.
- B/C: System-wide translation + Read Aloud/TTS requirements recorded (29 new IDs, docs only): docs/SYSTEM_TRANSLATION.md, docs/READ_ALOUD_TTS.md, D-022, D-023, ROADMAP M8b, M10b–d, V2/V3 milestones. No implementation.

## Session 5 – checkpoint D (M2b-1b)
- Branch `feature/m2b-1b-pdf-layout-quality`, PR #2 into develop (not merged). Code: `lib/features/engine/pdf/pdf_layout_analyzer.dart`, `pdf_quality.dart`, `PdfPageInfo.glyphs`. Tests: `pdf_layout_analyzer_test`, `pdf_quality_test`, `pdf_layout_pdfium_test`; fixtures `glyph_fixtures.dart`, `layoutPdf()`.
- CI run 42164277343: format ✅, analyze ✅, 84/84 ✅ (Android/iOS: see PR checks). Earlier run 42164083234 failed one test (paragraph gap with few lines) → fixed in 995cbce.
- Not done: tables/footnotes/>2 columns, per-run font FFI (investigated, D-024), threshold tuning on real books, integration into an import flow.

## Session 6 (PR #2 merge + M2b-1c)
- A: PR #2 merged into develop, merge commit d7e9601 (PR head 5b7cce1, runs 42164510713 + 42164649943 green). develop CI on d7e9601: run 42170637270 all green.
- B/C: branch `feature/m2b-1c-encoding`. Code: `lib/features/engine/text/text_encoding.dart`, `unicode_normalizer.dart`; `txt_parser.dart`, `book_parser.dart` (detectFormat + `textEncoding` override), `safe_zip.dart` (decodeXmlPart), `parse_exception.dart`. Tests: `test/unit/engine/text/*`, new group in `book_parser_test.dart`, fixtures `encoding_fixtures.dart`.
- CI run 42171138308 on 13c3f73: format ✅ analyze ✅ 112/112 ✅ Android ✅ iOS ✅.
- Not done: encoding UI (preview/confirm dialog), legacy 8-bit encodings (V1-ENC-04, M2b-2), NFC applied in storage (M3), zip-level EN06 fixture.

## Next exact task – M2b-2a (only after owner/tech-lead go; review/merge PR #3 first)
- Legacy font mapping prototype per ROADMAP M2b-2a. Chanakya/Kruti Dev samples only outside git.

## Commands to resume
```bash
git clone https://github.com/joshuamassey1963-star/AI_Books_Translator.git
cd AI_Books_Translator && git checkout develop
flutter pub get && flutter analyze && flutter test
```
