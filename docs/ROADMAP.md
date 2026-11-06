# Roadmap & Milestones

Requirements source: `docs/AI_Book_Translator_Roadmap_V1_V3.pdf` (03 Nov 2026). Feature IDs: `docs/FEATURE_MATRIX.md`. One milestone per session; each ends with tests, docs, commit, push, handover.

| # | Milestone | Scope (feature IDs) | Exit criteria | Status |
|---|---|---|---|---|
| M0 | Foundation (Session 1) | V1-NAV-01/02, V1-CI-01/02, docs | Shell + tests written; CI green on GitHub | DONE (CI run 42146771459) |
| M1 | Platform folders + CI green | commit android/ & ios/, first CI run, format pass | `flutter analyze` + `flutter test` green in CI; debug APK artifact | DONE (CI run 42149165709) |
| M2a | P0 spike: parsers | TXT/EPUB/DOCX → BookDocument, zip/XML hardening | parser unit tests green in CI | DONE (CI run 42152743112) |
| M2b-1 | PDF extraction + font/encoding diagnostics | V1-PDF-01/04/05/07, V1-OCR-01..04, V1-ENC-01..03/05 | see M2b-1a..c below | IN PROGRESS – M2b-1a DONE (run 42158726040); 1b, 1c next |
| M2b-2 | Legacy font mapping + Unicode conversion prototype | V1-LEG-01..08 | see M2b-2a..c | PLANNED |
| M2b-3 | Hindi PDF export + shaping verification | V1-EXP-04/06/07, V1-FNT-01/02/05 (partial) | see M2b-3a..c | PLANNED |
| M2b-4 | AI provider adapter + mock connection tests | V1-AIP-01/03/04 (interface + mocks) | see below | PLANNED |
| M2b-5 | Real-book regression tests + integration review | REGRESSION_CASES RC-001..015 | see below | PLANNED |
| M3 | V1-A Storage | V1-STO-01/02/04, V1-SEC-01, V1-SET-01 | Schema + migration tests; secure-storage test | PLANNED |
| M4 | V1-B Import | V1-IMP-01..07, V1-SEC-02, V1-LIB-01/02 | Content order + corrupt/malicious file tests | PLANNED |
| M5 | V1-C Glossary & Instructions | V1-GLO-01..07, V1-INS-01/02 | Glossary unit tests incl. conflicts, protected terms | PLANNED |
| M6 | V1-C Provider adapters | V1-AIP-01..08, V1-SEC-03 | Adapter tests with mocked HTTP for every error code | PLANNED |
| M7 | V1-C Chunking & pipeline | V1-ENG-01/02/07/08/09 | EN→HI on 3 sample chapters, structural validator tests | PLANNED |
| M8 | V1-D Queue & recovery | V1-ENG-03..06, V1-TSK-01..05, V1-ERR-01/02 | Force-stop, 429, offline recovery tests | PLANNED |
| M8b | V1 System translation (basic) | V1-STR-01/02 | Paste translation + background recovery tests (Android kill/resume; iOS pause honesty) | PLANNED |
| M9 | V1-E Editor | V1-EDT-01..03 | Alignment + autosave tests | PLANNED |
| M10 | V1-E Export | V1-EXP-01..05 | Hindi fonts, paragraph alignment, re-open tests | PLANNED |
| M10b | V1 Read Aloud TTS-1 | V1-TTS-01/03/04/05 | Fake-engine unit tests, layer-selection tests, Android Hindi+English device check | PLANNED |
| M10c | V1 Read Aloud TTS-2 | V1-TTS-06/07/09 | Position resume, interruption state machine, background device checklist | PLANNED |
| M10d | V1 Read Aloud TTS-3 | V1-TTS-02/08 | iOS speech check; BYOK config tests, no-network + no-auto-paid tests | PLANNED |
| M11 | V1 Release | V1-REL-01/02, V1-PRF-01/02, V1-CI-03/04 | Acceptance checklist signed off on real devices | PLANNED |
| M12+ | V2 | V2-* (incl. M13a–d system translation entry points V2-STR-01..07 after policy review; M14a–c AI TTS V2-TTS-01..06) | OCR benchmark + quality metrics | PLANNED |
| M20+ | V3 | V3-* (incl. M21 V3-STR-01/02 if policy review passes; M22 V3-TTS-01..03) | Device / cost / privacy validation | PLANNED |

## M2b – detailed plan (owner restructuring, 2026-11-06)

Order: M2b-1 → M2b-2 → M2b-3 → M2b-4 → M2b-5. One sub-milestone (or one lettered part) per session. Large parts are split into a/b/c. Each part follows the code workflow in HANDOVER.md and ends with CI evidence.

### M2b-1 PDF extraction and font/encoding diagnostics
- **Scope:** `PdfTextSource` interface; first engine adapter (candidate `pdfrx`/PDFium – license and CI feasibility checked first); per-run font metadata (name, subset prefix, embedded, ToUnicode present); diagnostics report; scanned/garbled page detection; encoding fixes for TXT.
  - **M2b-1a** engine evaluation + interface + text runs with coordinates/fonts + scanned-page detection + `OcrEngine` interface (no engine).
  - **M2b-1b** word/paragraph boundaries, reading order basics, header/footer detection, repeated/missing char + ligature + PUA diagnostics, quality score + gate.
  - **M2b-1c** UTF-16 LE/BE + BOM detection (fixes RC-012), NFC policy helper, encoding preview API.
- **Dependencies:** M2a parser (done). No storage needed (in-memory result objects).
- **Acceptance criteria:** generated test PDFs (our own text, OFL fonts) extract with correct Unicode and word boundaries; a PDF without ToUnicode is flagged; an image-only PDF yields `OCR required`; UTF-16 TXT decodes.
- **Automated tests:** unit tests on PDFs generated in CI/test setup (no copyrighted files); diagnostics thresholds; encoding cases EN01–EN07, EN11, EN12, EN14.
- **Manual tests:** owner opens 2–3 of his own PDFs in a debug screen (later) – only after automated tests pass.
- **Known limitations:** tables, footnotes, complex multi-column layouts only flagged, not reconstructed; no OCR engine.
- **Exit criteria:** CI green; RC-005/006/007/008/012/013 have tests (PASS or documented FAIL); FEATURE_MATRIX updated honestly.

### M2b-2 Legacy font mapping and Unicode conversion prototype
- **Scope:** legacy font registry; converter pipeline (substitution → reordering → NFC); confidence; mixed-font spans.
  - **M2b-2a** Kruti Dev 010 table + reordering rules + synthetic tests (RC-002, RC-003).
  - **M2b-2b** Chanakya / Walkman-Chanakya905 table – needs owner sample documents (kept outside git) (RC-001).
  - **M2b-2c** confidence scoring, mixed-font paragraph handling, English/digit protection (RC-004), unsupported-mapping warnings.
- **Dependencies:** M2b-1a font metadata per span.
- **Acceptance criteria:** synthetic legacy strings convert to expected Unicode; a table never runs on another font; English words/digits unchanged; raw and converted both available.
- **Automated tests:** table-driven unit tests per font; negative tests (wrong font, unknown chars).
- **Manual tests:** owner compares conversions of his private sample PDFs; results recorded in TEXT_ENCODING_FONT_COMPATIBILITY.md §6.
- **Known limitations:** only fonts with a built table; tables derived without copying GPL data, so coverage grows over time.
- **Exit criteria:** CI green; RC-001..004 status recorded with evidence.

### M2b-3 Hindi PDF export and shaping verification
- **Scope:** probe engines A–D from TEXT_ENCODING_FONT_COMPATIBILITY.md §8 with test strings T01–T11.
  - **M2b-3a** Engine A (`pdf` package + bundled Noto Serif Devanagari): CI generates PDF + PNG renders (pdftoppm) + `pdftotext`/`pdffonts` checks as artifacts.
  - **M2b-3b** one alternative prototype (native platform PDF or HarfBuzz-shaped path), chosen from 3a results.
  - **M2b-3c** comparison table X01–X10, decision record; owner visual check on Android + iOS.
- **Dependencies:** V1-FNT-02 license check for the bundled font.
- **Acceptance criteria:** X01–X10 all PASS for the chosen engine; otherwise the export stays "not production-ready".
- **Automated tests:** CI text round-trip (X06/X07), font embedding (X08); rendered PNG artifacts for review.
- **Manual tests:** owner visual check of PNGs and on-device PDFs (X01–X04, X10).
- **Known limitations:** visual correctness cannot be fully automated; golden images only after a human-approved baseline.
- **Exit criteria:** decision recorded (D-019 updated) with evidence.

### M2b-4 AI provider adapter and mock connection tests
- **Scope:** provider-independent adapter interface, error taxonomy (401/403/429/timeout/quota/network/model unavailable), model list fetched from provider (no hardcoded names), mock HTTP tests; optional manual BYOK ping by owner.
- **Dependencies:** none (pure Dart + `http` mock).
- **Acceptance criteria:** every error code mapped and tested with mocks; no key in repo, logs or CI.
- **Automated tests:** mocked HTTP for each provider type and error.
- **Manual tests:** owner pastes his own key in a debug build (later, when secure storage exists – M3) or via a local-only test.
- **Known limitations:** no real network calls in CI.
- **Exit criteria:** CI green; V1-AIP-01/03/04 IN PROGRESS with evidence.

### M2b-5 Real-book regression tests and integration review
- **Scope:** run TXT/EPUB/DOCX/PDF pipeline on owner-supplied real books (never committed); fill REGRESSION_CASES and the font matrix with results; review M2a+M2b code as a whole.
- **Dependencies:** M2b-1..4.
- **Acceptance criteria:** roadmap M2 exit – 2 chapters of a sample book import/export correctly; every RC case has a status with evidence.
- **Automated tests:** synthetic equivalents of each real-book failure.
- **Manual tests:** owner runs the debug APK on his books.
- **Known limitations:** results depend on the owner's sample set.
- **Exit criteria:** M2 marked DONE only with evidence; otherwise remaining gaps carried into M4 with IDs.
