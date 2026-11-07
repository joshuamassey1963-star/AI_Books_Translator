# Changelog

## [Unreleased]
### Added (Session 15 / M2b-3b-2c-2, 2026-11-07, no app version change)
- Engine C probe cases C04 (ZWJ), C05 (ZWNJ), C06 (composite glyph uni0906), default word+subset variant, composite subset checks and negative self-test (D-032). Not used by the app.
### Added (Session 14 / M2b-3b-2c-1, 2026-11-07, no app version change)
- PDF.js 4.10.38 vs 6.5.438 extraction, automated Firefox viewer check, probe-only ToUnicode experiments, interop regression gate, manual viewer checklist (D-031). Not used by the app.
### Added (Session 13 / M2b-3b-2b, 2026-11-07, no app version change)
- Engine C spike: three cases (C01–C03), two fonts, strict ToUnicode policy, word-level `/ActualText` option, hb-subset (retain-gids) with checks, strict comparison on Poppler, MuPDF, PDF.js and PDFium (D-030). Not used by the app.
### Added (Session 12 / M2b-3b-2a, 2026-11-07, no app version change)
- Engine C spike: `GlyphPdfWriter` (CID font, HarfBuzz glyph ids, `/ActualText` per cluster), structure check, host-side HarfBuzz fixture script, CI checks with qpdf. One case (`किताब`) passes end to end (D-029). Not used by the app.
### Added (Session 11 / M2b-3b-1, 2026-11-07, no app version change)
- Engine B probe: Android native PDF (`PdfDocument` + `StaticLayout`) behind the `ai_book_translator/pdf_probe` method channel (no UI), 3 PoC cases, CI job `pdf-export-probe-android` on an Android 14 emulator. Result: shaping correct, Unicode copy/search broken (D-028).
- Project memory files merged (AGENTS.md, docs/PROJECT_MEMORY.md, docs/SESSION_LEDGER.md; PR #9).
### Added (Session 10 / M2b-3a, 2026-11-06, no app version change)
- `PdfExportProbe` interface and Engine A probe (Dart `pdf` package) with 13 synthetic cases; CI job `pdf-export-probe` with poppler + HarfBuzz reference checks and artifact. Result: Engine A fails Devanagari shaping (D-027).
### Changed
- CI publishes the debug APK artifact only when the commit message contains `[publish-apk]` (owner APK policy). The APK is still built as a compile check.
### Added (Session 9 / M-DEV-02a, version 0.1.1+2, 2026-11-06)
- Developer Tests → TXT Parser: "Choose TXT File" (system document picker, no storage permission), size limit checked before reading, encoding choice for UTF-16 without BOM, file name/size/encoding/chapters/paragraphs/SHA-256/warnings, bounded scrollable preview with copy.
- More → About this build: version, build number, build type, commit SHA injected by CI (`--dart-define=GIT_SHA`).
- CI verifies APK version, permissions, embedded SHA and prints the signer certificate.
### Added (Session 8 / DEV-01, 2026-11-06)
- Debug-only Developer Tests screen (More → Developer Tests): text encoding inspection, Kruti Dev 010 conversion with copy, TXT parser diagnostics.
- CI: debug APK artifact named `ai-book-translator-<version>-debug-<sha>.apk`, size and SHA-256 in the run summary, kept 14 days.
### Added (Session 7 / M2b-2a, 2026-11-06)
- Kruti Dev 010 → Unicode converter (port of SIL KrutiDev010.map, MIT) behind `LegacyFontRegistry` (confirmed font only, no double conversion, warnings for unmapped characters).
### Added (Session 6 / M2b-1c, 2026-11-06)
- `EncodingDetector`: UTF-8 (BOM), UTF-16 LE/BE (BOM), BOM-less UTF-16 suggestion needing confirmation, explicit override, lossy preview, byte-offset diagnostics.
- `UnicodeNormalizer` (NFC per D-017, protected spans), dependency `unorm_dart` (MIT).
- `BookParser.parse(textEncoding:)` override; new `ParseErrorCode.encodingNeedsConfirmation`.
### Fixed
- RC-012: UTF-16 TXT with BOM was rejected as binary.
### Added (Session 5 / M2b-1b, 2026-11-06)
- `PdfLayoutAnalyzer`: words, lines, paragraphs from glyph boxes; two-column reading order; header/footer/page-number candidates.
- `PdfCharDiagnostics` + `ExtractionQualityGate`: FFFD, control, PUA, ligature, duplicate-glyph, Latin-1 signals; score 0–100; pass/warn/block.
- `PdfPageInfo.glyphs` (per-character boxes from PDFium).
- 21 new tests (84 total).
### Docs (Session 5)
- System-wide translation and Read Aloud/TTS specifications (29 planned IDs), D-022..D-024.
### Added (Session 4 / M2b-1a, 2026-11-06)
- `PdfTextSource` interface and `PdfrxTextSource` (pdfrx/PDFium): text runs with page number and coordinates, page size, SHA-256, original bytes untouched.
- `PdfStructureScanner` (pure Dart): page fonts (BaseFont, subset prefix, embedded, ToUnicode, encoding, mapping risk), image XObjects, inline images, text operators, form XObjects, object streams.
- Page status `textLayer / imageOnly / textNotExtractable / blank / unknownNoText`; scanned-PDF and missing-text-layer detection.
- `OcrEngine` interface + `UnavailableOcrEngine` (no OCR in V1).
- 29 new tests on generated PDFs (63 total). CI downloads PDFium for host tests.
### Added (Session 3 / M2a, 2026-11-06)
- Parser spike: TXT, EPUB 2/3 and DOCX → `BookDocument` (chapters, headings, paragraphs, stable block ids, SHA-256).
- Import hardening: magic-byte detection, size/entry/ratio limits, path-traversal and XXE blocking.
- 20 parser unit tests with in-memory fixtures (no copyrighted files in repo).
- Autoformat helper workflow (`format/**` branches).
### Changed
- Dart SDK constraint ^3.13.0 (required by `xml` 7.1.0); Flutter >=3.47.0.

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
