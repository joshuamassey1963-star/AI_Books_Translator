# Project Memory: AI Books Translator

**Snapshot:** 2026-11-07 (updated end of Session 11). **Repository:** https://github.com/joshuamassey1963-star/AI_Books_Translator
**Purpose:** A durable, public, project-only knowledge base for a new AI coding agent, engineer, maintainer or reviewer. This is **not** a dump of any private AI/user memory. Cross-check all changeable facts with current GitHub state before acting.

> Quick start: Read root [AGENTS.md](../AGENTS.md) first; then this file, [SESSION_LEDGER.md](SESSION_LEDGER.md), the existing [ROADMAP.md](ROADMAP.md), [FEATURE_MATRIX.md](FEATURE_MATRIX.md), [DECISIONS.md](DECISIONS.md), [HANDOVER.md](HANDOVER.md), and [REGRESSION_CASES.md](REGRESSION_CASES.md). The ledger is a historical snapshot, **not** live branch state.

## 1. Vision / scope
Build a Flutter Android/iOS application to translate **entire books**, initially English → Hindi, chapter by chapter, keeping structure and terminology consistent. Accept PDF, EPUB, DOCX and TXT; preserve headings, paragraphs, images where supported, footnotes, scripts quoted for explanation, and English or source-language words intentionally protected from translation. Source files are immutable. Users can define a custom dictionary, style and translation instructions; review and edit the output; resume long-running jobs; and export translated books as DOCX, PDF, EPUB or TXT.

**Localization-specific invariants:** Hindi translation is in Devanagari; numerical digits may be kept in English (0–9) by user preference; Greek, Hebrew, Sanskrit and other quoted source-language forms should stay in their original script when being explained or compared. Do **not** apply these constraints as blind global replacements. The glossary, protected terms and book-level instructions must enforce them in translation/validation.

Other scoped features, not all in V1:
- **V1:** offline-first local library, structured import, Unicode normalization, AI-provider-independent adapter with user-provided keys, glossary/instructions, safe chunking/checkpoints, editor, export, basic system/paste translation, basic Android/iOS device read-aloud, background reading, BYOK AI-TTS *configuration architecture*. See [OWNER_REQUESTS.md](OWNER_REQUESTS.md), [READ_ALOUD_TTS.md](READ_ALOUD_TTS.md).
- **V2:** advanced OCR, additional system share/selected text entry points, URL/article translation, actual online AI-TTS audio generation/caching/export, highlighting; see [SYSTEM_TRANSLATION.md](SYSTEM_TRANSLATION.md).
- **V3:** optional, privacy-reviewed accessibility-driven workflows, more complex website translation, advanced voice/sync/customization. There is no guaranteed universal cross-app access.

All requirements must be tracked in FEATURE_MATRIX.md with unique IDs, version, test evidence and truthful status. Do not invent support for a feature merely because it appears in ROADMAP.

## 2. Architecture and code
- Flutter/Dart, Riverpod, go_router; Android + iOS builds in GitHub Actions.
- Existing shell navigation: Home / Library / Translate / Tasks / More. Placeholder screens are intentional; do not market them as working features.
- Parsing engine: `lib/features/engine/parser/` for TXT/EPUB/DOCX, ZIP/XML safety limits, BookDocument, SHA-256.
- PDF engine: `lib/features/engine/pdf/` with `pdfrx`/PDFium, text runs/coordinates/page metadata, structure scanner (font dictionaries, ToUnicode presence) and layout/quality gate. PDF-only/image-only diagnostics and OCR *interface* exist; actual OCR recognition does not.
- Encoding/Unicode: `lib/features/engine/text/`, strict UTF-8/UTF-16 + BOM handling, conservative no-BOM handling, NFC helper, no NFKC. Original bytes preserved.
- Legacy font: `lib/features/engine/legacy/`: **Kruti Dev 010** mapping using SIL MIT-licensed map, explicit confirmed-font-only conversion. Does not auto-apply to pages, does not prove Chanakya works, does not preserve all mixed-font spans yet.
- Debug diagnostics: `lib/features/dev_tests/` (encoding, Kruti Dev, TXT parser/file picker) and build identity via More. **Debug-only tools are not production import UI.**
- PDF export probes: `lib/features/export/pdf_probe/` (Engine A, merged via PR #8) and Engine B Android native probe (`engine_b_android_native.dart` + `android/.../NativePdfProbe.kt`, method channel `ai_book_translator/pdf_probe`, no UI) on `feature/m2b-3b-1-shaped-pdf-poc`. Harness: `tool/pdf_probe/` (verify.py, visual review JSON per engine).
- Planned translation layers: L0 raw extraction; L1 normalized Unicode; L2 user-corrected source; L3 AI translation; L4 edited translation. Keep each separate; the TTS design consumes validated L2/L1 or L4/L3 only.

Technical decisions, contracts, and architecture diagrams in existing docs take priority over short summaries here. Some older PROGRESS/HANDOVER sections are stale; inspect dated sections and actual HEAD.

## 3. Verified GitHub state at snapshot

| Item | Snapshot / evidence |
| --- | --- |
| Integration branch | `develop` = `19f3630` (merge of PR #8), after `74606e6` (merge of PR #9); develop CI runs 42365226139 and 42365707590 succeeded |
| Protected by owner instruction | `main` = `882ff87fa8fc9e8c5d8a6dbd594182a8dd22cdd0`; never merge without explicit permission |
| PR #8 | M2b-3a Engine A probe merged as `19f3630` (head `527a3e7`) |
| PR #9 | Project memory files merged as `74606e6` (head `e1637d6`) |
| Open feature branch | `feature/m2b-3b-1-shaped-pdf-poc` (M2b-3b-1), PR into `develop`, **not merged**; see HANDOVER Session 11 for its PR number and CI |
| Feature Matrix | 187 IDs: 4 VERIFIED, 30 IN PROGRESS, 153 PLANNED (unchanged in S11); not a completion percentage |
| UI APK | Last meaningful debug feature build **0.1.1+2**, TXT picker; no APK published in S10/S11 |
| Memory risk | New sessions must read current refs, review open PRs, and check current CI instead of assuming the rows here remain current |

### Critical engineering result (D-027)
M2b-3a evaluated Dart `pdf` 3.13.1 with pinned-hash OFL Noto fonts and 13 synthetic cases. It **FAILED Devanagari shaping** (i-matra order, conjuncts, reph/rakar, mark positioning, half forms); text extraction matched source in 11/13 cases, fonts were embedded with ToUnicode. Therefore **Engine A is rejected for production Hindi PDF export**. Do **not** call the export feature done or reintroduce untested manual glyph reordering. Evidence and visual comparisons are artifacts of run [42203433139](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42203433139), artifact `pdf-export-probe-engine-a`; see D-027 and PR #8.

### Engineering result (D-028, M2b-3b-1)
Engine B = Android `PdfDocument` + `StaticLayout` (OS HarfBuzz shaping, system Noto fonts), 3 cases on an Android 14 emulator, run [42367039900](https://github.com/joshuamassey1963-star/AI_Books_Translator/actions/runs/42367039900): **glyphs visually correct 3/3, but `pdftotext` loses shaped Hindi glyphs 3/3** (किताब → कताब). Overall PARTIAL; rejected as-is. Likely cause: Skia PDF ToUnicode maps one glyph to at most one code point and writes no `/ActualText`. Next proposed: M2b-3b-2 HarfBuzz-shaped glyph writer with `/ActualText` (owner go needed).

### Open risks and blocked tasks
1. **Next engineering work is conditional:** review the M2b-3b-1 PR; then, only on owner go, **M2b-3b-2**: HarfBuzz-shaped glyph placement with a verified `/ActualText`/ToUnicode text layer, same 3 cases first. No working Hindi PDF engine exists yet (Engine A fails shaping, Engine B fails copy/search). iOS not evaluated.
2. **Chanakya / Walkman-Chanakya905 mapping (M2b-2b)** deferred pending verified owner-provided samples and legal mapping provenance. Never commit private sample books/fonts or invent mappings.
3. **M2b-2c** mixed-font confidence / span-specific application remains pending. PDF font info is currently mostly page-level, not reliable per run; do not auto-convert entire page.
4. **Issue [#7](https://github.com/joshuamassey1963-star/AI_Books_Translator/issues/7)**: `file_selector` reads accepted TXT file into memory. A 200 MB nominal limit does not bound peak memory. Track bounded/streaming read solution before claiming large-file readiness.
5. **M2b-4/5, M3–M11** are not complete: AI-provider mocks; real-book regressions; durable storage; production import UI; custom glossary/instructions; provider integration; chunked translation/recovery; editor; export; system TTS/release checks.
6. PDF reading order quality thresholds, ToUnicode map content, scanned pages and unicode font behavior have been tested mostly with synthetic fixtures; no broad genuine-book validation. No OCR engine is implemented.
7. iOS has compiled without signing in CI; do not claim actual iOS device validation.

## 4. Working rules the owner explicitly chose
- One sub-milestone per coding session. Never start the next automatically.
- Commit and push incremental stable checkpoints with tests and docs; keep a short precise handover even if the session cuts off.
- Main branch untouched unless approved. Use feature branch + PR into develop, with merge only after checks.
- Be evidence-driven: report failures, false positives, missing tests and limitations, not flattering percentages. Implementation ≠ user-device verification.
- **APK policy:** Compile Android/iOS in CI as necessary; do not upload or recommend a user-testing APK for backend/docs/minor UI changes. Only publish on substantial visible UI/user feature change, with explicit changed-function list, exact built SHA/version/checksum/download link and manual checklist. Workflow uses `[publish-apk]` opt-in for upload (verify current YAML). Do not bump version for docs-only changes.
- Never upload private books, credentials, reference fonts without licensing or other personal data into this public repository.
- In owner communication use Hindi; filenames/code/technical docs may be English for portability.
- The project is expected to last months. Preserve context by updating the ledger and this index at each milestone, not by relying on an AI's transient chat context.

## 5. Resumption procedure for a new AI/developer
1. Read `AGENTS.md`, this file and `SESSION_LEDGER.md`. Then read the relevant detailed docs and existing source/tests.
2. Query current `develop`, `main`, open PRs (especially #8), Issues (especially #7), CI workflow and latest feature matrix. Resolve discrepancies between docs and GitHub before edits.
3. Restate the **single exact scope** plus exit criteria in an engineering plan. If owner instructions specify a go/no-go gate, honor it.
4. Implement on new feature branch from updated `develop`; preserve validated code, add negative tests, verify build/CI, commit and push frequently.
5. Open a PR into `develop`, do **not** auto-merge; report changes and reproducible evidence in Hindi.
6. Update [SESSION_LEDGER.md](SESSION_LEDGER.md), this file's snapshot/active-blockers section, `HANDOVER.md`, `ROADMAP.md`, `FEATURE_MATRIX.md`, `DECISIONS.md`, and `REGRESSION_CASES.md` as applicable. Carry forward unresolved risks instead of erasing them.
