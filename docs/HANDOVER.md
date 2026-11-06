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

## Next exact task – M2b-1b (only after owner/tech-lead go)
1. Word/paragraph boundaries from char boxes (RC-005), reading-order basics + header/footer detection (RC-006), repeated/missing char, ligature and PUA diagnostics (RC-007, RC-014), extraction quality score + gate (V1-PDF-07, V1-OCR-02 garbled text).
2. Evaluate per-run font via PDFium FFI (`FPDFText_GetFontInfo`) behind pdfrx's worker; keep scanner as fallback.
3. Tests on generated PDFs only. Same branch workflow.

## Commands to resume
```bash
git clone https://github.com/joshuamassey1963-star/AI_Books_Translator.git
cd AI_Books_Translator && git checkout develop
flutter pub get && flutter analyze && flutter test
```
