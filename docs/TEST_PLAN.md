# Test Plan

## Levels
| Level | Tool | Where | Now |
|---|---|---|---|
| Unit | flutter_test | `test/unit/` | screen registry, FeatureStatus |
| Widget | flutter_test | `test/widget/` | launch, tabs, More sub-screens, per-tab stacks, Book Details route, no dead buttons/fake progress |
| Integration | integration_test | `integration_test/` | cold start (written; needs emulator, not run) |
| Static | flutter analyze, dart format | CI | configured |

## Corpus (roadmap §13, to be assembled in M2)
Public-domain novel, religious/philosophical book, technical book with footnotes/tables, 1000+ page book, broken PDF, scanned PDF. Hindi checks: conjuncts, matras, digits, mixed English, Unicode normalization, font embedding, copy/search. Glossary: 100+ terms incl. aliases, ambiguous terms, protected names, conflicts, chapter-boundary consistency.

## Text, font, encoding and export tests (owner requirements 2026-11-06)
- Matrices and test strings: `docs/TEXT_ENCODING_FONT_COMPATIBILITY.md` (40 Hindi + 20 English fonts, encoding cases EN01–EN14, test strings T01–T11, PDF export checks X01–X10).
- Regression cases from the old reader project: `docs/REGRESSION_CASES.md` (RC-001..015).
- Test PDFs are **generated** (our own text + OFL fonts) in test setup or CI; legacy-font samples and real books stay outside git and are run manually by the owner.
- CI tools for export checks (planned M2b-3): `pdftotext`, `pdffonts`, `pdftoppm` (poppler) on the Ubuntu runner; rendered PNGs uploaded as artifacts for visual review.
- Legacy conversion: table-driven unit tests per font + negative tests (wrong font, unknown chars, English/digits untouched).
- A font row becomes PASS only with a CI run id or a dated owner check per column.

## System translation and Read Aloud tests (planned, Session 5 requirements)
- Paste translation: paragraph count in == out, protected words, NFC, provider error mocks (401/429/timeout), cancel.
- Background: process kill → resume without re-billing completed chunks (Android emulator); iOS "paused in background" state.
- Entry points (V2): fake share / PROCESS_TEXT intents; no clipboard read without a user tap (code-path test); URL import with synthetic HTML fixtures, size/time/redirect limits.
- TTS: fake-engine contract tests; `TextSourceSelector` refuses L0/unvalidated OCR/legacy; sentence splitter (danda, abbreviations, numbers, mixed script) with "chunks concatenate to source"; position store + edit anchoring; audio-focus/interruption state machine; log scrubber proves keys never logged; no auto-switch to paid.
- Manual device checklists: Android Hindi + English voices, call/alarm/Bluetooth interruptions, screen off 30 min; iOS speech voices.

## Developer Tests screen (DEV-01, debug builds only)
- Unit: `test/unit/dev_tests/dev_diagnostics_test.dart` – UTF-8/UTF-16 BOM decode, BOM-less UTF-16 needs confirmation + override, invalid UTF-8 refused, NFC shown separately, Kruti Dev examples, wrong font refused, TXT parse + error codes.
- Widget: `test/widget/dev_tests_screen_test.dart` – More entry opens screen, encoding status, Kruti Dev refusal then conversion, TXT parse, disabled file-picker item.
- Manual (owner, phone): install CI debug APK → More → Developer Tests → checklist in HANDOVER.md.
- Release exclusion: route and More row are behind `kDebugMode` (compiled out of release); verify when release builds exist (D-013).

## Real TXT file picker (M-DEV-02a)
- Unit `test/unit/dev_tests/txt_file_diagnostics_test.dart`: UTF-8, Hindi+English, UTF-16 LE/BE BOM, BOM-less UTF-16 needs choice, invalid encoding, empty, oversized (checked before read), bounded preview, binary failure, bytes unchanged, manifest has no storage permission.
- Widget `test/widget/txt_file_picker_test.dart` with a fake `TxtFilePicker`: metadata + preview, UTF-16 BOM, encoding choice, invalid, empty, oversized without reading, cancel, picker failure, build info (no SHA invented in tests).
- CI `Verify APK metadata`: aapt2 badging (versionCode/versionName), aapt2 permissions (fails on storage permissions), GIT_SHA present in the APK, signer certificate printed.
- Manual: owner picks real TXT files on the phone (checklist in HANDOVER.md).

## Hindi PDF export probe (M2b-3a)
- Unit `test/pdf_probe/engine_a_probe_test.dart`: probe case ids, NFC, coverage of ZWJ/ZWNJ/halant/i-matra/reph/digits/Greek/Hebrew. The generation test is skipped unless `PDF_PROBE_FONT_DIR` and `PDF_PROBE_OUT_DIR` are set.
- CI job `pdf-export-probe`: fetches OFL Noto fonts (`tool/pdf_probe/fetch_fonts.sh`, SHA-256 pinned), writes one PDF per case plus the source text separately (`expected/`), then `tool/pdf_probe/verify.py` runs pdftotext/pdffonts/pdftoppm, makes a HarfBuzz reference image per case (`compare/`), and writes `report.json`/`report.md`. Artifact `pdf-export-probe-engine-a`.
- Visual verdicts come only from a person (`tool/pdf_probe/engine_a_visual_review.json`); without a review a case stays NEEDS_REVIEW.

## Shaped PDF export PoC (M2b-3b-1, Engine B Android native)
- Unit `test/pdf_probe/engine_b_channel_test.dart`: pinned code points of the 3 PoC strings; method channel receives the text unchanged; empty result → error; no handler (iOS/host) → UnsupportedError; native error passed on.
- Integration `integration_test/pdf_probe_android_test.dart` runs on an Android 14 emulator in CI job `pdf-export-probe-android` (reactivecircus/android-emulator-runner). PDFs go into a manifest saved to Downloads (survives the test uninstall) and are pulled with adb. The emulator's own fonts are pulled so the HarfBuzz reference uses the same fonts.
- `verify.py` reports `overall`: PASS only when visual is PASS **and** extraction is exact; otherwise PARTIAL/FAIL. Visual verdicts in `tool/pdf_probe/engine_b_android_native_visual_review.json`. Artifact `pdf-export-probe-engine-b-android`.

## Engine C spike (M2b-3b-2a, HarfBuzz + /ActualText)
- Unit `test/pdf_probe/glyph_pdf_writer_test.dart` (no font needed; committed HarfBuzz output `test/fixtures/pdf_probe/c01_kitab.hb.json` and expected text `c01_kitab.txt`): exact code points; cluster → source mapping (`कि`, `ता`, `ब`) with the i-matra glyph first; UTF-16BE + BOM encoding incl. a surrogate pair; balanced BDC/EMC, one span per cluster, source text exactly once; run/none scopes; structural check of the written PDF; broken PDFs rejected; unmapped/out-of-range/non-monotonic clusters and bad glyph ids throw; glyph list immutable, source text unchanged.
- CI (job `pdf-export-probe`): uharfbuzz 0.57.0 shapes the fixture with the pinned font and must equal the committed fixture; `test/pdf_probe/engine_c_spike_test.dart` writes 3 PDFs (per-cluster span, one span, control without span); `verify.py` runs qpdf --check, pdftotext, pdffonts, pdftoppm + raqm reference. Artifact `pdf-export-probe-engine-c-spike`. `overall` needs visual PASS + exact text + qpdf ok.

## Engine C three cases (M2b-3b-2b)
- Unit `glyph_pdf_writer_test.dart` (fixtures C01–C03, fake sfnt fonts): exact code points; C02 ligature/e-matra ranges; C03 font runs, reph order, digits; span coverage for every case and scope; `checkActualText` negatives (duplicate, nesting, non-BOM text, glyph outside span, stray EMC); strict vs cmapAll ToUnicode; two-font PDF structure; empty/too-small font refused; `.notdef`, bad cluster, uncovered start, unknown font, cluster split across fonts; immutability; word scope grouping.
- CI `pdf-export-probe`: `hb_shape_fixture.py --subset` (+ `--self-test-subset` negative), fixture equality, `engine_c_spike_test.dart` (full, subset, word, 2 controls), `engine_c_pdfium_extract_test.dart` (PDFium), `pdfjs_extract.mjs` (PDF.js), `verify.py` (qpdf, render, raqm reference, pdffonts) and `extract_compare.py` (strict Poppler/MuPDF/PDF.js/PDFium comparison, subset pixel comparison, fonts-report, tools). Artifact `pdf-export-probe-engine-c-3cases`.
- Not covered: interactive viewer search/copy (needs a person or a scripted browser), composite glyphs, wrapping.

## PDF reader interoperability (M2b-3b-2c-1)
- CI: pdfjs-dist 4.10.38 + 6.5.438 getTextContent (+ includeMarkedContent dump), real Firefox viewer via Selenium (copy handler + find, screenshots), probe experiments (`cluster_cid_experiment.py`), regression gate `interop_expectations.json` (fails CI if an EXACT extractor regresses).
- Manual: `docs/PDF_VIEWER_MANUAL_TEST.md` for Chrome, Acrobat, Android (not automatable here).

## Engine C C04–C06 (M2b-3b-2c-2)
- C04 ZWJ, C05 ZWNJ, C06 composite (आज, uni0906). Variants: full, subset, word, word_subset (default). Composite check + `--self-test-composite` negative test. Gate entries in `interop_expectations.json`.

## PDF.js candidate gate (M2b-3b-2c-3, D-033)
- `tounicode_candidate.py` writes `<case>_cand`, `<case>_cand0` (control) and MuPDF last-glyph controls; CI self-checks the mapping rule. `candidate_verdict.py` compares candidate vs default per extractor (exact code points), checks stop conditions (Poppler/MuPDF/PDFium EXACT, no duplicates, render unchanged, qpdf) and writes `candidate_verdict.json/.md`.

## Reliability scenarios
Airplane mode, network flapping, 429/503, app kill, device reboot, storage full, low RAM, cancel/resume.

## Rule
A feature becomes VERIFIED only when its tests pass in CI (and on real devices where the roadmap requires). Current evidence: see PROGRESS.md (latest green run 42152743112, 34/34 tests).
