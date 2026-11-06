# Changelog

## [Unreleased]
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
